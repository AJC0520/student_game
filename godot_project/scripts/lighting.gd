extends Node3D
## Placeholder lighting pass: ceiling lamps (OmniLight3D) + a weak sun, with a few moods to compare.
## F1 = daylight (sun only), F2 = interior (lamps + weak sun, default), F3 = everything bright.
## Lamp positions are given in Blender plan coordinates (x, y) and converted to Godot (x, height, -y).

@export var sun_path: NodePath = ^"../Sun"
@export var environment_path: NodePath = ^"../WorldEnvironment"
@export var lamp_energy: float = 0.8
@export var lamp_range: float = 9.0

const LAMP_HEIGHT: float = 2.7
const LAMPS: Array[Vector2] = [
	# corridor A4-024
	Vector2(-21, -1.25), Vector2(-15, -1.25), Vector2(-9, -1.25), Vector2(-4.5, -1.25),
	# cross corridor + A4-001
	Vector2(-2.3, 2.0), Vector2(-2.3, -3.2), Vector2(3.0, -2.2),
	# Online lounge, A4-138
	Vector2(-17.5, 2.2), Vector2(-12.5, 2.2), Vector2(-26.0, 2.2),
	# A4-025 / A4-124 / A4-156
	Vector2(-27.0, -4.0), Vector2(-24.0, -10.0), Vector2(-16.0, -10.0), Vector2(-8.0, -9.0), Vector2(-2.0, -8.0),
]
const CAB_LAMP: Vector3 = Vector3(0.75, 2.3, -1.8)   # inside lift cab 1

var _lamps: Array[OmniLight3D] = []
var _sun: DirectionalLight3D
var _env: Environment


func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we:
		_env = we.environment
	for p in LAMPS:
		_add_lamp(Vector3(p.x, LAMP_HEIGHT, -p.y), lamp_range, false)
	_add_lamp(CAB_LAMP, 4.5, false)
	_apply(2)


func _add_lamp(pos: Vector3, rng: float, shadow: bool) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = rng
	l.light_energy = lamp_energy
	l.light_color = Color(1.0, 0.95, 0.82)
	l.shadow_enabled = shadow
	add_child(l)
	_lamps.append(l)


func _apply(mode: int) -> void:
	match mode:
		1:  # daylight
			_set_mood(true, 1.0, 0.7, false)
		2:  # interior
			_set_mood(true, 0.35, 0.5, true)
		3:  # everything
			_set_mood(true, 0.9, 0.6, true)


func _set_mood(sun_on: bool, sun_energy: float, ambient: float, lamps_on: bool) -> void:
	if _sun:
		_sun.visible = sun_on
		_sun.light_energy = sun_energy
		_sun.shadow_enabled = true
	if _env:
		_env.ambient_light_energy = ambient
	for l in _lamps:
		l.visible = lamps_on


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: _apply(1)
			KEY_F2: _apply(2)
			KEY_F3: _apply(3)
