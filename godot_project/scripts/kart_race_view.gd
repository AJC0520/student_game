extends Node3D
## The Online room TV racer: a low-poly harbour circuit drawn in its own 3D world (a SubViewport, see tv_screen.gd). While
## nobody plays it shows a demo race where T.T. is losing; sofa_race.gd switches it to the real, playable race and shows
## it full screen. The rules live in race_sim.gd, the circuit in race_track.gd, the scenery in race_world.gd and the HUD in
## race_hud.gd; this script moves the cars to where the simulation says they are and follows one of them with the camera.

signal race_finished(player_won: bool)

const RaceTrack := preload("res://scripts/race_track.gd")
const RaceSim := preload("res://scripts/race_sim.gd")
const RaceWorld := preload("res://scripts/race_world.gd")
const RaceHud := preload("res://scripts/race_hud.gd")

const HUD_TEXT := Color8(244, 242, 232)
const HUD_GOOD := Color8(150, 235, 150)
const HUD_BAD := Color8(255, 140, 120)

var _track: RaceTrack = RaceTrack.new()
var _sim: RaceSim
var _world: RaceWorld
var _hud: RaceHud
var _interactive: bool = false
var _race_input: Dictionary = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "boost": false}
var _result_shown: bool = false
var _demo_restart_timer: float = 0.0
var _go_timer: float = 0.0
var _clock: float = 0.0

var _camera: Camera3D
var _cam_dir: Vector3 = Vector3.RIGHT
var _cam_shake: float = 0.0
var _cam_y: float = 5.0
var _car_nodes: Dictionary = {}
var _material_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}


func _ready() -> void:
	_world = RaceWorld.new()
	add_child(_world)
	_world.build(_track)
	_start_demo()
	_build_cars()
	_build_camera()
	_hud = RaceHud.new()
	add_child(_hud)
	_hud.setup(_track.points)
	_sync_cars()
	_update_camera(1.0)
	_update_hud()


func _process(delta: float) -> void:
	_clock += delta
	if not _interactive:                       # menu screen: the cars wait on the grid while the camera circles the start line
		_hud.set_menu(true)
		_orbit_camera()
		return
	_hud.set_menu(false)
	_sim.update(delta, _race_input)
	_sync_cars()
	_update_camera(delta)
	_update_hud()
	if _sim.state == RaceSim.State.FINISHED and not _result_shown:
		_show_result(_sim.player_beat_rival)


# ------------------------------------------------------------------ API used by tv_screen.gd / sofa_race.gd

func start_interactive_race() -> void:
	_interactive = true
	_result_shown = false
	_hud.hide_result()
	_race_input = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "boost": false}
	_sim = RaceSim.new()
	_sim.setup(false)
	_go_timer = 0.0
	_sync_cars()
	_update_camera(1.0)
	_update_hud()


## throttle / brake 0..1, steer -1..1 (+ = right), boost held.
func set_race_input(throttle: float, brake: float, steer: float, boost: bool) -> void:
	_race_input = {"throttle": throttle, "brake": brake, "steer": steer, "boost": boost}


## Ends the race right now and shows the result (Esc, or the race script giving up).
func finish_interactive_race(player_won: bool) -> void:
	if _sim.state != RaceSim.State.FINISHED:
		_sim.abort_as_loss()
	if not _result_shown:
		_show_result(player_won)


func stop_interactive_race() -> void:
	_interactive = false
	_result_shown = false
	_hud.hide_result()
	_race_input = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "boost": false}
	_start_demo()
	_sync_cars()


# ------------------------------------------------------------------ simulation <-> scene

func _start_demo() -> void:
	_sim = RaceSim.new()
	_sim.setup(true)
	_demo_restart_timer = 0.0
	_go_timer = 0.0


func _orbit_camera() -> void:
	var angle := _clock * 0.18
	var centre := _track.center(-12.0) + Vector3.UP * 1.5
	_camera.global_position = centre + Vector3(cos(angle) * 22.0, 7.0, sin(angle) * 22.0)
	_camera.look_at(centre, Vector3.UP)
	_camera.fov = 62.0


