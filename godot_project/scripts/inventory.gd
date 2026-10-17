extends CanvasLayer
## Minecraft-style hotbar (5 slots at the bottom of the screen, keys 1-5 or the mouse wheel to pick one, no inventory screen)
## and the phone that the student drops at the start. While the phone's slot is selected you hold the phone up: it slides in
## on the right and shows the task list. Tasks are checked off with complete_task(id); that plays a little animation on the
## phone, a toast at the top of the screen with confetti and a chime, and pulses the phone's slot if the phone is not in hand.
## Other scripts find this node through the group "inventory" (add_item, has_item, complete_task, is_task_done).

signal task_completed(id: String)
signal item_added(id: String)

const SLOTS := 5
const ITEMS := {
	"phone": {"name": "Phone"},
}
## The phone's task list. Only the first is real so far; the rest are placeholders.
const TASKS: Array[Dictionary] = [
	{"id": "beat_tt", "text": "Beat T.T. in a race on the Online room TV"},
	{"id": "task_2", "text": "Lorem ipsum dolor sit amet"},
	{"id": "task_3", "text": "Consectetur adipiscing elit sed do eiusmod"},
	{"id": "task_4", "text": "Tempor incididunt ut labore et dolore"},
]

const GREEN := Color8(110, 220, 130)
const TEXT_COLOR := Color8(236, 240, 250)
const DIM_COLOR := Color8(130, 160, 140)


## One hotbar slot: dark square, number, the item's icon and a selection frame.
class Slot extends Control:
	var index: int = 0
	var item_id: String = ""
	var selected: bool = false
	var pulse: float = 0.0              # 1 -> 0, a green flash when something happened to the item

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.05, 0.06, 0.09, 0.72)
		back.set_corner_radius_all(int(size.x * 0.08))
		back.border_color = Color(1, 1, 1, 0.16)
		back.set_border_width_all(maxi(1, int(size.x * 0.03)))
		draw_style_box(back, box)
		if item_id == "phone":
			_draw_phone_icon()
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(size.x * 0.1, size.y * 0.24), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.y * 0.24), Color(1, 1, 1, 0.55))
		if pulse > 0.0:
			var glow := StyleBoxFlat.new()
			glow.bg_color = Color(GREEN.r, GREEN.g, GREEN.b, 0.25 * pulse)
			glow.set_corner_radius_all(int(size.x * 0.08))
			glow.border_color = Color(GREEN.r, GREEN.g, GREEN.b, pulse)
			glow.set_border_width_all(maxi(2, int(size.x * 0.06)))
			draw_style_box(glow, box)
		if selected:
			var frame := StyleBoxFlat.new()
			frame.draw_center = false
			frame.border_color = Color(1, 1, 1, 0.95)
			frame.set_border_width_all(maxi(2, int(size.x * 0.07)))
			frame.set_corner_radius_all(int(size.x * 0.1))
			frame.set_expand_margin_all(size.x * 0.04)
			draw_style_box(frame, box)

	func _draw_phone_icon() -> void:
		var w := size.x * 0.34
		var h := size.y * 0.62
		var body := Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.5 + size.y * 0.04), Vector2(w, h))
		var case := StyleBoxFlat.new()
		case.bg_color = Color8(26, 28, 38)
		case.set_corner_radius_all(int(w * 0.2))
		case.border_color = Color8(150, 160, 185)
		case.set_border_width_all(maxi(1, int(w * 0.07)))
		draw_style_box(case, body)
		var screen := body.grow(-w * 0.14)
		screen.position.y += h * 0.03
		draw_rect(screen, Color8(86, 190, 255))
		draw_rect(Rect2(screen.position + Vector2(screen.size.x * 0.15, screen.size.y * 0.14), Vector2(screen.size.x * 0.7, screen.size.y * 0.1)), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(screen.position + Vector2(screen.size.x * 0.15, screen.size.y * 0.34), Vector2(screen.size.x * 0.55, screen.size.y * 0.08)), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(screen.position + Vector2(screen.size.x * 0.15, screen.size.y * 0.5), Vector2(screen.size.x * 0.62, screen.size.y * 0.08)), Color(1, 1, 1, 0.5))


