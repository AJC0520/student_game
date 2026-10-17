extends Node3D
## First minigame: the glass door from the lift lobby into the A4 corridor is locked and the player forgot their card (all dialogue is Norwegian).
## Walk up to the glowing card reader and press E -> "access denied" -> keep the marker in the green (skill_bar.gd) to
## get someone's attention -> a fellow student steps out of A4-147, swipes his card and opens the door.
##
## Everything (LED, prompt, light, UI, the NPC) is created here; the door / reader meshes come from the level glb
## (Door_A4Entrance, Card_Readers). Coordinates are Godot: Blender (x, y, z) -> (x, z, -y).

const SkillBar := preload("res://scripts/skill_bar.gd")
const PlayerModel := preload("res://scripts/player_model.gd")
const NPC_SCENE := preload("res://assets/npc_student.glb")
const PhonePickup := preload("res://scripts/phone_pickup.gd")

## Lobby-side card reader (centre of the screen) and the LED above it.
const READER_POS := Vector3(-0.80, 1.20, 3.00)
const LED_POS := Vector3(-0.797, 1.36, 3.00)
const READER_PROMPT_POS := Vector3(-0.60, 1.32, 3.00)
const READER_RANGE := 1.15
const DOOR_POS := Vector3(-0.82, 1.20, 1.95)
const DOOR_PROMPT_POS := Vector3(-0.60, 1.34, 1.95)
const DOOR_RANGE := 0.9

## The student's door (first door on the right when you look down the corridor from the lobby) and his route.
const STUDENT_DOOR := "Door_A4-147*"
const STUDENT_DOOR_HINGE := Vector3(-6.17, 0.0, 0.0)        # west edge of the leaf (the glb origin); swings open into the corridor
const NPC_SPAWN := Vector3(-5.67, 0.0, -0.7)               # inside the group room, behind the door
const NPC_ABOVE_DOOR := Vector3(-5.67, 0.0, 1.12)
const NPC_AT_READER := Vector3(-1.42, 0.0, 3.00)           # stops beside the relocated reader on the lobby side
const NPC_SPEED := 2.3
const PHONE_DROP_SPOT := Vector3(-3.55, 0.0, 2.06)         # on his way back he "accidentally" drops his phone here

enum State { IDLE, AWAIT_KNOCK, KNOCKING, GAME, NPC, DONE }

signal door_unlocked

@export var level_path: NodePath = ^"../Level"
@export var enabled: bool = true

var _state: State = State.IDLE
var _player: Node3D
var _camera: Camera3D
var _entrance: Node3D
var _student_hinge: Node3D
var _npc: Node3D
var _npc_walking: bool = false

var _led: MeshInstance3D
var _led_mat: StandardMaterial3D
var _led_colour := Color(1.0, 0.15, 0.1)
var _led_blink: bool = true
var _glow: OmniLight3D
var _prompt: Label3D
var _prompt_alpha: float = 0.0
var _t: float = 0.0

var _bar: Control
var _dialog: PanelContainer
var _speaker: Label
var _line: Label
var _knock_hand: Node3D


func _ready() -> void:
	var level := get_node(level_path)
	_entrance = level.find_child("Door_A4Entrance*", true, false) as Node3D
	var student_door := level.find_child(STUDENT_DOOR, true, false) as Node3D
	if _entrance == null or student_door == null:
		push_warning("DoorMinigame: entrance or student door not found in the level; minigame disabled")
		enabled = false
		return
	_make_student_hinge(student_door)
	_make_reader_fx()
	_make_ui()


func _process(delta: float) -> void:
	if not enabled:
		return
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player:
			_camera = _player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D

	# reader attention-grabber: pulsing LED and a soft light
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var level := (0.35 + 0.65 * pulse) if _led_blink else 1.0
	_led_mat.albedo_color = _led_colour * level
	_glow.light_energy = (0.5 + 0.8 * pulse) if _state == State.IDLE else 0.35

	# Reader interaction comes first; knocking is available only after the card is rejected.
	var near_reader := false
	var near_door := false
	if _player and _state == State.IDLE:
		var reader_delta := _player.global_position - READER_POS
		reader_delta.y = 0.0
		near_reader = reader_delta.length() < READER_RANGE and _player.global_position.x > -0.85
	if _player and _state == State.AWAIT_KNOCK:
		var door_delta := _player.global_position - DOOR_POS
		door_delta.y = 0.0
		near_door = door_delta.length() < DOOR_RANGE and _player.global_position.x > -0.85
	var can_interact := near_reader or near_door
	_prompt.text = "E  Bruk" if near_reader else "E  Bank"
	var prompt_pos := READER_PROMPT_POS if near_reader else DOOR_PROMPT_POS
	_prompt_alpha = move_toward(_prompt_alpha, 1.0 if can_interact else 0.0, delta * 4.0)
	_prompt.modulate.a = _prompt_alpha
	_prompt.position = prompt_pos
	_prompt.visible = _prompt_alpha > 0.01

	if can_interact and Input.is_action_just_pressed("interact"):
		if near_reader:
			_try_card()
		else:
			_knock_and_start_minigame()

	# the student breathes / idles while he is standing around
	if _npc and not _npc_walking:
		_npc.call("update_pose", delta, 0.0, 6.0, true, 0.0)


