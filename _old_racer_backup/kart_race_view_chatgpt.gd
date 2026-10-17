extends Node3D
## Low-poly street-circuit scene rendered by the TV and its full-screen racing interface.

const TRACK_LENGTH := 1150.0
const TRACK_SEGMENTS := 224
const PATH_SAMPLES := 512
const ROAD_HALF_WIDTH := 13.0
const RADIUS_X := 162.0
const RADIUS_Z := 201.0
const CIRCUIT_CORNER_EXPONENT := 0.78
const PLAYER_LATERAL_SCALE := 10.5
const CURB_OFFSETS: Array[float] = [-(ROAD_HALF_WIDTH - 0.2), ROAD_HALF_WIDTH - 0.2]
const BARRIER_OFFSETS: Array[float] = [-(ROAD_HALF_WIDTH + 2.6), ROAD_HALF_WIDTH + 2.6]
const DOUBLE_LINE_OFFSETS: Array[float] = [-0.28, 0.28]
const OPPONENT_NAMES: Array[String] = ["T.T", "MIA", "JON", "KAI", "LEA"]
const OPPONENT_NUMBERS: Array[int] = [7, 12, 4, 22, 5]

const SKY_COLOR := Color8(6, 163, 246)
const ASPHALT := Color8(83, 83, 86)
const GRASS := Color8(92, 176, 61)
const CURB_RED := Color8(220, 38, 43)
const CURB_WHITE := Color8(239, 235, 216)
const CLOTHING: Array[Color] = [Color8(246, 47, 53), Color8(48, 174, 220), Color8(248, 196, 40), Color8(61, 183, 89), Color8(247, 239, 224)]

var _clock: float = 0.0
var _demo_distance: float = 0.0
var _race_active: bool = false
var _race_finished: bool = false
var _player_won: bool = false
var _distance_m: float = 0.0
var _speed_kmh: float = 0.0
var _lap: int = 1
var _seconds_left: float = 70.0
var _steer_offset: float = 0.0
var _opponents: Array[Dictionary] = []
var _path_points := PackedVector3Array()
var _path_cumulative := PackedFloat32Array()
var _path_actual_length: float = 0.0

var _camera: Camera3D
var _player_car: Node3D
var _opponent_cars: Array[Node3D] = []
var _hud_layer: CanvasLayer
var _lap_value: Label
var _time_value: Label
var _speed_value: Label
var _result_panel: ColorRect
var _result_title: Label
var _result_subtitle: Label
var _material_cache: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _hud_labels: Array[Label] = []
var _last_ui_scale: float = -1.0


func _ready() -> void:
	_build_track_path()
	_build_lighting()
	_build_ground()
	_build_track()
	_build_circuit_city()
	_build_traffic()
	_build_camera()
	_build_hud()
	_update_traffic(_demo_distance, _demo_opponents())
	_update_camera(1.0)


func _process(delta: float) -> void:
	_clock += delta
	_refresh_hud_scale()
	if not _race_active:
		_demo_distance += delta * 48.0
		_update_traffic(_demo_distance, _demo_opponents())
	_update_camera(delta)
	if not _race_active:
		_update_hud()


func start_interactive_race() -> void:
	_race_active = true
	_race_finished = false
	_player_won = false
	_distance_m = 0.0
	_speed_kmh = 0.0
	_lap = 1
	_seconds_left = 70.0
	_steer_offset = 0.0
	_opponents.clear()
	_demo_distance = 0.0
	_result_panel.visible = false
	_update_hud()
	_update_traffic(_distance_m, _opponents)
	_update_camera(1.0)


func update_interactive_race(distance_m: float, speed_kmh: float, lap: int, seconds_left: float, opponents: Array[Dictionary], steer_offset: float) -> void:
	_distance_m = distance_m
	_speed_kmh = speed_kmh
	_lap = lap
	_seconds_left = seconds_left
	_steer_offset = steer_offset
	_opponents.clear()
	for opponent: Dictionary in opponents:
		_opponents.append(opponent)
	_update_traffic(_distance_m, _opponents)
	_update_hud()