## The phone held up: body, status bar and the task list with its check-off animation.
class PhoneView extends Control:
	var tasks: Array[Dictionary] = []
	var progress: Dictionary = {}       # task id -> 0..1 animation of the check mark
	var done: Dictionary = {}
	var flash: float = 0.0              # green flash of the screen frame when a task is checked

	func _draw() -> void:
		var u := size.x / 240.0
		var font := ThemeDB.fallback_font
		var shell := StyleBoxFlat.new()
		shell.bg_color = Color8(14, 16, 22)
		shell.set_corner_radius_all(int(30.0 * u))
		shell.border_color = Color8(78, 84, 102).lerp(GREEN, flash)
		shell.set_border_width_all(int(4.0 * u))
		shell.shadow_color = Color(0, 0, 0, 0.45)
		shell.shadow_size = int(14.0 * u)
		draw_style_box(shell, Rect2(Vector2.ZERO, size))
		var screen := Rect2(Vector2(12.0, 12.0) * u, size - Vector2(24.0, 24.0) * u)
		var glass := StyleBoxFlat.new()
		glass.bg_color = Color8(22, 30, 48).lerp(Color8(26, 70, 44), flash * 0.5)
		glass.set_corner_radius_all(int(22.0 * u))
		draw_style_box(glass, screen)
		# status bar
		draw_string(font, Vector2(34.0, 44.0) * u, "9:41", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * u), Color(1, 1, 1, 0.75))
		draw_rect(Rect2(Vector2(size.x / u - 58.0, 33.0) * u, Vector2(20.0, 10.0) * u), Color(1, 1, 1, 0.7), false, 1.5 * u)
		draw_rect(Rect2(Vector2(size.x / u - 56.0, 35.0) * u, Vector2(13.0, 6.0) * u), GREEN)
		draw_rect(Rect2(Vector2(size.x / u - 38.0, 35.0) * u, Vector2(2.0, 6.0) * u), Color(1, 1, 1, 0.7))
		# header
		var finished := 0
		for task in tasks:
			if bool(done.get(task["id"], false)):
				finished += 1
		draw_string(font, Vector2(30.0, 82.0) * u, "TASKS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22.0 * u), TEXT_COLOR)
		draw_string(font, Vector2(30.0, 82.0) * u, "%d/%d" % [finished, tasks.size()], HORIZONTAL_ALIGNMENT_RIGHT, size.x - 60.0 * u, int(16.0 * u), DIM_COLOR if finished < tasks.size() else GREEN)
		draw_line(Vector2(30.0, 94.0) * u, Vector2(size.x / u - 30.0, 94.0) * u, Color(1, 1, 1, 0.15), 1.5 * u)
		# rows
		var y := 110.0
		for task in tasks:
			var id: String = task["id"]
			var p := float(progress.get(id, 0.0))
			var row_height := 74.0
			var box_size := 24.0 * u
			var pop := 1.0 + 0.4 * sin(clampf(p, 0.0, 1.0) * PI)
			var centre := Vector2(44.0, y + 20.0) * u
			var half := box_size * 0.5 * pop
			var box := Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)
			var tick := StyleBoxFlat.new()
			tick.bg_color = Color(GREEN.r, GREEN.g, GREEN.b, p)
			tick.set_corner_radius_all(int(6.0 * u))
			tick.border_color = Color(1, 1, 1, 0.55).lerp(GREEN, p)
			tick.set_border_width_all(maxi(1, int(2.0 * u)))
			draw_style_box(tick, box)
			if p > 0.0:                                                   # the check mark draws itself
				var a := box.position + box.size * Vector2(0.24, 0.54)
				var b := box.position + box.size * Vector2(0.43, 0.73)
				var c := box.position + box.size * Vector2(0.78, 0.30)
				var q := clampf(p * 1.6 - 0.2, 0.0, 1.0)
				if q < 0.5:
					draw_line(a, a.lerp(b, q * 2.0), Color(0.05, 0.12, 0.07), 3.0 * u)
				else:
					draw_line(a, b, Color(0.05, 0.12, 0.07), 3.0 * u)
					draw_line(b, b.lerp(c, (q - 0.5) * 2.0), Color(0.05, 0.12, 0.07), 3.0 * u)
			var text: String = task["text"]
			var text_x := 70.0 * u
			var text_width := size.x - text_x - 28.0 * u
			var fs := int(15.0 * u)
			var colour := TEXT_COLOR.lerp(DIM_COLOR, p)
			draw_multiline_string(font, Vector2(text_x, (y + 16.0) * u), text, HORIZONTAL_ALIGNMENT_LEFT, text_width, fs, 3, colour)
			if p > 0.0:                                                   # strike-through sweeps across the first line
				var line_w := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, text_width, fs, 1).x
				draw_line(Vector2(text_x, (y + 11.0) * u), Vector2(text_x + line_w * clampf(p * 1.3, 0.0, 1.0), (y + 11.0) * u), GREEN, 2.0 * u)
			y += row_height
		draw_string(font, Vector2(0.0, size.y - 26.0 * u), "more soon...", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(12.0 * u), Color(1, 1, 1, 0.25))