# ---------------------------------------------------------------- the minigame sequence

func _try_card() -> void:
	_state = State.KNOCKING
	_led_colour = Color(1.0, 0.1, 0.05)
	_player.set("locked", true)
	_player.set("look_locked", true)
	var turn: Tween = _player.call("face_point", READER_POS, 0.55)
	var fov0 := _camera.fov
	var zoom := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(_camera, "fov", fov0 - 7.0, 0.55)
	await turn.finished
	await _say("", "ADGANG NEKTET", 0.9, Color(1.0, 0.35, 0.3))
	await _say("Du", "Kortet mitt. Faen hvor er den?", 1.25)
	_hide_dialog()
	var back := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(_camera, "fov", fov0, 0.45)
	await back.finished
	_player.set("locked", false)
	_player.set("look_locked", false)
	_state = State.AWAIT_KNOCK


func _knock_and_start_minigame() -> void:
	_state = State.KNOCKING
	_player.set("locked", true)
	_player.set("look_locked", true)
	if _knock_hand == null:
		_make_knock_hand()
	var turn: Tween = _player.call("face_point", DOOR_POS, 0.35)
	await turn.finished
	await _play_knock_animation()
	_state = State.GAME
	await _bar.slide_in()
	_bar.start()
	await _bar.succeeded
	await _bar.slide_out()
	_player.set("locked", false)
	_player.set("look_locked", false)
	_state = State.NPC
	_student_sequence()
	await _say("Du", "Noen hørte meg!", 1.4)
	_hide_dialog()


func _make_knock_hand() -> void:
	if _camera == null:
		return
	_knock_hand = Node3D.new()
	_knock_hand.name = "KnockHand"
	_knock_hand.position = Vector3(0.34, -0.28, -0.58)
	_knock_hand.visible = false
	_camera.add_child(_knock_hand)
	var sleeve := MeshInstance3D.new()
	var sleeve_mesh := BoxMesh.new()
	sleeve_mesh.size = Vector3(0.16, 0.18, 0.32)
	sleeve.mesh = sleeve_mesh
	sleeve.position = Vector3(0.0, -0.08, 0.13)
	var sleeve_mat := StandardMaterial3D.new()
	sleeve_mat.albedo_color = Color(0.16, 0.22, 0.32)
	sleeve.material_override = sleeve_mat
	_knock_hand.add_child(sleeve)
	var fist := MeshInstance3D.new()
	var fist_mesh := BoxMesh.new()
	fist_mesh.size = Vector3(0.13, 0.13, 0.15)
	fist.mesh = fist_mesh
	fist.position = Vector3(0.0, 0.0, -0.08)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.48, 0.34)
	fist.material_override = skin
	_knock_hand.add_child(fist)


func _play_knock_animation() -> void:
	_knock_hand.visible = true
	var rest := Vector3(0.34, -0.28, -0.58)
	var hit := Vector3(0.24, -0.19, -0.86)
	for i in 3:
		var knock := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		knock.tween_property(_knock_hand, "position", hit, 0.12)
		knock.tween_callback(func() -> void: _entrance.rotation.y += deg_to_rad(1.2))
		knock.tween_property(_entrance, "rotation:y", _entrance.rotation.y - deg_to_rad(2.4), 0.08)
		knock.tween_property(_entrance, "rotation:y", _entrance.rotation.y, 0.08)
		knock.tween_property(_knock_hand, "position", rest, 0.14)
		await knock.finished
	_knock_hand.visible = false


func _student_sequence() -> void:
	_swing(_student_hinge, deg_to_rad(-88.0), 0.9)
	await get_tree().create_timer(0.55).timeout
	_spawn_npc()
	await _walk_to(NPC_ABOVE_DOOR)
	await _walk_to(NPC_AT_READER)
	await _turn_npc(-PI / 2.0, 0.35)
	var arm := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arm.tween_property(_npc, "arm_r_raise", 1.4, 0.5)
	await arm.finished
	for i in 3:
		var wig := create_tween()
		wig.tween_property(_npc, "arm_r_raise", 1.25, 0.1)
		wig.tween_property(_npc, "arm_r_raise", 1.45, 0.1)
		await wig.finished
	_led_colour = Color(0.15, 1.0, 0.3)
	_led_blink = false
	await get_tree().create_timer(0.35).timeout
	var lower := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lower.tween_property(_npc, "arm_r_raise", 0.0, 0.5)
	_swing(_entrance, deg_to_rad(-92.0), 1.1)
	_state = State.DONE
	door_unlocked.emit()
	await get_tree().create_timer(0.6).timeout
	await _say("Student", "Glemt kortet igjen?", 2.2, Color(0.95, 0.8, 0.3))
	_hide_dialog()
	await get_tree().create_timer(2.0).timeout
	await _turn_npc(PI / 2.0, 0.35)
	await _walk_to(PHONE_DROP_SPOT)
	_drop_phone()
	await _walk_to(NPC_ABOVE_DOOR)
	await _walk_to(NPC_SPAWN)
	_npc.queue_free()
	_npc = null
	await _swing(_student_hinge, 0.0, 0.8)