func finish_interactive_race(player_won: bool) -> void:
	_race_finished = true
	_player_won = player_won
	_result_title.text = "CHECKERED FLAG"
	_result_subtitle.text = "YOU BEAT T.T.!" if player_won else "T.T. GOT THERE FIRST"
	_result_panel.visible = true


func stop_interactive_race() -> void:
	_race_active = false
	_race_finished = false
	_result_panel.visible = false
	_demo_distance = _distance_m


func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY_COLOR
	environment.ambient_light_color = Color8(198, 210, 224)
	environment.ambient_light_energy = 0.68
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "GrandPrixSun"
	sun.rotation_degrees = Vector3(-48.0, -28.0, -12.0)
	sun.light_color = Color8(255, 245, 218)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 240.0
	add_child(sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "IslandGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	ground.mesh = plane
	ground.position.y = -0.42
	ground.material_override = _material(GRASS, 1.0)
	add_child(ground)



func _build_track() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var segment_length := TRACK_LENGTH / TRACK_SEGMENTS
	for i in TRACK_SEGMENTS:
		var a := _track_pose(i * segment_length)
		var b := _track_pose((i + 1) * segment_length)
		var center_a: Vector3 = a["center"] + Vector3.UP * 0.015
		var center_b: Vector3 = b["center"] + Vector3.UP * 0.015
		var side_a: Vector3 = a["side"]
		var side_b: Vector3 = b["side"]
		var base := vertices.size()
		vertices.append(center_a + side_a * ROAD_HALF_WIDTH)
		vertices.append(center_a - side_a * ROAD_HALF_WIDTH)
		vertices.append(center_b + side_b * ROAD_HALF_WIDTH)
		vertices.append(center_b - side_b * ROAD_HALF_WIDTH)
		for _corner in 4:
			normals.append(Vector3.UP)
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var road_mesh := ArrayMesh.new()
	road_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var road := MeshInstance3D.new()
	road.name = "CircuitAsphalt"
	road.mesh = road_mesh
	road.material_override = _material(ASPHALT, 0.94)
	add_child(road)

	var segment_width := segment_length + 0.15
	_add_box_multimesh("Kerbs", Vector3(segment_width, 0.17, 1.45), CURB_OFFSETS, 0.08, true, CURB_RED)
	_add_box_multimesh("SafetyBarriers", Vector3(segment_width, 1.15, 0.72), BARRIER_OFFSETS, 0.62, true, CURB_WHITE)
	_add_box_multimesh("DoubleYellowLines", Vector3(segment_length + 0.18, 0.045, 0.16), DOUBLE_LINE_OFFSETS, 0.055, false, Color8(255, 216, 28))
	_build_broken_lane_lines(segment_length)
	_build_start_finish_line()


func _build_broken_lane_lines(segment_length: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(segment_length * 3.8, 0.045, 0.14)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.custom_aabb = AABB(Vector3(-300.0, -2.0, -300.0), Vector3(600.0, 40.0, 600.0))
	var indices: Array[Vector2i] = []
	for i in range(0, TRACK_SEGMENTS, 8):
		indices.append(Vector2i(i, -1))
		indices.append(Vector2i(i, 1))
	multimesh.instance_count = indices.size()
	for idx in indices.size():
		var item := indices[idx]
		var start_pose := _track_pose(item.x * segment_length)
		var end_pose := _track_pose((item.x + 4.0) * segment_length)
		var pose := _track_pose((item.x + 2.0) * segment_length)
		var basis := _track_basis(pose)
		var dash_length := _track_center(start_pose).distance_to(_track_center(end_pose))
		basis.x = _track_tangent(pose) * (dash_length / mesh.size.x)
		var position: Vector3 = _track_center(pose) + _track_side(pose) * item.y * 4.2 + Vector3.UP * 0.055
		multimesh.set_instance_transform(idx, Transform3D(basis, position))
	var marks := MultiMeshInstance3D.new()
	marks.name = "BrokenWhiteLaneLines"
	marks.multimesh = multimesh
	marks.material_override = _material(Color8(232, 229, 218), 1.0)
	add_child(marks)


func _build_start_finish_line() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 0.055, ROAD_HALF_WIDTH * 2.0 / 16.0 + 0.1)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.custom_aabb = AABB(Vector3(-300.0, -2.0, -300.0), Vector3(600.0, 40.0, 600.0))
	multimesh.instance_count = 16
	var pose := _track_pose(0.0)
	var basis := _track_basis(pose)
	for i in 16:
		var offset := -ROAD_HALF_WIDTH + (float(i) + 0.5) * ROAD_HALF_WIDTH * 2.0 / 16.0
		multimesh.set_instance_transform(i, Transform3D(basis, _track_center(pose) + _track_side(pose) * offset + Vector3.UP * 0.065))
		multimesh.set_instance_color(i, Color.BLACK if i % 2 == 0 else CURB_WHITE)
	var material := _material(Color.WHITE, 1.0, true)
	var stripe := MultiMeshInstance3D.new()
	stripe.name = "StartFinishChecker"
	stripe.multimesh = multimesh
	stripe.material_override = material
	add_child(stripe)


func _add_box_multimesh(label: String, box_size: Vector3, offsets: Array[float], y: float, alternate: bool, base_color: Color) -> void:
	var box := BoxMesh.new()
	box.size = box_size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = alternate
	multimesh.mesh = box
	multimesh.custom_aabb = AABB(Vector3(-300.0, -2.0, -300.0), Vector3(600.0, 40.0, 600.0))
	multimesh.instance_count = TRACK_SEGMENTS * offsets.size()
	var index := 0
	var segment_length := TRACK_LENGTH / TRACK_SEGMENTS
	for i in TRACK_SEGMENTS:
		var pose := _track_pose((float(i) + 0.5) * segment_length)
		var basis := _track_basis(pose)
		var start_pose := _track_pose(float(i) * segment_length)
		var end_pose := _track_pose(float(i + 1) * segment_length)
		var physical_length := _track_center(start_pose).distance_to(_track_center(end_pose)) + 0.15
		basis.x = _track_tangent(pose) * (physical_length / box_size.x)
		for offset: float in offsets:
			var position: Vector3 = _track_center(pose) + _track_side(pose) * offset + Vector3.UP * y
			multimesh.set_instance_transform(index, Transform3D(basis, position))
			if alternate:
				multimesh.set_instance_color(index, CURB_RED if i % 2 == 0 else CURB_WHITE)
			index += 1
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multimesh
	var mat := _material(base_color, 0.9, alternate)
	instance.material_override = mat
	add_child(instance)


func _build_circuit_city() -> void:
	for distance in range(0, int(TRACK_LENGTH), 150):
		_add_palm(float(distance), -1.0)
		_add_palm(float(distance) + 36.0, 1.0)
	for distance: float in [72.0, 224.0, 384.0, 548.0, 714.0, 882.0, 1030.0]:
		_add_street_light(distance, 1.0 if int(distance / 160.0) % 2 == 0 else -1.0)
	var buildings: Array[Dictionary] = [
		{"distance": 165.0, "side": 1.0, "height": 28.0, "color": Color8(230, 231, 221)},
		{"distance": 320.0, "side": -1.0, "height": 20.0, "color": Color8(247, 211, 153)},
		{"distance": 505.0, "side": 1.0, "height": 34.0, "color": Color8(236, 239, 233)},
		{"distance": 686.0, "side": -1.0, "height": 23.0, "color": Color8(246, 219, 140)},
		{"distance": 854.0, "side": 1.0, "height": 31.0, "color": Color8(226, 232, 234)},
		{"distance": 1015.0, "side": -1.0, "height": 19.0, "color": Color8(239, 220, 190)}
	]
	for entry: Dictionary in buildings:
		var building_color: Color = entry["color"]
		_add_building(float(entry["distance"]), float(entry["side"]), float(entry["height"]), building_color)
	_add_grandstand(55.0, 1.0)
	_add_grandstand(572.0, -1.0)
	_build_clouds()


func _add_palm(distance: float, side_sign: float) -> void:
	var pose := _track_pose(distance)
	var position: Vector3 = _track_center(pose) + _track_side(pose) * side_sign * 20.5
	var tree := Node3D.new()
	tree.name = "PalmTree"
	tree.transform = Transform3D(_track_basis(pose), position)
	add_child(tree)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.44
	trunk_mesh.height = 8.0
	trunk_mesh.radial_segments = 6
	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, 4.0, 0.0)
	trunk.rotation.z = 0.08 * side_sign
	trunk.material_override = _material(Color8(145, 105, 67), 1.0)
	tree.add_child(trunk)
	for frond in 5:
		var leaf := BoxMesh.new()
		leaf.size = Vector3(5.2, 0.18, 0.85)
		var leaf_instance := MeshInstance3D.new()
		leaf_instance.mesh = leaf
		leaf_instance.position = Vector3(1.6, 7.55, 0.0)
		leaf_instance.rotation = Vector3(0.0, frond * TAU / 5.0, -0.18)
		leaf_instance.material_override = _material(Color8(56 + frond * 4, 143 + frond * 5, 47), 1.0)
		tree.add_child(leaf_instance)


