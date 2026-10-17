extends RefCounted
## The racing rules behind the Online room TV game: arcade car physics, AI drivers, a start countdown, boost, collisions and
## results. No nodes in here; kart_race_view.gd draws the state and feeds the input.
##
## Every car is a real moving body in the world (position x / z, heading h, velocity vx / vz). The wheels steer the nose with a
## yaw rate that is limited by grip (fast = wide turns), the velocity follows the nose with a little slide, the throttle and
## brake pedals build up smoothly, and the barriers and other cars push back like solid objects. The track is only used to
## measure progress (s = distance along it, d = sideways offset, psi = heading relative to the road) and by the AI.
## Tuned with a Python copy of this model: T.T. (skill 0.97, uses boost and rubber-bands to the player) is only beaten by a
## clean, fast race.

const RaceTrack := preload("res://scripts/race_track.gd")

const LAPS := 2
const ROAD_HALF_WIDTH := 13.0
const BARRIER_D := 15.6
const SLOPE_DRAG := 6.0             # m/s^2 lost per unit of road slope (uphill is slower)
const V_TOP := 55.0                 # m/s (198 km/h)
const ACCEL := 9.5                  # m/s^2 from a standstill; fades out towards top speed (0-100 km/h in ~4 s)
const BRAKE := 22.0                 # m/s^2 with the brake fully down
const COAST := 1.8                  # engine braking when you lift off
const DRAG := 0.0016                # extra slowing per (m/s)^2 when off the throttle
const PEDAL_UP_RATE := 7.0          # how quickly the throttle / brake pedals reach what the keys ask for (1/s)
const PEDAL_BRAKE_RATE := 12.0
const GRASS_V := 26.0               # the most you can do on the grass
const STEER_GRIP := 24.0            # the most lateral acceleration the tyres give (m/s^2)
const YAW_PER_SPEED := 0.2          # yaw rate at full lock per m/s at low speed (1/m)
const LAT_GRIP_ROAD := 9.0          # how fast sideways slide dies out (1/s)
const LAT_GRIP_GRASS := 3.0
const AI_CORNER_G := 22.0           # lateral acceleration the AI drivers plan their corners with
const STEER_RATE_UP := 5.0          # how fast the wheel follows a pressed key (1/s)
const STEER_RATE_DOWN := 8.0        # and how fast it returns to centre
const SIM_DT := 1.0 / 60.0
const CAR_RADIUS := 1.45
const COUNTDOWN_SECONDS := 3.5
const MAX_RACE_SECONDS := 240.0
const BOOST_SECONDS := 2.5
const BOOST_RECHARGE_PER_SECOND := 0.12

enum State { COUNTDOWN, RUNNING, FINISHED }


class Car extends RefCounted:
	var name: String = ""
	var number: int = 0
	var color: Color = Color.WHITE
	var is_player: bool = false
	var skill: float = 0.9
	var uses_boost: bool = false
	var lane_amp: float = 2.0
	var phase: float = 0.0
	var x: float = 0.0                # world position and heading (heading 0 = +x, turning right = increasing)
	var z: float = 0.0
	var h: float = 0.0
	var vx: float = 0.0               # world velocity
	var vz: float = 0.0
	var prev_x: float = 0.0           # state one simulation step ago, for smooth drawing between steps
	var prev_z: float = 0.0
	var prev_h: float = 0.0
	var s: float = 0.0                # progress along the track, offset from the centre line, heading relative to the road
	var d: float = 0.0
	var psi: float = 0.0
	var v: float = 0.0                # forward speed
	var steer: float = 0.0
	var pedal_throttle: float = 0.0
	var pedal_brake: float = 0.0
	var boost: float = 1.0
	var boosting: bool = false
	var finish_time: float = -1.0
	var bump_cooldown: float = 0.0
	var wall_cooldown: float = 0.0
	var hit_flash: float = 0.0        # 1 -> 0 after a collision (the view shakes the camera with it)


var track: RaceTrack = RaceTrack.new()
var cars: Array[Car] = []
var player: Car
var rival: Car                        # T.T., the one to beat
var state: State = State.COUNTDOWN
var countdown_left: float = COUNTDOWN_SECONDS
var race_time: float = 0.0
var demo: bool = false                # true = every car (also the red one) is driven by the AI
var player_rank: int = 0
var player_beat_rival: bool = false
var timed_out: bool = false

var _accum: float = 0.0


