class_name HudSlot
extends Control
## One square action slot: frame, keycap, tinted icon, and the overlays that
## carry its state - a cooldown sweep, a charge ring, a count, a pulse.

enum State { NORMAL, EQUIPPED, ACTIVE, PRIMED, EMPTY, UNAVAILABLE, OPEN }

## Space above the frame reserved for the keycap overhang.
const KEY_OVERHANG: float = 12.0

@export var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
@export var key_text: String = "":
	set(value):
		key_text = value
		queue_redraw()
@export var slot_size: float = 68.0:
	set(value):
		slot_size = value
		_resize()
## Base tint for the icon in the NORMAL state.
@export var accent: Color = HudStyle.SAND

var state: State = State.NORMAL:
	set(value):
		if state != value:
			state = value
			queue_redraw()
## Fraction of the slot still dark from a cooldown or reload, 0 = none.
var sweep: float = 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(sweep, value):
			sweep = value
			queue_redraw()
## Charge ring progress, 0 = hidden.
var ring: float = 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(ring, value):
			ring = value
			queue_redraw()
var ring_color: Color = HudStyle.GOLD
## Stack count in the corner, -1 hides it.
var count: int = -1:
	set(value):
		if count != value:
			count = value
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _resize() -> void:
	custom_minimum_size = Vector2(slot_size, slot_size + KEY_OVERHANG)
	queue_redraw()


func _process(_delta: float) -> void:
	# Only the pulsing states need a redraw every frame.
	if state == State.EMPTY or state == State.PRIMED:
		queue_redraw()


func frame_rect() -> Rect2:
	return Rect2(0.0, KEY_OVERHANG, slot_size, slot_size)


func _draw() -> void:
	var box: Rect2 = frame_rect()
	var tint: Color = accent
	var border: Color = HudStyle.LINE
	var border_width: int = 1
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU)
	match state:
		State.EQUIPPED:
			tint = HudStyle.GOLD_LIGHT
			border = HudStyle.GOLD
			border_width = 2
			_glow(box, Color(HudStyle.GOLD, 0.28))
		State.ACTIVE:
			tint = HudStyle.SPICE_BLUE
			border = HudStyle.SPICE_BLUE
			border_width = 2
			_glow(box, Color(HudStyle.SPICE_BLUE, 0.28))
		State.PRIMED:
			tint = HudStyle.GOLD
			border = HudStyle.GOLD
			border_width = 2
			_glow(box, Color(HudStyle.GOLD, 0.25 + 0.25 * pulse))
		State.EMPTY:
			tint = HudStyle.DANGER
			border = HudStyle.DANGER.lerp(Color("7a2f20"), 1.0 - pulse)
			border_width = 2
			_glow(box, Color(HudStyle.DANGER, 0.3 * pulse))
		State.UNAVAILABLE:
			tint = Color(HudStyle.SAND_DIM, 0.45)
		State.OPEN:
			tint = Color(0, 0, 0, 0)
	if state == State.OPEN:
		_dashed_frame(box)
	else:
		var fill: StyleBoxFlat = HudStyle.panel_box(border, HudStyle.PANEL_2, border_width)
		fill.shadow_size = 6
		draw_style_box(fill, box)
	if ring > 0.0:
		var radius: float = slot_size * 0.5 - 6.0
		draw_arc(box.get_center(), radius, -PI * 0.5, -PI * 0.5 + TAU * ring, 48, ring_color, 4.0, true)
	if icon != null and state != State.OPEN:
		var inset: float = slot_size * 0.19
		draw_texture_rect(icon, box.grow(-inset), false, tint)
	if sweep > 0.0:
		draw_colored_polygon(_sweep_polygon(box, sweep), Color(0, 0, 0, 0.66))
	if count >= 0:
		var font: Font = HudStyle.mono_font()
		var text: String = str(count)
		var size: int = 15
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = Vector2(box.end.x - width - 6.0, box.end.y - 6.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, HudStyle.TEXT if count > 0 else HudStyle.DANGER)
	if key_text != "":
		HudStyle.draw_keycap(self, Vector2(box.get_center().x, 0.0), key_text)


func _glow(box: Rect2, color: Color) -> void:
	for step in range(3):
		var grow: float = 3.0 + step * 3.0
		var halo: StyleBoxFlat = StyleBoxFlat.new()
		halo.bg_color = Color(color, color.a * (0.5 - step * 0.15))
		halo.set_corner_radius_all(8 + step * 2)
		draw_style_box(halo, box.grow(grow))


func _dashed_frame(box: Rect2) -> void:
	var color: Color = Color(HudStyle.LINE, 0.9)
	var corners: PackedVector2Array = [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y), box.position]
	for index in range(4):
		draw_dashed_line(corners[index], corners[index + 1], color, 1.5, 6.0)


## Dark wedge covering the unrecovered fraction, clockwise from 12 o'clock,
## traced along the square edge so it fills the corners.
func _sweep_polygon(box: Rect2, fraction: float) -> PackedVector2Array:
	var center: Vector2 = box.get_center()
	var half: float = box.size.x * 0.5
	var points: PackedVector2Array = [center]
	var start: float = -PI * 0.5 + TAU * (1.0 - fraction)
	var end: float = -PI * 0.5 + TAU
	var steps: int = maxi(4, int(64.0 * fraction))
	for index in range(steps + 1):
		var angle: float = lerpf(start, end, float(index) / steps)
		var direction: Vector2 = Vector2.from_angle(angle)
		var scale: float = half / maxf(absf(direction.x), absf(direction.y))
		points.append(center + direction * scale)
	return points
