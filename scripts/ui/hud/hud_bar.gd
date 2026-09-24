class_name HudBar
extends Control
## Segmented meter: health, ammo pips, worm sign, prescience energy.

enum Style { SEGMENTS, PIPS }

@export var style: Style = Style.SEGMENTS
@export var segments: int = 10:
	set(value):
		segments = maxi(value, 1)
		queue_redraw()
@export var segment_size: Vector2 = Vector2(16, 10):
	set(value):
		segment_size = value
		_resize()
@export var gap: float = 3.0
var fill_color: Color = HudStyle.OK
var empty_color: Color = Color(1, 1, 1, 0.12)
## Filled fraction; for PIPS the filled count is round(ratio * segments).
var ratio: float = 1.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if not is_equal_approx(ratio, value):
			ratio = value
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_resize()


func set_value(current: float, maximum: float) -> void:
	ratio = current / maxf(maximum, 0.001)


func _resize() -> void:
	custom_minimum_size = Vector2(segments * segment_size.x + (segments - 1) * gap, segment_size.y)
	queue_redraw()


func _draw() -> void:
	# Magazines too big to draw one pip per round collapse into a solid bar.
	var count: int = segments
	var width: float = segment_size.x
	if style == Style.PIPS and count > 14:
		count = 1
		width = size.x
	var filled: int = roundi(ratio * count) if count > 1 else 0
	for index in range(count):
		var rect: Rect2 = Rect2(index * (width + gap), 0.0, width, segment_size.y)
		if count == 1:
			draw_rect(rect, empty_color)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill_color)
		elif index < filled:
			draw_rect(rect, fill_color)
		elif style == Style.PIPS:
			draw_rect(rect.grow(-0.75), Color(HudStyle.SAND_DIM, 0.7), false, 1.5)
		else:
			draw_rect(rect, empty_color)
