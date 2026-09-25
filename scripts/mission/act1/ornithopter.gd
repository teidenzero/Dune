class_name Ornithopter
extends Node2D
## An Atreides ornithopter waiting on the rock: the way out. Drawn standing in
## the isometric view; a placeholder until its art is painted.

var label: String = "ORNITHOPTER"
var _flap: float = 0.0


func _ready() -> void:
	add_to_group("iso_sorted")


func _process(delta: float) -> void:
	_flap = fmod(_flap + delta * 2.0, TAU)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 6), 70.0, Color(0, 0, 0, 0.22))
	if IsoView.active:
		draw_set_transform_matrix(IsoView.upright())
	var droop: float = 4.0 * sin(_flap)
	# Folded wings, a long body, a canopy.
	draw_colored_polygon(PackedVector2Array([Vector2(-110, -40 + droop), Vector2(-10, -58), Vector2(-10, -46), Vector2(-100, -30 + droop)]), Color(0.42, 0.45, 0.4))
	draw_colored_polygon(PackedVector2Array([Vector2(110, -40 + droop), Vector2(10, -58), Vector2(10, -46), Vector2(100, -30 + droop)]), Color(0.36, 0.39, 0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(-70, -20), Vector2(60, -24), Vector2(80, -38), Vector2(-60, -44)]), Color(0.3, 0.36, 0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(30, -40), Vector2(70, -38), Vector2(60, -56), Vector2(36, -56)]), Color(0.55, 0.7, 0.78))
	draw_line(Vector2(-60, -18), Vector2(-60, 0), Color(0.2, 0.2, 0.18), 3.0)
	draw_line(Vector2(50, -22), Vector2(50, 0), Color(0.2, 0.2, 0.18), 3.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var font: Font = HudStyle.body_font(700)
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	IsoView.draw_text(self, font, Vector2.ZERO, Vector2(-width * 0.5, -90), label, 12, HudStyle.SPICE_BLUE, 3)
