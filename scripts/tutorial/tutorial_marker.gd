class_name TutorialMarker
extends Node2D
## One reusable marker for destinations, order targets, checkpoints, and actor
## highlights. Parent it to an actor to highlight that actor; leave it standing
## in the level to mark a place. Only the current step's markers are drawn.

@export var radius: float = 42.0
@export var label: String = ""
@export var color: Color = Color(0.95, 0.82, 0.45)
## Markers start hidden; TutorialManager activates the current step's markers.
@export var active: bool = false

var _pulse: float = 0.0


func _ready() -> void:
	add_to_group("tutorial_markers")
	z_index = 1


func set_active(value: bool) -> void:
	active = value
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return
	_pulse = fmod(_pulse + delta, TAU)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var swell: float = 1.0 + 0.12 * sin(_pulse * 2.4)
	draw_arc(Vector2.ZERO, radius * swell, 0, TAU, 40, Color(color, 0.85), 3.0, true)
	draw_arc(Vector2.ZERO, radius * 0.62, 0, TAU, 32, Color(color, 0.35), 2.0, true)
	# A downward chevron reads as "here" without needing colour alone.
	var tip: float = -radius - 12.0 - 5.0 * sin(_pulse * 2.4)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, tip + 16.0), Vector2(-9, tip), Vector2(9, tip)]), Color(color, 0.9))
	if label != "":
		var font: Font = ThemeDB.fallback_font
		var size: int = WorldLabel.font_size(self, 13)
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var point: Vector2 = Vector2(-width * 0.5, radius + 22.0)
		draw_string_outline(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.06, 0.07, 0.09))
		draw_string(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, 0.95))
