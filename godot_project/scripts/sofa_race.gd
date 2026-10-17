extends CanvasLayer
## Starts and drives the low-poly street Grand Prix shown by the Online room television.

const SOFA_POSITION := Vector3(-10.55, 0.56, -2.9) # Blender (-10.55, 2.9, 0.56) -> Godot
const TV_CENTER := Vector3(-12.6, 1.12, -0.466)
const INTERACT_RANGE := 2.0
const TV_REVEAL_SCALE := Vector2(0.82, 0.82)

enum State { IDLE, OPENING, RACING, RESULT, CLOSING, RESTORING }

var _state: State = State.IDLE
var _player: CharacterBody3D
var _camera: Camera3D
var _tv_screen: Node
var _prompt: Label
var _overlay_texture: TextureRect
var _camera_transition: bool = false
var _saved_camera_aim: Vector3
var _saved_camera_fov: float = 75.0
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 20
	_tv_screen = get_node_or_null("../TVScreen")
	_make_prompt()
	if _tv_screen:
		var view: Node = _tv_screen.call("get_race_view")
		if view:
			view.connect("race_finished", _on_race_finished)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return
	if _state == State.IDLE:
		_update_prompt()
	elif _state == State.RACING:
		_send_input()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _state == State.IDLE and key_event.physical_keycode == KEY_E and _prompt.visible:
		_start_race()
		get_viewport().set_input_as_handled()
	elif _state == State.OPENING or _state == State.RACING:
		if key_event.keycode == KEY_ESCAPE:
			if _state == State.RACING:
				_finish_race(false)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_V or key_event.is_action("move_left") or key_event.is_action("move_right") or key_event.is_action("move_forward") or key_event.is_action("move_back"):
			get_viewport().set_input_as_handled()
	elif _state == State.RESULT and (key_event.physical_keycode == KEY_E or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
		_close_result()
		get_viewport().set_input_as_handled()


func _update_prompt() -> void:
	var offset := _player.global_position - SOFA_POSITION
	offset.y = 0.0
	_prompt.visible = offset.length() <= INTERACT_RANGE
	_prompt.text = "E  •  RACE T.T. ON THE TV"


## The race itself runs inside the TV view (race_sim.gd); here we only pass the keys on.
func _send_input() -> void:
	if _tv_screen:
		_tv_screen.call("set_race_input", Input.get_action_strength("move_forward"), Input.get_action_strength("move_back"),
			Input.get_axis("move_left", "move_right"), Input.is_action_pressed("sprint"))


func _on_race_finished(player_won: bool) -> void:
	if _state == State.RACING:
		_state = State.RESULT
	if player_won:                       # the phone's first task
		var inventory := get_tree().get_first_node_in_group("inventory")
		if inventory:
			inventory.call("complete_task", "beat_tt")


func _start_race() -> void:
	_state = State.OPENING
	_saved_mouse_mode = Input.mouse_mode
	_camera = _player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if _camera:
		_saved_camera_fov = _camera.fov
		_saved_camera_aim = _camera.global_position - _camera.global_transform.basis.z * 8.0
	_player.set("locked", true)
	_player.set("look_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_prompt.visible = false
	if _camera:
		_camera_transition = true
		var turn: Tween = _player.call("face_point", TV_CENTER, 0.55)
		await turn.finished
		var tv_distance := _camera.global_position.distance_to(TV_CENTER)
		var zoom_fov := clampf(rad_to_deg(2.0 * atan(0.44 / tv_distance)), 12.0, 28.0)
		var zoom := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		zoom.tween_property(_camera, "fov", zoom_fov, 0.75)
		await zoom.finished
		_camera_transition = false
	if _tv_screen:
		_tv_screen.call("set_fullscreen_mode", true, Vector2i(get_viewport().size))
		_overlay_texture.texture = _tv_screen.call("get_race_texture") as Texture2D
	await _open_race_interface()
	if _state == State.OPENING:
		if _tv_screen:
			_tv_screen.call("start_interactive_race")       # the 3-2-1 countdown starts now that the picture is full screen
		_state = State.RACING


func _open_race_interface() -> void:
	_overlay_texture.visible = true
	_overlay_texture.scale = TV_REVEAL_SCALE
	_overlay_texture.pivot_offset = _overlay_texture.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay_texture, "scale", Vector2.ONE, 0.55)
	await tween.finished


func _finish_race(player_won: bool) -> void:
	_state = State.RESULT
	if _tv_screen:
		_tv_screen.call("finish_interactive_race", player_won)


func _close_result() -> void:
	_state = State.CLOSING
	_prompt.visible = false
	if _overlay_texture == null or _overlay_texture.texture == null:
		if _player:
			_player.set("locked", false)
			_player.set("look_locked", false)
		Input.mouse_mode = _saved_mouse_mode
		_state = State.IDLE
		return
	_overlay_texture.pivot_offset = _overlay_texture.size * 0.5
	var shrink := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	shrink.tween_property(_overlay_texture, "scale", TV_REVEAL_SCALE, 0.4)
	await shrink.finished
	_overlay_texture.visible = false
	_state = State.RESTORING
	if _tv_screen:
		_tv_screen.call("set_fullscreen_mode", false, Vector2i.ZERO)
		_tv_screen.call("stop_interactive_race")
	if _camera and _player:
		_camera_transition = true
		var turn: Tween = _player.call("face_point", _saved_camera_aim, 0.55)
		await turn.finished
		var zoom := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		zoom.tween_property(_camera, "fov", _saved_camera_fov, 0.55)
		await zoom.finished
		_camera_transition = false
	if _player:
		_player.set("locked", false)
		_player.set("look_locked", false)
	Input.mouse_mode = _saved_mouse_mode
	_overlay_texture.texture = null
	_state = State.IDLE


func _make_prompt() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_overlay_texture = TextureRect.new()
	_overlay_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_overlay_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_overlay_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_texture.visible = false
	root.add_child(_overlay_texture)
	_prompt = Label.new()
	_prompt.text = "E  •  CHALLENGE T.T. (#07)"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(0.68, 0.9, 1.0))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-270.0, -86.0)
	_prompt.size = Vector2(540.0, 38.0)
	_prompt.visible = false
	root.add_child(_prompt)