func _followed_car() -> RaceSim.Car:
	return _sim.player if _interactive else _sim.rival


## The car drawn between its last two simulation steps (the sim runs at a fixed 60 Hz, the picture does not):
## x = world x, y = world z, z = heading.
func _shown(car: RaceSim.Car) -> Vector3:
	var a := _sim.alpha() if _sim.state == RaceSim.State.RUNNING else 1.0
	return Vector3(lerpf(car.prev_x, car.x, a), lerpf(car.prev_z, car.z, a), lerp_angle(car.prev_h, car.h, a))


func _heading_at(shown: Vector3) -> Vector3:
	return Vector3(cos(shown.z), 0.0, sin(shown.z))


func _sync_cars() -> void:
	for car in _sim.cars:
		var node: Node3D = _car_nodes.get(car.name)
		if node == null:
			continue
		var shown := _shown(car)
		var at := Vector3(shown.x, _track.center(car.s).y + 0.02, shown.y)
		var forward := (_heading_at(shown) + Vector3.UP * _track.slope(car.s)).normalized()      # nose follows the hills
		node.position = at
		node.look_at(at + forward, Vector3.UP)
		node.rotate_object_local(Vector3(0.0, 0.0, 1.0), car.steer * 0.05 * clampf(car.v / 40.0, 0.0, 1.0))    # leans out of the corner
		var flame := node.get_meta("flame") as Node3D
		if flame:
			flame.visible = car.boosting
		if car == _followed_car() and car.hit_flash > 0.0:
			_cam_shake = maxf(_cam_shake, car.hit_flash)


func _update_camera(delta: float) -> void:
	var car := _followed_car()
	if _camera == null or car == null:
		return
	var shown := _shown(car)
	var at := Vector3(shown.x, _track.center(car.s).y, shown.y)
	var wanted := (_track.tangent(car.s) * 0.4 + _heading_at(shown) * 0.6).normalized()      # follows the nose, but never whips around
	if delta >= 0.5:
		_cam_dir = wanted
	else:
		_cam_dir = _cam_dir.lerp(wanted, 1.0 - exp(-delta * 5.0)).normalized()
	var speed_ratio := clampf(car.v / RaceSim.V_TOP, 0.0, 1.3)
	var intro := 0.0
	if _sim.state == RaceSim.State.COUNTDOWN and _interactive:
		intro = clampf(_sim.countdown_left / RaceSim.COUNTDOWN_SECONDS, 0.0, 1.0)
		intro = intro * intro
	var desired := at - _cam_dir * (10.5 + 2.0 * speed_ratio + 8.0 * intro) + Vector3.UP * (4.2 + 0.7 * speed_ratio + 4.0 * intro)
	# sits at a fixed distance behind the car (no lag that grows with speed); only the height is smoothed over crests
	if delta >= 0.5:
		_cam_y = desired.y
	else:
		_cam_y = lerpf(_cam_y, desired.y, 1.0 - exp(-delta * 6.0))
	_camera.global_position = Vector3(desired.x, _cam_y, desired.z)
	_cam_shake = maxf(0.0, _cam_shake - delta * 2.2)
	var shake := Vector3(sin(_clock * 71.0), sin(_clock * 53.0 + 1.0), 0.0) * 0.18 * _cam_shake
	_camera.global_position += shake
	_camera.look_at(at + _cam_dir * 14.0 + Vector3.UP * 1.1, Vector3.UP)
	var target_fov := 60.0 + 20.0 * minf(speed_ratio, 1.0) + (6.0 if car.boosting else 0.0)
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-delta * 4.0))


