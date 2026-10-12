extends "res://scripts/static_model.gd"
## The guy slouching on the Online room's corner sofa (assets/npc_sofa.glb). Same toon re-skin as static_model.gd,
## plus a small procedural idle loop on the Sg_* pivots: breathing, an occasional sigh, head lolling, rubbing his forehead,
## mashing the controller in bursts and tapping a foot.
## All motion is a pure function of time, so nothing needs to be saved or synced.

@export var speed: float = 1.0                # global playback speed of the idle loop

var _t: float = 0.0

@onready var _torso: Node3D = find_child("Sg_Torso", true, false)
@onready var _head: Node3D = find_child("Sg_Head", true, false)
@onready var _arm_r: Node3D = find_child("Sg_ArmR", true, false)
@onready var _arm_l: Node3D = find_child("Sg_ArmL", true, false)
@onready var _pad: Node3D = find_child("Sg_Pad", true, false)
@onready var _leg_l: Node3D = find_child("Sg_LegL", true, false)
@onready var _foot_r: Node3D = find_child("Sg_FootR", true, false)
@onready var _foot_l: Node3D = find_child("Sg_FootL", true, false)


func _process(delta: float) -> void:
	_t += delta * speed
	var t := _t

	# breathing, with a long sigh every ~11 s
	var breath := 0.5 + 0.5 * sin(t * 1.7)
	var sigh := pow(sin(clampf(fmod(t, 11.0) / 2.6, 0.0, 1.0) * PI), 2.0)
	_torso.scale = Vector3(1.0 + 0.012 * breath + 0.012 * sigh, 1.0 + 0.03 * breath + 0.05 * sigh, 1.0 + 0.012 * breath)
	_torso.rotation.x = -0.01 * breath - 0.025 * sigh

	# head lolls slowly and drops a little on the sigh
	_head.rotation = Vector3(sin(t * 0.5 + 1.0) * 0.03 + sigh * 0.05, sin(t * 0.35) * 0.05, sin(t * 0.27) * 0.03)

	# hand on forehead: slow drift, plus a rub every ~7 s
	var rub := pow(sin(clampf(fmod(t + 2.0, 7.0) / 1.6, 0.0, 1.0) * PI), 2.0)
	_arm_r.rotation = Vector3(sin(t * 0.6) * 0.015, sin(t * 9.0) * 0.05 * rub, sin(t * 0.8) * 0.02 + rub * 0.04)

	# controller: bursts of thumb mashing, calm in between
	var burst := smoothstep(0.5, 0.85, sin(t * 0.45))
	_pad.rotation = Vector3(sin(t * 27.0) * 0.045, sin(t * 31.0) * 0.03, sin(t * 23.0) * 0.05) * burst
	_arm_l.rotation = Vector3(0.01 * breath + sin(t * 17.0) * 0.012 * burst, 0.0, 0.0)

	# legs: right foot taps in bursts, left leg just settles
	var tap := smoothstep(0.3, 0.6, sin(t * 0.3 + 2.0))
	_foot_r.rotation.x = maxf(0.0, sin(t * 7.0)) * 0.3 * tap
	_foot_l.rotation.x = sin(t * 0.9) * 0.02
	_leg_l.rotation.x = sin(t * 0.7) * 0.01
