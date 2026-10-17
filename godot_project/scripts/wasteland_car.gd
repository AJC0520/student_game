extends CharacterBody3D
## One racing car of the wasteland racer: an arcade controller on a CharacterBody3D (no VehicleBody3D). Forward and reverse
## acceleration, steering by turning the body, and a sideways slide: cornering fast, or pulling the handbrake, lets the grip
## go so the car drifts, which leaves skid marks and a dust trail. The race script (wasteland_race.gd) sets the inputs and
## calls step() every physics frame, for the player (keys) and for the AI drivers alike.

signal skid(left_pos: Vector3, right_pos: Vector3, yaw: float)
signal hit_wall(strength: float)

const CAR_MODEL := "res://assets/wasteland/wasteland_car.glb"

const TOP_SPEED := 46.0              # m/s (165 km/h)
const ACCEL := 14.0                  # m/s^2 from a standstill, fading out towards the top speed
const BRAKE := 30.0
const REVERSE_ACCEL := 10.0
const REVERSE_TOP := 12.0
const COAST := 2.5
const DRAG := 0.0012
const YAW_PER_SPEED := 0.30          # yaw rate at full lock per m/s at low speed
const CORNER_GRIP := 30.0            # the most lateral acceleration the tyres give (m/s^2)
const GRIP_NORMAL := 12.0            # how fast a sideways slide dies out (1/s)
const GRIP_DRIFT := 5.0              # ... when cornering very hard at speed
const GRIP_HANDBRAKE := 1.6
const STEER_RATE := 9.0             # how fast the wheel follows the keys (1/s); it returns to centre faster
const MAX_HEALTH := 100.0

var driver_name: String = ""
var number: int = 0
var paint_color: Color = Color.WHITE
var is_player: bool = false
var skill: float = 0.9

# inputs, set by whoever drives the car
var input_throttle: float = 0.0      # 0..1
var input_brake: float = 0.0         # 0..1 (brakes, then reverses)
var input_steer: float = 0.0         # -1..1, + = right
var input_handbrake: bool = false

# state
var health: float = MAX_HEALTH
var steer: float = 0.0
var forward_speed: float = 0.0
var slide_speed: float = 0.0
var drifting: bool = false
var wrecked: bool = false
var invulnerable: float = 0.0
var hit_flash: float = 0.0

# race bookkeeping (owned by the race script)
var hint_index: int = 0
var laps_done: int = 0
var last_s: float = 0.0
var total_s: float = 0.0
var finish_time: float = -1.0
var wreck_timer: float = 0.0
var stuck_timer: float = 0.0

var show_overlay: bool = false         # the bars above the car (the race script turns them on during a race)

var _model: Node3D
var _overlay: Node3D
var _hp_fill: MeshInstance3D
var _info: Label3D
var _hp_material: StandardMaterial3D
var _smoke: CPUParticles3D
var _skid_timer: float = 0.0
var _lean: float = 0.0
var _last_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("race_car")
	collision_layer = 2
	collision_mask = 3
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 1.2, 4.3)
	shape.shape = box
	shape.position = Vector3(0.0, 0.7, 0.0)
	add_child(shape)
	_build_model()
	_build_blob_shadow()
	_build_smoke()
	_build_overlay()


