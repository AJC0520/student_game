extends Node3D
## The wasteland racer shown on the Online room TV (rendered in its own world by tv_screen.gd): a top-down, car-combat style
## race on a modular dirt track with yellow guardrails and junk all around. You (red) race five rivals for 3 laps and have to
## beat T.T. (blue). Crashing costs health, repair kits are on the track, and a wrecked car respawns after a moment.
## Pieces: wasteland_track.gd (geometry), wasteland_car.gd (arcade CharacterBody3D cars), wasteland_hud.gd (HUD + minimap).
## Models come from assets/wasteland/*.glb (blender_assets/build_scripts/wasteland_assets.py).
## The interface towards sofa_race.gd / tv_screen.gd is the same as the old racer: start_interactive_race(),
## set_race_input(), finish_interactive_race(), stop_interactive_race() and the race_finished signal.

signal race_finished(player_won: bool)

const Track := preload("res://scripts/wasteland_track.gd")
const Car := preload("res://scripts/wasteland_car.gd")
const Hud := preload("res://scripts/wasteland_hud.gd")
const StaticMerge := preload("res://scripts/static_merge.gd")

const ASSET_DIR := "res://assets/wasteland/"
const LAPS := 3
const COUNTDOWN_SECONDS := 3.5
const MAX_RACE_SECONDS := 300.0
const MINIMAP_LAYER := 2

const AI_CORNER_G := 17.0
const AI_BRAKE := 24.0
const SKID_POOL := 260

enum State { COUNTDOWN, RUNNING, FINISHED }

var _track: Track = Track.new()
var _hud: Hud
var _camera: Camera3D
var _cars: Array[Car] = []
var _player: Car
var _rival: Car
var _blips: Dictionary = {}
var _state: State = State.COUNTDOWN
var _countdown_left: float = COUNTDOWN_SECONDS
var _race_time: float = 0.0
var _interactive: bool = false
var _result_shown: bool = false
var _player_rank: int = 0
var _player_beat_rival: bool = false
var _timed_out: bool = false
var _clock: float = 0.0
var _go_timer: float = 0.0
var _cam_shake: float = 0.0
var _cam_target: Vector3 = Vector3.ZERO

var _in_throttle: float = 0.0
var _in_brake: float = 0.0
var _in_steer: float = 0.0
var _in_handbrake: bool = false

var _pickups: Array[Dictionary] = []
var _skids: Array[MeshInstance3D] = []
var _skid_next: int = 0
var _skid_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _scene_cache: Dictionary = {}
var debug_damage: Dictionary = {}          # damage the player took, by source (for playtests)


func _ready() -> void:
	_rng.seed = 7731
	_build_environment()
	_build_ground()
	_build_track_modules()
	_build_walls()
	_build_start_line()
	_build_props()
	_build_pickups()
	_merge_scenery()
	_build_cars()
	_build_minimap_layer()
	_build_camera()
	_hud = Hud.new()
	add_child(_hud)
	var extent := _track_extent()
	_hud.build_minimap(extent[0], extent[1])
	_reset_race()
	_hud.set_menu(true)
	_update_camera(1.0)


func _process(delta: float) -> void:
	_clock += delta
	if not _interactive:                       # menu screen: the cars wait on the grid while the camera circles the start line
		_hud.set_menu(true)
		_orbit_camera()
		_update_blips()
		return
	_hud.set_menu(false)
	_update_camera(delta)
	_update_blips()
	_update_hud()
	if _state == State.FINISHED and not _result_shown:
		_show_result()


func _physics_process(delta: float) -> void:
	if not _interactive or _state == State.FINISHED:
		return
	if _state == State.COUNTDOWN:
		_countdown_left -= delta
		if _countdown_left <= 0.0:
			_state = State.RUNNING
		return
	_race_time += delta
	for car in _cars:
		if car.wrecked:
			car.wreck_timer -= delta
			if car.wreck_timer <= 0.0:
				_respawn(car)
			car.step(delta)
			continue
		if car == _player:
			car.input_throttle = _in_throttle
			car.input_brake = _in_brake
			car.input_steer = _in_steer
			car.input_handbrake = _in_handbrake
		else:
			_drive_ai(car)
		car.step(delta)
		_update_progress(car)
		_check_stuck(car, delta)
	_update_pickups(delta)
	_check_end()


