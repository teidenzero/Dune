class_name DuneBackdrop
extends Control
## A desert at dusk, drawn in code for the menus and the story pages: a
## deepening sky, two moons, and layered dunes. `dim` darkens it for text.

@export_range(0.0, 1.0) var dim: float = 0.0

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var bands: int = 24
	for index in range(bands):
		var t: float = float(index) / bands
		var color: Color = Color("1b1020").lerp(Color("b5673a"), pow(t, 1.6))
		draw_rect(Rect2(0, h * t * 0.7, w, h * 0.7 / bands + 1.0), color)
	draw_circle(Vector2(w * 0.78, h * 0.2), 34.0, Color(0.95, 0.9, 0.8, 0.85))
	draw_circle(Vector2(w * 0.72, h * 0.14), 16.0, Color(0.9, 0.85, 0.78, 0.6))
	_dune(h * 0.62, 70.0, Color("6e3b22"), 0.0017, 0.4)
	_dune(h * 0.72, 55.0, Color("4a2616"), 0.0024, 1.7)
	_dune(h * 0.84, 40.0, Color("2a150c"), 0.0031, 3.1)
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.01, dim))


func _dune(base: float, amplitude: float, color: Color, frequency: float, phase: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 64
	var drift: float = _time * 0.02
	for index in range(steps + 1):
		var x: float = size.x * index / steps
		var y: float = base - amplitude * (0.6 * sin(x * frequency + phase + drift) + 0.4 * sin(x * frequency * 2.3 + phase * 1.7))
		points.append(Vector2(x, y))
	points.append(Vector2(size.x, size.y))
	points.append(Vector2(0, size.y))
	draw_colored_polygon(points, color)
