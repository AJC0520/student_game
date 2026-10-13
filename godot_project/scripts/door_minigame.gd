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

## Lobby-side card reader (centre of the screen) and the LED above it.
const READER_POS := Vector3(-0.80, 1.20, 1.12)
const LED_POS := Vector3(-0.797, 1.36, 1.12)
const PROMPT_POS := Vector3(-0.55, 1.78, 1.12)
const INTERACT_RANGE := 2.4

## The student's door (first door on the right when you look down the corridor from the lobby) and his route.
const STUDENT_DOOR := "Door_A4-147*"
const STUDENT_DOOR_HINGE := Vector3(-6.17, 0.0, 0.0)        # west edge of the leaf (the glb origin); swings open into the corridor
const NPC_SPAWN := Vector3(-5.67, 0.0, -0.7)               # inside the group room, behind the door
const NPC_ABOVE_DOOR := Vector3(-5.67, 0.0, 1.12)
const NPC_AT_READER := Vector3(-1.42, 0.0, 1.12)           # stands in the corridor, right arm reaching the reader
const NPC_SPEED := 2.3

enum State { IDLE, INTRO, GAME, NPC, DONE }

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


func _ready() -> void:
	var level := get_node(level_path)
	_entrance = level.find_child("Door_A4Entrance*", true, false) as Node3D
	var student_door := level.find_child(STUDENT_DOOR, true, false) as Node3D
	if _entrance == null or student_door == null:
		push_warning("DoorMinigame: door meshes not found in the level, minigame disabled")
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

	# "Press E" prompt fades in when the player is close
	var near := false
	if _player and _state == State.IDLE:
		var d := _player.global_position - READER_POS
		d.y = 0.0
		# only from the lobby side: the reader sits in the glass wall at x = -0.9
		near = d.length() < INTERACT_RANGE and _player.global_position.x > -0.85
	_prompt_alpha = move_toward(_prompt_alpha, 1.0 if near else 0.0, delta * 4.0)
	_prompt.modulate.a = _prompt_alpha
	_prompt.position = PROMPT_POS + Vector3(0.0, sin(_t * 3.0) * 0.015, 0.0)
	_prompt.visible = _prompt_alpha > 0.01

	if near and Input.is_action_just_pressed("interact"):
		_run_sequence()

	# the student breathes / idles while he is standing around
	if _npc and not _npc_walking:
		_npc.call("update_pose", delta, 0.0, 6.0, true, 0.0)


# ---------------------------------------------------------------- the minigame sequence

func _run_sequence() -> void:
	_state = State.INTRO
	_led_colour = Color(1.0, 0.1, 0.05)
	_player.set("locked", true)
	_player.set("look_locked", true)

	# smooth start: turn to the reader and ease the camera in a little
	var turn: Tween = _player.call("face_point", READER_POS, 0.9)
	var fov0 := _camera.fov
	var zoom := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(_camera, "fov", fov0 - 12.0, 0.9)
	await turn.finished

	await _say("", "ADGANG NEKTET", 1.0, Color(1.0, 0.35, 0.3))
	await _say("Du", "...kortet mitt. Faen.", 1.5)
	await _say("Du", "Banker jeg høyt nok, hører noen meg kanskje.", 1.8)
	_hide_dialog()

	_state = State.GAME
	await _bar.slide_in()
	_bar.start()
	await _bar.succeeded
	await _bar.slide_out()

	var back := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(_camera, "fov", fov0, 0.7)
	_player.set("locked", false)
	_player.set("look_locked", false)
	_state = State.NPC
	_student_sequence()
	await _say("Du", "Noen hørte meg!", 1.4)
	_hide_dialog()


func _student_sequence() -> void:
	# his door swings open into the corridor, he steps out of the group room
	_swing(_student_hinge, deg_to_rad(-88.0), 0.9)
	await get_tree().create_timer(0.55).timeout
	_spawn_npc()
	await _walk_to(NPC_ABOVE_DOOR)
	await _walk_to(NPC_AT_READER)
	await _turn_npc(-PI / 2.0, 0.35)

	# card swipe: lift the right arm to the reader, a quick scan wiggle, beep, green light
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

	# door unlocks and swings open into the lobby
	_swing(_entrance, deg_to_rad(-92.0), 1.1)
	_state = State.DONE
	door_unlocked.emit()
	await get_tree().create_timer(0.6).timeout
	await _say("Student", "Glemt kortet igjen?", 2.2, Color(0.95, 0.8, 0.3))
	_hide_dialog()

	# he heads back to his office and the door closes behind him
	await get_tree().create_timer(2.0).timeout
	await _turn_npc(PI / 2.0, 0.35)
	await _walk_to(NPC_ABOVE_DOOR)
	await _walk_to(NPC_SPAWN)
	_npc.queue_free()
	_npc = null
	await _swing(_student_hinge, 0.0, 0.8)


# ---------------------------------------------------------------- the student

func _spawn_npc() -> void:
	_npc = NPC_SCENE.instantiate() as Node3D
	_npc.set_script(PlayerModel)
	add_child(_npc)
	_npc.global_position = NPC_SPAWN
	_npc.rotation.y = PI      # walking out of the door towards +Z


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


## Rotates a hinge node about its own Y axis to `angle` (radians).
func _swing(hinge: Node3D, angle: float, time: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(hinge, "rotation:y", angle, time)
	await tw.finished


# ---------------------------------------------------------------- scene helpers

func _make_student_hinge(door: Node3D) -> void:
	# the glb door's origin is not its hinge, so hang it on a pivot placed at the hinge edge
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
	_prompt.font_size = 64
	_prompt.pixel_size = 0.002
	_prompt.outline_size = 16
	_prompt.outline_modulate = Color(0.04, 0.04, 0.06)
	_prompt.modulate = Color(1.0, 0.9, 0.45, 0.0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.shaded = false
	_prompt.no_depth_test = true
	_prompt.position = PROMPT_POS
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


## Shows one line with a typewriter effect, keeps it for `hold` seconds. Empty speaker = a system message.
func _say(speaker: String, text: String, hold: float, colour: Color = Color(1, 1, 1)) -> void:
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_speaker.modulate = Color(0.55, 0.8, 1.0) if speaker == "Du" else colour
	_line.text = text
	_line.modulate = colour if speaker == "" else Color(1, 1, 1)
	_line.visible_ratio = 0.0
	_dialog.visible = true
	create_tween().tween_property(_dialog, "modulate:a", 1.0, 0.2)
	var type_time := 0.035 * text.length()
	var tw := create_tween()
	tw.tween_property(_line, "visible_ratio", 1.0, type_time)
	await tw.finished
	await get_tree().create_timer(hold).timeout


func _hide_dialog() -> void:
	var tw := create_tween()
	tw.tween_property(_dialog, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: _dialog.visible = false)
