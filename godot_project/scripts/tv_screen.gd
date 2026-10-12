extends Node3D
## Easter egg: the TV in the Online room plays a kart-racing game where "T.T" is losing.
## The picture is drawn live (scrolling road, two karts, HUD) into a SubViewport and shown on a quad
## placed over the blue screen of the level's TV (online_block.py: centre (-12.6, 0.45, 1.12), 1.25 x 0.70 m).

const SCREEN_SIZE := Vector2(1.25, 0.70)
const TEXTURE_SIZE := Vector2i(576, 322)
## Blender (x, y, z) -> Godot (x, z, -y); the screen faces +Y in Blender = -Z in Godot.
const SCREEN_POS := Vector3(-12.6, 1.12, -0.466)
const KartRace := preload("res://scripts/kart_race_view.gd")


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = TEXTURE_SIZE
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var view := KartRace.new()
	view.size = Vector2(TEXTURE_SIZE)
	vp.add_child(view)
	add_child(vp)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = SCREEN_SIZE
	quad.mesh = mesh
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = SCREEN_POS
	quad.rotation.y = PI    # QuadMesh faces +Z by default
	add_child(quad)