# ------------------------------------------------------------------ API used by tv_screen.gd / sofa_race.gd

func start_interactive_race() -> void:
	_reset_race()
	_interactive = true
	_result_shown = false
	_hud.hide_result()
	_set_overlays(true)
	_state = State.COUNTDOWN
	_countdown_left = COUNTDOWN_SECONDS
	_go_timer = 0.0
	_update_camera(1.0)


## throttle / brake 0..1, steer -1..1 (+ = right), handbrake held (Shift).
func set_race_input(throttle: float, brake: float, steer: float, handbrake: bool) -> void:
	_in_throttle = throttle
	_in_brake = brake
	_in_steer = steer
	_in_handbrake = handbrake


## Ends the race right now and shows the result (Esc, or the race script giving up).
func finish_interactive_race(_player_won: bool) -> void:
	if _state != State.FINISHED:
		_player_rank = _rank_of(_player)
		_player_beat_rival = false
		_state = State.FINISHED
	if not _result_shown:
		_show_result()


func stop_interactive_race() -> void:
	_interactive = false
	_set_overlays(false)
	_result_shown = false
	_hud.hide_result()
	_in_throttle = 0.0
	_in_brake = 0.0
	_in_steer = 0.0
	_in_handbrake = false
	_reset_race()


# ------------------------------------------------------------------ building the world

func _scene(file: String) -> PackedScene:
	if not _scene_cache.has(file):
		_scene_cache[file] = load(ASSET_DIR + file)
	return _scene_cache[file] as PackedScene


func _spawn(file: String, parent: Node, xform: Transform3D) -> Node3D:
	var scene := _scene(file)
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	instance.transform = xform
	parent.add_child(instance)
	return instance


func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color8(222, 158, 106)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color8(236, 208, 178)
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = Color8(226, 164, 112)
	environment.fog_density = 0.0016
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "WastelandSun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color8(255, 226, 186)
	sun.light_energy = 1.15
	sun.shadow_enabled = false                  # the cars get a blob shadow instead (shadow maps left hard dark patches on the road)
	add_child(sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Wasteland"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2600.0, 2600.0)
	ground.mesh = plane
	ground.position = Vector3(0.0, -0.4, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color8(190, 142, 88)
	material.roughness = 1.0
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# big rocks on the horizon
	var horizon := Node3D.new()
	horizon.name = "Horizon"
	add_child(horizon)
	var centre := _track_extent()[0] as Vector3
	for i in 46:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(330.0, 640.0)
		var spot := centre + Vector3(cos(angle) * radius, -0.4, sin(angle) * radius)
		var size := _rng.randf_range(5.0, 16.0)
		var xform := Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(size, size * 1.2, size)), spot)
		_spawn("wasteland_rock.glb", horizon, xform)


func _build_track_modules() -> void:
	var holder := Node3D.new()
	holder.name = "TrackModules"
	add_child(holder)
	for piece in _track.pieces:
		var basis := Basis.looking_at(piece.forward, Vector3.UP)
		var file := "wasteland_track_straight.glb"
		if piece.kind != "S":
			file = "wasteland_track_curve_right.glb" if piece.kind == "R" else "wasteland_track_curve.glb"      # the right curve is a real mirrored mesh
		_spawn(file, holder, Transform3D(basis, piece.origin))


## The track modules, junk and horizon rocks never move: merge them into a few big meshes (about 800 draw calls become ~80).
func _merge_scenery() -> void:
	for holder_name in ["TrackModules", "Junk", "Horizon"]:
		var holder := get_node_or_null(holder_name)
		if holder == null:
			continue
		var sources: Array[MeshInstance3D] = []
		for node in holder.find_children("*", "MeshInstance3D", true, false):
			sources.append(node as MeshInstance3D)
		StaticMerge.merge(self, sources, 90.0, false, null, true, "Scenery%s" % holder_name)


func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "GuardrailColliders"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for i in _track.count:
		var a := _track.points[i]
		var b := _track.points[(i + 1) % _track.count]
		var along := (b - a)
		var seg := along.length()
		if seg < 0.01:
			continue
		var t := along / seg
		var right := _track.right_of(t)
		var mid := (a + b) * 0.5
		for side_sign: float in [-1.0, 1.0]:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(Track.WALL_THICKNESS, 2.0, seg + 0.5)
			shape.shape = box
			shape.transform = Transform3D(Basis.looking_at(t, Vector3.UP), mid + right * side_sign * Track.WALL_CENTER + Vector3(0.0, 1.0, 0.0))
			body.add_child(shape)


