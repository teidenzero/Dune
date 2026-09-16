@tool
extends Node2D
## Static, seeded surface detail; nothing is simulated each frame.

@export var arena_rect: Rect2 = Rect2(-1600, -1100, 3200, 2200)
@export var sand_color: Color = Color("c5a16b")
@export var detail_seed: int = 41


func _ready() -> void:
	# Ground art sits behind everything, which is what leaves the band just
	# above it free for things painted on the ground - vision cones, for one.
	# See VisionCone.GROUND_Z / VisionCone.CONE_Z.
	z_index = VisionCone.GROUND_Z


func _draw() -> void:
	draw_rect(arena_rect, sand_color)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = detail_seed
	for index in range(200):
		var start: Vector2 = Vector2(
			random.randf_range(arena_rect.position.x + 80, arena_rect.end.x - 160),
			random.randf_range(arena_rect.position.y + 80, arena_rect.end.y - 80))
		var length: float = random.randf_range(35.0, 150.0)
		var points: PackedVector2Array = PackedVector2Array([
			start, start + Vector2(length * 0.5, -9), start + Vector2(length, -3)])
		draw_polyline(points, Color(0.9, 0.76, 0.52, 0.3), 2.0, true)
	# A visible darker perimeter corresponds to the static boundary bodies.
	draw_rect(arena_rect.grow(-12), Color("8c704c"), false, 24.0)
