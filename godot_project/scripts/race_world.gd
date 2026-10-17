extends Node3D
## Everything you see around the circuit of the Online room TV racer: sky and fog, a hilly coast with a fjord, the road
## with kerbs, barriers, a tunnel and a bridge, and the scenery (trees, houses, a small town, a harbour with a crane and
## a lighthouse, a grandstand, billboards ...). It is built once from the track in build(); kart_race_view.gd only adds
## the cars and the camera. Most small things go through a few MultiMesh batches so the whole world is ~40 draw calls.

const RaceTrack := preload("res://scripts/race_track.gd")

const ROAD_HALF_WIDTH := 13.0
const SHOULDER_HALF_WIDTH := 16.3          # the run-off strip between the kerb and the end of the road structure
const BARRIER_OFFSET := 15.6
const TUNNEL_HEIGHT := 7.6
const TERRAIN_MIN := Vector2(-600.0, -560.0)
const TERRAIN_CELL := 10.0
const TERRAIN_CELLS := 120
const STAMP_RADIUS := 100.0
const NEAR := 17.0                         # closer than this to the road the ground simply follows the road
const FAR := 95.0                          # farther than this it is the natural landscape
const HILL_RAISE := 10.0                   # how far the hill over the tunnel rises above the road

const SKY_HORIZON := Color8(176, 214, 240)
const ASPHALT := Color8(82, 83, 88)
const SHOULDER := Color8(118, 128, 104)
const CONCRETE := Color8(150, 152, 150)
const SKIRT := Color8(78, 80, 86)
const CURB_RED := Color8(220, 38, 43)
const CURB_WHITE := Color8(239, 235, 216)
const SAND := Color8(222, 205, 150)
const GRASS := Color8(104, 176, 66)
const GRASS_DARK := Color8(62, 132, 70)
const ROCK := Color8(128, 124, 120)
const SNOW := Color8(236, 240, 244)
const WINDOW := Color8(104, 186, 220)
const WALL_COLORS: Array[Color] = [Color8(230, 231, 221), Color8(247, 211, 153), Color8(236, 239, 233), Color8(246, 219, 140), Color8(226, 232, 234), Color8(239, 190, 170), Color8(196, 214, 226)]
const HOUSE_COLORS: Array[Color] = [Color8(238, 232, 218), Color8(214, 84, 66), Color8(240, 200, 98), Color8(96, 140, 178), Color8(232, 150, 96)]
const ROOF_COLORS: Array[Color] = [Color8(84, 70, 66), Color8(120, 62, 52), Color8(70, 78, 90)]
const CROWD_COLORS: Array[Color] = [Color8(246, 47, 53), Color8(48, 174, 220), Color8(248, 196, 40), Color8(61, 183, 89), Color8(247, 239, 224)]


## Triangle soup with a colour per triangle; works out the winding from a hint direction (Godot: clockwise = front).
class MeshBuilder extends RefCounted:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	func tri(a: Vector3, b: Vector3, c: Vector3, hint: Vector3, color: Color) -> void:
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1.0e-10:
			return
		var second := b
		var third := c
		if n.dot(hint) < 0.0:
			second = c
			third = b
			n = -n
		n = n.normalized()
		vertices.append(a)
		vertices.append(second)
		vertices.append(third)
		for _corner in 3:
			normals.append(n)
			colors.append(color)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, color: Color) -> void:
		tri(a, b, c, hint, color)
		tri(a, c, d, hint, color)

	func build(material: Material) -> MeshInstance3D:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return instance


## Many copies of one unit mesh (scaled / rotated / coloured per instance) drawn in one go.
class Batch extends RefCounted:
	var mesh: Mesh
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	func add(xform: Transform3D, color: Color) -> void:
		transforms.append(xform)
		colors.append(color)

	func build(material: Material) -> MultiMeshInstance3D:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
			multimesh.set_instance_color(i, colors[i])
		multimesh.custom_aabb = AABB(Vector3(-800.0, -80.0, -800.0), Vector3(1600.0, 260.0, 1600.0))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return instance


var _track: RaceTrack
var _segments: int = 0
var _segment_length: float = 5.0
var _heights := PackedFloat32Array()
var _dist := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _material_cache: Dictionary = {}
var _houses: Array[Vector2] = []

var _boxes: Batch
var _cones: Batch
var _cylinders: Batch
var _prisms: Batch
var _spheres: Batch


func build(track: RaceTrack) -> void:
	_track = track
	_segments = maxi(8, int(round(track.length / 5.0)))
	_segment_length = track.length / float(_segments)
	_rng.seed = 90210
	_make_batches()
	_build_environment()
	_build_terrain()
	_build_water()
	_build_road()
	_build_tunnel()
	_build_bridge()
	_build_start_area()
	_build_road_furniture()
	_build_harbour()
	_build_town()
	_scatter_houses()
	_scatter_trees()
	_build_clouds()
	_flush_batches()


## Height of the ground (or the road, near it) at a world position.
func ground_y(x: float, z: float) -> float:
	var fx := (x - TERRAIN_MIN.x) / TERRAIN_CELL
	var fz := (z - TERRAIN_MIN.y) / TERRAIN_CELL
	var ix := clampi(int(floorf(fx)), 0, TERRAIN_CELLS - 1)
	var iz := clampi(int(floorf(fz)), 0, TERRAIN_CELLS - 1)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)
	var n := TERRAIN_CELLS + 1
	var h00 := _heights[iz * n + ix]
	var h10 := _heights[iz * n + ix + 1]
	var h01 := _heights[(iz + 1) * n + ix]
	var h11 := _heights[(iz + 1) * n + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


## Distance (m, capped) from a world position to the nearest part of the track.
func track_distance(x: float, z: float) -> float:
	var fx := (x - TERRAIN_MIN.x) / TERRAIN_CELL
	var fz := (z - TERRAIN_MIN.y) / TERRAIN_CELL
	var ix := clampi(int(floorf(fx)), 0, TERRAIN_CELLS - 1)
	var iz := clampi(int(floorf(fz)), 0, TERRAIN_CELLS - 1)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)
	var n := TERRAIN_CELLS + 1
	var d00 := _dist[iz * n + ix]
	var d10 := _dist[iz * n + ix + 1]
	var d01 := _dist[(iz + 1) * n + ix]
	var d11 := _dist[(iz + 1) * n + ix + 1]
	return lerpf(lerpf(d00, d10, tx), lerpf(d01, d11, tx), tz)


