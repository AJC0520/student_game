extends Node3D
## The Online room TV displays a low-poly Grand Prix preview, then switches to the playable sofa challenge.
## Its picture is rendered live in a low-poly 3D SubViewport and shown on a quad
## placed over the blue screen of the level's TV (online_block.py: centre (-12.6, 0.45, 1.12), 1.25 x 0.70 m).

const SCREEN_SIZE := Vector2(1.25, 0.70)
const TEXTURE_SIZE := Vector2i(640, 360)
## Blender (x, y, z) -> Godot (x, z, -y); the screen faces +Y in Blender = -Z in Godot.
const SCREEN_POS := Vector3(-12.6, 1.12, -0.466)
const KartRace := preload("res://scripts/kart_race_view.gd")

var _race_view: Node3D
var _viewport: SubViewport


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = TEXTURE_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_race_view = KartRace.new()
	_viewport.add_child(_race_view)
	add_child(_viewport)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
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


func start_interactive_race() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_race_view.call("start_interactive_race")


func update_interactive_race(distance_m: float, speed_kmh: float, lap: int, seconds_left: float, opponents: Array[Dictionary], steer_offset: float) -> void:
	_race_view.call("update_interactive_race", distance_m, speed_kmh, lap, seconds_left, opponents, steer_offset)


func finish_interactive_race(player_won: bool) -> void:
	_race_view.call("finish_interactive_race", player_won)


func get_race_texture() -> Texture2D:
	return _viewport.get_texture()


func set_fullscreen_mode(enabled: bool, fullscreen_size: Vector2i) -> void:
	_viewport.size = fullscreen_size if enabled else TEXTURE_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func stop_interactive_race() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_race_view.call("stop_interactive_race")