func _show_result(player_won: bool) -> void:
	_result_shown = true
	var car := _sim.player
	var title := "You beat T.T." if player_won else "T.T. wins"
	if _sim.timed_out:
		title = "Time is up"
	var detail := "place %d of %d" % [maxi(_sim.player_rank, 1), _sim.cars.size()]
	if car.finish_time >= 0.0:
		detail += "     " + _format_time(car.finish_time)
	_hud.show_result(title, detail, "press E to get back on the sofa")
	race_finished.emit(player_won)


func _format_time(t: float) -> String:
	if t < 0.0:
		return "-:--.-"
	return "%d:%02d.%d" % [floori(t / 60.0), int(t) % 60, int(fposmod(t, 1.0) * 10.0)]


# ------------------------------------------------------------------ HUD

func _update_hud() -> void:
	if _hud == null or _sim == null:
		return
	var car := _followed_car()
	var time_text := _format_time(maxf(_sim.race_time, 0.0)) if _sim.state != RaceSim.State.COUNTDOWN else "0:00.0"
	_hud.update_values(_sim.rank_of(car), _sim.cars.size(), _sim.lap_of(car), RaceSim.LAPS, time_text, int(round(car.v * 3.6)), _sim.player.boost)
	_hud.set_driving(_interactive)

	if _interactive:
		var gap := _sim.gap_to_rival_seconds()
		if gap >= 0.0:
			_hud.set_gap("T.T. is %.1f s behind" % gap, HUD_GOOD)
		else:
			_hud.set_gap("T.T. is %.1f s ahead" % absf(gap), HUD_BAD)
	else:
		var rival_rank := _sim.rank_of(_sim.rival)
		_hud.set_gap("T.T. is losing" if rival_rank >= 4 else "T.T. is fighting back", HUD_TEXT)

	var dots: Array[Dictionary] = []
	for other in _sim.cars:
		var spot := _track.center(other.s)
		dots.append({"pos": Vector2(spot.x, spot.z), "color": other.color, "main": other == car})
	_hud.set_dots(dots)

	var countdown_text := ""
	var countdown_color := HUD_TEXT
	if _sim.state == RaceSim.State.COUNTDOWN:
		_go_timer = 0.0
		if _interactive:
			var left := _sim.countdown_left
			if left > 0.5:
				countdown_text = str(int(ceil(left - 0.5)))
			else:
				countdown_text = "GO"
				countdown_color = HUD_GOOD
	else:
		_go_timer += get_process_delta_time()
		if _go_timer < 0.9 and _interactive:
			countdown_text = "GO"
			countdown_color = HUD_GOOD
	_hud.set_countdown(countdown_text, countdown_color)

	if _interactive and _sim.race_time < 10.0:
		_hud.set_hint("W gas   S brake   A D steer   Shift boost   Esc quit")
	else:
		_hud.set_hint("")


# ------------------------------------------------------------------ cars and camera

func _build_cars() -> void:
	for car in _sim.cars:
		var node := _make_car(car.name, car.color, Color8(25, 30, 37), car.number)
		add_child(node)
		_car_nodes[car.name] = node


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "RaceChaseCamera"
	_camera.fov = 62.0
	_camera.near = 0.2
	_camera.far = 3000.0
	_camera.current = true
	add_child(_camera)


