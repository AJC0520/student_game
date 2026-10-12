extends CharacterBody3D
## Third-person walker.
## Move: WASD / arrow keys (input actions move_*, relative to the camera), run: Shift (sprint), jump: Space,
## orbit camera: mouse, Esc frees the mouse.
## Collision shape, camera rig and character model live in scenes/player.tscn so they can be tuned in the editor.

@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
@export var jump_velocity: float = 4.6      # ~1 m jump height
@export var turn_speed: float = 12.0        # how quickly the character turns towards the walking direction
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = deg_to_rad(-65.0)   # camera looking down on the player
@export var max_pitch: float = deg_to_rad(30.0)    # camera dipping below head height

## Set true to freeze walking (cutscenes etc.); looking around still works.
var locked: bool = false

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-8.0)
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _cam_pivot: Node3D = $CameraPivot
@onready var _model: Node3D = $Model

## Fallback if the input map in project.godot has no entries (e.g. the editor overwrote it).
const _DEFAULT_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
}


func _ready() -> void:
	_ensure_input_actions()
	# The node's placed rotation (see main.tscn) is the initial facing; the body itself never rotates,
	# only the model and the camera rig do.
	_yaw = rotation.y
	rotation = Vector3.ZERO
	_model.rotation.y = _yaw
	_apply_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw = wrapf(_yaw - motion.relative.x * mouse_sensitivity, -PI, PI)
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, min_pitch, max_pitch)
		_apply_camera()
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
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
		if not locked and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	move_and_slide()

	if direction != Vector3.ZERO:
		var target_yaw := atan2(-direction.x, -direction.z)   # model faces -Z at rotation 0
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))
	_model.call("update_pose", delta, Vector2(velocity.x, velocity.z).length(), run_speed, is_on_floor(), velocity.y)


func _apply_camera() -> void:
	_cam_pivot.rotation = Vector3(_pitch, _yaw, 0.0)


static func _ensure_input_actions() -> void:
	for action: String in _DEFAULT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in _DEFAULT_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