func _build_blob_shadow() -> void:
	var blob := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.6, 0.01, 4.9)
	blob.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob.material_override = material
	blob.position = Vector3(0.0, 0.05, 0.0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var scene := load(CAR_MODEL) as PackedScene
	if scene != null:
		var instance := scene.instantiate() as Node3D
		_model.add_child(instance)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = paint_color
		paint.roughness = 0.8
		for node in instance.find_children("Car_Paint*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_override = paint
	else:                                                      # stand-in until the .glb exists
		var body := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.9, 0.9, 4.0)
		body.mesh = mesh
		body.position = Vector3(0.0, 0.8, 0.0)
		var paint2 := StandardMaterial3D.new()
		paint2.albedo_color = paint_color
		body.material_override = paint2
		_model.add_child(body)


func set_paint(color: Color) -> void:
	paint_color = color
	if _model == null:
		return
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.8
	for node in _model.find_children("Car_Paint*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = paint


## Health bar and name floating above the car, always facing the camera and drawn on top.
func _bar_material(color: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.no_depth_test = true
	material.render_priority = priority
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _bar_quad(parent: Node3D, width: float, height: float, left_anchored: bool, material: Material, at: Vector3) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	if left_anchored:
		quad.center_offset = Vector3(width * 0.5, 0.0, 0.0)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _build_overlay() -> void:
	_overlay = Node3D.new()
	_overlay.name = "StatusBars"
	_overlay.top_level = true
	_overlay.visible = false
	add_child(_overlay)
	var width := 5.0
	_bar_quad(_overlay, width + 0.3, 0.9, false, _bar_material(Color(0.0, 0.0, 0.0, 0.7), 10), Vector3.ZERO)
	_hp_material = _bar_material(Color8(120, 210, 90), 11)
	_hp_fill = _bar_quad(_overlay, width, 0.6, true, _hp_material, Vector3(-width * 0.5, 0.0, 0.0))
	_info = Label3D.new()
	_info.font_size = 32
	_info.pixel_size = 0.028
	_info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_info.no_depth_test = true
	_info.shaded = false
	_info.render_priority = 12
	_info.outline_size = 10
	_info.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	_info.modulate = Color8(255, 226, 120) if is_player else Color8(235, 225, 205)
	_info.position = Vector3(0.0, 1.05, 0.0)
	_overlay.add_child(_info)


func _update_overlay() -> void:
	if _overlay == null:
		return
	_overlay.visible = show_overlay and not wrecked
	if not _overlay.visible:
		return
	_overlay.global_position = global_position + Vector3(0.0, 4.5, -1.6)
	var ratio := clampf(health / MAX_HEALTH, 0.0, 1.0)
	_hp_fill.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
	_hp_material.albedo_color = Color8(120, 210, 90).lerp(Color8(230, 60, 40), 1.0 - ratio).lerp(Color.WHITE, clampf(hit_flash, 0.0, 1.0) * 0.6)
	_info.text = driver_name


func _build_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.name = "DustTrail"
	_smoke.amount = 30
	_smoke.lifetime = 0.9
	_smoke.emitting = false
	_smoke.local_coords = false
	_smoke.position = Vector3(0.0, 0.35, 1.8)
	_smoke.direction = Vector3(0.0, 1.0, 0.0)
	_smoke.spread = 35.0
	_smoke.gravity = Vector3(0.0, 0.6, 0.0)
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 2.6
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.5
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.9
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 5
	puff.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.82, 0.66, 0.46, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = material
	_smoke.mesh = puff
	add_child(_smoke)


## Advances the car by one physics frame (called by the race script).
func step(delta: float) -> void:
	invulnerable = maxf(0.0, invulnerable - delta)
	hit_flash = maxf(0.0, hit_flash - delta * 2.5)
	if _model != null:
		_model.visible = not wrecked and (invulnerable <= 0.0 or fmod(invulnerable, 0.3) < 0.18)
	if wrecked:
		velocity = Vector3.ZERO
		_smoke.emitting = false
		_update_overlay()
		return

	var basis_now := global_transform.basis
	var fwd := -basis_now.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := basis_now.x
	right.y = 0.0
	right = right.normalized()
	var vf := velocity.dot(fwd)
	var vl := velocity.dot(right)

	var steer_rate := STEER_RATE if absf(input_steer) > absf(steer) else STEER_RATE * 1.6      # centres faster than it turns in
	steer += (input_steer - steer) * minf(1.0, delta * steer_rate)

	# forward / reverse
	if input_throttle > 0.0 and vf < TOP_SPEED:
		var curve := 1.0 - pow(clampf(maxf(vf, 0.0) / (TOP_SPEED * 1.05), 0.0, 1.0), 1.5)
		vf += ACCEL * maxf(curve, 0.0) * input_throttle * delta
	elif input_throttle <= 0.0:
		vf -= signf(vf) * minf(absf(vf), (COAST + DRAG * vf * vf) * delta)
	if input_brake > 0.0:
		if vf > 1.0:
			vf -= BRAKE * input_brake * delta
		elif vf > -REVERSE_TOP:
			vf -= REVERSE_ACCEL * input_brake * delta
	if input_handbrake and absf(vf) > 1.0:
		vf -= signf(vf) * 7.0 * delta

	# grip: cornering hard at speed, or the handbrake, lets the tail slide
	var slip := clampf((absf(vf) - 24.0) / 14.0, 0.0, 1.0) * absf(steer)
	var grip := lerpf(GRIP_NORMAL, GRIP_DRIFT, clampf(slip * 1.6, 0.0, 1.0))
	if input_handbrake and absf(vf) > 6.0:
		grip = GRIP_HANDBRAKE
	vl *= exp(-grip * delta)

	var yaw_rate := steer * minf(YAW_PER_SPEED * absf(vf), CORNER_GRIP / maxf(absf(vf), 1.0)) * signf(vf)
	if input_handbrake:
		yaw_rate *= 1.35
	rotation.y -= yaw_rate * delta

	velocity = fwd * vf + right * vl
	# with grip the velocity turns together with the nose (no crabbing); in a drift only part of it follows, so the car slides
	var follow := clampf((grip - GRIP_HANDBRAKE) / (GRIP_NORMAL - GRIP_HANDBRAKE), 0.0, 1.0)
	velocity = velocity.rotated(Vector3.UP, -yaw_rate * delta * follow)
	velocity.y = 0.0
	_last_velocity = velocity
	move_and_slide()
	global_position.y = 0.0
	_handle_contacts()
	forward_speed = velocity.dot(-global_transform.basis.z)
	slide_speed = vl

	drifting = absf(vl) > 3.2 and absf(vf) > 8.0
	_smoke.emitting = drifting
	if drifting:
		_skid_timer -= delta
		if _skid_timer <= 0.0:
			_skid_timer = 0.04
			var b := global_transform.basis
			var rear := global_position + b.z * 1.45
			skid.emit(rear - b.x * 1.0, rear + b.x * 1.0, rotation.y)
	_lean = lerpf(_lean, clampf(vl * 0.012 - steer * 0.03 * minf(absf(vf) / 30.0, 1.0), -0.12, 0.12), minf(1.0, delta * 8.0))
	_model.rotation.z = _lean
	_update_overlay()


func _handle_contacts() -> void:
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var other: Node = contact.get_collider() as Node
		var normal := contact.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.0001:
			continue
		normal = normal.normalized()
		var closing := -_last_velocity.dot(normal)
		if other != null and other is CharacterBody3D and other.is_in_group("race_car"):
			var rival := other as CharacterBody3D
			if closing > 0.0:
				var push := normal * closing * 0.55          # shoulder the other car along, lose some speed ourselves
				rival.velocity -= push
				velocity += push * 0.35
				if closing > 4.0:
					hit_flash = maxf(hit_flash, minf(1.0, closing / 14.0))
					hit_wall.emit(closing * 0.4)
		elif closing > 6.0:
			hit_flash = maxf(hit_flash, minf(1.0, closing / 20.0))
			hit_wall.emit(closing)


## Returns true when this hit destroyed the car.
func apply_damage(amount: float) -> bool:
	if wrecked or invulnerable > 0.0:
		return false
	health = maxf(0.0, health - amount)
	hit_flash = maxf(hit_flash, 0.6)
	if health <= 0.0:
		wrecked = true
		set_solid(false)
		return true
	return false


## A wreck is not solid: other cars drive through it and bullets pass over it until it respawns.
func set_solid(solid: bool) -> void:
	collision_layer = 2 if solid else 0
	collision_mask = 3 if solid else 0


func repair(amount: float) -> void:
	health = minf(MAX_HEALTH, health + amount)