func _add_street_light(distance: float, side_sign: float) -> void:
	var pose := _track_pose(distance)
	var position: Vector3 = _track_center(pose) + _track_side(pose) * side_sign * 19.5
	var root := Node3D.new()
	root.name = "StreetLight"
	root.transform = Transform3D(_track_basis(pose), position)
	add_child(root)
	_add_box(root, Vector3(0.22, 8.5, 0.22), Vector3(0, 4.25, 0), _material(Color8(211, 218, 216)))
	_add_box(root, Vector3(2.6, 0.18, 0.18), Vector3(0, 8.3, -side_sign * 1.1), _material(Color8(211, 218, 216)))
	_add_box(root, Vector3(1.0, 0.22, 0.5), Vector3(0, 8.18, -side_sign * 2.15), _material(Color8(255, 238, 144)))


func _add_building(distance: float, side_sign: float, height: float, color: Color) -> void:
	var pose := _track_pose(distance)
	var position: Vector3 = _track_center(pose) + _track_side(pose) * side_sign * 39.0
	var building := Node3D.new()
	building.name = "StreetBuilding"
	building.transform = Transform3D(_track_basis(pose), position)
	add_child(building)
	var width := 18.0 + fposmod(distance * 0.37, 10.0)
	var depth := 15.0 + fposmod(distance * 0.19, 7.0)
	_add_box(building, Vector3(width, height, depth), Vector3(0, height * 0.5, 0), _material(color, 0.92))
	var window_color := _material(Color8(104, 186, 220), 0.5)
	var road_face := -side_sign * (depth * 0.5 + 0.035)
	var floors := maxi(2, int(height / 4.5))
	for floor_index in floors:
		for column in 3:
			var wx := (float(column) - 1.0) * width * 0.27
			_add_box(building, Vector3(width * 0.16, 1.35, 0.08), Vector3(wx, 2.0 + floor_index * 3.8, road_face), window_color)
	# Flat roof cap gives the simple blocks a low-poly city silhouette.
	_add_box(building, Vector3(width + 0.8, 0.55, depth + 0.8), Vector3(0, height + 0.25, 0), _material(Color8(220, 224, 224)))


