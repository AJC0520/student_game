extends Node3D
## The student character (assets/player.glb). Re-skins the glb with the toon / outline shaders like level.gd does
## and animates the rigid body parts (Pv_* pivots) procedurally: idle breathing, walk and run cycle.
## player.gd calls update_pose() every physics frame.

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const MC := preload("res://scripts/material_colors.gd")

@export var stride_rate: float = 1.9          # cycle speed per m/s of movement
@export var leg_swing: float = 0.75           # radians at full run speed
@export var arm_swing: float = 0.6
@export var lean: float = 0.12                # forward lean of the torso at full run speed

var _phase: float = 0.0
var _amount: float = 0.0   # smoothed 0..1 "how much are we moving"
var _idle_t: float = 0.0
var _air: float = 0.0      # smoothed 0..1 "are we airborne"
var _land: float = 0.0     # 1 right after landing, decays to 0
var _toon_cache: Dictionary = {}
var _outline_mat: ShaderMaterial

@onready var _hips: Node3D = find_child("Pv_Hips", true, false)
@onready var _torso: Node3D = find_child("P_Torso", true, false)
@onready var _head: Node3D = find_child("Pv_Head", true, false)
@onready var _arm_l: Node3D = find_child("Pv_ArmL", true, false)
@onready var _arm_r: Node3D = find_child("Pv_ArmR", true, false)
@onready var _leg_l: Node3D = find_child("Pv_LegL", true, false)
@onready var _leg_r: Node3D = find_child("Pv_LegR", true, false)
@onready var _hips_y: float = _hips.position.y


func _ready() -> void:
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OUTLINE
	_skin(self)


## speed: horizontal speed in m/s, run_speed: speed that counts as "full" movement.
func update_pose(delta: float, speed: float, run_speed: float, on_floor: bool, vertical_speed: float = 0.0) -> void:
	var target := clampf(speed / run_speed, 0.0, 1.0) if on_floor else _amount
	_amount = lerpf(_amount, target, clampf(delta * 12.0, 0.0, 1.0))
	_idle_t += delta
	var was_air := _air > 0.5
	_air = lerpf(_air, 0.0 if on_floor else 1.0, clampf(delta * 14.0, 0.0, 1.0))
	if on_floor:
		_phase += delta * speed * stride_rate    # the cycle freezes in the air so the leap starts from the stride
		if was_air and _air <= 0.5:
			_land = 1.0
	_land = maxf(_land - delta * 5.0, 0.0)

	var ground := 1.0 - _air
	var s := sin(_phase)
	var swing := _amount * ground                # ground walk/run weight
	var rise := clampf(vertical_speed / 4.6, -1.0, 1.0)   # +1 going up, -1 falling
	var moving := _amount                         # how much we were moving when we left the ground

	# walk / run cycle
	var leg_r := s * leg_swing * swing
	var leg_l := -leg_r
	var arm_r := -s * arm_swing * swing
	var arm_l := -arm_r
	var spread := 0.05 + 0.1 * swing

	# airborne: a leap when moving (one leg reaching forward, the other trailing, arms counter-swinging),
	# a small hop with the arms slightly out when standing
	if _air > 0.001:
		var lead := 1.0 if s >= 0.0 else -1.0     # the leg that was forward at take-off keeps leading
		leg_r = lerpf(leg_r, lead * 0.6 * moving - 0.1 * rise * (1.0 - moving), _air)
		leg_l = lerpf(leg_l, -lead * 0.45 * moving - 0.1 * rise * (1.0 - moving), _air)
		arm_r = lerpf(arm_r, -lead * 0.7 * moving - 0.3 * (1.0 - moving), _air)
		arm_l = lerpf(arm_l, lead * 0.7 * moving - 0.3 * (1.0 - moving), _air)
		spread = lerpf(spread, 0.2 + 0.15 * (1.0 - moving), _air)
	_leg_r.rotation.x = leg_r
	_leg_l.rotation.x = leg_l
	_arm_r.rotation.x = arm_r
	_arm_l.rotation.x = arm_l
	_arm_r.rotation.z = spread
	_arm_l.rotation.z = -spread

	# --- body ---
	var bob := absf(cos(_phase)) * 0.04 * swing
	var breathe := sin(_idle_t * 2.0) * 0.006 * (1.0 - _amount) * ground
	var crouch := _land * 0.07                    # little squash when landing
	_hips.position.y = _hips_y - 0.02 * swing + bob + breathe - crouch
	_torso.rotation.x = -lean * (swing + 0.6 * moving * _air) + 0.05 * _land
	_torso.rotation.y = s * 0.1 * swing
	_head.rotation.x = lean * (swing + 0.6 * moving * _air) * 0.7
	_head.rotation.y = -s * 0.06 * swing


func _skin(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for i in mi.mesh.get_surface_count():
				var src: Material = mi.mesh.surface_get_material(i)
				var key := src.resource_name.rstrip("0123456789.") if src else ""
				if key == "Toon_Outline":
					mi.set_surface_override_material(i, _outline_mat)
				else:
					mi.set_surface_override_material(i, _toon_for(key, src))
	for child in node.get_children():
		_skin(child)


func _toon_for(key: String, src: Material) -> ShaderMaterial:
	if _toon_cache.has(key):
		return _toon_cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	var col := Color(0.8, 0.8, 0.85)
	if MC.COLORS.has(key):
		col = MC.COLORS[key]
	elif src is BaseMaterial3D:
		col = (src as BaseMaterial3D).albedo_color
	m.set_shader_parameter("albedo", col)
	_toon_cache[key] = m
	return m