func _build_start_line() -> void:
	var t := _track.tangent_at(0.0)
	var right := _track.right_of(t)
	var origin := _track.center_at(0.0)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color8(20, 20, 22)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color8(238, 232, 214)
	var tile := BoxMesh.new()
	tile.size = Vector3(1.5, 0.04, 1.5)
	for column in 12:
		for row in 2:
			var tile_node := MeshInstance3D.new()
			tile_node.mesh = tile
			tile_node.material_override = black if (column + row) % 2 == 0 else white
			tile_node.position = origin + right * (-8.25 + float(column) * 1.5) + t * (float(row) * 1.5) + Vector3(0.0, 0.03, 0.0)
			tile_node.rotation.y = atan2(-t.x, -t.z)
			tile_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tile_node)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color8(90, 94, 100)
	var yaw := atan2(-t.x, -t.z)
	for side_sign: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.7, 8.0, 0.7)
		post.mesh = post_mesh
		post.material_override = steel
		post.position = origin + right * side_sign * 10.6 + Vector3(0.0, 4.0, 0.0)
		add_child(post)
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(22.0, 1.6, 0.6)
	beam.mesh = beam_mesh
	var beam_material := StandardMaterial3D.new()
	beam_material.albedo_color = Color8(214, 160, 30)
	beam.material_override = beam_material
	beam.position = origin + Vector3(0.0, 8.0, 0.0)
	beam.rotation.y = yaw
	add_child(beam)
	var banner := Label3D.new()
	banner.text = "START / FINISH"
	banner.font_size = 72
	banner.pixel_size = 0.02
	banner.modulate = Color8(30, 24, 18)
	banner.shaded = false
	banner.position = origin + Vector3(0.0, 8.0, 0.0) - t * 0.35
	banner.rotation.y = yaw
	add_child(banner)


func _distance_to_track(p: Vector3) -> float:
	var best := 1.0e9
	for i in range(0, _track.count, 2):
		var q := _track.points[i]
		best = minf(best, Vector2(q.x - p.x, q.z - p.z).length())
	return best


## Rusted cars, shipping containers, barrels and rocks outside the guardrails.
func _build_props() -> void:
	var holder := Node3D.new()
	holder.name = "Junk"
	add_child(holder)
	var container_files: Array[String] = ["wasteland_container_red.glb", "wasteland_container_blue.glb", "wasteland_container_green.glb", "wasteland_container_orange.glb"]
	var placed := 0
	var tries := 0
	while placed < 90 and tries < 900:
		tries += 1
		var s := _rng.randf_range(0.0, _track.length)
		var t := _track.tangent_at(s)
		var side_sign := 1.0 if _rng.randf() < 0.5 else -1.0
		var lateral := _rng.randf_range(15.0, 55.0)
		var spot := _track.center_at(s) + _track.right_of(t) * side_sign * lateral
		if _distance_to_track(spot) < 14.0:
			continue
		var yaw := atan2(-t.x, -t.z) + (_rng.randf_range(-0.5, 0.5) if _rng.randf() < 0.6 else _rng.randf_range(0.0, TAU))
		var basis := Basis(Vector3.UP, yaw)
		var roll := _rng.randf()
		if roll < 0.32:
			_spawn("wasteland_rusted_car.glb", holder, Transform3D(basis, spot))
		elif roll < 0.62:
			var file := container_files[_rng.randi() % container_files.size()]
			_spawn(file, holder, Transform3D(basis, spot))
			if _rng.randf() < 0.35:
				_spawn(container_files[_rng.randi() % container_files.size()], holder, Transform3D(basis * Basis(Vector3.UP, 0.12), spot + Vector3(0.0, 2.5, 0.0)))
		elif roll < 0.82:
			for k in 3:
				_spawn("wasteland_barrel.glb", holder, Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)), spot + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))))
		else:
			var size := _rng.randf_range(1.2, 3.0)
			_spawn("wasteland_rock.glb", holder, Transform3D(basis * Basis.from_scale(Vector3(size, size, size)), spot))
		placed += 1


