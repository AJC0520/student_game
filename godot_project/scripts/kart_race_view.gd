extends Control
## Draws the fake kart-racing picture shown on the Online room TV (see tv_screen.gd).
## Everything is simple shapes: scrolling road in pseudo-perspective, a rival kart ahead and "T.T" trailing behind.

const HORIZON := 118.0
const BANDS := 14
const PLAYER_NAME := "T.T"

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var font := ThemeDB.fallback_font
	_draw_scenery(w, h)
	_draw_road(w, h)

	# a banana peel on the road, rival kart ahead, our (losing) kart close to the camera
	var bob := sin(_t * 9.0) * 1.5
	_draw_banana(Vector2(w * 0.5 + 62.0, 190.0), 1.0)
	_draw_kart(Vector2(w * 0.5 + 18.0 + sin(_t * 1.3) * 10.0, 172.0 + bob), 0.55, Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.2), "")
	var px := w * 0.5 - 58.0 + sin(_t * 2.1) * 14.0     # wobbling around, can't hold a line
	_draw_kart(Vector2(px, 268.0 + bob * 2.0), 1.0, Color(0.25, 0.45, 0.9), Color(0.2, 0.7, 0.35), PLAYER_NAME)

	_draw_hud(w, h, font)


func _draw_scenery(w: float, h: float) -> void:
	# sky gradient
	var steps := 12
	for i in steps:
		var f := float(i) / steps
		var c := Color(0.45, 0.72, 1.0).lerp(Color(0.85, 0.94, 1.0), f)
		draw_rect(Rect2(0, f * HORIZON, w, HORIZON / steps + 1.0), c)
	draw_circle(Vector2(w * 0.8, 38.0), 17.0, Color(1.0, 0.96, 0.6))
	# drifting clouds
	for i in 3:
		var cx := fposmod(i * 230.0 + _t * 6.0, w + 120.0) - 60.0
		var cy := 28.0 + i * 20.0
		draw_circle(Vector2(cx, cy), 13.0, Color.WHITE)
		draw_circle(Vector2(cx + 15.0, cy + 3.0), 11.0, Color.WHITE)
		draw_circle(Vector2(cx - 15.0, cy + 3.0), 10.0, Color.WHITE)
	# hills
	var hills := PackedVector2Array([Vector2(0, HORIZON), Vector2(70, HORIZON - 42), Vector2(150, HORIZON), Vector2(230, HORIZON - 30),
		Vector2(330, HORIZON), Vector2(430, HORIZON - 50), Vector2(520, HORIZON), Vector2(w, HORIZON - 24), Vector2(w, HORIZON)])
	draw_colored_polygon(hills, Color(0.3, 0.62, 0.38))


func _draw_road(w: float, h: float) -> void:
	var cx := w * 0.5 + sin(_t * 0.6) * 18.0     # the road sways as the track curves
	var scroll := _t * 4.0
	for k in range(-1, BANDS + 1):
		var t0 := clampf((k + fposmod(scroll, 1.0)) / BANDS, 0.0, 1.0)
		var t1 := clampf((k + 1.0 + fposmod(scroll, 1.0)) / BANDS, 0.0, 1.0)
		var y0 := HORIZON + (h - HORIZON) * t0 * t0
		var y1 := HORIZON + (h - HORIZON) * t1 * t1
		if y1 - y0 < 0.1:
			continue
		var odd := (k + int(scroll)) % 2 == 0
		# grass
		draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), Color(0.28, 0.66, 0.34) if odd else Color(0.24, 0.6, 0.3))
		# road + rumble strips
		var x0 := _road_x(cx, y0, h)
		var x1 := _road_x(cx, y1, h)
		var hw0 := _road_hw(y0, h)
		var hw1 := _road_hw(y1, h)
		var kerb := Color(0.9, 0.2, 0.2) if odd else Color.WHITE
		var edge0 := hw0 * 1.12
		var edge1 := hw1 * 1.12
		draw_colored_polygon(PackedVector2Array([Vector2(x0 - edge0, y0), Vector2(x0 + edge0, y0), Vector2(x1 + edge1, y1 + 1.0), Vector2(x1 - edge1, y1 + 1.0)]), kerb)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 - hw0, y0), Vector2(x0 + hw0, y0), Vector2(x1 + hw1, y1 + 1.0), Vector2(x1 - hw1, y1 + 1.0)]),
			Color(0.46, 0.47, 0.52) if odd else Color(0.42, 0.43, 0.48))
		if odd:   # dashed centre line
			var lw0 := hw0 * 0.03
			var lw1 := hw1 * 0.03
			draw_colored_polygon(PackedVector2Array([Vector2(x0 - lw0, y0), Vector2(x0 + lw0, y0), Vector2(x1 + lw1, y1 + 1.0), Vector2(x1 - lw1, y1 + 1.0)]), Color(0.98, 0.95, 0.7))