func _add_grandstand(distance: float, side_sign: float) -> void:
	var pose := _track_pose(distance)
	var position: Vector3 = _track_center(pose) + _track_side(pose) * side_sign * 19.0
	var stand := Node3D.new()
	stand.name = "Grandstand"
	stand.transform = Transform3D(_track_basis(pose), position)
	add_child(stand)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.38
	head_mesh.radial_segments = 6
	head_mesh.rings = 3
	var skin_material := _material(Color8(226, 177, 136), 1.0)
	var clothing_materials: Array[StandardMaterial3D] = []
	for clothing_color: Color in CLOTHING:
		clothing_materials.append(_material(clothing_color, 1.0))
	for row in 3:
		var z := side_sign * (2.0 + row * 2.0)
		_add_box(stand, Vector3(43.0 - row * 3.0, 1.0, 1.8), Vector3(0.0, 0.8 + row * 0.85, z), _material(Color8(114, 124, 134)))
		for person in 14:
			var px := (float(person) - 6.5) * 3.0
			var shirt := clothing_materials[(person + row * 3) % clothing_materials.size()]
			_add_box(stand, Vector3(0.52, 0.72, 0.42), Vector3(px, 1.62 + row * 0.85, z + side_sign * 0.45), shirt)
			var head := MeshInstance3D.new()
			head.mesh = head_mesh
			head.position = Vector3(px, 2.12 + row * 0.85, z + side_sign * 0.45)
			head.material_override = skin_material
			stand.add_child(head)
	# A red-white concrete wall protects the crowd along the straight.
	_add_box(stand, Vector3(54.0, 1.1, 0.85), Vector3(0.0, 0.55, side_sign * 11.0), _material(Color8(225, 235, 232)))


