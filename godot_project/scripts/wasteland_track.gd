extends RefCounted
## The modular dirt circuit of the Online room TV racer. It is a loop of 24 m straights and 90 degree curves (radius 24 m)
## laid end to end from a short recipe (LAYOUT: S = straight, L = left curve, R = right curve). The loop closes on itself and
## never crosses itself (checked when the layout was chosen). This script knows the geometry: where each module goes, the
## centre line (a point every ~2 m) with tangents and curvature, and how to find where a car is on it.
## Godot convention: forward at the start is -Z; right of a direction f is (-f.z, 0, f.x).

const LAYOUT := "SLRLSLSSRLSSSLSLSRRLLSSS"
const TILE_LENGTH := 24.0
const CURVE_RADIUS := 24.0
const ARC_STEPS := 18
const ROAD_HALF := 9.5
const WALL_CENTER := 9.0                  # lateral position of the guardrails (centre)
const WALL_THICKNESS := 0.6


class Piece extends RefCounted:
	var kind: String = "S"
	var origin: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3(0.0, 0.0, -1.0)


var pieces: Array[Piece] = []
var points := PackedVector3Array()        # centre line samples, in driving order
var tangents := PackedVector3Array()
var cum := PackedFloat32Array()           # distance along the lap of each sample
var curvature := PackedFloat32Array()     # |1 / radius| around each sample
var length: float = 0.0
var count: int = 0
var _profiles: Dictionary = {}


func _init() -> void:
	var pos := Vector3.ZERO
	var f := Vector3(0.0, 0.0, -1.0)
	for ch in LAYOUT:
		var piece := Piece.new()
		piece.kind = ch
		piece.origin = pos
		piece.forward = f
		pieces.append(piece)
		var left := Vector3(f.z, 0.0, -f.x)
		if ch == "S":
			var k := 0.0
			while k < TILE_LENGTH - 0.01:
				points.append(pos + f * k)
				k += 2.0
			pos += f * TILE_LENGTH
		else:
			var turn := 1.0 if ch == "L" else -1.0
			var inward := left * turn
			var centre := pos + inward * CURVE_RADIUS
			for i in ARC_STEPS:
				var phi := PI * 0.5 * float(i) / float(ARC_STEPS)
				points.append(centre + (-inward * cos(phi) + f * sin(phi)) * CURVE_RADIUS)
			pos = centre + f * CURVE_RADIUS
			f = inward
	count = points.size()
	cum.resize(count)
	var run := 0.0
	for i in count:
		cum[i] = run
		run += points[i].distance_to(points[(i + 1) % count])
	length = run
	tangents.resize(count)
	curvature.resize(count)
	for i in count:
		tangents[i] = (points[(i + 1) % count] - points[i]).normalized()
	var raw := PackedFloat32Array()
	raw.resize(count)
	for i in count:
		var a := tangents[i]
		var b := tangents[(i + 1) % count]
		raw[i] = absf(atan2(a.x * b.z - a.z * b.x, a.dot(b))) / maxf(points[i].distance_to(points[(i + 1) % count]), 0.1)
	for i in count:
		var sum := 0.0
		for j in range(-2, 3):
			sum += raw[(i + j + count) % count]
		curvature[i] = sum / 5.0


func right_of(t: Vector3) -> Vector3:
	return Vector3(-t.z, 0.0, t.x)


func wrap_s(s: float) -> float:
	return fposmod(s, length)


## Index of the last sample at or before lap distance s.
func index_at(s: float) -> int:
	var w := wrap_s(s)
	var lo := 0
	var hi := count - 1
	while lo < hi:                                  # binary search in the cumulative distances
		var mid := (lo + hi + 1) / 2
		if cum[mid] <= w:
			lo = mid
		else:
			hi = mid - 1
	return lo


func center_at(s: float) -> Vector3:
	var i := index_at(s)
	var j := (i + 1) % count
	var seg := maxf(points[i].distance_to(points[j]), 0.001)
	return points[i].lerp(points[j], clampf((wrap_s(s) - cum[i]) / seg, 0.0, 1.0))


func tangent_at(s: float) -> Vector3:
	var i := index_at(s)
	var j := (i + 1) % count
	var seg := maxf(points[i].distance_to(points[j]), 0.001)
	return tangents[i].lerp(tangents[j], clampf((wrap_s(s) - cum[i]) / seg, 0.0, 1.0)).normalized()


func curvature_at(s: float) -> float:
	return curvature[index_at(s)]


## Where a world position is on the track: x = nearest sample index, y = lap distance, z = sideways offset (+ = right).
## `hint` is the sample the car was near last time (the search only looks around it).
func locate(pos: Vector3, hint: int) -> Vector3:
	var best := 1.0e12
	var best_i := hint
	for k in range(-24, 25):
		var i := (hint + k + count) % count
		var d2 := (points[i].x - pos.x) * (points[i].x - pos.x) + (points[i].z - pos.z) * (points[i].z - pos.z)
		if d2 < best:
			best = d2
			best_i = i
	var t := tangents[best_i]
	var off := pos - points[best_i]
	var s := cum[best_i] + off.x * t.x + off.z * t.z
	var lateral := off.x * (-t.z) + off.z * t.x
	return Vector3(float(best_i), wrap_s(s), lateral)


## Fastest speed allowed at lap distance s for a car that corners at lateral acceleration a_lat and brakes at `brake` m/s^2.
func speed_limit(a_lat: float, brake: float, v_top: float, s: float) -> float:
	var key := "%.2f:%.1f:%.1f" % [a_lat, brake, v_top]
	if not _profiles.has(key):
		_profiles[key] = _build_profile(a_lat, brake, v_top)
	var profile: PackedFloat32Array = _profiles[key]
	return profile[index_at(s)]


func _build_profile(a_lat: float, brake: float, v_top: float) -> PackedFloat32Array:
	var v := PackedFloat32Array()
	v.resize(count)
	for i in count:
		v[i] = minf(v_top, sqrt(a_lat / maxf(curvature[i], 0.0001)))
	for _sweep in 3:
		for n in range(count * 2):
			var j := (count - 1 - n % count + count) % count
			var nxt := (j + 1) % count
			var step := points[j].distance_to(points[nxt])
			v[j] = minf(v[j], sqrt(v[nxt] * v[nxt] + 2.0 * brake * step))
	return v
