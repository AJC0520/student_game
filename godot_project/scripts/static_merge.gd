extends RefCounted
## Merges many static MeshInstance3D nodes into a few big meshes: one per cell of the ground plan and per material. This turns
## hundreds or thousands of draw calls into a handful without changing how anything looks. Triangles that belong to the
## outline-shader surfaces (the inverted-hull shells of the toon level) go into separate meshes that do not cast shadows.


## sources: the meshes to merge (they must be in the scene tree). host: where the merged meshes are added (its transform is
## taken into account). use_override_materials: true when the materials are surface overrides (level.gd), false for the
## mesh's own materials (glb props). free_sources: delete the originals instead of just hiding them (hide when they carry
## colliders that must stay).
static func merge(host: Node3D, sources: Array[MeshInstance3D], cell_size: float, use_override_materials: bool,
		shell_material: Material, free_sources: bool, merged_name: String = "Merged") -> int:
	var to_local := host.global_transform.affine_inverse()
	var cells: Dictionary = {}        # "cx,cz" -> { material -> {"v", "n", "i"} }
	for mi in sources:
		if mi.mesh == null:
			continue
		var xf := to_local * mi.global_transform
		var centre := (xf * mi.mesh.get_aabb()).get_center()
		var cell_key := "%d,%d" % [floori(centre.x / cell_size), floori(centre.z / cell_size)]
		if not cells.has(cell_key):
			cells[cell_key] = {}
		var cell: Dictionary = cells[cell_key]
		var normal_xf := Transform3D(xf.basis, Vector3.ZERO)
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(i) if use_override_materials else mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if verts.is_empty() or normals.size() != verts.size():
				continue
			if not cell.has(mat):
				cell[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "i": PackedInt32Array()}
			var bucket: Dictionary = cell[mat]
			var bucket_v: PackedVector3Array = bucket["v"]           # packed arrays are copied out of the dictionary: modify, then store back
			var bucket_n: PackedVector3Array = bucket["n"]
			var bucket_i: PackedInt32Array = bucket["i"]
			var base: int = bucket_v.size()
			bucket_v.append_array(xf * verts)
			bucket_n.append_array(normal_xf * normals)
			var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
			var indices := PackedInt32Array()
			if index_data is PackedInt32Array and not (index_data as PackedInt32Array).is_empty():
				indices = index_data as PackedInt32Array
			else:
				indices.resize(verts.size())
				for k in verts.size():
					indices[k] = k
			var shifted := PackedInt32Array()
			shifted.resize(indices.size())
			for k in indices.size():
				shifted[k] = indices[k] + base
			bucket_i.append_array(shifted)
			bucket["v"] = bucket_v
			bucket["n"] = bucket_n
			bucket["i"] = bucket_i
		if free_sources:
			mi.queue_free()
		else:
			mi.visible = false
	var created := 0
	for cell_key: String in cells:
		var solid := ArrayMesh.new()
		var shells := ArrayMesh.new()
		var cell: Dictionary = cells[cell_key]
		for mat: Material in cell:
			var bucket: Dictionary = cell[mat]
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = bucket["v"]
			arrays[Mesh.ARRAY_NORMAL] = bucket["n"]
			arrays[Mesh.ARRAY_INDEX] = bucket["i"]
			var target := shells if (shell_material != null and mat == shell_material) else solid
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			target.surface_set_material(target.get_surface_count() - 1, mat)
		for part: Array in [[solid, true, "Solid"], [shells, false, "Outline"]]:
			var mesh: ArrayMesh = part[0]
			if mesh.get_surface_count() == 0:
				continue
			var merged := MeshInstance3D.new()
			merged.name = "%s%s_%s" % [merged_name, part[2], cell_key.replace(",", "_").replace("-", "m")]
			merged.mesh = mesh
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(part[1]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			host.add_child(merged)
			created += 1
	return created