func _build_clouds() -> void:
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.0
	cloud_mesh.height = 1.5
	cloud_mesh.radial_segments = 7
	cloud_mesh.rings = 4
	var cloud_mat := _material(Color8(249, 250, 246), 1.0)
	for cloud_index in 8:
		var pose := _track_pose(cloud_index * TRACK_LENGTH / 8.0 + 35.0)
		var root := Node3D.new()
		root.position = _track_center(pose) + _track_side(pose) * (55.0 + (cloud_index % 2) * 24.0) + Vector3.UP * (38.0 + (cloud_index % 3) * 7.0)
		add_child(root)
		for puff in 4:
			var cloud := MeshInstance3D.new()
			cloud.mesh = cloud_mesh
			cloud.scale = Vector3(7.0 + puff * 1.5, 3.0 + (puff % 2), 4.0)
			cloud.position = Vector3((puff - 1.5) * 5.0, sin(puff * 2.0) * 1.0, 0.0)
			cloud.material_override = cloud_mat
			root.add_child(cloud)


func _build_traffic() -> void:
	_player_car = _make_car("PlayerCar", Color8(214, 33, 29), Color8(31, 34, 40), 1)
	add_child(_player_car)
	var colors: Array[Color] = [Color8(34, 113, 211), Color8(243, 203, 34), Color8(40, 154, 81), Color8(244, 185, 31), Color8(126, 53, 179)]
	for i in OPPONENT_NAMES.size():
		var car := _make_car(OPPONENT_NAMES[i], colors[i], Color8(25, 30, 37), OPPONENT_NUMBERS[i])
		add_child(car)
		_opponent_cars.append(car)
	_update_traffic(_demo_distance, _demo_opponents())


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
	number_label.rotation.y = PI
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
	return car


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "RaceChaseCamera"
	_camera.fov = 62.0
	_camera.current = true
	add_child(_camera)


func _update_traffic(player_distance: float, opponents: Array[Dictionary]) -> void:
	var player_pose := _track_pose(player_distance)
	var player_lateral := _steer_offset * PLAYER_LATERAL_SCALE
	var player_position: Vector3 = _track_center(player_pose) + _track_side(player_pose) * player_lateral
	_set_car_pose(_player_car, player_position, _track_tangent(player_pose))
	for i in _opponent_cars.size():
		if i >= opponents.size():
			continue
		var info: Dictionary = opponents[i]
		var pose := _track_pose(float(info["distance"]))
		var lane_offset := float(info["lane"]) * 8.0
		var position: Vector3 = _track_center(pose) + _track_side(pose) * lane_offset
		_set_car_pose(_opponent_cars[i], position, _track_tangent(pose))


func _set_car_pose(car: Node3D, position: Vector3, tangent: Vector3) -> void:
	if car == null:
		return
	car.global_position = position + Vector3.UP * 0.02
	car.look_at(car.global_position + tangent, Vector3.UP)


