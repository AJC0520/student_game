extends Node3D
## The Online room TV displays a low-poly Grand Prix preview, then switches to the playable sofa challenge.
## Its picture is rendered live in a low-poly 3D SubViewport and shown on a quad
## placed over the blue screen of the level's TV (online_block.py: centre (-12.6, 0.45, 1.12), 1.25 x 0.70 m).

const SCREEN_SIZE := Vector2(1.25, 0.70)
const TEXTURE_SIZE := Vector2i(640, 360)
## Blender (x, y, z) -> Godot (x, z, -y); the screen faces +Y in Blender = -Z in Godot.
const SCREEN_POS := Vector3(-12.6, 1.12, -0.466)
const KartRace := preload("res://scripts/wasteland_race.gd")
## Farther than this from the TV (and not racing) the picture is not redrawn: the whole circuit is rendered every frame otherwise.
const IDLE_RENDER_RANGE := 20.0

var _race_view: Node3D
var _viewport: SubViewport
var _player: Node3D
var _racing: bool = false
var _forced: bool = false           # the picture is shown full screen: always render
var _menu_timer: float = 0.0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = TEXTURE_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_2X
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


func _process(delta: float) -> void:
	if _racing or _forced:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	# The menu picture is only redrawn while the TV is on screen: 12 times a second when close, 5 when far (it costs ~3 ms a frame otherwise).
	var camera := get_viewport().get_camera_3d()
	var on_screen := camera != null and camera.is_position_in_frustum(SCREEN_POS)
	var distance := _player.global_position.distance_to(SCREEN_POS)
	if distance < IDLE_RENDER_RANGE and on_screen:
		_menu_timer -= delta
		if _menu_timer <= 0.0:
			_menu_timer = 1.0 / (12.0 if distance < 10.0 else 5.0)
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func start_interactive_race() -> void:
	_racing = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_race_view.call("start_interactive_race")


## Driving input for the race on the TV: throttle / brake 0..1, steer -1..1 (+ = right), handbrake (drift) held.
func set_race_input(throttle: float, brake: float, steer: float, handbrake: bool) -> void:
	_race_view.call("set_race_input", throttle, brake, steer, handbrake)


## Ends the race now and shows the result panel (used when the player quits with Esc).
func finish_interactive_race(player_won: bool) -> void:
	_race_view.call("finish_interactive_race", player_won)


func get_race_view() -> Node3D:
	return _race_view


func get_race_texture() -> Texture2D:
	return _viewport.get_texture()


func set_fullscreen_mode(enabled: bool, fullscreen_size: Vector2i) -> void:
	_forced = enabled
	_viewport.size = fullscreen_size if enabled else TEXTURE_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func stop_interactive_race() -> void:
	_racing = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_race_view.call("stop_interactive_race")