## The phone slips out of his pocket (he does not notice) and lands behind him on the floor, ready to be picked up.
func _drop_phone() -> void:
	var phone := PhonePickup.new()
	phone.name = "DroppedPhone"
	add_child(phone)
	var pocket := _npc.global_position + Vector3(0.16, 0.85, 0.05)
	var landing := _npc.global_position + Vector3(0.55, 0.012, 0.14)
	phone.drop(pocket, landing)


func _spawn_npc() -> void:
	_npc = NPC_SCENE.instantiate() as Node3D
	_npc.set_script(PlayerModel)
	add_child(_npc)
	_npc.global_position = NPC_SPAWN
	_npc.rotation.y = PI


func _walk_to(target: Vector3) -> void:
	_npc_walking = true
	while true:
		var delta := get_process_delta_time()
		var to := target - _npc.global_position
		to.y = 0.0
		var dist := to.length()
		if dist < 0.03:
			break
		var dir := to / dist
		_npc.global_position += dir * minf(NPC_SPEED * delta, dist)
		_npc.rotation.y = lerp_angle(_npc.rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 10.0, 0.0, 1.0))
		_npc.call("update_pose", delta, NPC_SPEED + 0.6, 6.0, true, 0.0)
		await get_tree().process_frame
	_npc_walking = false


func _turn_npc(yaw: float, time: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var from := _npc.rotation.y
	tw.tween_method(func(k: float) -> void: _npc.rotation.y = lerp_angle(from, yaw, k), 0.0, 1.0, time)
	await tw.finished


func _swing(hinge: Node3D, angle: float, time: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(hinge, "rotation:y", angle, time)
	await tw.finished


func _make_student_hinge(door: Node3D) -> void:
	_student_hinge = Node3D.new()
	_student_hinge.name = "StudentDoorHinge"
	door.get_parent().add_child(_student_hinge)
	_student_hinge.global_position = STUDENT_DOOR_HINGE
	door.reparent(_student_hinge, true)


func _make_reader_fx() -> void:
	_led = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.022, 0.06)
	_led.mesh = box
	_led_mat = StandardMaterial3D.new()
	_led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_led.material_override = _led_mat
	_led.position = LED_POS
	_led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_led)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.85, 0.4)
	_glow.omni_range = 1.8
	_glow.position = READER_POS + Vector3(0.35, 0.1, 0.0)
	_glow.shadow_enabled = false
	add_child(_glow)
	_prompt = Label3D.new()
	_prompt.text = "Trykk  E"
	_prompt.font_size = 36
	_prompt.pixel_size = 0.0012
	_prompt.outline_size = 6
	_prompt.outline_modulate = Color(0.04, 0.04, 0.06)
	_prompt.modulate = Color(1.0, 0.9, 0.45, 0.0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.shaded = false
	_prompt.no_depth_test = false
	_prompt.position = READER_PROMPT_POS
	_prompt.visible = false
	add_child(_prompt)


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_bar = SkillBar.new()
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_bar)
	_dialog = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.82)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	style.border_color = Color(1, 1, 1, 0.15)
	style.set_border_width_all(2)
	_dialog.add_theme_stylebox_override("panel", style)
	_dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog.custom_minimum_size = Vector2(620, 0)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialog.offset_top = -190
	_dialog.offset_bottom = -190
	_dialog.visible = false
	_dialog.modulate.a = 0.0
	layer.add_child(_dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_dialog.add_child(box)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 16)
	box.add_child(_speaker)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 22)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_line)


func _say(speaker: String, text: String, hold: float, colour: Color = Color(1, 1, 1)) -> void:
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_speaker.modulate = Color(0.55, 0.8, 1.0) if speaker == "Du" else colour
	_line.text = text
	_line.modulate = colour if speaker == "" else Color(1, 1, 1)
	_line.visible_ratio = 0.0
	_dialog.visible = true
	create_tween().tween_property(_dialog, "modulate:a", 1.0, 0.2)
	var tw := create_tween()
	tw.tween_property(_line, "visible_ratio", 1.0, 0.035 * text.length())
	await tw.finished
	await get_tree().create_timer(hold).timeout


func _hide_dialog() -> void:
	var tw := create_tween()
	tw.tween_property(_dialog, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: _dialog.visible = false)
