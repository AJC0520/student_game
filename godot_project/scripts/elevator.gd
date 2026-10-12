extends Node3D
## Level intro: the player starts inside lift 1 with the doors closed (free to walk around inside).
## The LED display counts 1..4 with animated up-arrows, then the doors slide open.

@export var level_path: NodePath = ^"../Level"   # node holding the imported level (for the lift door leaves)
@export var play_intro: bool = false         # true = start in the lift and play the ride (final game); false = skip it (quick look-around testing)
@export var top_floor: int = 4
@export var seconds_per_floor: float = 1.7
@export var first_delay: float = 1.2
@export var open_distance: float = 0.9
@export var open_time: float = 1.4
@export var arrow_step: float = 0.22          # seconds per arrow in the rising chase animation

const LIT := Color(1.0, 0.55, 0.1)
const DIM := Color(0.22, 0.10, 0.03)
const ARROW_Z := -0.172                 # just in front of the display backing (Blender y=0.165 -> Godot z=-0.165)

## Emitted each time the display changes floor (2, 3, 4...).
signal floor_changed(floor_number: int)
## Emitted when the doors have finished opening.
signal ride_finished

var _left: Node3D
var _right: Node3D
var _label: Label3D
var _arrow_mats: Array[StandardMaterial3D] = []
var _riding: bool = false
var _t: float = 0.0


func _ready() -> void:
	var level := get_node(level_path)
	_left = level.find_child("Lift1_Leaf_L*", true, false) as Node3D
	_right = level.find_child("Lift1_Leaf_R*", true, false) as Node3D
	if not play_intro:
		# testing mode: no ride, doors simply stay open
		if _left and _right:
			_left.position.x -= open_distance
			_right.position.x += open_distance
		return
	_make_display()
	if _left == null or _right == null:
		push_warning("Elevator: door leaves not found, skipping the ride")
		return
	_riding = true
	_ride()


func _make_display() -> void:
	_label = Label3D.new()
	_label.text = "1"
	_label.font_size = 48
	_label.pixel_size = 0.003
	_label.modulate = LIT
	_label.shaded = false
	_label.double_sided = false
	_label.outline_size = 0
	# Display backing spans x 0.5..1.0, z 2.15..2.35 on the cab's front-wall inner face.
	# Turned 180 degrees so it faces into the cab (toward the player).
	_label.position = Vector3(0.86, 2.25, ARROW_Z)
	_label.rotation = Vector3(0, PI, 0)
	add_child(_label)
	# three stacked up-arrows left of the digit; lit one by one from the bottom to look like upward motion
	for i in 3:
		var m := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.09, 0.045, 0.004)
		m.mesh = prism
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = DIM
		m.material_override = mat
		m.position = Vector3(0.62, 2.19 + 0.06 * i, ARROW_Z)
		add_child(m)
		_arrow_mats.append(mat)


func _process(delta: float) -> void:
	if not _riding:
		return
	_t += delta
	var lit_idx := int(_t / arrow_step) % (_arrow_mats.size() + 1)   # last step = all dim, then restart
	for i in _arrow_mats.size():
		_arrow_mats[i].albedo_color = LIT if i == lit_idx else DIM


func _ride() -> void:
	await get_tree().create_timer(first_delay).timeout
	for f in range(2, top_floor + 1):
		await get_tree().create_timer(seconds_per_floor).timeout
		_label.text = str(f)
		floor_changed.emit(f)
	await get_tree().create_timer(0.5).timeout
	_riding = false
	for mat in _arrow_mats:
		mat.albedo_color = DIM
	await get_tree().create_timer(0.3).timeout
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_left, "position:x", _left.position.x - open_distance, open_time)
	t.tween_property(_right, "position:x", _right.position.x + open_distance, open_time)
	await t.finished
	ride_finished.emit()
