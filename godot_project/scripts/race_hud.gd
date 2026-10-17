extends CanvasLayer
## Heads-up display of the TV racer. Deliberately plain: small monospace text with a dark outline in the corners of the
## picture, a thin boost line and a track outline. No panels, bars or glow. kart_race_view.gd feeds it the numbers.

const TEXT_COLOR := Color8(244, 242, 232)
const DIM_COLOR := Color8(186, 192, 196)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const BOOST_COLOR := Color8(255, 190, 70)


## The track as a thin line with one dot per car.
class Minimap extends Control:
	var outline := PackedVector2Array()
	var dots: Array[Dictionary] = []
	var _min := Vector2.ZERO
	var _extent := Vector2.ONE

	func setup(points: PackedVector2Array) -> void:
		outline = points.duplicate()
		outline.append(points[0])
		_min = points[0]
		var upper := points[0]
		for p in points:
			_min = Vector2(minf(_min.x, p.x), minf(_min.y, p.y))
			upper = Vector2(maxf(upper.x, p.x), maxf(upper.y, p.y))
		_extent = upper - _min

	func _to_view(p: Vector2) -> Vector2:
		var margin := 4.0
		var fit := minf((size.x - margin * 2.0) / _extent.x, (size.y - margin * 2.0) / _extent.y)
		var used := _extent * fit
		return (size - used) * 0.5 + (p - _min) * fit

	func _draw() -> void:
		if outline.size() < 2:
			return
		var line := PackedVector2Array()
		for p in outline:
			line.append(_to_view(p))
		draw_polyline(line, Color(0.0, 0.0, 0.0, 0.55), 4.0)
		draw_polyline(line, Color(0.93, 0.95, 0.96, 0.9), 2.0)
		for dot: Dictionary in dots:
			var at := _to_view(dot["pos"] as Vector2)
			var radius := 4.5 if bool(dot["main"]) else 3.0
			draw_circle(at, radius + 1.2, Color(0.0, 0.0, 0.0, 0.85))
			draw_circle(at, radius, dot["color"] as Color)


var _font: SystemFont
var _root: Control
var _entries: Array[Dictionary] = []
var _last_scale: float = -1.0

var _position_label: Label
var _lap_label: Label
var _time_label: Label
var _speed_label: Label
var _gap_label: Label
var _hint_label: Label
var _countdown_label: Label
var _boost_back: ColorRect
var _boost_fill: ColorRect
var _minimap: Minimap
var _result_dim: ColorRect
var _result_title: Label
var _result_sub: Label
var _result_hint: Label
var _menu: Control
var _menu_blink: Label
var _clock: float = 0.0


func _ready() -> void:
	layer = 5
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_position_label = _label("1/6", 26, HORIZONTAL_ALIGNMENT_LEFT, Vector4(0.0, 0.0, 0.4, 0.0), Vector4(12.0, 6.0, 0.0, 36.0))
	_lap_label = _label("LAP 1/3", 13, HORIZONTAL_ALIGNMENT_LEFT, Vector4(0.0, 0.0, 0.4, 0.0), Vector4(12.0, 38.0, 0.0, 56.0), DIM_COLOR)
	_time_label = _label("0:00.0", 16, HORIZONTAL_ALIGNMENT_RIGHT, Vector4(0.6, 0.0, 1.0, 0.0), Vector4(0.0, 8.0, -12.0, 30.0))
	_speed_label = _label("0 km/h", 22, HORIZONTAL_ALIGNMENT_RIGHT, Vector4(0.55, 1.0, 1.0, 1.0), Vector4(0.0, -42.0, -12.0, -16.0))
	_gap_label = _label("", 15, HORIZONTAL_ALIGNMENT_LEFT, Vector4(0.0, 1.0, 0.55, 1.0), Vector4(12.0, -32.0, 0.0, -10.0))
	_hint_label = _label("", 11, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.2, 0.0, 0.8, 0.0), Vector4(0.0, 8.0, 0.0, 24.0), DIM_COLOR)
	_countdown_label = _label("", 72, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.3, 0.2, 0.7, 0.2), Vector4(0.0, 0.0, 0.0, 96.0))

	_boost_back = ColorRect.new()
	_boost_back.color = Color(0.0, 0.0, 0.0, 0.5)
	_boost_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boost_back)
	_register(_boost_back, Vector4(0.78, 1.0, 1.0, 1.0), Vector4(0.0, -12.0, -12.0, -8.0))
	_boost_fill = ColorRect.new()
	_boost_fill.color = BOOST_COLOR
	_boost_fill.anchor_bottom = 1.0
	_boost_fill.anchor_right = 1.0
	_boost_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_back.add_child(_boost_fill)

	_minimap = Minimap.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_minimap)
	_register(_minimap, Vector4(0.8, 0.0, 1.0, 0.0), Vector4(0.0, 34.0, -8.0, 116.0))

	_result_dim = ColorRect.new()
	_result_dim.color = Color(0.0, 0.0, 0.0, 0.42)
	_result_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_dim.visible = false
	_root.add_child(_result_dim)
	_result_title = _label("", 40, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.34, 1.0, 0.34), Vector4(0.0, 0.0, 0.0, 52.0), TEXT_COLOR, _result_dim)
	_result_sub = _label("", 18, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.52, 1.0, 0.52), Vector4(0.0, 0.0, 0.0, 28.0), TEXT_COLOR, _result_dim)
	_result_hint = _label("", 13, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.64, 1.0, 0.64), Vector4(0.0, 0.0, 0.0, 22.0), DIM_COLOR, _result_dim)
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.10, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(shade)
	_label("GRAND PRIX", 46, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.18, 1.0, 0.18), Vector4(0.0, 0.0, 0.0, 60.0), Color8(255, 226, 44), _menu)
	_label("2 laps  -  6 cars  -  harbour circuit", 14, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.36, 1.0, 0.36), Vector4(0.0, 0.0, 0.0, 22.0), DIM_COLOR, _menu)
	_menu_blink = _label("T.T. is losing", 18, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.5, 1.0, 0.5), Vector4(0.0, 0.0, 0.0, 28.0), TEXT_COLOR, _menu)
	_label("> PRESS E TO START <", 20, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.64, 1.0, 0.64), Vector4(0.0, 0.0, 0.0, 30.0), TEXT_COLOR, _menu)
	_label("W gas   S brake   A D steer   Shift boost   Esc quit", 11, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.86, 1.0, 0.86), Vector4(0.0, 0.0, 0.0, 18.0), DIM_COLOR, _menu)
	_apply_scale(true)


