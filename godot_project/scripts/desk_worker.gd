extends "res://scripts/static_model.gd"
## The student working at the group table by the west window (assets/npc_worker.glb): types on the laptop and every
## ~14 s drinks some coffee: the right hand leaves the keys, grabs the mug on the table, lifts it to his mouth while he
## leans his head back and tilts the mug, then puts it down and goes back to typing.
## The right arm is solved with a small two-bone IK in the (forward, up) plane, so the hand really reaches the mug and
## the mouth. Everything is a pure function of time. The glb is exported in its final world position (node at the origin).

const CYCLE := 14.0          # seconds between sips

# right arm rig, (forward, up) relative to the seat (matches npc_worker.py)
const SHOULDER := Vector2(0.086, 0.59)
const UPPER_LEN := 0.28
const FORE_LEN := 0.31
# hand targets (forward, up) of the hand centre
# (all hand poses below were fitted in Blender so the hand really lands on the keys / mug / mouth)
const HAND_TYPE := Vector2(0.52, 0.286)       # on the keyboard
const HAND_HOVER := Vector2(0.484, 0.406)     # just above the mug
const HAND_MUG := Vector2(0.484, 0.31)        # holding the mug on the table
const HAND_MOUTH := Vector2(0.453, 0.814)     # mug at his lips (fitted in Blender: with SIDE_MOUTH the rim lands on the mouth)
const MUG_HOLD_DROP := 0.045                  # mug bottom is this far below the hand centre
const SIDE_TYPE := -0.428                     # shoulder swing in so the right hand is over the keys
const SIDE_HOVER := 0.291
const SIDE_MUG := 0.23                        # shoulder swing out to the mug (it stands a bit to his right)
const SIDE_MOUTH := -1.13                     # shoulder swing in across the chest, so the hand comes to his mouth from the front

@export var speed: float = 1.0

var _t: float = 0.0
var _mug_rest: Transform3D

@onready var _torso: Node3D = find_child("Dw_Torso", true, false)
@onready var _head: Node3D = find_child("Dw_Head", true, false)
@onready var _upper_r: Node3D = find_child("Dw_UpperR", true, false)
@onready var _upper_l: Node3D = find_child("Dw_UpperL", true, false)
@onready var _fore_r: Node3D = find_child("Dw_ForeR", true, false)
@onready var _fore_l: Node3D = find_child("Dw_ForeL", true, false)
@onready var _hand_r: Node3D = find_child("Dw_HandR", true, false)
@onready var _mug: Node3D = find_child("Dw_Mug", true, false)


func _ready() -> void:
	super()
	_mug_rest = _mug.global_transform


func _process(delta: float) -> void:
	_t += delta * speed
	var c := fposmod(_t, CYCLE)

	# breathing
	var breath := 0.5 + 0.5 * sin(_t * 1.8)
	_torso.scale = Vector3(1.0 + 0.008 * breath, 1.0 + 0.012 * breath, 1.0)

	# right hand path through the sip: keys -> above mug -> mug -> mouth -> mug -> above mug -> keys
	var target := HAND_TYPE + Vector2(0.0, sin(_t * 19.0) * 0.006)           # key presses
	target = target.lerp(HAND_HOVER, smoothstep(8.0, 8.7, c))
	target = target.lerp(HAND_MUG, smoothstep(8.7, 9.0, c))
	target = target.lerp(HAND_MOUTH + Vector2(0.0, sin(_t * 2.0) * 0.004), smoothstep(9.3, 10.3, c))
	target = target.lerp(HAND_MUG, smoothstep(11.7, 12.7, c))
	target = target.lerp(HAND_HOVER, smoothstep(12.8, 13.2, c))
	target = target.lerp(HAND_TYPE, smoothstep(13.2, 13.9, c))
	# sideways swing of the shoulder: out to the mug (it is a bit to his right), in towards his mouth
	var side := lerpf(SIDE_TYPE, SIDE_HOVER, smoothstep(8.0, 8.7, c))
	side = lerpf(side, SIDE_MUG, smoothstep(8.7, 9.0, c))
	side = lerpf(side, SIDE_MOUTH, smoothstep(9.3, 10.3, c))
	side = lerpf(side, SIDE_MUG, smoothstep(11.7, 12.7, c))
	side = lerpf(side, SIDE_HOVER, smoothstep(12.8, 13.2, c))
	side = lerpf(side, SIDE_TYPE, smoothstep(13.2, 13.9, c))
	var angles := _solve_arm(target)
	_upper_r.rotation = Vector3(angles.x, 0.0, side)
	_fore_r.rotation.x = angles.y

	# left hand keeps typing
	_upper_l.rotation = Vector3(0.471 + sin(_t * 0.7) * 0.02, 0.0, 0.435)         # fitted: left hand over the keys
	_fore_l.rotation.x = 0.927 + sin(_t * 13.0 + 1.3) * 0.05

	# head: looks down at the screen, glances up now and then, leans back for the sip
	var sip := smoothstep(9.9, 10.5, c) * (1.0 - smoothstep(11.4, 12.0, c))
	var glance := maxf(0.0, sin(_t * 0.45)) * 0.05
	_head.rotation = Vector3(-0.1 + glance * (1.0 - sip) + sip * 0.3, sin(_t * 0.31) * 0.06 * (1.0 - sip), sin(_t * 0.23) * 0.02)

	# the mug: on the table, in the hand while it is held (upright, tipping towards his mouth during the sip)
	var held := smoothstep(9.0, 9.15, c) * (1.0 - smoothstep(12.65, 12.8, c))
	if held > 0.001:
		var in_hand := _hand_r.global_position + Vector3.DOWN * MUG_HOLD_DROP
		var pos := _mug_rest.origin.lerp(in_hand, held)
		var tilt := smoothstep(10.2, 10.7, c) * (1.0 - smoothstep(11.2, 11.7, c)) * 0.55      # fitted together with HAND_MOUTH
		var axis := _torso.global_transform.basis.x.normalized()               # his right: positive tilt = rim towards him
		_mug.global_transform = Transform3D(_mug_rest.basis.rotated(axis, tilt * held), pos)
	else:
		_mug.global_transform = _mug_rest


## Two-bone IK in the (forward, up) plane. Returns (upper arm angle, forearm angle relative to the upper arm), both measured
## from "hanging straight down" with positive = swinging forward (the same convention as the pivots' rotation.x).
func _solve_arm(target: Vector2) -> Vector2:
	var d := target - SHOULDER
	var dist := clampf(d.length(), 0.08, UPPER_LEN + FORE_LEN - 0.005)
	var phi := atan2(d.x, -d.y)
	var a := acos(clampf((UPPER_LEN * UPPER_LEN + dist * dist - FORE_LEN * FORE_LEN) / (2.0 * UPPER_LEN * dist), -1.0, 1.0))
	var th1 := phi - a                                  # the elbow stays below the line shoulder -> hand
	var elbow := SHOULDER + Vector2(sin(th1), -cos(th1)) * UPPER_LEN
	var e := target - elbow
	var th2 := atan2(e.x, -e.y)
	var rel := th2 - th1
	if rel < -0.3:
		rel += TAU                                       # keep the elbow bend continuous when the forearm points up
	return Vector2(th1, rel)