func setup(is_demo: bool) -> void:
	demo = is_demo
	cars.clear()
	state = State.COUNTDOWN
	countdown_left = COUNTDOWN_SECONDS
	race_time = 0.0
	player_rank = 0
	player_beat_rival = false
	timed_out = false
	_accum = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	# name, number, colour, skill, s, d
	var grid: Array[Dictionary] = [
		{"name": "JON", "number": 4, "color": Color8(243, 203, 34), "skill": 0.955, "s": -6.0, "d": -4.0},
		{"name": "LEA", "number": 5, "color": Color8(126, 53, 179), "skill": 0.925, "s": -6.0, "d": 4.0},
		{"name": "YOU", "number": 1, "color": Color8(214, 33, 29), "skill": 0.96, "s": -18.0, "d": -4.0},
		{"name": "T.T", "number": 7, "color": Color8(34, 113, 211), "skill": 0.97, "s": -18.0, "d": 4.0},
		{"name": "MIA", "number": 12, "color": Color8(40, 154, 81), "skill": 0.87, "s": -30.0, "d": -4.0},
		{"name": "KAI", "number": 22, "color": Color8(244, 150, 31), "skill": 0.84, "s": -30.0, "d": 4.0},
	]
	for entry: Dictionary in grid:
		var car := Car.new()
		car.name = entry["name"]
		car.number = entry["number"]
		car.color = entry["color"]
		car.skill = entry["skill"]
		car.s = entry["s"]
		car.d = entry["d"]
		_place(car)
		car.lane_amp = rng.randf_range(1.0, 3.0)
		car.phase = rng.randf_range(0.0, 6.0)
		car.is_player = car.name == "YOU" and not is_demo
		car.uses_boost = car.name == "T.T"
		cars.append(car)
		if car.name == "YOU":
			player = car
		elif car.name == "T.T":
			rival = car
	if is_demo:
		rival.skill = 0.80            # in the preview T.T. is losing, as the TV likes to point out
		rival.uses_boost = false
	cars.sort_custom(func(a: Car, b: Car) -> bool: return a.s > b.s)


func update(delta: float, input: Dictionary) -> void:
	if state == State.FINISHED:
		return
	_accum += minf(delta, 0.1)
	while _accum >= SIM_DT and state != State.FINISHED:
		_accum -= SIM_DT
		_step(SIM_DT, input)


## How far (0..1) the picture is between the last two simulation steps; the view blends the cars' states with it.
func alpha() -> float:
	return clampf(_accum / SIM_DT, 0.0, 1.0)


func total_distance() -> float:
	return LAPS * track.length


## 1 = leading. Finished cars rank by finish time, the others by distance driven.
func rank_of(car: Car) -> int:
	var mine := _progress(car)
	var rank := 1
	for other in cars:
		if other != car and _progress(other) > mine:
			rank += 1
	return rank


func lap_of(car: Car) -> int:
	return clampi(int(floorf(maxf(car.s, 0.0) / track.length)) + 1, 1, LAPS)


## Seconds the player is ahead of (+) or behind (-) the rival, from the distance between them and the player's speed.
func gap_to_rival_seconds() -> float:
	if player == null or rival == null:
		return 0.0
	return (player.s - rival.s) / maxf(maxf(player.v, rival.v), 12.0)


## Ends the race early (Esc): the player is treated as having lost to T.T.
func abort_as_loss() -> void:
	player_rank = rank_of(player)
	player_beat_rival = false
	state = State.FINISHED


func _progress(car: Car) -> float:
	if car.finish_time >= 0.0:
		return 1.0e7 - car.finish_time
	return car.s


func _step(dt: float, input: Dictionary) -> void:
	if state == State.COUNTDOWN:
		countdown_left -= dt
		if countdown_left <= 0.0:
			state = State.RUNNING
		return
	race_time += dt
	for car in cars:
		car.bump_cooldown = maxf(0.0, car.bump_cooldown - dt)
		car.wall_cooldown = maxf(0.0, car.wall_cooldown - dt)
		car.hit_flash = maxf(0.0, car.hit_flash - dt * 2.5)
		car.prev_x = car.x
		car.prev_z = car.z
		car.prev_h = car.h
		var command: Dictionary
		if car.is_player:
			command = input
		else:
			command = _drive_ai(car)
		_step_car(car, dt, command)
	_resolve_collisions(dt)
	for car in cars:
		_project(car)
		if car.finish_time < 0.0 and car.s >= total_distance():
			car.finish_time = race_time
	_check_end()


func _check_end() -> void:
	var tracked := player          # the race ends when the red car (player or demo AI) crosses the line
	if tracked.finish_time >= 0.0:
		player_rank = rank_of(tracked)
		player_beat_rival = rival.finish_time < 0.0 or rival.finish_time > tracked.finish_time
		state = State.FINISHED
	elif race_time >= MAX_RACE_SECONDS:
		timed_out = true
		player_rank = rank_of(tracked)
		player_beat_rival = tracked.s > rival.s
		state = State.FINISHED