func _build_pickups() -> void:
	var kinds: Array[String] = ["repair"]
	var files := {"repair": "wasteland_pickup_repair.glb"}
	var s := 70.0
	var index := 0
	while s < _track.length - 40.0:
		var kind := kinds[index % kinds.size()]
		var t := _track.tangent_at(s)
		var spot := _track.center_at(s) + _track.right_of(t) * _rng.randf_range(-4.5, 4.5)
		var node := Node3D.new()
		node.position = spot + Vector3(0.0, 0.3, 0.0)
		add_child(node)
		_spawn(files[kind], node, Transform3D(Basis.from_scale(Vector3(1.6, 1.6, 1.6)), Vector3.ZERO))
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 1.6
		ring_mesh.bottom_radius = 1.6
		ring_mesh.height = 0.04
		ring_mesh.radial_segments = 12
		ring.mesh = ring_mesh
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.albedo_color = Color8(255, 226, 120)
		ring.material_override = ring_material
		ring.position = Vector3(0.0, -0.25, 0.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(ring)
		_pickups.append({"node": node, "kind": kind, "cooldown": 0.0})
		s += 150.0
		index += 1


func _build_cars() -> void:
	var grid: Array[Dictionary] = [
		{"name": "JON", "number": 4, "color": Color8(236, 196, 40), "skill": 0.93},
		{"name": "LEA", "number": 5, "color": Color8(132, 62, 184), "skill": 0.90},
		{"name": "YOU", "number": 1, "color": Color8(214, 33, 29), "skill": 1.0},
		{"name": "T.T", "number": 7, "color": Color8(40, 120, 220), "skill": 0.96},
		{"name": "MIA", "number": 12, "color": Color8(44, 160, 92), "skill": 0.86},
		{"name": "KAI", "number": 22, "color": Color8(244, 150, 31), "skill": 0.82},
	]
	for entry: Dictionary in grid:
		var car := Car.new()
		car.driver_name = entry["name"]
		car.number = entry["number"]
		car.paint_color = entry["color"]
		car.skill = entry["skill"]
		car.is_player = car.driver_name == "YOU"
		add_child(car)
		car.skid.connect(_add_skid)
		car.hit_wall.connect(_on_car_hit_wall.bind(car))
		_cars.append(car)
		if car.is_player:
			_player = car
		elif car.driver_name == "T.T":
			_rival = car
		if not car.is_player:
			car.set_meta("phase", _rng.randf_range(0.0, 6.0))
			car.set_meta("lane_amp", _rng.randf_range(1.0, 3.0))


func _build_minimap_layer() -> void:
	# the track ribbon, only seen by the minimap camera (visual layer 2)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in _track.count:
		var a := _track.points[i]
		var b := _track.points[(i + 1) % _track.count]
		var ra := _track.right_of(_track.tangents[i]) * 6.0
		var rb := _track.right_of(_track.tangents[(i + 1) % _track.count]) * 6.0
		var base := vertices.size()
		vertices.append(a + ra)
		vertices.append(a - ra)
		vertices.append(b + rb)
		vertices.append(b - rb)
		for _k in 4:
			normals.append(Vector3.UP)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ribbon := MeshInstance3D.new()
	ribbon.name = "MinimapTrack"
	ribbon.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color8(226, 196, 150)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = material
	ribbon.layers = MINIMAP_LAYER
	ribbon.position = Vector3(0.0, 1.0, 0.0)
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)
	for car in _cars:
		var blip := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		var radius := 11.0 if car.is_player else 7.5
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.5
		disc.radial_segments = 10
		blip.mesh = disc
		var blip_material := StandardMaterial3D.new()
		blip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blip_material.albedo_color = car.paint_color
		blip.material_override = blip_material
		blip.layers = MINIMAP_LAYER
		blip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blip)
		_blips[car] = blip


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "TopDownCamera"
	_camera.fov = 52.0
	_camera.near = 1.0
	_camera.far = 1400.0
	_camera.cull_mask = 1                     # layer 1 only: the minimap layer (2) is not drawn in the main view
	_camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	_camera.current = true
	add_child(_camera)