## "Task complete" banner: panel, a check mark that draws itself, the task name.
class Toast extends Control:
	var title: String = "Task complete"
	var detail: String = ""
	var check: float = 0.0

	func _draw() -> void:
		var u := size.y / 76.0
		var font := ThemeDB.fallback_font
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.05, 0.08, 0.07, 0.92)
		panel.set_corner_radius_all(int(size.y * 0.3))
		panel.border_color = GREEN
		panel.set_border_width_all(maxi(2, int(2.5 * u)))
		panel.shadow_color = Color(0, 0, 0, 0.4)
		panel.shadow_size = int(12.0 * u)
		draw_style_box(panel, Rect2(Vector2.ZERO, size))
		var centre := Vector2(size.y * 0.5, size.y * 0.5)
		draw_circle(centre, size.y * 0.3, Color(GREEN.r, GREEN.g, GREEN.b, 0.25))
		draw_arc(centre, size.y * 0.3, -PI * 0.5, -PI * 0.5 + TAU * minf(check * 1.4, 1.0), 40, GREEN, 3.0 * u)
		var r := size.y * 0.3
		var a := centre + Vector2(-0.45, 0.02) * r
		var b := centre + Vector2(-0.1, 0.38) * r
		var c := centre + Vector2(0.52, -0.38) * r
		var q := clampf(check * 2.0 - 0.8, 0.0, 1.0)
		if q > 0.0:
			if q < 0.5:
				draw_line(a, a.lerp(b, q * 2.0), GREEN, 4.0 * u)
			else:
				draw_line(a, b, GREEN, 4.0 * u)
				draw_line(b, b.lerp(c, (q - 0.5) * 2.0), GREEN, 4.0 * u)
		draw_string(font, Vector2(size.y * 0.98, size.y * 0.44), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(21.0 * u), GREEN)
		draw_string(font, Vector2(size.y * 0.98, size.y * 0.72), detail, HORIZONTAL_ALIGNMENT_LEFT, size.x - size.y * 1.15, int(15.0 * u), TEXT_COLOR)


var items: Array[String] = []
var selected: int = 0
var done: Dictionary = {}

var _slots: Array[Slot] = []
var _hotbar: HBoxContainer
var _phone: PhoneView
var _toast: Toast
var _confetti: CPUParticles2D
var _name_label: Label
var _name_timer: float = 0.0
var _chime: AudioStreamPlayer
var _phone_show: float = 0.0
var _toast_tween: Tween
var _last_size := Vector2i.ZERO