func _road_hw(y: float, h: float) -> float:
	return 14.0 + (y - HORIZON) / (h - HORIZON) * 235.0


func _road_x(cx: float, y: float, h: float) -> float:
	var depth := 1.0 - (y - HORIZON) / (h - HORIZON)      # 0 = near, 1 = far
	return cx + depth * depth * sin(_t * 0.6) * 40.0


## Kart seen from behind. `origin` is the bottom centre of the kart on screen.
func _draw_kart(origin: Vector2, s: float, body: Color, accent: Color, nametag: String) -> void:
	var o := origin
	draw_rect(Rect2(o.x - 46 * s, o.y - 4 * s, 92 * s, 10 * s), Color(0, 0, 0, 0.28))                       # shadow
	for side in [-1.0, 1.0]:
		var wx: float = o.x + side * 36.0 * s
		draw_rect(Rect2(wx - 11 * s, o.y - 30 * s, 22 * s, 32 * s), Color(0.08, 0.08, 0.1))                 # rear wheels
		draw_rect(Rect2(wx - 6 * s, o.y - 26 * s, 12 * s, 24 * s), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(o.x - 30 * s, o.y - 34 * s, 60 * s, 26 * s), body)                                       # body
	draw_rect(Rect2(o.x - 30 * s, o.y - 14 * s, 60 * s, 6 * s), body.darkened(0.3))
	draw_rect(Rect2(o.x - 26 * s, o.y - 40 * s, 52 * s, 8 * s), accent)                                      # spoiler
	draw_rect(Rect2(o.x - 22 * s, o.y - 10 * s, 8 * s, 6 * s), Color(0.7, 0.7, 0.75))                        # exhausts
	draw_rect(Rect2(o.x + 14 * s, o.y - 10 * s, 8 * s, 6 * s), Color(0.7, 0.7, 0.75))
	# driver: back of a hooded figure
	draw_rect(Rect2(o.x - 15 * s, o.y - 58 * s, 30 * s, 26 * s), Color(0.9, 0.35, 0.25))
	draw_circle(Vector2(o.x, o.y - 66 * s), 13 * s, Color(0.24, 0.15, 0.1))
	draw_rect(Rect2(o.x - 15 * s, o.y - 56 * s, 30 * s, 3 * s), Color(0.7, 0.25, 0.2))
	if nametag != "":
		var font := ThemeDB.fallback_font
		var fs := 15
		var tw := font.get_string_size(nametag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(o.x - tw * 0.5, o.y - 90 * s)
		draw_rect(Rect2(pos.x - 4, pos.y - 13, tw + 8, 18), Color(0, 0, 0, 0.6))
		draw_string(font, pos, nametag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _draw_banana(p: Vector2, s: float) -> void:
	var pts := PackedVector2Array([p + Vector2(-9, 0) * s, p + Vector2(-4, -12) * s, p + Vector2(6, -14) * s, p + Vector2(11, -6) * s, p + Vector2(2, -6) * s, p + Vector2(-3, 2) * s])
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.15))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.55, 0.4, 0.05), 1.5)


func _draw_hud(w: float, h: float, font: Font) -> void:
	# race position, bottom left like a kart-game HUD
	draw_string_outline(font, Vector2(14, h - 14), "8", HORIZONTAL_ALIGNMENT_LEFT, -1, 62, 8, Color.BLACK)
	draw_string(font, Vector2(14, h - 14), "8", HORIZONTAL_ALIGNMENT_LEFT, -1, 62, Color(1.0, 0.85, 0.2))
	draw_string_outline(font, Vector2(52, h - 16), "/8", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color.BLACK)
	draw_string(font, Vector2(52, h - 16), "/8", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	# lap + time, top right
	draw_rect(Rect2(w - 150, 8, 142, 44), Color(0, 0, 0, 0.45))
	draw_string(font, Vector2(w - 142, 28), "LAP 3/3", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var tm := 94.0 + _t
	draw_string(font, Vector2(w - 142, 46), "%d'%02d\"%02d" % [int(tm / 60.0), int(tm) % 60, int(fposmod(tm, 1.0) * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.9, 1.0))
	# item box, top left (empty: nothing helpful for the loser)
	draw_rect(Rect2(10, 10, 40, 40), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(10, 10, 40, 40), Color(1, 1, 1, 0.8), false, 2.0)
	draw_string(font, Vector2(23, 40), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.5))

	# the easter-egg banner
	var text := PLAYER_NAME + " is losing"
	var pulse := 1.0 + sin(_t * 6.0) * 0.06
	var fs := int(26.0 * pulse)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((w - tw) * 0.5, 88.0)
	draw_rect(Rect2(pos.x - 12, pos.y - 28, tw + 24, 40), Color(0.75, 0.1, 0.1, 0.85))
	draw_rect(Rect2(pos.x - 12, pos.y - 28, tw + 24, 40), Color.WHITE, false, 2.0)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
