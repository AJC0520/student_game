extends Control
## The "keep it in the green" bar for the locked-door minigame (see door_minigame.gd).
## Hold Space (input action "jump") to push the marker right, let go and it falls back left. While the marker is inside the
## green zone the progress meter fills, outside it drains. The zone gets smaller and starts to wander as progress grows.
## Drawn in code as a simple dark card at the bottom of the screen: red bar, green zone, white marker and a progress bar.

signal succeeded

const CARD_SIZE := Vector2(720.0, 150.0)
const TRACK_H := 30.0
const TRACK_W := 640.0

const INK := Color(0.04, 0.04, 0.07)
const CARD := Color(0.07, 0.09, 0.16, 0.9)
const DANGER := Color(0.86, 0.20, 0.26)
const SAFE := Color(0.22, 0.82, 0.42)
const GOLD := Color(1.0, 0.82, 0.25)

@export var title: String = "BANK PÅ GLASSET"
@export var hint: String = "Hold inne MELLOMROM for å holde markøren i det grønne"
@export var fill_rate: float = 0.15       # progress per second inside the zone (~7 s of good play)
@export var drain_rate: float = 0.04      # progress per second outside the zone

var running: bool = false
var progress: float = 0.0

var _m: float = 0.5            # marker position 0..1
var _v: float = 0.0
var _phase: float = 0.0
var _zone_c: float = 0.5
var _zone_w: float = 0.40
var _in_zone: bool = false
var _holding: bool = false
var _slide: float = 0.0        # 0 = hidden below the screen, 1 = in place
var _t: float = 0.0
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func slide_in() -> void:
	_reset()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_slide", 1.0, 0.8)
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	await tw.finished


func slide_out() -> void:
	running = false
	await get_tree().create_timer(0.35).timeout
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_slide", 0.0, 0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	await tw.finished


func start() -> void:
	running = true


func _reset() -> void:
	progress = 0.0
	_m = 0.5
	_v = 0.0
	_phase = 0.0
	_zone_c = 0.5
	_zone_w = 0.40


func _process(delta: float) -> void:
	_t += delta
	if running:
		# marker: pushed up while Space is held, falls back otherwise (with a bit of drag)
		_holding = Input.is_action_pressed("jump")
		_v += ((3.2 if _holding else -2.4) - 3.2 * _v) * delta
		_m += _v * delta
		if _m < 0.0 or _m > 1.0:
			_m = clampf(_m, 0.0, 1.0)
			_v = -_v * 0.25
		# zone: shrinks and wanders more as progress grows
		_zone_w = lerpf(0.40, 0.24, progress)
		_phase += delta * lerpf(0.35, 0.7, progress)
		var amp := lerpf(0.06, 0.18, progress)
		_zone_c = clampf(0.5 + amp * sin(_phase) + 0.5 * amp * sin(_phase * 2.3 + 1.0), _zone_w * 0.5, 1.0 - _zone_w * 0.5)
		_in_zone = absf(_m - _zone_c) <= _zone_w * 0.5
		progress = clampf(progress + (fill_rate if _in_zone else -drain_rate) * delta, 0.0, 1.0)
		if progress >= 1.0:
			running = false
			succeeded.emit()
	if modulate.a > 0.0:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var lift := (1.0 - _slide) * 200.0
	var card := Rect2(Vector2((size.x - CARD_SIZE.x) * 0.5, size.y - CARD_SIZE.y - 28.0 + lift), CARD_SIZE)
	_box(card, CARD, 16.0, 3.0, INK)

	_text(font, Vector2(card.position.x, card.position.y + 34.0), title, 22, Color.WHITE, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(font, Vector2(card.position.x, card.position.y + 56.0), hint, 14, Color(1, 1, 1, 0.75), card.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	# red bar with the green zone and the marker
	var tx := card.position.x + (CARD_SIZE.x - TRACK_W) * 0.5
	var ty := card.position.y + 74.0
	var track := Rect2(tx, ty, TRACK_W, TRACK_H)
	_box(track, DANGER, 8.0, 3.0, INK)
	var zone := Rect2(tx + (_zone_c - _zone_w * 0.5) * TRACK_W, ty, _zone_w * TRACK_W, TRACK_H)
	_box(zone, SAFE, 8.0, 3.0, INK)
	var mx := tx + _m * TRACK_W
	_box(Rect2(mx - 5.0, ty - 7.0, 10.0, TRACK_H + 14.0), Color.WHITE, 4.0, 2.0, INK)

	# progress
	var pm := Rect2(tx, ty + TRACK_H + 18.0, TRACK_W, 12.0)
	_box(pm, Color(0.14, 0.15, 0.24), 6.0, 2.0, INK)
	if progress > 0.01:
		_box(Rect2(pm.position, Vector2(maxf(pm.size.x * progress, 12.0), pm.size.y)), GOLD.lerp(SAFE, progress), 6.0)


func _box(rect: Rect2, col: Color, radius: float, border: float = 0.0, border_col: Color = INK) -> void:
	_sb.bg_color = col
	_sb.set_corner_radius_all(int(radius))
	_sb.set_border_width_all(int(border))
	_sb.border_color = border_col
	draw_style_box(_sb, rect)


func _text(font: Font, pos: Vector2, text: String, fs: int, col: Color, width: float, align: HorizontalAlignment) -> void:
	draw_string_outline(font, pos, text, align, width, fs, 5, INK)
	draw_string(font, pos, text, align, width, fs, col)