func _update_camera(delta: float) -> void:
	if _camera == null or _player_car == null:
		return
	var pose := _track_pose(_distance_m if _race_active else _demo_distance)
	var player_position: Vector3 = _track_center(pose) + _track_side(pose) * _steer_offset * PLAYER_LATERAL_SCALE
	var tangent: Vector3 = _track_tangent(pose)
	var desired := player_position - tangent * 13.0 + Vector3.UP * 6.2
	if delta >= 0.5:
		_camera.global_position = desired
	else:
		_camera.global_position = _camera.global_position.lerp(desired, 1.0 - exp(-delta * 5.5))
	_camera.look_at(player_position + tangent * 12.0 + Vector3.UP * 1.35, Vector3.UP)


func _demo_opponents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in OPPONENT_NAMES.size():
		result.append({"distance": _demo_distance + 48.0 + i * 36.0, "lane": sin(i * 2.1) * 0.42})
	return result


func _track_pose(distance: float) -> Dictionary:
	var path_distance := fposmod(distance, TRACK_LENGTH) / TRACK_LENGTH * _path_actual_length
	var low := 1
	var high := PATH_SAMPLES
	while low < high:
		var middle := int((low + high) / 2)
		if _path_cumulative[middle] < path_distance:
			low = middle + 1
		else:
			high = middle
	var index := clampi(low, 1, PATH_SAMPLES)
	var segment_start := _path_cumulative[index - 1]
	var segment_length := _path_cumulative[index] - segment_start
	var segment_weight := (path_distance - segment_start) / maxf(segment_length, 0.0001)
	var path_scale := TRACK_LENGTH / _path_actual_length
	var center: Vector3 = _path_points[index - 1].lerp(_path_points[index], segment_weight) * path_scale
	var tangent: Vector3 = (_path_points[index] - _path_points[index - 1]).normalized()
	var side := Vector3(-tangent.z, 0.0, tangent.x)
	return {"center": center, "tangent": tangent, "side": side}


func _build_track_path() -> void:
	_path_points.resize(PATH_SAMPLES + 1)
	_path_cumulative.resize(PATH_SAMPLES + 1)
	_path_actual_length = 0.0
	for i in PATH_SAMPLES + 1:
		var angle := TAU * float(i) / PATH_SAMPLES
		var point := _track_point(angle)
		_path_points[i] = point
		if i > 0:
			_path_actual_length += point.distance_to(_path_points[i - 1])
		_path_cumulative[i] = _path_actual_length


func _track_point(angle: float) -> Vector3:
	var sin_angle := sin(angle)
	var cos_angle := cos(angle)
	var x := signf(sin_angle) * pow(absf(sin_angle), CIRCUIT_CORNER_EXPONENT) * RADIUS_X
	var z := -signf(cos_angle) * pow(absf(cos_angle), CIRCUIT_CORNER_EXPONENT) * RADIUS_Z
	return Vector3(x, 0.0, z)


func _track_center(pose: Dictionary) -> Vector3:
	var value: Vector3 = pose["center"]
	return value


func _track_side(pose: Dictionary) -> Vector3:
	var value: Vector3 = pose["side"]
	return value


func _track_tangent(pose: Dictionary) -> Vector3:
	var value: Vector3 = pose["tangent"]
	return value


func _track_basis(pose: Dictionary) -> Basis:
	return Basis(_track_tangent(pose), Vector3.UP, _track_side(pose))


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