# ------------------------------------------------------------------ helpers

func _make_batches() -> void:
	_boxes = Batch.new()
	_boxes.mesh = BoxMesh.new()
	_cones = Batch.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 1
	_cones.mesh = cone
	_cylinders = Batch.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	cylinder.rings = 1
	_cylinders.mesh = cylinder
	_prisms = Batch.new()
	_prisms.mesh = PrismMesh.new()
	_spheres = Batch.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 7
	sphere.rings = 4
	_spheres.mesh = sphere


func _flush_batches() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	for batch: Batch in [_boxes, _cones, _cylinders, _prisms, _spheres]:
		if batch.transforms.size() > 0:
			add_child(batch.build(material))


## Adds one scaled copy of a batch mesh, positioned in the frame `frame` (local position + size).
func _put(batch: Batch, frame: Transform3D, local_pos: Vector3, size: Vector3, color: Color) -> void:
	batch.add(frame * Transform3D(Basis.from_scale(size), local_pos), color)


## Upright frame at a world position, turned by yaw.
func _upright(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func _material(color: Color, roughness: float = 0.9, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s:%d:%s" % [color.to_html(true), int(roughness * 100.0), str(unshaded)]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = material
	return material


func _vertex_color_material(cull_off: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	if cull_off:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _box_node(parent: Node, size: Vector3, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Orientation that follows the road: x along the road (including its slope), z to the driver's right, y = road normal.
func _road_basis(s: float) -> Basis:
	var side := _track.side(s)
	var along := (_track.tangent(s) + Vector3.UP * _track.slope(s)).normalized()
	return Basis(along, side.cross(along), side)


func _frame_at(s: float, lateral: float, lift: float = 0.0) -> Transform3D:
	var basis := _road_basis(s)
	var origin := _track.center(s) + _track.side(s) * lateral + basis.y * lift
	return Transform3D(basis, origin)


func _yaw_of(s: float) -> float:
	var t := _track.tangent(s)
	return atan2(-t.z, t.x)


## 1 inside [start, end] (lap distance), fading to 0 over `ramp` metres outside.
func _zone_weight(s: float, start: float, end: float, ramp: float) -> float:
	var w := _track.wrap_s(s)
	if w < start:
		return clampf(1.0 - (start - w) / ramp, 0.0, 1.0)
	if w > end:
		return clampf(1.0 - (w - end) / ramp, 0.0, 1.0)
	return 1.0


## The ground at an arbitrary place with a flat enough surface for a building (returns the lowest corner height).
func _flat_ground(x: float, z: float, half_x: float, half_z: float, max_spread: float) -> float:
	var low := 1.0e9
	var high := -1.0e9
	for corner_x: float in [-half_x, half_x]:
		for corner_z: float in [-half_z, half_z]:
			var h := ground_y(x + corner_x, z + corner_z)
			low = minf(low, h)
			high = maxf(high, h)
	if high - low > max_spread:
		return NAN
	return low


# ------------------------------------------------------------------ sky, light

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color8(52, 124, 214)
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.ground_bottom_color = Color8(120, 160, 190)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color8(205, 214, 226)
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = SKY_HORIZON
	environment.fog_density = 0.0011
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "GrandPrixSun"
	sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	sun.light_color = Color8(255, 244, 220)
	sun.light_energy = 1.05
	sun.shadow_enabled = false      # cars get a blob shadow instead (the TV picture is rendered while you play)
	add_child(sun)


# ------------------------------------------------------------------ terrain and water

## The landscape without the road: rolling hills, mountains around, the sea in the north and a fjord in the west.
func _natural_height(x: float, z: float) -> float:
	var centre_dist := Vector2(x - 20.0, z - 20.0).length()
	var calm := 0.35 + 0.65 * smoothstep(120.0, 260.0, centre_dist)
	var hills := 6.0 + calm * (5.0 * sin(x * 0.012 + 1.3) * cos(z * 0.010) + 3.0 * sin(x * 0.031 + z * 0.023) + 1.2 * sin(z * 0.06 - x * 0.045))
	var mountains := 62.0 * smoothstep(290.0, 560.0, centre_dist)
	var shore := -228.0 + 14.0 * sin(x * 0.015)
	var land_mix := smoothstep(shore - 14.0, shore + 18.0, z)
	var fjord := exp(-pow(z / 46.0, 2.0)) * (1.0 - smoothstep(-205.0, -120.0, x))
	var height := lerpf(-6.0, hills + mountains, land_mix) - 22.0 * fjord * land_mix
	var edge := minf(minf(x - TERRAIN_MIN.x, TERRAIN_MIN.x + TERRAIN_CELL * float(TERRAIN_CELLS) - x), minf(z - TERRAIN_MIN.y, TERRAIN_MIN.y + TERRAIN_CELL * float(TERRAIN_CELLS) - z))
	return lerpf(-8.0, height, smoothstep(0.0, 90.0, edge))


func _build_terrain() -> void:
	var n := TERRAIN_CELLS + 1
	var nearest := PackedFloat32Array()
	nearest.resize(n * n)
	nearest.fill(1.0e12)
	var road_y := PackedFloat32Array()
	road_y.resize(n * n)
	var follow := PackedFloat32Array()
	follow.resize(n * n)
	var raise_in := PackedFloat32Array()
	raise_in.resize(n * n)
	var raise_out := PackedFloat32Array()
	raise_out.resize(n * n)
	var s := 0.0
	while s < _track.length:
		var c := _track.center(s)
		var f := 1.0 - _zone_weight(s, RaceTrack.BRIDGE_START + 6.0, RaceTrack.BRIDGE_END - 6.0, 30.0)
		var r_in := _zone_weight(s, RaceTrack.TUNNEL_START + 4.0, RaceTrack.TUNNEL_END - 4.0, 8.0)
		var r_out := _zone_weight(s, RaceTrack.TUNNEL_START, RaceTrack.TUNNEL_END, 60.0)
		var ix0 := clampi(int(floorf((c.x - STAMP_RADIUS - TERRAIN_MIN.x) / TERRAIN_CELL)), 0, n - 1)
		var ix1 := clampi(int(ceilf((c.x + STAMP_RADIUS - TERRAIN_MIN.x) / TERRAIN_CELL)), 0, n - 1)
		var iz0 := clampi(int(floorf((c.z - STAMP_RADIUS - TERRAIN_MIN.y) / TERRAIN_CELL)), 0, n - 1)
		var iz1 := clampi(int(ceilf((c.z + STAMP_RADIUS - TERRAIN_MIN.y) / TERRAIN_CELL)), 0, n - 1)
		for iz in range(iz0, iz1 + 1):
			var dz := TERRAIN_MIN.y + float(iz) * TERRAIN_CELL - c.z
			for ix in range(ix0, ix1 + 1):
				var dx := TERRAIN_MIN.x + float(ix) * TERRAIN_CELL - c.x
				var d2 := dx * dx + dz * dz
				var k := iz * n + ix
				if d2 < nearest[k]:
					nearest[k] = d2
					road_y[k] = c.y
					follow[k] = f
					raise_in[k] = r_in
					raise_out[k] = r_out
		s += 6.0

	_heights.resize(n * n)
	_dist.resize(n * n)
	for iz in n:
		for ix in n:
			var k := iz * n + ix
			var wx := TERRAIN_MIN.x + float(ix) * TERRAIN_CELL
			var wz := TERRAIN_MIN.y + float(iz) * TERRAIN_CELL
			var d := sqrt(nearest[k])
			var w := (1.0 - smoothstep(NEAR, FAR, d)) * follow[k]
			var lift := HILL_RAISE * raise_out[k] * smoothstep(14.0, 30.0, d)       # the roadway itself stays open; a mound covers the tube
			var target := road_y[k] - 1.0 + lift
			_heights[k] = lerpf(_natural_height(wx, wz), target, w)
			_dist[k] = minf(d, 999.0)

	var builder := MeshBuilder.new()
	for iz in TERRAIN_CELLS:
		for ix in TERRAIN_CELLS:
			var p00 := _terrain_vertex(ix, iz)
			var p10 := _terrain_vertex(ix + 1, iz)
			var p01 := _terrain_vertex(ix, iz + 1)
			var p11 := _terrain_vertex(ix + 1, iz + 1)
			if (ix + iz) % 2 == 0:
				_terrain_tri(builder, p00, p01, p10)
				_terrain_tri(builder, p10, p01, p11)
			else:
				_terrain_tri(builder, p00, p01, p11)
				_terrain_tri(builder, p00, p11, p10)
	var terrain := builder.build(_vertex_color_material(true))
	terrain.name = "Landscape"
	add_child(terrain)


func _terrain_vertex(ix: int, iz: int) -> Vector3:
	var n := TERRAIN_CELLS + 1
	return Vector3(TERRAIN_MIN.x + float(ix) * TERRAIN_CELL, _heights[iz * n + ix], TERRAIN_MIN.y + float(iz) * TERRAIN_CELL)


func _terrain_tri(builder: MeshBuilder, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var steep := 1.0 - absf(normal.y)
	var height := (a.y + b.y + c.y) / 3.0
	var jitter := _rng.randf_range(-0.05, 0.05)
	builder.tri(a, b, c, Vector3.UP, _terrain_color(height, steep, jitter))


func _terrain_color(height: float, steep: float, jitter: float) -> Color:
	var color: Color
	if height < -0.2:
		color = Color8(70, 140, 160)
	elif height < 0.9:
		color = SAND
	elif height < 24.0:
		color = GRASS.lerp(GRASS_DARK, clampf(height / 24.0, 0.0, 1.0))
	elif height < 46.0:
		color = GRASS_DARK.lerp(ROCK, clampf((height - 24.0) / 22.0, 0.0, 1.0))
	else:
		color = ROCK.lerp(SNOW, clampf((height - 46.0) / 14.0, 0.0, 1.0))
	if steep > 0.38:
		color = color.lerp(ROCK, clampf((steep - 0.38) * 3.5, 0.0, 0.85))
	return color.lightened(jitter) if jitter > 0.0 else color.darkened(-jitter)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(5000.0, 5000.0)
	var water := MeshInstance3D.new()
	water.name = "Sea"
	water.mesh = plane
	water.position = Vector3(0.0, 0.0, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color8(38, 138, 188)
	material.roughness = 0.25
	material.metallic = 0.15
	material.metallic_specular = 0.8
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ------------------------------------------------------------------ road

func _build_road() -> void:
	var asphalt := MeshBuilder.new()
	var shoulder := MeshBuilder.new()
	var paint := MeshBuilder.new()
	var up := Vector3.UP
	var line_color := Color8(236, 234, 224)
	for i in _segments:
		var s0 := float(i) * _segment_length
		var s1 := s0 + _segment_length
		var c0 := _track.center(s0) + up * 0.02
		var c1 := _track.center(s1) + up * 0.02
		var r0 := _track.side(s0)
		var r1 := _track.side(s1)
		var tone := ASPHALT.darkened(0.05) if i % 2 == 0 else ASPHALT
		asphalt.quad(c0 + r0 * ROAD_HALF_WIDTH, c1 + r1 * ROAD_HALF_WIDTH, c1 - r1 * ROAD_HALF_WIDTH, c0 - r0 * ROAD_HALF_WIDTH, up, tone)
		for side_sign: float in [-1.0, 1.0]:
			var inner0 := c0 + r0 * ROAD_HALF_WIDTH * side_sign
			var inner1 := c1 + r1 * ROAD_HALF_WIDTH * side_sign
			var outer0 := c0 + r0 * SHOULDER_HALF_WIDTH * side_sign - up * 0.04
			var outer1 := c1 + r1 * SHOULDER_HALF_WIDTH * side_sign - up * 0.04
			shoulder.quad(inner0, inner1, outer1, outer0, up, SHOULDER)
			var drop := Vector3.DOWN * 1.7
			shoulder.quad(outer0, outer1, outer1 + drop, outer0 + drop, r0 * side_sign, SKIRT)
			# white edge line, one metre inside the kerb
			var e0 := c0 + r0 * (ROAD_HALF_WIDTH - 1.0) * side_sign + up * 0.04
			var e1 := c1 + r1 * (ROAD_HALF_WIDTH - 1.0) * side_sign + up * 0.04
			paint.quad(e0 - r0 * 0.12, e1 - r1 * 0.12, e1 + r1 * 0.12, e0 + r0 * 0.12, up, line_color)
		if i % 2 == 0:                    # dashed centre line
			var m0 := _track.center(s0 + 1.0) + up * 0.04
			var m1 := _track.center(s0 + 4.0) + up * 0.04
			var rm := _track.side(s0 + 2.5)
			paint.quad(m0 - rm * 0.1, m1 - rm * 0.1, m1 + rm * 0.1, m0 + rm * 0.1, up, line_color)
	# chequered start / finish line
	for column in 16:
		for row in 2:
			var l0 := -ROAD_HALF_WIDTH + float(column) * ROAD_HALF_WIDTH * 2.0 / 16.0
			var l1 := l0 + ROAD_HALF_WIDTH * 2.0 / 16.0
			var a := _track.center(float(row) * 1.0)
			var b := _track.center(float(row + 1) * 1.0)
			var rs := _track.side(0.5)
			var checker := Color.BLACK if (column + row) % 2 == 0 else CURB_WHITE
			paint.quad(a + rs * l0 + up * 0.045, b + rs * l0 + up * 0.045, b + rs * l1 + up * 0.045, a + rs * l1 + up * 0.045, up, checker)
	var asphalt_mesh := asphalt.build(_vertex_color_material(true))
	asphalt_mesh.name = "Asphalt"
	add_child(asphalt_mesh)
	var shoulder_mesh := shoulder.build(_vertex_color_material(true))
	shoulder_mesh.name = "RoadShoulders"
	add_child(shoulder_mesh)
	var paint_mesh := paint.build(_vertex_color_material(true))
	paint_mesh.name = "RoadPaint"
	add_child(paint_mesh)

	# kerbs on both edges, red / white
	for i in _segments:
		var mid := (float(i) + 0.5) * _segment_length
		var length := _track.center(float(i) * _segment_length).distance_to(_track.center(float(i + 1) * _segment_length)) + 0.15
		for side_sign: float in [-1.0, 1.0]:
			var frame := _frame_at(mid, (ROAD_HALF_WIDTH - 0.2) * side_sign, 0.1)
			_put(_boxes, frame, Vector3.ZERO, Vector3(length, 0.17, 1.45), CURB_RED if i % 2 == 0 else CURB_WHITE)
			if _track.in_tunnel(mid):
				continue
			var barrier_color := CURB_RED if i % 2 == 0 else CURB_WHITE
			var barrier_frame := _frame_at(mid, BARRIER_OFFSET * side_sign, 0.62)
			_put(_boxes, barrier_frame, Vector3.ZERO, Vector3(length, 1.15, 0.72), barrier_color)


# ------------------------------------------------------------------ tunnel and bridge

func _build_tunnel() -> void:
	var wall := Color8(88, 90, 98)
	var roof := Color8(62, 64, 70)
	var light := Color8(255, 246, 200)
	var s := RaceTrack.TUNNEL_START
	while s < RaceTrack.TUNNEL_END:
		var mid := s + _segment_length * 0.5
		var length := _segment_length + 0.15
		for side_sign: float in [-1.0, 1.0]:
			_put(_boxes, _frame_at(mid, 15.6 * side_sign, TUNNEL_HEIGHT * 0.5), Vector3.ZERO, Vector3(length, TUNNEL_HEIGHT + 1.2, 1.0), wall)
			_put(_boxes, _frame_at(mid, 14.9 * side_sign, 1.6), Vector3.ZERO, Vector3(length, 0.5, 0.3), Color8(246, 168, 40))
		_put(_boxes, _frame_at(mid, 0.0, TUNNEL_HEIGHT + 0.5), Vector3.ZERO, Vector3(length, 1.0, 33.0), roof)
		_put(_boxes, _frame_at(mid, 0.0, TUNNEL_HEIGHT + 3.2), Vector3.ZERO, Vector3(length, 4.4, 34.0), Color8(178, 172, 160))
		if int(round(s / _segment_length)) % 3 == 0:
			for lane: float in [-6.0, 6.0]:
				_put(_boxes, _frame_at(mid, lane, TUNNEL_HEIGHT - 0.1), Vector3.ZERO, Vector3(2.4, 0.12, 0.7), light)
		s += _segment_length
	# portals: two pillars and a lintel framing each mouth, with a sign
	for entry: Array in [[RaceTrack.TUNNEL_START, 1.0], [RaceTrack.TUNNEL_END, -1.0]]:
		var at: float = entry[0]
		var facing: float = entry[1]
		var frame := _frame_at(at - facing * 0.5, 0.0, 0.0)
		var stone := Color8(178, 172, 160)
		for side_sign: float in [-1.0, 1.0]:
			_put(_boxes, frame, Vector3(0.0, 6.5, 19.2 * side_sign), Vector3(2.4, 13.0, 8.0), stone)
		_put(_boxes, frame, Vector3(0.0, TUNNEL_HEIGHT + 2.6, 0.0), Vector3(2.4, 5.2, 34.0), stone)
		var sign_label := Label3D.new()
		sign_label.text = "TUNNEL"
		sign_label.font_size = 80
		sign_label.pixel_size = 0.014
		sign_label.modulate = Color8(30, 36, 44)
		sign_label.shaded = false
		sign_label.position = frame.origin + frame.basis.y * (TUNNEL_HEIGHT + 2.6) - frame.basis.x * facing * 1.25
		var t := _track.tangent(at)
		sign_label.rotation.y = atan2(-facing * t.x, -facing * t.z)       # the text faces the drivers coming through
		add_child(sign_label)


func _build_bridge() -> void:
	var deck := Color8(124, 126, 132)
	var pier := Color8(176, 176, 170)
	var s := RaceTrack.BRIDGE_START
	while s < RaceTrack.BRIDGE_END:
		var mid := s + _segment_length * 0.5
		var length := _segment_length + 0.15
		_put(_boxes, _frame_at(mid, 0.0, -0.95), Vector3.ZERO, Vector3(length, 1.5, SHOULDER_HALF_WIDTH * 2.0), deck)
		s += _segment_length
	var pier_s := RaceTrack.BRIDGE_START + 10.0
	while pier_s < RaceTrack.BRIDGE_END:
		var frame := _frame_at(pier_s, 0.0)
		var top := frame.origin.y - 1.6
		var bottom := -9.0
		for side_sign: float in [-1.0, 1.0]:
			var column := frame.origin + frame.basis.z * 8.0 * side_sign
			var pier_frame := _upright(Vector3(column.x, (top + bottom) * 0.5, column.z), _yaw_of(pier_s))
			_put(_boxes, pier_frame, Vector3.ZERO, Vector3(2.6, top - bottom, 3.2), pier)
		pier_s += 26.0
	# arched look: lamp posts along the bridge
	var lamp_s := RaceTrack.BRIDGE_START + 4.0
	while lamp_s < RaceTrack.BRIDGE_END:
		for side_sign: float in [-1.0, 1.0]:
			var frame := _frame_at(lamp_s, 15.0 * side_sign)
			_put(_cylinders, frame, Vector3(0.0, 3.2, 0.0), Vector3(0.28, 6.4, 0.28), Color8(214, 220, 218))
			_put(_boxes, frame, Vector3(0.0, 6.5, -0.7 * side_sign), Vector3(0.5, 0.18, 1.6), Color8(255, 238, 150))
		lamp_s += 30.0


# ------------------------------------------------------------------ start area

func _build_start_area() -> void:
	# gantry over the line with the banner
	var frame := _frame_at(0.0, 0.0)
	var gantry := Node3D.new()
	gantry.name = "StartGantry"
	gantry.transform = frame
	add_child(gantry)
	var steel := _material(Color8(205, 211, 214), 0.6)
	for side_sign: float in [-1.0, 1.0]:
		_box_node(gantry, Vector3(0.7, 8.0, 0.7), Vector3(0.0, 4.0, side_sign * (ROAD_HALF_WIDTH + 1.6)), steel)
	_box_node(gantry, Vector3(1.3, 1.9, ROAD_HALF_WIDTH * 2.0 + 4.2), Vector3(0.0, 8.4, 0.0), _material(Color8(14, 31, 72), 0.8))
	var banner := Label3D.new()
	banner.text = "GRAND  PRIX"
	banner.font_size = 96
	banner.pixel_size = 0.016
	banner.modulate = Color8(255, 226, 44)
	banner.outline_size = 10
	banner.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	banner.shaded = false
	banner.position = Vector3(-0.72, 8.4, 0.0)
	banner.rotation.y = -PI * 0.5          # the gantry's local +Z is the track's right side; this turns the text towards the drivers
	gantry.add_child(banner)

	# grandstand on the right side of the main straight, full of people
	_build_grandstand(150.0, 1.0)
	_build_grandstand(250.0, 1.0)
	# a row of tall buildings along the right of the straight (the harbour front)
	var s := 40.0
	var n := 0
	while s < 320.0:
		var lateral := 52.0 + float(n % 3) * 6.0
		var f := _frame_at(s, lateral)
		var height := 14.0 + fposmod(s * 0.37, 16.0)
		_add_building(Vector3(f.origin.x, ground_y(f.origin.x, f.origin.z) - 0.6, f.origin.z), _yaw_of(s), 22.0 + fposmod(s * 0.23, 8.0), 17.0, height, WALL_COLORS[n % WALL_COLORS.size()])
		s += 46.0
		n += 1


func _build_grandstand(s: float, side_sign: float) -> void:
	var frame := _frame_at(s, 21.0 * side_sign)
	var base := Vector3(frame.origin.x, ground_y(frame.origin.x, frame.origin.z) - 0.4, frame.origin.z)
	var f := Transform3D(Basis(Vector3.UP, _yaw_of(s)), base)
	for row in 4:
		var z := side_sign * (1.0 + float(row) * 1.9)
		_put(_boxes, f, Vector3(0.0, 0.5 + float(row) * 0.9, z), Vector3(44.0 - float(row) * 3.0, 1.0 + float(row) * 1.8, 1.9), Color8(112, 122, 134))
		for person in 15:
			var px := (float(person) - 7.0) * 2.8 + _rng.randf_range(-0.4, 0.4)
			var shirt: Color = CROWD_COLORS[_rng.randi() % CROWD_COLORS.size()]
			var y := 1.4 + float(row) * 1.8
			_put(_boxes, f, Vector3(px, y, z), Vector3(0.55, 0.75, 0.45), shirt)
			_put(_spheres, f, Vector3(px, y + 0.62, z), Vector3(0.4, 0.4, 0.4), Color8(226, 177, 136))
	# roof over the stand
	_put(_boxes, f, Vector3(0.0, 7.4, side_sign * 5.0), Vector3(48.0, 0.4, 11.0), Color8(214, 60, 52))
	for post_x: float in [-22.0, 22.0]:
		_put(_boxes, f, Vector3(post_x, 3.7, side_sign * 9.5), Vector3(0.5, 7.4, 0.5), Color8(205, 211, 214))


# ------------------------------------------------------------------ road furniture

func _build_road_furniture() -> void:
	# reflector posts
	var s := 8.0
	while s < _track.length:
		for side_sign: float in [-1.0, 1.0]:
			var frame := _frame_at(s, 17.1 * side_sign)
			var ground := ground_y(frame.origin.x, frame.origin.z)
			_put(_boxes, Transform3D(frame.basis, Vector3(frame.origin.x, ground, frame.origin.z)), Vector3(0.0, 0.55, 0.0), Vector3(0.18, 1.3, 0.18), Color8(250, 250, 244))
		s += 16.0

	# yellow chevron boards on the outside of every proper corner, tyre stacks around the hairpin
	var board_mat := _material(Color8(255, 214, 30), 0.8)
	s = 8.0
	while s < _track.length:
		var k := _track.curvature(s)
		if absf(k) > 0.020 and not _track.in_tunnel(s) and not _track.in_bridge(s):
			var outer := -signf(k)
			var frame := _frame_at(s, outer * (BARRIER_OFFSET + 5.0))
			var ground := ground_y(frame.origin.x, frame.origin.z)
			var post_height := maxf(frame.origin.y + 3.6 - ground, 1.0)
			_put(_cylinders, Transform3D(frame.basis, Vector3(frame.origin.x, ground, frame.origin.z)), Vector3(0.0, post_height * 0.5, 0.0), Vector3(0.22, post_height, 0.22), Color8(60, 64, 70))
			var sign_node := Node3D.new()
			sign_node.name = "CornerSign"
			sign_node.transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 3.4)
			add_child(sign_node)
			_box_node(sign_node, Vector3(0.14, 2.2, 3.6), Vector3.ZERO, board_mat)
			var arrows := Label3D.new()
			arrows.text = ">>>" if k > 0.0 else "<<<"
			arrows.font_size = 120
			arrows.pixel_size = 0.016
			arrows.modulate = Color8(20, 20, 24)
			arrows.shaded = false
			arrows.position = Vector3(-0.09, 0.0, 0.0)
			arrows.rotation.y = -PI * 0.5
			sign_node.add_child(arrows)
			s += 60.0
		else:
			s += 12.0
	var tyre_s := 800.0
	while tyre_s < 870.0:
		for stack in 3:
			var frame := _frame_at(tyre_s, -signf(_track.curvature(tyre_s)) * (BARRIER_OFFSET + 1.6))
			var ground := ground_y(frame.origin.x, frame.origin.z)
			var tyre_frame := Transform3D(Basis(Vector3.UP, _yaw_of(tyre_s)), Vector3(frame.origin.x, ground, frame.origin.z))
			_put(_cylinders, tyre_frame, Vector3(0.0, 0.3 + float(stack) * 0.6, 0.0), Vector3(1.1, 0.58, 1.1), Color8(30, 30, 34) if stack % 2 == 0 else Color8(220, 220, 214))
		tyre_s += 3.0

	# street lights along the harbour straight
	s = 20.0
	while s < 330.0:
		var frame := _frame_at(s, -(SHOULDER_HALF_WIDTH + 3.2))
		var ground := ground_y(frame.origin.x, frame.origin.z)
		var base := Transform3D(frame.basis, Vector3(frame.origin.x, ground, frame.origin.z))
		_put(_cylinders, base, Vector3(0.0, 4.2, 0.0), Vector3(0.24, 8.4, 0.24), Color8(211, 218, 216))
		_put(_boxes, base, Vector3(0.0, 8.3, 1.2), Vector3(0.2, 0.2, 2.6), Color8(211, 218, 216))
		_put(_boxes, base, Vector3(0.0, 8.15, 2.2), Vector3(0.5, 0.22, 1.0), Color8(255, 238, 144))
		s += 38.0

	# billboards behind the barriers
	var ads: Array[String] = ["A4", "ONLINE", "KAFFE", "T.T.", "STUDENT GP", "NTNU", "KAFFE", "HOLD DEG UNNA"]
	var colors: Array[Color] = [Color8(255, 214, 30), Color8(220, 60, 52), Color8(236, 236, 228), Color8(60, 140, 210)]
	var ad_s := 70.0
	var ad_index := 0
	while ad_s < _track.length - 40.0:
		if not _track.in_tunnel(ad_s) and not _track.in_bridge(ad_s) and absf(_track.curvature(ad_s)) < 0.012:
			var side_sign := 1.0 if ad_index % 2 == 0 else -1.0
			var frame := _frame_at(ad_s, side_sign * (BARRIER_OFFSET + 2.8))
			var ground := ground_y(frame.origin.x, frame.origin.z)
			var panel := Node3D.new()
			panel.name = "Billboard"
			panel.transform = Transform3D(frame.basis, Vector3(frame.origin.x, maxf(ground, frame.origin.y - 1.0), frame.origin.z))
			add_child(panel)
			var board_color: Color = colors[ad_index % colors.size()]
			_box_node(panel, Vector3(8.0, 2.4, 0.2), Vector3(0.0, 2.4, 0.0), _material(board_color, 0.8))
			for post_x: float in [-3.0, 3.0]:
				_box_node(panel, Vector3(0.25, 2.4, 0.25), Vector3(post_x, 1.2, -0.2 * side_sign), _material(Color8(60, 64, 70)))
			var text := Label3D.new()
			text.text = ads[ad_index % ads.size()]
			text.font_size = 72
			text.pixel_size = 0.016
			text.modulate = Color8(24, 24, 30)
			text.shaded = false
			text.position = Vector3(0.0, 2.4, -0.12 * side_sign)      # on the face that looks at the road
			text.rotation.y = PI if side_sign > 0.0 else 0.0
			panel.add_child(text)
			ad_index += 1
			ad_s += 85.0
		else:
			ad_s += 15.0


# ------------------------------------------------------------------ harbour, town, nature

func _add_building(pos: Vector3, yaw: float, w: float, d: float, h: float, color: Color) -> void:
	var f := _upright(pos, yaw)
	_put(_boxes, f, Vector3(0.0, h * 0.5 + 0.2, 0.0), Vector3(w, h + 1.2, d), color)
	_put(_boxes, f, Vector3(0.0, h + 0.9, 0.0), Vector3(w + 0.8, 0.5, d + 0.8), Color8(220, 224, 224))
	_put(_boxes, f, Vector3(w * 0.2, h + 1.6, d * 0.1), Vector3(w * 0.25, 1.0, d * 0.2), Color8(150, 154, 158))
	var rows := maxi(2, int(h / 3.6))
	for row in rows:
		var y := 2.6 + float(row) * 3.4
		if y > h - 0.8:
			break
		_put(_boxes, f, Vector3(0.0, y, d * 0.5 + 0.03), Vector3(w * 0.84, 1.3, 0.1), WINDOW)
		_put(_boxes, f, Vector3(0.0, y, -d * 0.5 - 0.03), Vector3(w * 0.84, 1.3, 0.1), WINDOW)
		_put(_boxes, f, Vector3(w * 0.5 + 0.03, y, 0.0), Vector3(0.1, 1.3, d * 0.84), WINDOW)
		_put(_boxes, f, Vector3(-w * 0.5 - 0.03, y, 0.0), Vector3(0.1, 1.3, d * 0.84), WINDOW)


func _build_harbour() -> void:
	# a quay with containers and a gantry crane on the sea side (left) of the main straight
	var colors: Array[Color] = [Color8(200, 60, 52), Color8(48, 112, 190), Color8(238, 150, 40), Color8(66, 150, 96), Color8(228, 228, 220), Color8(120, 70, 150)]
	var count := 0
	for block in 4:
		var s := 60.0 + float(block) * 34.0
		var f := _frame_at(s, -(SHOULDER_HALF_WIDTH + 14.0))
		var ground := ground_y(f.origin.x, f.origin.z)
		var base := Transform3D(Basis(Vector3.UP, _yaw_of(s)), Vector3(f.origin.x, ground, f.origin.z))
		for column in 3:
			for tier in 1 + (block + column) % 3:
				_put(_boxes, base, Vector3(float(column) * 6.2 - 6.0, 1.3 + float(tier) * 2.65, 0.0), Vector3(6.0, 2.6, 2.5), colors[count % colors.size()])
				count += 1
	var crane_s := 205.0
	var cf := _frame_at(crane_s, -(SHOULDER_HALF_WIDTH + 12.0))
	var cground := ground_y(cf.origin.x, cf.origin.z)
	var crane := Transform3D(Basis(Vector3.UP, _yaw_of(crane_s)), Vector3(cf.origin.x, cground, cf.origin.z))
	for leg_x: float in [-9.0, 9.0]:
		for leg_z: float in [-3.5, 3.5]:
			_put(_boxes, crane, Vector3(leg_x, 14.0, leg_z), Vector3(0.9, 28.0, 0.9), Color8(214, 70, 52))
	_put(_boxes, crane, Vector3(0.0, 28.5, 0.0), Vector3(20.0, 1.4, 9.0), Color8(214, 70, 52))
	_put(_boxes, crane, Vector3(0.0, 31.0, -9.0), Vector3(3.0, 3.0, 36.0), Color8(236, 236, 228))
	_put(_boxes, crane, Vector3(0.0, 26.0, -16.0), Vector3(0.3, 8.0, 0.3), Color8(40, 40, 44))
	# a jetty and a few moored / sailing boats on the water
	var jetty_frame := _frame_at(120.0, -(SHOULDER_HALF_WIDTH + 28.0))
	var jetty := _upright(Vector3(jetty_frame.origin.x, 0.55, jetty_frame.origin.z - 18.0), 0.0)
	_put(_boxes, jetty, Vector3.ZERO, Vector3(3.4, 0.5, 44.0), Color8(140, 104, 70))
	var boats: Array[Vector3] = [Vector3(-60.0, 0.0, -262.0), Vector3(10.0, 0.0, -290.0), Vector3(90.0, 0.0, -255.0), Vector3(-130.0, 0.0, -300.0), Vector3(170.0, 0.0, -300.0), Vector3(40.0, 0.0, -340.0)]
	var boat_index := 0
	for boat_pos: Vector3 in boats:
		var bf := _upright(boat_pos, float(boat_index) * 0.9)
		var hull_color: Color = colors[boat_index % colors.size()]
		_put(_boxes, bf, Vector3(0.0, 0.5, 0.0), Vector3(7.5, 1.4, 2.6), hull_color)
		_put(_boxes, bf, Vector3(-0.6, 1.5, 0.0), Vector3(3.0, 1.2, 2.0), Color8(240, 240, 232))
		_put(_cylinders, bf, Vector3(1.2, 4.2, 0.0), Vector3(0.18, 8.0, 0.18), Color8(210, 210, 204))
		_put(_prisms, bf, Vector3(0.4, 4.6, 0.0), Vector3(0.12, 5.6, 3.4), Color8(250, 250, 244))
		boat_index += 1
	# lighthouse on a rock at the end of the quay
	var rock := Vector3(236.0, 0.0, -236.0)
	_put(_cones, _upright(rock, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(22.0, 9.0, 22.0), ROCK)
	for band in 4:
		var band_color := Color8(224, 60, 52) if band % 2 == 0 else Color8(240, 240, 234)
		var radius := 5.2 - float(band) * 0.6
		_put(_cylinders, _upright(rock, 0.0), Vector3(0.0, 6.5 + float(band) * 4.0, 0.0), Vector3(radius * 2.0, 4.0, radius * 2.0), band_color)
	_put(_boxes, _upright(rock, 0.0), Vector3(0.0, 21.6, 0.0), Vector3(4.0, 2.4, 4.0), Color8(255, 236, 140))
	_put(_cones, _upright(rock, 0.0), Vector3(0.0, 24.6, 0.0), Vector3(6.4, 3.6, 6.4), Color8(70, 74, 86))


func _build_town() -> void:
	# a little city of tall blocks in the middle of the circuit, visible over the harbour front
	for gx in 5:
		for gz in 3:
			var x := 0.0 + float(gx) * 36.0 + _rng.randf_range(-6.0, 6.0)
			var z := -84.0 + float(gz) * 38.0 + _rng.randf_range(-5.0, 5.0)
			if track_distance(x, z) < 50.0:
				continue
			var w := _rng.randf_range(16.0, 24.0)
			var d := _rng.randf_range(14.0, 20.0)
			var ground := _flat_ground(x, z, w * 0.5, d * 0.5, 7.0)
			if is_nan(ground):
				ground = ground_y(x, z) - 3.0
			var height := _rng.randf_range(12.0, 40.0)
			_add_building(Vector3(x, ground - 3.0, z), _rng.randf_range(-0.12, 0.12), w, d, height + 3.0, WALL_COLORS[_rng.randi() % WALL_COLORS.size()])
			_houses.append(Vector2(x, z))


func _scatter_houses() -> void:
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 1500:
		tries += 1
		var x := _rng.randf_range(-420.0, 460.0)
		var z := _rng.randf_range(-190.0, 420.0)
		var dist := track_distance(x, z)
		if dist < 34.0 or dist > 190.0:
			continue
		var ground := _flat_ground(x, z, 4.0, 4.0, 1.3)
		if is_nan(ground) or ground < 1.6 or ground > 24.0:
			continue
		var too_close := false
		for other in _houses:
			if other.distance_to(Vector2(x, z)) < 16.0:
				too_close = true
				break
		if too_close:
			continue
		_houses.append(Vector2(x, z))
		var yaw := _rng.randf_range(0.0, TAU)
		var f := _upright(Vector3(x, ground - 0.4, z), yaw)
		var w := _rng.randf_range(6.0, 9.0)
		var d := _rng.randf_range(5.0, 7.0)
		var h := _rng.randf_range(3.4, 5.2)
		_put(_boxes, f, Vector3(0.0, h * 0.5 + 0.4, 0.0), Vector3(w, h + 0.8, d), HOUSE_COLORS[_rng.randi() % HOUSE_COLORS.size()])
		var roof_frame := Transform3D(f.basis * Basis(Vector3.UP, PI * 0.5), f.origin)      # the prism's ridge runs along its local z
		_put(_prisms, roof_frame, Vector3(0.0, h + 1.9, 0.0), Vector3(d + 1.2, 2.2, w + 1.0), ROOF_COLORS[_rng.randi() % ROOF_COLORS.size()])
		_put(_boxes, f, Vector3(w * 0.5 + 0.03, 2.0, 0.0), Vector3(0.1, 1.2, d * 0.45), WINDOW)
		placed += 1


func _scatter_trees() -> void:
	var planted := 0
	var n := TERRAIN_CELLS
	var autumn: Array[Color] = [Color8(219, 150, 60), Color8(200, 110, 52)]
	for iz in range(2, n - 1):
		for ix in range(2, n - 1):
			if planted >= 1100:
				return
			var x := TERRAIN_MIN.x + float(ix) * TERRAIN_CELL + _rng.randf_range(-5.0, 5.0)
			var z := TERRAIN_MIN.y + float(iz) * TERRAIN_CELL + _rng.randf_range(-5.0, 5.0)
			var dist := track_distance(x, z)
			if dist < 23.0:
				continue
			var ground := ground_y(x, z)
			if ground < 1.5 or ground > 40.0:
				continue
			var density := 0.5 + 0.5 * sin(x * 0.021 + 1.0) * sin(z * 0.017 + 0.4)
			var chance := 0.34 * density * (1.0 if dist < 130.0 else 0.35)
			if _rng.randf() > chance:
				continue
			var blocked := false
			for house in _houses:
				if house.distance_to(Vector2(x, z)) < 13.0:
					blocked = true
					break
			if blocked:
				continue
			var tree_scale := _rng.randf_range(0.8, 1.5)
			var f := _upright(Vector3(x, ground - 0.3, z), 0.0)
			_put(_cylinders, f, Vector3(0.0, 1.0 * tree_scale, 0.0), Vector3(0.5 * tree_scale, 2.0 * tree_scale, 0.5 * tree_scale), Color8(110, 78, 52))
			if ground > 22.0 or _rng.randf() < 0.7:        # spruce
				var green := Color8(30 + _rng.randi() % 14, 98 + _rng.randi() % 24, 62)
				_put(_cones, f, Vector3(0.0, 3.4 * tree_scale, 0.0), Vector3(4.4 * tree_scale, 5.2 * tree_scale, 4.4 * tree_scale), green)
				_put(_cones, f, Vector3(0.0, 6.2 * tree_scale, 0.0), Vector3(3.0 * tree_scale, 4.2 * tree_scale, 3.0 * tree_scale), green.lightened(0.08))
			else:                                            # round leafy tree
				var leaf: Color = autumn[_rng.randi() % 2] if _rng.randf() < 0.25 else Color8(72 + _rng.randi() % 20, 150 + _rng.randi() % 24, 60)
				_put(_spheres, f, Vector3(0.0, 4.2 * tree_scale, 0.0), Vector3(4.6 * tree_scale, 4.2 * tree_scale, 4.6 * tree_scale), leaf)
			planted += 1


func _build_clouds() -> void:
	var white := Color8(250, 251, 248)
	for cloud_index in 12:
		var centre := Vector3(_rng.randf_range(-500.0, 520.0), _rng.randf_range(120.0, 190.0), _rng.randf_range(-480.0, 520.0))
		var f := _upright(centre, _rng.randf_range(0.0, TAU))
		for puff in 5:
			var size := Vector3(_rng.randf_range(22.0, 36.0), _rng.randf_range(9.0, 14.0), _rng.randf_range(16.0, 24.0))
			_put(_spheres, f, Vector3((float(puff) - 2.0) * 16.0, _rng.randf_range(-2.0, 2.0), _rng.randf_range(-4.0, 4.0)), size, white)
