extends CharacterBody3D
## Walker with a first- or third-person camera (V toggles, `first_person` sets the default).
## Move: WASD / arrow keys (input actions move_*, relative to the camera), run: Shift (sprint), jump: Space,
## look / orbit camera: mouse, Esc frees the mouse.
## Bunny hop (bhop_enabled): Source-style movement with momentum, auto-hop (hold Space) and air strafing (turn the mouse while holding A or D in the air to gain speed).
## Collision shape, camera rig and character model live in scenes/player.tscn so they can be tuned in the editor.

@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
## Start in first person: the character model is hidden and the camera sits at eye height.
@export var first_person: bool = true
@export var jump_velocity: float = 4.6      # ~1 m jump height
@export var turn_speed: float = 12.0        # how quickly the character turns towards the walking direction
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = deg_to_rad(-65.0)   # third person: camera looking down on the player
@export var max_pitch: float = deg_to_rad(30.0)    # third person: camera dipping below head height
@export var eye_height: float = 1.65
@export var third_person_height: float = 1.55
@export var third_person_distance: float = 3.4

@export_group("Bunny hop")
## Source-style movement: momentum on the ground (friction + acceleration), air strafing and auto-hop.
## Off = the old instant walk / run movement.
@export var bhop_enabled: bool = true
## Hold Space to jump again the moment you land (no ground friction on the landing frame, so no speed is lost).
@export var auto_hop: bool = false
@export var ground_accel: float = 14.0
@export var ground_friction: float = 6.0
@export var stop_speed: float = 2.0         # friction uses at least this speed, so you come to a stop quickly
@export var air_accel: float = 10.0
## Wish speed limit in the air: this is what makes strafe-jumping (A/D + turning the mouse) add speed.
@export var air_speed_cap: float = 0.8
@export var max_speed: float = 20.0         # hard cap on horizontal speed (m/s)

## Set true to freeze walking (cutscenes etc.); looking around still works.
var locked: bool = false
## Set true to also freeze mouse look (minigames); face_point() can still turn the camera.
var look_locked: bool = false

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-8.0)
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _cam_pivot: Node3D = $CameraPivot
@onready var _model: Node3D = $Model
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D

## Fallback if the input map in project.godot has no entries (e.g. the editor overwrote it).
const _DEFAULT_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"toggle_view": [KEY_V],
	"interact": [KEY_E],
}


func _ready() -> void:
	_ensure_input_actions()
	# The node's placed rotation (see main.tscn) is the initial facing; the body itself never rotates,
	# only the model and the camera rig do.
	_yaw = rotation.y
	rotation = Vector3.ZERO
	_model.rotation.y = _yaw
	_apply_view()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if look_locked:
			return
		var motion := event as InputEventMouseMotion
		_yaw = wrapf(_yaw - motion.relative.x * mouse_sensitivity, -PI, PI)
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, _min_pitch(), _max_pitch())
		_apply_camera()
	elif event.is_action_pressed("toggle_view"):
		first_person = not first_person
		_apply_view()
	elif event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if not locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (Basis(Vector3.UP, _yaw) * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	if bhop_enabled:
		_move_bhop(direction, speed, delta)
	else:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
			if not locked and Input.is_action_just_pressed("jump"):
				velocity.y = jump_velocity
		move_and_slide()

	if first_person:
		_model.rotation.y = _yaw
	elif direction != Vector3.ZERO:
		var target_yaw := atan2(-direction.x, -direction.z)   # model faces -Z at rotation 0
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))
	_model.call("update_pose", delta, Vector2(velocity.x, velocity.z).length(), run_speed, is_on_floor(), velocity.y)


## Source-style movement: friction + acceleration on the ground, limited-speed acceleration in the air.
## Jumping on the landing frame skips friction, which is what lets speed build up over a chain of hops.
func _move_bhop(direction: Vector3, speed: float, delta: float) -> void:
	var want_jump := not locked and (Input.is_action_pressed("jump") if auto_hop else Input.is_action_just_pressed("jump"))
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var wish_speed := speed if direction != Vector3.ZERO else 0.0
	if is_on_floor():
		if want_jump:
			velocity.y = jump_velocity
			hv = _air_accelerate(hv, direction, wish_speed, delta)
		else:
			velocity.y = 0.0
			hv = _apply_friction(hv, delta)
			hv = _accelerate(hv, direction, wish_speed, ground_accel, delta)
	else:
		velocity.y -= _gravity * delta
		hv = _air_accelerate(hv, direction, wish_speed, delta)
	if hv.length() > max_speed:
		hv = hv.normalized() * max_speed
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()


func _apply_friction(hv: Vector3, delta: float) -> Vector3:
	var spd := hv.length()
	if spd < 0.001:
		return Vector3.ZERO
	var drop := maxf(spd, stop_speed) * ground_friction * delta
	return hv * (maxf(spd - drop, 0.0) / spd)


func _accelerate(hv: Vector3, direction: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	var add := wish_speed - hv.dot(direction)
	if add <= 0.0:
		return hv
	return hv + direction * minf(accel * wish_speed * delta, add)


func _air_accelerate(hv: Vector3, direction: Vector3, wish_speed: float, delta: float) -> Vector3:
	var capped := minf(wish_speed, air_speed_cap)
	var add := capped - hv.dot(direction)
	if add <= 0.0:
		return hv
	return hv + direction * minf(air_accel * wish_speed * delta, add)


func _apply_camera() -> void:
	_cam_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


## Smoothly turns the camera (and the model, in first person) towards a world point. Await the returned tween to wait for it.
func face_point(point: Vector3, duration: float = 0.8) -> Tween:
	var d := point - _cam_pivot.global_position
	var yaw_to := atan2(-d.x, -d.z)
	var pitch_to := clampf(atan2(d.y, Vector2(d.x, d.z).length()), _min_pitch(), _max_pitch())
	var yaw_from := _yaw
	var pitch_from := _pitch
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float) -> void:
		_yaw = lerp_angle(yaw_from, yaw_to, k)
		_pitch = lerpf(pitch_from, pitch_to, k)
		_apply_camera(), 0.0, 1.0, duration)
	return tw


## Switches between the eye-height camera (model hidden) and the orbiting camera behind the character.
func _apply_view() -> void:
	_model.visible = not first_person
	_arm.spring_length = 0.0 if first_person else third_person_distance
	_arm.collision_mask = 0 if first_person else 1
	_cam_pivot.position.y = eye_height if first_person else third_person_height
	_pitch = clampf(_pitch, _min_pitch(), _max_pitch())
	_apply_camera()


func _min_pitch() -> float:
	return deg_to_rad(-85.0) if first_person else min_pitch


func _max_pitch() -> float:
	return deg_to_rad(85.0) if first_person else max_pitch


static func _ensure_input_actions() -> void:
	for action: String in _DEFAULT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in _DEFAULT_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
