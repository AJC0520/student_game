extends CanvasLayer
## HUD of the wasteland racer, plain monospace text with a dark outline:
##   top right    lap counter and the position leaderboard
##   bottom left  minimap (a SubViewport with an orthographic camera that only sees the "track layer" of the world)
##   bottom right health bar
## plus the countdown, the start menu and the result screen. wasteland_race.gd feeds it the numbers.

const TEXT_COLOR := Color8(240, 232, 214)
const DIM_COLOR := Color8(190, 176, 150)
const YOU_COLOR := Color8(255, 214, 80)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const HEALTH_GOOD := Color8(120, 200, 90)
const HEALTH_LOW := Color8(220, 70, 50)
const MINIMAP_LAYER := 2                  # visual layer (bit value 2) that only the minimap camera renders
const BOARD_ROWS := 6

var _font: SystemFont
var _root: Control
var _entries: Array[Dictionary] = []
var _last_scale: float = -1.0
var _clock: float = 0.0

var _lap_label: Label
var _board: Array[Label] = []
var _health_back: ColorRect
var _health_fill: ColorRect
var _health_label: Label
var _hint_label: Label
var _countdown_label: Label
var _minimap_frame: ColorRect
var _minimap_view: TextureRect
var _menu: Control
var _menu_blink: Label
var _result_dim: ColorRect
var _result_title: Label
var _result_sub: Label
var _result_hint: Label
var _race_items: Array[Control] = []
var _menu_state: int = -1


func _ready() -> void:
	layer = 5
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_lap_label = _label("LAP 1/3", 16, HORIZONTAL_ALIGNMENT_RIGHT, Vector4(0.6, 0.0, 1.0, 0.0), Vector4(0.0, 8.0, -12.0, 28.0))
	for row in BOARD_ROWS:
		var top := 32.0 + float(row) * 16.0
		_board.append(_label("", 13, HORIZONTAL_ALIGNMENT_RIGHT, Vector4(0.6, 0.0, 1.0, 0.0), Vector4(0.0, top, -12.0, top + 16.0)))

	_health_label = _label("HEALTH 100", 13, HORIZONTAL_ALIGNMENT_RIGHT, Vector4(0.6, 1.0, 1.0, 1.0), Vector4(0.0, -62.0, -12.0, -46.0))
	_health_back = ColorRect.new()
	_health_back.color = Color(0.0, 0.0, 0.0, 0.55)
	_health_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_health_back)
	_register(_health_back, Vector4(0.72, 1.0, 1.0, 1.0), Vector4(0.0, -44.0, -12.0, -38.0))
	_health_fill = ColorRect.new()
	_health_fill.color = HEALTH_GOOD
	_health_fill.anchor_right = 1.0
	_health_fill.anchor_bottom = 1.0
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_back.add_child(_health_fill)

	_minimap_frame = ColorRect.new()
	_minimap_frame.color = Color(0.0, 0.0, 0.0, 0.45)
	_minimap_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_minimap_frame)
	_register(_minimap_frame, Vector4(0.0, 1.0, 0.0, 1.0), Vector4(10.0, -136.0, 134.0, -10.0))
	_minimap_view = TextureRect.new()
	_minimap_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap_view.stretch_mode = TextureRect.STRETCH_SCALE
	_minimap_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_minimap_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_frame.add_child(_minimap_view)

	_hint_label = _label("", 11, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.15, 0.0, 0.6, 0.0), Vector4(0.0, 8.0, 0.0, 24.0), DIM_COLOR)
	_countdown_label = _label("", 72, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.3, 0.2, 0.7, 0.2), Vector4(0.0, 0.0, 0.0, 96.0))

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
	shade.color = Color(0.10, 0.06, 0.03, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(shade)
	_label("WASTELAND GP", 46, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.16, 1.0, 0.16), Vector4(0.0, 0.0, 0.0, 60.0), Color8(255, 168, 48), _menu)
	_label("3 laps  -  6 cars  -  dirt, junk and drifting", 14, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.34, 1.0, 0.34), Vector4(0.0, 0.0, 0.0, 22.0), DIM_COLOR, _menu)
	_menu_blink = _label("T.T. is losing", 18, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.48, 1.0, 0.48), Vector4(0.0, 0.0, 0.0, 28.0), TEXT_COLOR, _menu)
	_label("> PRESS E TO START <", 20, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.62, 1.0, 0.62), Vector4(0.0, 0.0, 0.0, 30.0), TEXT_COLOR, _menu)
	_label("W gas   S brake / reverse   A D steer   Shift handbrake (drift)   Esc quit", 11, HORIZONTAL_ALIGNMENT_CENTER, Vector4(0.0, 0.86, 1.0, 0.86), Vector4(0.0, 0.0, 0.0, 18.0), DIM_COLOR, _menu)

	_race_items = [_lap_label, _health_label, _health_back, _minimap_frame, _hint_label, _countdown_label]
	for label in _board:
		_race_items.append(label)
	_apply_scale(true)


func _process(delta: float) -> void:
	_clock += delta
	if _menu.visible and _menu_blink != null:
		_menu_blink.modulate.a = 1.0 if fmod(_clock, 1.2) < 0.8 else 0.35
	_apply_scale(false)


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


# ------------------------------------------------------------------ API used by wasteland_race.gd

## Builds the minimap: a SubViewport that shares the race world (it sits inside the TV viewport) and an orthographic camera
## high above the circuit that only renders the minimap layer (the track ribbon and one blip per car).
func build_minimap(centre: Vector3, extent: float) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	_root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent
	camera.near = 1.0
	camera.far = 400.0
	camera.cull_mask = MINIMAP_LAYER
	camera.current = true
	camera.position = Vector3(centre.x, 200.0, centre.z)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	viewport.add_child(camera)
	_minimap_view.texture = viewport.get_texture()


func set_menu(on: bool) -> void:
	var state := 1 if on else 0
	if state == _menu_state:
		return
	_menu_state = state
	_menu.visible = on
	for node in _race_items:
		node.visible = not on


func set_race_values(lap: int, laps: int, order: Array[String], player_name: String, health: float, max_health: float) -> void:
	_lap_label.text = "LAP %d/%d" % [lap, laps]
	for i in BOARD_ROWS:
		if i < order.size():
			_board[i].text = "%d  %s" % [i + 1, order[i]]
			_board[i].add_theme_color_override("font_color", YOU_COLOR if order[i] == player_name else TEXT_COLOR)
		else:
			_board[i].text = ""
	var ratio := clampf(health / max_health, 0.0, 1.0)
	_health_fill.anchor_right = ratio
	_health_fill.color = HEALTH_GOOD.lerp(HEALTH_LOW, 1.0 - ratio)
	_health_label.text = "HEALTH %d" % int(round(health))


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
