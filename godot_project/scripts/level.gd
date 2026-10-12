extends Node3D
## Re-skins the glb exported from Blender with the toon / outline / glass shaders and builds collision.
## Imported materials are matched by name ("Toon_<Name>"); colours come from MaterialColors (generated from Blender).

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const GLASS := preload("res://shaders/glass.gdshader")
const MC := preload("res://scripts/material_colors.gd")

## Meshes whose node name starts with one of these get a trimesh StaticBody3D (world layer).
const COLLIDERS: Array[String] = ["Walls", "Floor", "Glass_Wall", "Railing", "Lift1_Leaf", "Online_Furn", "Ceil_"]

var _toon_cache: Dictionary = {}
var _outline_mat: ShaderMaterial
var _glass_mat: ShaderMaterial


func _ready() -> void:
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OUTLINE
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = GLASS
	_skin(self)


func _skin(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src: Material = mi.mesh.surface_get_material(i)
				var key := _material_key(src)
				match key:
					"Toon_Outline":
						mi.set_surface_override_material(i, _outline_mat)
					"Toon_Glass":
						mi.set_surface_override_material(i, _glass_mat)
					_:
						mi.set_surface_override_material(i, _toon_for(key, src))
			for prefix in COLLIDERS:
				if mi.name.begins_with(prefix):
					_add_collider(mi)
					break
	for child in node.get_children():
		_skin(child)


## Trimesh collider built from the visible surfaces only. The exported outline shells would double the
## triangle count and make walls ~3 cm thicker than they look (see the collision-proxy skill).
func _add_collider(mi: MeshInstance3D) -> void:
	var faces := PackedVector3Array()
	for i in mi.mesh.get_surface_count():
		if _material_key(mi.mesh.surface_get_material(i)) == "Toon_Outline":
			continue
		var arrays := mi.mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
		if index_data is PackedInt32Array and not (index_data as PackedInt32Array).is_empty():
			for vi: int in (index_data as PackedInt32Array):
				faces.append(verts[vi])
		else:
			faces.append_array(verts)
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()   # default layer 1 = "world"
	body.name = "Collider"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)


## Material name without glTF's duplicate suffix (".001" / "_2" are not used by us, trailing digits are stripped).
func _material_key(src: Material) -> String:
	if src == null:
		return ""
	return src.resource_name.rstrip("0123456789.")


func _toon_for(key: String, src: Material) -> ShaderMaterial:
	if _toon_cache.has(key):
		return _toon_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	var col := Color(0.8, 0.8, 0.85)
	if MC.COLORS.has(key):
		col = MC.COLORS[key]
	elif src is BaseMaterial3D:
		col = (src as BaseMaterial3D).albedo_color
	m.set_shader_parameter("albedo", col)
	_toon_cache[key] = m
	return m