func _drive_ai(car: Car) -> Dictionary:
	var rubber := 1.0
	if not demo and car != player:
		var lead := player.s - car.s            # > 0 = the player is ahead of this car
		if car == rival:                         # T.T. hunts you down when you pull away, but eases off when he is clear
			rubber = clampf(1.0 + 0.0005 * lead, 0.975, 1.045)
		else:
			rubber = clampf(1.0 + 0.00025 * lead, 0.94, 1.045)     # keeps the pack close to the player
	var curvature_here := track.curvature(car.s)
	var lane_scale := 0.6 if absf(curvature_here) > 0.01 else 1.0
	var d_target := 0.0
	if car != player:                    # the red car drives the racing line in the demo, the others wander a little
		d_target = sin(race_time * 0.3 + car.phase) * car.lane_amp * lane_scale
	var a_lat := AI_CORNER_G * car.skill * car.skill
	var target_speed := minf(track.speed_limit(a_lat, BRAKE, V_TOP, car.s), V_TOP * car.skill) * rubber
	var speed := maxf(car.v, 0.0)
	var throttle := 1.0 if speed < target_speed else 0.0
	var brake := 1.0 if speed > target_speed + 1.5 else 0.0
	var k_ahead := track.curvature(car.s + speed * 0.15)
	var yaw_cap := minf(YAW_PER_SPEED * maxf(speed, 1.0), STEER_GRIP / maxf(speed, 1.0))
	var feed_forward := k_ahead * speed / maxf(yaw_cap, 0.001)
	var psi_wanted := -clampf(0.05 * (car.d - d_target), -0.5, 0.5)
	var steer := clampf(feed_forward + 2.2 * (psi_wanted - car.psi), -1.0, 1.0)
	var boost := false
	if car.uses_boost and car.boost > 0.2 and throttle > 0.0 and speed > 30.0:
		boost = absf(curvature_here) < 0.004 and absf(track.curvature(car.s + speed * 1.2)) < 0.006
	return {"throttle": throttle, "brake": brake, "steer": steer, "boost": boost}


func _place(car: Car) -> void:
	var centre := track.center(car.s)
	var side := track.side(car.s)
	var t := track.tangent(car.s)
	car.x = centre.x + side.x * car.d
	car.z = centre.z + side.z * car.d
	car.h = atan2(t.z, t.x)
	car.vx = 0.0
	car.vz = 0.0
	car.prev_x = car.x
	car.prev_z = car.z
	car.prev_h = car.h


## Works out progress (s), sideways offset (d) and heading relative to the road (psi) from the world position.
func _project(car: Car) -> void:
	for _i in 3:
		var c := track.center(car.s)
		var t := track.tangent(car.s)
		car.s += (car.x - c.x) * t.x + (car.z - c.z) * t.z
	var c2 := track.center(car.s)
	var t2 := track.tangent(car.s)
	car.d = (car.x - c2.x) * (-t2.z) + (car.z - c2.z) * t2.x
	car.psi = wrapf(car.h - atan2(t2.z, t2.x), -PI, PI)


