@tool
extends Node2D
## Static paved courtyard beneath the training yards. Seeded detail only; the
## desert arena keeps its own sand surface.

@export var courtyard_rect: Rect2 = Rect2(-1680, -620, 8640, 1240)
@export var stone_color: Color = Color("3b3936")
@export var seam_color: Color = Color(0.29, 0.28, 0.27, 0.55)
@export var paving: float = 160.0
@export var detail_seed: int = 17


func _draw() -> void:
	draw_rect(courtyard_rect.grow(60.0), Color("2a2724"))
	draw_rect(courtyard_rect, stone_color)
	var x: float = courtyard_rect.position.x
	while x < courtyard_rect.end.x:
		draw_line(Vector2(x, courtyard_rect.position.y), Vector2(x, courtyard_rect.end.y), seam_color, 2.0)
		x += paving
	var y: float = courtyard_rect.position.y
	while y < courtyard_rect.end.y:
		draw_line(Vector2(courtyard_rect.position.x, y), Vector2(courtyard_rect.end.x, y), seam_color, 2.0)
		y += paving
	# Warm Arrakis light spilling in, and a little wind-blown sand.
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = detail_seed
	for index in range(90):
		var point: Vector2 = Vector2(
			random.randf_range(courtyard_rect.position.x + 40, courtyard_rect.end.x - 40),
			random.randf_range(courtyard_rect.position.y + 40, courtyard_rect.end.y - 40))
		var size: float = random.randf_range(26.0, 90.0)
		draw_circle(point, size, Color(0.78, 0.66, 0.44, 0.06))
