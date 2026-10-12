extends CharacterBody3D
## First-person walker.
## Move: WASD / arrow keys (input actions move_*), run: Shift (sprint), look: mouse, Esc frees the mouse.
## Collision shape and camera live in scenes/player.tscn so they can be tuned in the editor.

@export var walk_speed: float = 3.5
@export var run_speed: float = 6.0
@export var mouse_sensitivity: float = 0.0025

## Set true to freeze walking (cutscenes etc.); looking around still works.
var locked: bool = false

var _pitch: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _cam: Camera3D = $Camera3D

## Fallback if the input map in project.godot has no entries (e.g. the editor overwrote it).
const _DEFAULT_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
}


func _ready() -> void:
	_ensure_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, deg_to_rad(-85.0), deg_to_rad(85.0))
		_cam.rotation.x = _pitch
	elif event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if not locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()


static func _ensure_input_actions() -> void:
	for action: String in _DEFAULT_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in _DEFAULT_ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