func _step_car(car: Car, dt: float, input: Dictionary) -> void:
	var throttle: float = clampf(float(input.get("throttle", 0.0)), 0.0, 1.0)
	var brake: float = clampf(float(input.get("brake", 0.0)), 0.0, 1.0)
	var steer_in: float = clampf(float(input.get("steer", 0.0)), -1.0, 1.0)
	var want_boost: bool = bool(input.get("boost", false))

	# the steering wheel follows the keys with a little delay (so a tapped key is a small correction)
	var wheel_rate := STEER_RATE_UP if absf(steer_in) > 0.01 else STEER_RATE_DOWN
	car.steer += (steer_in - car.steer) * minf(1.0, dt * wheel_rate)

	car.boosting = false
	if want_boost and car.boost > 0.0 and throttle > 0.0:
		car.boosting = true
		car.boost = maxf(0.0, car.boost - dt / BOOST_SECONDS)
	elif not want_boost:
		car.boost = minf(1.0, car.boost + dt * BOOST_RECHARGE_PER_SECOND)

	# pedals: they take a moment to reach what the keys ask for, so acceleration and braking build up smoothly
	car.pedal_throttle += (throttle - car.pedal_throttle) * minf(1.0, dt * PEDAL_UP_RATE)
	car.pedal_brake += (brake - car.pedal_brake) * minf(1.0, dt * PEDAL_BRAKE_RATE)

	var fwd := Vector2(cos(car.h), sin(car.h))
	var right := Vector2(-fwd.y, fwd.x)
	var vel := Vector2(car.vx, car.vz)
	var vf := vel.dot(fwd)
	var vl := vel.dot(right)

	var on_grass := absf(car.d) > ROAD_HALF_WIDTH
	var v_top := V_TOP * (1.12 if car.boosting else 1.0)
	var v_cap := v_top if not on_grass else GRASS_V
	if vf < v_cap:
		var accel := ACCEL * (1.0 - pow(minf(maxf(vf, 0.0) / (v_top * 1.05), 1.0), 1.5))
		if car.boosting:
			accel *= 1.6
		vf += maxf(accel, 0.0) * car.pedal_throttle * dt
	vf -= (COAST + DRAG * vf * vf) * (1.0 - car.pedal_throttle) * dt
	vf -= BRAKE * car.pedal_brake * dt
	vf -= track.slope(car.s) * SLOPE_DRAG * dt
	if on_grass and vf > GRASS_V:
		vf -= 14.0 * dt
	vf = maxf(vf, 0.0)
	vl *= exp(-(LAT_GRIP_GRASS if on_grass else LAT_GRIP_ROAD) * dt)       # the tyres pull the slide out
	vel = fwd * vf + right * vl
	car.vx = vel.x
	car.vz = vel.y
	car.v = vf

	# the nose turns with a yaw rate that grows with speed at first and is limited by grip later (wide turns when fast)
	var yaw_rate := car.steer * minf(YAW_PER_SPEED * vf, STEER_GRIP / maxf(vf, 1.0))
	car.h += yaw_rate * dt
	car.x += car.vx * dt
	car.z += car.vz * dt
	_project(car)

	if absf(car.d) > BARRIER_D:                    # the barrier is solid: no bouncing, it scrubs speed and turns the nose along it
		var t := track.tangent(car.s)
		var n := Vector2(-t.z, t.x) * signf(car.d)
		var over := absf(car.d) - BARRIER_D
		car.x -= n.x * over
		car.z -= n.y * over
		var vn := car.vx * n.x + car.vz * n.y
		if vn > 0.0:
			car.vx -= n.x * vn * 1.15
			car.vz -= n.y * vn * 1.15
			if vn > 4.0 and car.wall_cooldown <= 0.0:
				car.wall_cooldown = 0.4
				car.hit_flash = minf(1.0, vn / 12.0)
		car.vx *= 1.0 - 0.5 * dt
		car.vz *= 1.0 - 0.5 * dt
		if cos(car.h) * n.x + sin(car.h) * n.y > 0.0:
			car.h += wrapf(atan2(t.z, t.x) - car.h, -PI, PI) * minf(1.0, dt * 4.0)
		_project(car)


## Cars are three circles each (front, middle, rear). Overlapping circles are pushed apart and exchange momentum like soft
## solid bodies; an off-centre hit also nudges the nose a little.
func _resolve_collisions(_dt: float) -> void:
	var offsets: Array[float] = [-1.6, 0.0, 1.6]
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a: Car = cars[i]
			var b: Car = cars[j]
			if (a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z) > 36.0:
				continue
			var best := 1.0e9
			var best_delta := Vector2.ZERO
			var best_oa := 0.0
			var best_ob := 0.0
			for oa in offsets:
				var pa := Vector2(a.x + cos(a.h) * oa, a.z + sin(a.h) * oa)
				for ob in offsets:
					var pb := Vector2(b.x + cos(b.h) * ob, b.z + sin(b.h) * ob)
					var delta := pa - pb
					var dist := delta.length()
					if dist < 2.0 * CAR_RADIUS and dist < best:
						best = dist
						best_delta = delta
						best_oa = oa
						best_ob = ob
			if best > 1.0e8:
				continue
			var normal := Vector2(1.0, 0.0)
			if best > 0.0001:
				normal = best_delta / best
			var over := 2.0 * CAR_RADIUS - best
			a.x += normal.x * over * 0.5
			a.z += normal.y * over * 0.5
			b.x -= normal.x * over * 0.5
			b.z -= normal.y * over * 0.5
			var closing := (a.vx - b.vx) * normal.x + (a.vz - b.vz) * normal.y
			if closing < 0.0:
				var impulse := -(1.0 + 0.15) * closing * 0.5
				a.vx += normal.x * impulse
				a.vz += normal.y * impulse
				b.vx -= normal.x * impulse
				b.vz -= normal.y * impulse
				a.h += clampf((cos(a.h) * normal.y - sin(a.h) * normal.x) * impulse * best_oa * 0.004, -0.05, 0.05)
				b.h -= clampf((cos(b.h) * normal.y - sin(b.h) * normal.x) * impulse * best_ob * 0.004, -0.05, 0.05)
				if impulse > 1.2:
					for car: Car in [a, b]:
						if car.bump_cooldown <= 0.0:
							car.bump_cooldown = 0.4
							car.hit_flash = clampf(impulse / 5.0, 0.2, 0.8)