func _make_car(label: String, body_color: Color, accent_color: Color, number: int) -> Node3D:
	var car := Node3D.new()
	car.name = label
	var body := _material(body_color, 0.68)
	var dark := _material(accent_color, 0.85)
	var glass := _material(Color8(36, 62, 82), 0.28)
	var tire := _material(Color8(13, 15, 19), 0.95)
	var metal := _material(Color8(190, 197, 199), 0.48)
	var lamp := _material(Color8(255, 50, 38), 0.45)
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.57
	wheel_mesh.bottom_radius = 0.57
	wheel_mesh.height = 0.42
	wheel_mesh.radial_segments = 8
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.2
	hub_mesh.bottom_radius = 0.2
	hub_mesh.height = 0.44
	hub_mesh.radial_segments = 8
	_add_box(car, Vector3(2.5, 0.56, 4.8), Vector3(0, 0.72, 0), body)
	_add_box(car, Vector3(2.28, 0.36, 1.65), Vector3(0, 1.04, 1.15), body)
	_add_box(car, Vector3(2.05, 0.32, 1.7), Vector3(0, 0.94, -1.36), body)
	_add_box(car, Vector3(1.62, 0.78, 2.1), Vector3(0, 1.32, 0.05), dark)
	_add_box(car, Vector3(1.5, 0.5, 0.11), Vector3(0, 1.42, -1.02), glass)
	_add_box(car, Vector3(1.48, 0.48, 0.11), Vector3(0, 1.42, 1.1), glass)
	_add_box(car, Vector3(1.62, 0.18, 1.0), Vector3(0, 1.79, 0.0), body)
	_add_box(car, Vector3(2.95, 0.16, 0.28), Vector3(0, 1.33, 2.0), body)
	_add_box(car, Vector3(0.22, 0.72, 0.2), Vector3(-0.98, 0.98, 1.9), body)
	_add_box(car, Vector3(0.22, 0.72, 0.2), Vector3(0.98, 0.98, 1.9), body)
	_add_box(car, Vector3(0.45, 0.24, 0.16), Vector3(-0.82, 0.84, 2.42), lamp)
	_add_box(car, Vector3(0.45, 0.24, 0.16), Vector3(0.82, 0.84, 2.42), lamp)
	_add_box(car, Vector3(0.72, 0.34, 0.07), Vector3(0.0, 1.08, 2.47), _material(Color8(240, 239, 222)))
	var number_label := Label3D.new()
	number_label.text = "%02d" % number
	number_label.font_size = 64
	number_label.pixel_size = 0.004
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.modulate = Color8(24, 36, 48)
	number_label.position = Vector3(0.0, 1.08, 2.515)
	number_label.rotation.y = 0.0
	car.add_child(number_label)
	_add_box(car, Vector3(1.45, 0.15, 0.18), Vector3(0, 0.26, -2.36), dark)
	for wheel_x: float in [-1.28, 1.28]:
		for wheel_z: float in [-1.48, 1.52]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(wheel_x, 0.56, wheel_z)
			wheel.rotation.z = PI * 0.5
			wheel.material_override = tire
			car.add_child(wheel)
			var hub_instance := MeshInstance3D.new()
			hub_instance.mesh = hub_mesh
			hub_instance.position = wheel.position
			hub_instance.rotation.z = PI * 0.5
			hub_instance.material_override = metal
			car.add_child(hub_instance)
	# blob shadow on the road and a boost flame at the back
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow := _add_box(car, Vector3(3.1, 0.02, 5.4), Vector3(0.0, 0.025, 0.0), shadow_mat)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color8(255, 150, 40)
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flame := _add_box(car, Vector3(0.9, 0.5, 2.2), Vector3(0.0, 0.84, 3.6), flame_mat)
	flame.visible = false
	car.set_meta("flame", flame)
	if label == "T.T":                      # the one to beat gets a small tag above the car
		var tag := Label3D.new()
		tag.text = "T.T."
		tag.font_size = 48
		tag.pixel_size = 0.014
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color8(170, 212, 255)
		tag.outline_size = 8
		tag.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		tag.shaded = false
		tag.position = Vector3(0.0, 3.4, 0.0)
		car.add_child(tag)
	return car


func _add_box(parent: Node, size: Vector3, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_key := "%.2f,%.2f,%.2f" % [size.x, size.y, size.z]
	var box: BoxMesh
	if _box_mesh_cache.has(mesh_key):
		box = _box_mesh_cache[mesh_key] as BoxMesh
	else:
		box = BoxMesh.new()
		box.size = size
		_box_mesh_cache[mesh_key] = box
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return instance


func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var cache_key := "%s:%d" % [color.to_html(true), int(roughness * 100.0)]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_material_cache[cache_key] = material
	return material
