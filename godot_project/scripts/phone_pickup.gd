extends Node3D
## The phone the student drops on the floor. Glows a little so it is easy to spot; press E near it to pick it up into the
## hotbar (inventory.gd). drop() plays the fall from his pocket.

signal picked_up

const PHONE_MODEL := preload("res://assets/phone.glb")
const PICKUP_RANGE := 1.5
const MODEL_SCALE := 2.4                    # a real phone is tiny on screen; this is a toon world

var _t: float = 0.0
var _player: Node3D
var _prompt: Label3D
var _ring_material: StandardMaterial3D
var _marker: MeshInstance3D
var _model: Node3D
var _picked: bool = false
var _landed: bool = false


func _ready() -> void:
	_model = PHONE_MODEL.instantiate() as Node3D
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)

	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.26
	ring_mesh.bottom_radius = 0.26
	ring_mesh.height = 0.004
	ring_mesh.radial_segments = 20
	ring.mesh = ring_mesh
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = Color(1.0, 0.92, 0.5, 0.35)
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = _ring_material
	ring.position = Vector3(0.0, 0.003, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	_marker = MeshInstance3D.new()
	var diamond := SphereMesh.new()
	diamond.radius = 0.07
	diamond.height = 0.14
	diamond.radial_segments = 4
	diamond.rings = 2
	_marker.mesh = diamond
	var marker_material := StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(1.0, 0.92, 0.45)
	_marker.material_override = marker_material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)

	_prompt = Label3D.new()
	_prompt.text = "E  Pick up phone"
	_prompt.font_size = 56
	_prompt.pixel_size = 0.0028
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.shaded = false
	_prompt.outline_size = 12
	_prompt.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	_prompt.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_prompt.position = Vector3(0.0, 0.62, 0.0)
	add_child(_prompt)


func _process(delta: float) -> void:
	if _picked:
		return
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 3.5)
	_ring_material.albedo_color.a = 0.15 + 0.3 * pulse
	_marker.visible = _landed
	_marker.position = Vector3(0.0, 0.42 + 0.06 * sin(_t * 2.4), 0.0)
	_marker.rotation.y = _t * 1.8
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	var near := offset.length() < PICKUP_RANGE and _landed
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if near else 0.0, delta * 5.0)
	if near and Input.is_action_just_pressed("interact"):
		_pick_up()


## Falls from the student's pocket at `from` and lands at `to` with a little bounce.
func drop(from: Vector3, to: Vector3) -> void:
	global_position = from
	rotation = Vector3(0.0, randf() * TAU, 0.0)
	var fall := create_tween()
	fall.set_parallel(true)
	fall.tween_property(self, "global_position:x", to.x, 0.55)
	fall.tween_property(self, "global_position:z", to.z, 0.55)
	fall.tween_property(self, "rotation:x", TAU, 0.55)
	fall.tween_property(self, "global_position:y", to.y, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	rotation.x = 0.0
	var bounce := create_tween()
	bounce.tween_property(self, "global_position:y", to.y + 0.1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(self, "global_position:y", to.y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await bounce.finished
	_landed = true


func _pick_up() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory")
	if inventory == null or not bool(inventory.call("add_item", "phone")):
		return
	_picked = true
	_prompt.visible = false
	_marker.visible = false
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(self, "global_position", _player.global_position + Vector3(0.0, 1.2, 0.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(self, "scale", Vector3.ONE * 0.1, 0.3)
	await fly.finished
	picked_up.emit()
	queue_free()