func _material(color: Color, roughness: float = 0.9, vertex_color: bool = false) -> StandardMaterial3D:
	var cache_key := "%s:%d:%s" % [color.to_html(true), int(roughness * 100.0), str(vertex_color)]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.vertex_color_use_as_albedo = vertex_color
	_material_cache[cache_key] = material
	return material


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(root)
	var height := float(get_viewport().size.y)
	var ui_scale := clampf(height / 360.0, 0.85, 1.8)
	_last_ui_scale = ui_scale
	var header := ColorRect.new()
	header.color = Color(0.015, 0.05, 0.10, 0.28)
	header.anchor_right = 1.0
	header.anchor_bottom = 0.145
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var metrics := HBoxContainer.new()
	metrics.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	metrics.offset_left = 20.0 * ui_scale
	metrics.offset_right = -20.0 * ui_scale
	metrics.add_theme_constant_override("separation", int(24.0 * ui_scale))
	header.add_child(metrics)
	_lap_value = _make_metric(metrics, "LAP", "1 / 3", Color8(109, 220, 255), ui_scale)
	_time_value = _make_metric(metrics, "TIME", "70", Color8(255, 225, 27), ui_scale)
	_speed_value = _make_metric(metrics, "SPEED", "0 km/h", Color8(109, 220, 255), ui_scale)
	var controls := Label.new()
	controls.text = "T.T. IS BLUE #07   W/↑ GAS   A/D STEER   S/↓ BRAKE   ESC QUIT"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.anchor_left = 0.08
	controls.anchor_right = 0.92
	controls.anchor_top = 0.92
	controls.anchor_bottom = 0.985
	controls.add_theme_font_size_override("font_size", int(13.0 * ui_scale))
	controls.add_theme_color_override("font_color", Color8(248, 245, 227))
	controls.set_meta("base_font_size", 13)
	_hud_labels.append(controls)
	root.add_child(controls)
	_result_panel = ColorRect.new()
	_result_panel.color = Color(0.015, 0.05, 0.1, 0.91)
	_result_panel.anchor_left = 0.28
	_result_panel.anchor_right = 0.72
	_result_panel.anchor_top = 0.39
	_result_panel.anchor_bottom = 0.62
	_result_panel.visible = false
	root.add_child(_result_panel)
	var result_layout := VBoxContainer.new()
	result_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(result_layout)
	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_title.add_theme_font_size_override("font_size", int(28.0 * ui_scale))
	_result_title.add_theme_color_override("font_color", Color8(255, 226, 44))
	_result_title.set_meta("base_font_size", 28)
	_hud_labels.append(_result_title)
	result_layout.add_child(_result_title)
	_result_subtitle = Label.new()
	_result_subtitle.text = "PRESS E TO RETURN"
	_result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_subtitle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_subtitle.add_theme_font_size_override("font_size", int(18.0 * ui_scale))
	_result_subtitle.add_theme_color_override("font_color", Color8(232, 241, 246))
	_result_subtitle.set_meta("base_font_size", 18)
	_hud_labels.append(_result_subtitle)
	result_layout.add_child(_result_subtitle)


func _make_metric(parent: HBoxContainer, caption: String, initial_value: String, color: Color, ui_scale: float) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(column)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(14.0 * ui_scale))
	label.add_theme_color_override("font_color", color.darkened(0.1))
	label.set_meta("base_font_size", 14)
	_hud_labels.append(label)
	column.add_child(label)
	var value := Label.new()
	value.text = initial_value
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", int(25.0 * ui_scale))
	value.add_theme_color_override("font_color", color)
	value.set_meta("base_font_size", 25)
	_hud_labels.append(value)
	column.add_child(value)
	return value


func _refresh_hud_scale() -> void:
	var scale := clampf(float(get_viewport().size.y) / 360.0, 0.85, 1.8)
	if is_equal_approx(scale, _last_ui_scale):
		return
	_last_ui_scale = scale
	for label: Label in _hud_labels:
		label.add_theme_font_size_override("font_size", int(label.get_meta("base_font_size") * scale))


func _update_hud() -> void:
	if _lap_value == null:
		return
	var current_lap := mini(3, int(_distance_m / TRACK_LENGTH) + 1) if _race_active else 1
	var seconds := maxi(0, int(ceil(_seconds_left))) if _race_active else 70
	var speed := int(round(_speed_kmh)) if _race_active else 0
	_lap_value.text = "%d / 3" % current_lap
	_time_value.text = "%02d" % seconds
	_speed_value.text = "%d km/h" % speed