## Centre of the circuit and how much of the world the minimap has to show.
func _track_extent() -> Array:
	var low := Vector3(1.0e9, 0.0, 1.0e9)
	var high := Vector3(-1.0e9, 0.0, -1.0e9)
	for p in _track.points:
		low.x = minf(low.x, p.x)
		low.z = minf(low.z, p.z)
		high.x = maxf(high.x, p.x)
		high.z = maxf(high.z, p.z)
	var centre := (low + high) * 0.5
	var extent := maxf(high.x - low.x, high.z - low.z) + 60.0
	return [centre, extent]


# ------------------------------------------------------------------ race flow

func _reset_race() -> void:
	for pickup in _pickups:
		pickup["cooldown"] = 0.0
		(pickup["node"] as Node3D).visible = true
	_state = State.COUNTDOWN
	_countdown_left = COUNTDOWN_SECONDS
	_race_time = 0.0
	_player_rank = 0
	_player_beat_rival = false
	_timed_out = false
	var rows: Array = [
		["JON", -5.0, -3.8], ["LEA", -5.0, 3.8], ["YOU", -17.0, -3.8], ["T.T", -17.0, 3.8], ["MIA", -29.0, -3.8], ["KAI", -29.0, 3.8]]
	for row in rows:
		var car: Car = _car_named(row[0] as String)
		var s_grid: float = float(row[1])
		var lateral: float = float(row[2])
		var s_wrapped := _track.wrap_s(s_grid)
		var t := _track.tangent_at(s_wrapped)
		car.global_position = _track.center_at(s_wrapped) + _track.right_of(t) * lateral
		car.rotation = Vector3(0.0, atan2(-t.x, -t.z), 0.0)
		car.velocity = Vector3.ZERO
		car.steer = 0.0
		car.health = Car.MAX_HEALTH
		car.wrecked = false
		car.set_solid(true)
		car.invulnerable = 0.0
		car.finish_time = -1.0
		car.laps_done = -1
		car.last_s = s_wrapped
		car.total_s = s_grid
		car.hint_index = _track.index_at(s_wrapped)
		car.stuck_timer = 0.0
		car.input_throttle = 0.0
		car.input_brake = 0.0
		car.input_steer = 0.0
		car.input_handbrake = false


func _set_overlays(on: bool) -> void:
	for car in _cars:
		car.show_overlay = on
		car._update_overlay()


func _car_named(driver_name: String) -> Car:
	for car in _cars:
		if car.driver_name == driver_name:
			return car
	return _cars[0]


func _update_progress(car: Car) -> void:
	var loc := _track.locate(car.global_position, car.hint_index)
	car.hint_index = int(loc.x)
	var s_local := loc.y
	if s_local < car.last_s - _track.length * 0.5:
		car.laps_done += 1
	elif s_local > car.last_s + _track.length * 0.5:
		car.laps_done -= 1
	car.last_s = s_local
	car.total_s = float(car.laps_done) * _track.length + s_local
	if car.finish_time < 0.0 and car.total_s >= float(LAPS) * _track.length:
		car.finish_time = _race_time


## A car that cannot get moving (wedged on a guardrail) is put back on the road after a few seconds.
func _check_stuck(car: Car, delta: float) -> void:
	if absf(car.forward_speed) < 1.5 and (car.input_throttle > 0.5 or car.input_brake > 0.5):
		car.stuck_timer += delta
	else:
		car.stuck_timer = 0.0
	if car.stuck_timer > (4.0 if car.is_player else 2.5):
		_put_on_track(car, car.last_s)
		car.stuck_timer = 0.0


func _put_on_track(car: Car, s: float) -> void:
	var t := _track.tangent_at(s)
	car.global_position = _track.center_at(s)
	car.rotation = Vector3(0.0, atan2(-t.x, -t.z), 0.0)
	car.velocity = Vector3.ZERO
	car.steer = 0.0
	car.hint_index = _track.index_at(s)


func _respawn(car: Car) -> void:
	_put_on_track(car, car.last_s)
	car.wrecked = false
	car.set_solid(true)
	car.health = 60.0
	car.invulnerable = 2.0


func _progress_of(car: Car) -> float:
	if car.finish_time >= 0.0:
		return 1.0e7 - car.finish_time
	return car.total_s