func _ready() -> void:
	layer = 15
	add_to_group("inventory")
	for i in SLOTS:
		items.append("")
	_hotbar = HBoxContainer.new()
	_hotbar.add_theme_constant_override("separation", 4)
	add_child(_hotbar)
	for i in SLOTS:
		var slot := Slot.new()
		slot.index = i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar.add_child(slot)
		_slots.append(slot)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_name_label.add_theme_constant_override("outline_size", 6)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_phone = PhoneView.new()
	_phone.tasks.assign(TASKS)
	_phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.visible = false
	add_child(_phone)
	_toast = Toast.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	_confetti = CPUParticles2D.new()
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.explosiveness = 1.0
	_confetti.amount = 48
	_confetti.lifetime = 1.4
	_confetti.direction = Vector2(0, -1)
	_confetti.spread = 110.0
	_confetti.gravity = Vector2(0, 900)
	_confetti.initial_velocity_min = 260.0
	_confetti.initial_velocity_max = 560.0
	_confetti.angular_velocity_min = -540.0
	_confetti.angular_velocity_max = 540.0
	_confetti.scale_amount_min = 5.0
	_confetti.scale_amount_max = 9.0
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color8(110, 220, 130), Color8(255, 214, 80), Color8(90, 180, 255), Color8(255, 120, 150), Color8(240, 240, 250)])
	_confetti.color_initial_ramp = gradient
	add_child(_confetti)
	_chime = AudioStreamPlayer.new()
	_chime.stream = _make_chime()
	_chime.volume_db = -6.0
	add_child(_chime)
	_refresh()
	_layout()


func _process(delta: float) -> void:
	var window_size := Vector2i(get_viewport().get_visible_rect().size)
	if window_size != _last_size:
		_layout()
	var holding := _held_item() == "phone"
	_phone_show = lerpf(_phone_show, 1.0 if holding else 0.0, 1.0 - exp(-delta * 12.0))
	_phone.visible = _phone_show > 0.01
	_place_phone()
	_phone.flash = maxf(0.0, _phone.flash - delta * 1.4)
	for slot in _slots:
		slot.pulse = maxf(0.0, slot.pulse - delta * 1.1)
		slot.queue_redraw()
	_phone.queue_redraw()
	_name_timer = maxf(0.0, _name_timer - delta)
	_name_label.modulate.a = clampf(_name_timer * 2.0, 0.0, 1.0)
	_toast.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code := (event as InputEventKey).physical_keycode
		if code >= KEY_1 and code < KEY_1 + SLOTS:
			select(int(code) - int(KEY_1))
	elif event is InputEventMouseButton and event.pressed:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_WHEEL_UP:
			select((selected - 1 + SLOTS) % SLOTS)
		elif button == MOUSE_BUTTON_WHEEL_DOWN:
			select((selected + 1) % SLOTS)


# ------------------------------------------------------------------ API

func select(index: int) -> void:
	selected = clampi(index, 0, SLOTS - 1)
	_refresh()
	var held := _held_item()
	if held != "":
		_name_label.text = String(ITEMS[held]["name"])
		_name_timer = 2.0


func has_item(id: String) -> bool:
	return items.has(id)


## Puts an item in the first free slot and takes it in hand. False if the hotbar is full.
func add_item(id: String) -> bool:
	var slot_index := items.find("")
	if slot_index < 0:
		return false
	items[slot_index] = id
	_slots[slot_index].pulse = 1.0
	select(slot_index)
	item_added.emit(id)
	return true


func is_task_done(id: String) -> bool:
	return bool(done.get(id, false))


