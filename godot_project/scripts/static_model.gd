extends Node3D
## Re-skins a static glb from Blender (props / NPCs) with the toon + outline shaders, like level.gd and player_model.gd do.
## No collision: NPCs that sit on furniture are covered by the furniture's own collider.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const MC := preload("res://scripts/material_colors.gd")

var _toon_cache: Dictionary = {}
var _outline_mat: ShaderMaterial


func _ready() -> void:
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OUTLINE
	_skin(self)


func _skin(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src: Material = mi.mesh.surface_get_material(i)
				var key := src.resource_name.rstrip("0123456789.") if src else ""
				if key == "Toon_Outline":
					mi.set_surface_override_material(i, _outline_mat)
				else:
					mi.set_surface_override_material(i, _toon_for(key, src))
	for child in node.get_children():
		_skin(child)


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