func _rank_of(car: Car) -> int:
	var mine := _progress_of(car)
	var rank := 1
	for other in _cars:
		if other != car and _progress_of(other) > mine:
			rank += 1
	return rank


func _ordered_names() -> Array[String]:
	var sorted_cars := _cars.duplicate()
	sorted_cars.sort_custom(func(a: Car, b: Car) -> bool: return _progress_of(a) > _progress_of(b))
	var names: Array[String] = []
	for car: Car in sorted_cars:
		names.append(car.driver_name)
	return names


func _check_end() -> void:
	if _player.finish_time >= 0.0:
		_player_rank = _rank_of(_player)
		_player_beat_rival = _rival.finish_time < 0.0 or _rival.finish_time > _player.finish_time
		_state = State.FINISHED
	elif _race_time >= MAX_RACE_SECONDS:
		_timed_out = true
		_player_rank = _rank_of(_player)
		_player_beat_rival = _player.total_s > _rival.total_s
		_state = State.FINISHED


func _show_result() -> void:
	_result_shown = true
	var title := "You beat T.T." if _player_beat_rival else "T.T. wins"
	if _timed_out:
		title = "Time is up"
	var detail := "place %d of %d" % [maxi(_player_rank, 1), _cars.size()]
	if _player.finish_time >= 0.0:
		detail += "     " + _format_time(_player.finish_time)
	_hud.show_result(title, detail, "press E to get back on the sofa")
	race_finished.emit(_player_beat_rival)


func _format_time(t: float) -> String:
	if t < 0.0:
		return "-:--.-"
	return "%d:%02d.%d" % [floori(t / 60.0), int(t) % 60, int(fposmod(t, 1.0) * 10.0)]


# ------------------------------------------------------------------ AI

func _drive_ai(car: Car) -> void:
	var loc := _track.locate(car.global_position, car.hint_index)
	var s := loc.y
	var speed := maxf(car.forward_speed, 0.0)
	var phase: float = float(car.get_meta("phase"))
	var lane_amp: float = float(car.get_meta("lane_amp"))
	var lane := sin(_race_time * 0.35 + phase) * lane_amp * (0.4 if _track.curvature_at(s) > 0.02 else 1.0)
	var look := 6.0 + speed * 0.42
	var t_s := s + look
	var target := _track.center_at(t_s) + _track.right_of(_track.tangent_at(t_s)) * lane
	var local := car.global_transform.affine_inverse() * target
	var angle := atan2(local.x, -local.z)
	car.input_steer = clampf(angle * 2.0, -1.0, 1.0)
	var rubber := 1.0
	var lead := _player.total_s - car.total_s          # > 0 = the player is ahead of this car
	if car == _rival:                                   # T.T. hunts you down when you pull away
		rubber = clampf(1.0 + 0.0006 * lead, 0.97, 1.06)
	else:
		rubber = clampf(1.0 + 0.0003 * lead, 0.92, 1.05)
	var limit := minf(_track.speed_limit(AI_CORNER_G * car.skill * car.skill, AI_BRAKE, Car.TOP_SPEED, s + speed * 0.25), Car.TOP_SPEED * car.skill) * rubber
	car.input_throttle = 1.0 if speed < limit else 0.0
	car.input_brake = 1.0 if speed > limit + 2.0 else 0.0
	car.input_handbrake = false
func _damage_car(car: Car, amount: float) -> void:
	if car == _player:
		debug_damage["crashes"] = float(debug_damage.get("crashes", 0.0)) + amount
	if car.apply_damage(amount):
		car.wreck_timer = 2.5
		_puff(car.global_position + Vector3(0.0, 1.0, 0.0), 5.0, 0.7)
		if car == _player:
			_cam_shake = 1.0
	elif car == _player:
		_cam_shake = maxf(_cam_shake, 0.25)


func _on_car_hit_wall(strength: float, car: Car) -> void:
	var amount := maxf(0.0, strength - 5.0) * 0.9
	if amount > 0.0 and not car.wrecked:
		_damage_car(car, amount)
	if car == _player:
		_cam_shake = maxf(_cam_shake, minf(0.7, strength / 25.0))