func complete_task(id: String) -> void:
	if is_task_done(id):
		return
	var text := ""
	for task in TASKS:
		if task["id"] == id:
			text = task["text"]
	if text == "":
		return
	done[id] = true
	_phone.done = done
	task_completed.emit(id)
	if not has_item("phone"):                       # the phone is not found yet: the task is remembered and shows up checked later
		_phone.progress[id] = 1.0
		return
	var anim := create_tween()
	anim.tween_method(func(v: float) -> void: _phone.progress[id] = v, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_phone.flash = 1.0
	var phone_slot := items.find("phone")
	if phone_slot >= 0 and phone_slot != selected:
		_slots[phone_slot].pulse = 1.0
	_show_toast("Task complete", text)


# ------------------------------------------------------------------ drawing and layout

func _held_item() -> String:
	return items[selected]


func _refresh() -> void:
	for i in SLOTS:
		_slots[i].item_id = items[i]
		_slots[i].selected = i == selected
	_phone.done = done


func _ui_scale() -> float:
	return clampf(get_viewport().get_visible_rect().size.y / 720.0, 0.8, 2.4)


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	_last_size = Vector2i(view)
	var u := _ui_scale()
	var slot_size := Vector2(56.0, 56.0) * u
	for slot in _slots:
		slot.custom_minimum_size = slot_size
		slot.size = slot_size
	_hotbar.add_theme_constant_override("separation", int(4.0 * u))
	var bar_width := slot_size.x * SLOTS + 4.0 * u * (SLOTS - 1)
	_hotbar.size = Vector2(bar_width, slot_size.y)
	_hotbar.position = Vector2((view.x - bar_width) * 0.5, view.y - slot_size.y - 14.0 * u)
	_name_label.add_theme_font_size_override("font_size", int(18.0 * u))
	_name_label.size = Vector2(bar_width, 28.0 * u)
	_name_label.position = Vector2(_hotbar.position.x, _hotbar.position.y - 52.0 * u)
	_phone.size = Vector2(240.0, 480.0) * u
	_phone.pivot_offset = _phone.size * 0.5
	_toast.size = Vector2(460.0, 76.0) * u
	_toast.pivot_offset = _toast.size * 0.5
	_place_phone()


## The phone slides up from the bottom right when it is in hand and sinks away when another slot is selected.
func _place_phone() -> void:
	var view := get_viewport().get_visible_rect().size
	var u := _ui_scale()
	var shown_y := view.y - _phone.size.y - 20.0 * u
	var hidden_y := view.y + 30.0 * u
	_phone.position = Vector2(view.x - _phone.size.x - 28.0 * u, lerpf(hidden_y, shown_y, _phone_show))
	_phone.rotation = deg_to_rad(-3.0 * (1.0 - _phone_show) - 1.5)


func _show_toast(title: String, detail: String) -> void:
	var view := get_viewport().get_visible_rect().size
	var u := _ui_scale()
	_toast.title = title
	_toast.detail = detail
	_toast.check = 0.0
	_toast.visible = true
	_toast.modulate.a = 1.0
	var x := (view.x - _toast.size.x) * 0.5
	_toast.position = Vector2(x, -_toast.size.y - 10.0)
	_toast.scale = Vector2(0.9, 0.9)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "position:y", 26.0 * u, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.parallel().tween_property(_toast, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.parallel().tween_property(_toast, "check", 1.0, 0.7).set_delay(0.25)
	_toast_tween.tween_callback(_burst_confetti)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "position:y", -_toast.size.y - 10.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)
	_chime.play()


func _burst_confetti() -> void:
	_confetti.position = _toast.position + Vector2(_toast.size.x * 0.5, _toast.size.y * 0.5)
	_confetti.restart()
	_confetti.emitting = true


## A short two-note "ding" made from sine waves, so no audio file is needed.
func _make_chime() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.7
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var note := 1318.5 if t < 0.16 else 1975.5
		var local := t if t < 0.16 else t - 0.16
		var envelope := minf(local * 80.0, 1.0) * exp(-local * 7.0)
		var value := (sin(TAU * note * t) + 0.35 * sin(TAU * note * 2.0 * t)) * envelope * 0.5
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
