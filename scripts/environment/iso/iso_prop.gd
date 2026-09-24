class_name IsoProp
extends StaticBody2D
## Machinery standing on one cell: a console, an engine block, a hatch. Drawn
## as a lower box than a wall; `solid` false leaves it walk-over (the hatch).

@export var height: float = 40.0
@export var footprint: float = 0.6
@export var solid: bool = true
@export var top_color: Color = Color("6d6252")
@export var side_color: Color = Color("3f372f")
@export var light_color: Color = Color(0, 0, 0, 0)
@export var caption: String = ""
@export var caption_color: Color = Color(0.85, 0.8, 0.7)

var _pulse: float = 0.0
var fade: float = 1.0:
	set(value):
		if not is_equal_approx(fade, value):
			fade = value
			modulate.a = value


func _ready() -> void:
	collision_layer = 1 if solid else 0
	collision_mask = 0
	if solid:
		var shape: CollisionPolygon2D = CollisionPolygon2D.new()
		shape.polygon = IsoMath.diamond(footprint)
		add_child(shape)


func _process(delta: float) -> void:
	if light_color.a > 0.0:
		_pulse = fmod(_pulse + delta * 3.0, TAU)
		queue_redraw()


func _draw() -> void:
	var d: PackedVector2Array = IsoMath.diamond(footprint)
	var up: Vector2 = Vector2(0, -height)
	if height > 0.0:
		draw_colored_polygon(PackedVector2Array([d[3] + up, d[2] + up, d[2], d[3]]), side_color)
		draw_colored_polygon(PackedVector2Array([d[2] + up, d[1] + up, d[1], d[2]]), side_color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([d[0] + up, d[1] + up, d[2] + up, d[3] + up]), top_color)
	draw_polyline(PackedVector2Array([d[0] + up, d[1] + up, d[2] + up, d[3] + up, d[0] + up]), Color("1a1612"), 2.0, true)
	if light_color.a > 0.0:
		var glow: float = 0.55 + 0.45 * sin(_pulse)
		draw_circle(up + Vector2(0, -2), 7.0, Color(light_color, glow))
	if caption != "":
		var font: Font = ThemeDB.fallback_font
		var size: int = WorldLabel.font_size(self, 13)
		var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var point: Vector2 = Vector2(-width * 0.5, up.y - 22.0)
		draw_string_outline(font, point, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.06, 0.05, 0.04))
		draw_string(font, point, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, caption_color)