func _process(delta: float) -> void:
	_clock += delta
	if _menu.visible and _menu_blink != null:
		_menu_blink.modulate.a = 1.0 if fmod(_clock, 1.2) < 0.8 else 0.35
	_apply_scale(false)


## The start menu on the TV: shown while nobody is racing; hides the race read-outs.
func set_menu(on: bool) -> void:
	if _menu.visible == on:
		return
	_menu.visible = on
	for node: Control in [_position_label, _lap_label, _time_label, _speed_label, _gap_label, _hint_label, _countdown_label, _boost_back, _minimap]:
		node.visible = not on


## One label placed by anchors (l, t, r, b) + offsets in 360p units that scale with the picture height.
func _label(text: String, base_size: int, align: HorizontalAlignment, anchors: Vector4, offsets: Vector4, color: Color = TEXT_COLOR, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.set_meta("base_size", base_size)
	(parent if parent != null else _root).add_child(label)
	_register(label, anchors, offsets)
	return label


func _register(node: Control, anchors: Vector4, offsets: Vector4) -> void:
	_entries.append({"node": node, "anchors": anchors, "offsets": offsets})


func _apply_scale(force: bool) -> void:
	var ui_scale := clampf(float(get_viewport().size.y) / 360.0, 0.85, 2.2)
	if not force and is_equal_approx(ui_scale, _last_scale):
		return
	_last_scale = ui_scale
	for entry: Dictionary in _entries:
		var node: Control = entry["node"]
		var a: Vector4 = entry["anchors"]
		var o: Vector4 = entry["offsets"]
		node.anchor_left = a.x
		node.anchor_top = a.y
		node.anchor_right = a.z
		node.anchor_bottom = a.w
		node.offset_left = o.x * ui_scale
		node.offset_top = o.y * ui_scale
		node.offset_right = o.z * ui_scale
		node.offset_bottom = o.w * ui_scale
		if node is Label and node.has_meta("base_size"):
			node.add_theme_font_size_override("font_size", int(round(float(node.get_meta("base_size")) * ui_scale)))
			node.add_theme_constant_override("outline_size", maxi(2, int(round(2.0 * ui_scale))))


# ------------------------------------------------------------------ API used by kart_race_view.gd

func setup(points: PackedVector2Array) -> void:
	_minimap.setup(points)


func set_driving(driving: bool) -> void:
	_boost_back.visible = driving
	_lap_label.visible = true


func update_values(rank: int, total: int, lap: int, laps: int, time_text: String, speed_kmh: int, boost: float) -> void:
	_position_label.text = "%d/%d" % [rank, total]
	_lap_label.text = "LAP %d/%d" % [lap, laps]
	_time_label.text = time_text
	_speed_label.text = "%d km/h" % speed_kmh
	_boost_fill.anchor_right = clampf(boost, 0.0, 1.0)


func set_gap(text: String, color: Color) -> void:
	_gap_label.text = text
	_gap_label.add_theme_color_override("font_color", color)


func set_dots(dots: Array[Dictionary]) -> void:
	_minimap.dots = dots
	_minimap.queue_redraw()


func set_countdown(text: String, color: Color) -> void:
	_countdown_label.text = text
	_countdown_label.add_theme_color_override("font_color", color)


func set_hint(text: String) -> void:
	_hint_label.text = text


func show_result(title: String, subtitle: String, hint: String) -> void:
	_result_title.text = title
	_result_sub.text = subtitle
	_result_hint.text = hint
	_result_dim.visible = true


func hide_result() -> void:
	_result_dim.visible = false