## A quick expanding fireball / dust cloud that fades away.
func _puff(spot: Vector3, size: float, duration: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.62, 0.2, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.scale = Vector3.ONE * 0.4
	add_child(node)
	node.global_position = spot
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", Vector3.ONE * size, duration)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(node.queue_free)


# ------------------------------------------------------------------ pickups, skids

func _update_pickups(delta: float) -> void:
	for pickup in _pickups:
		var node: Node3D = pickup["node"]
		node.rotation.y += delta * 1.6
		if float(pickup["cooldown"]) > 0.0:
			pickup["cooldown"] = float(pickup["cooldown"]) - delta
			if float(pickup["cooldown"]) <= 0.0:
				node.visible = true
			continue
		for car in _cars:
			if car.wrecked:
				continue
			var offset := car.global_position - node.global_position
			offset.y = 0.0
			if offset.length() < 3.2:
				car.repair(40.0)
				pickup["cooldown"] = 12.0
				node.visible = false
				break


func _add_skid(left_pos: Vector3, right_pos: Vector3, yaw: float) -> void:
	if _skid_material == null:
		_skid_material = StandardMaterial3D.new()
		_skid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_skid_material.albedo_color = Color(0.10, 0.07, 0.05, 0.55)
		_skid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for wheel_pos: Vector3 in [left_pos, right_pos]:
		var mark: MeshInstance3D
		if _skids.size() < SKID_POOL:
			mark = MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.38, 0.01, 1.3)
			mark.mesh = mesh
			mark.material_override = _skid_material
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mark)
			_skids.append(mark)
		else:
			mark = _skids[_skid_next]                    # the oldest mark makes room for the newest
			_skid_next = (_skid_next + 1) % SKID_POOL
		mark.global_position = Vector3(wheel_pos.x, 0.035, wheel_pos.z)
		mark.rotation = Vector3(0.0, yaw, 0.0)


# ------------------------------------------------------------------ camera and HUD

func _orbit_camera() -> void:
	var angle := _clock * 0.15
	var centre := _track.center_at(-12.0)
	_camera.rotation_degrees = Vector3(-48.0, 0.0, 0.0)
	_camera.global_position = centre + Vector3(0.0, 44.0, 38.0)
	_camera.look_at(centre + Vector3(sin(angle) * 6.0, 0.0, cos(angle) * 4.0), Vector3.UP)


func _update_camera(delta: float) -> void:
	if _camera == null or _player == null:
		return
	var speed := _player.velocity.length()
	var height := 36.0 + speed * 0.32
	_camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	var focus := _player.global_position + _player.velocity * 0.25            # looks a little ahead of the car
	if delta >= 0.5:
		_cam_target = focus
	else:
		_cam_target = _cam_target.lerp(focus, 1.0 - exp(-delta * 5.0))
	var desired := _cam_target + Vector3(0.0, height, height / tan(deg_to_rad(60.0)))
	_cam_shake = maxf(0.0, _cam_shake - delta * 2.4)
	var shake := Vector3(sin(_clock * 63.0), 0.0, sin(_clock * 47.0 + 1.0)) * 0.9 * _cam_shake
	_camera.global_position = desired + shake


func _update_blips() -> void:
	for car in _cars:
		var blip := _blips.get(car) as Node3D
		if blip != null:
			blip.global_position = Vector3(car.global_position.x, 6.0, car.global_position.z)
			blip.visible = not car.wrecked


func _update_hud() -> void:
	var lap := clampi(_player.laps_done + 1, 1, LAPS)
	_hud.set_race_values(lap, LAPS, _ordered_names(), "YOU", _player.health, Car.MAX_HEALTH)
	var countdown_text := ""
	var countdown_color := Color8(240, 232, 214)
	if _state == State.COUNTDOWN:
		_go_timer = 0.0
		if _countdown_left > 0.5:
			countdown_text = str(int(ceil(_countdown_left - 0.5)))
		else:
			countdown_text = "GO"
			countdown_color = Color8(150, 235, 150)
	else:
		_go_timer += get_process_delta_time()
		if _go_timer < 0.9:
			countdown_text = "GO"
			countdown_color = Color8(150, 235, 150)
	if _player.wrecked:
		countdown_text = "WRECKED"
		countdown_color = Color8(255, 120, 90)
	_hud.set_countdown(countdown_text, countdown_color)
	if _race_time < 12.0:
		_hud.set_hint("W gas   S brake / reverse   A D steer   Shift handbrake")
	else:
		_hud.set_hint("")
