class_name TutorialMarker
extends Node2D
## One reusable marker for destinations, order targets, checkpoints, and actor
## highlights. Parent it to an actor to highlight that actor; leave it standing
## in the level to mark a place. Only the current step's markers are drawn.

@export var radius: float = 42.0
@export var label: String = ""
## Spice blue by default: it has to stand out on sand and on rock.
@export var color: Color = Color(0.3, 0.8, 1.0)
## Markers start hidden; TutorialManager activates the current step's markers.
@export var active: bool = false

var _pulse: float = 0.0


## Height of the beacon above a place marker in the isometric view.
const BEACON: float = 96.0


func _ready() -> void:
	add_to_group("tutorial_markers")
	z_index = 1
	# In the isometric view a marker is sorted by depth like any figure, and
	# walls in front of an active one turn see-through (IsoView).
	add_to_group("iso_sorted")
	z_as_relative = false


## A highlight rides on an actor; a place marker stands on the ground.
func is_highlight() -> bool:
	return not (get_parent() is Node2D) or get_parent().name != "Markers"


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
	# On the ground: a dark rim under the ring so it reads on pale sand.
	draw_arc(Vector2.ZERO, radius * swell, 0, TAU, 40, Color(0.04, 0.08, 0.14, 0.55), 7.0, true)
	draw_arc(Vector2.ZERO, radius * swell, 0, TAU, 40, Color(color, 0.95), 3.5, true)
	draw_arc(Vector2.ZERO, radius * 0.62, 0, TAU, 32, Color(color, 0.45), 2.0, true)
	if IsoView.active:
		_draw_standing(swell)
		return
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


## The isometric view: a beacon that stands up off the ground - a column of
## light and a floating diamond over a place, a diamond over a highlighted
## figure's head - with the label upright above it.
func _draw_standing(swell: float) -> void:
	draw_set_transform_matrix(IsoView.upright())
	var bob: float = 6.0 * sin(_pulse * 2.4)
	var outline: Color = Color(0.04, 0.08, 0.14, 0.85)
	var top: float = -(BEACON if not is_highlight() else 150.0) - bob
	if not is_highlight():
		# The column: bright at the foot, fading as it rises.
		var steps: int = 8
		for index in range(steps):
			var a: float = -BEACON * index / steps
			var b: float = -BEACON * (index + 1) / steps
			var alpha: float = 0.55 * (1.0 - float(index) / steps)
			draw_rect(Rect2(Vector2(-4, b), Vector2(8, a - b)), Color(color, alpha))
		draw_line(Vector2.ZERO, Vector2(0, -BEACON), Color(color, 0.9), 1.5)
	var diamond: PackedVector2Array = [Vector2(0, top - 16), Vector2(11, top), Vector2(0, top + 16), Vector2(-11, top)]
	var ring: PackedVector2Array = diamond.duplicate()
	ring.append(diamond[0])
	draw_colored_polygon(diamond, Color(color, 0.95))
	draw_polyline(ring, outline, 2.5, true)
	if label != "":
		var font: Font = HudStyle.body_font(700)
		var size: int = 15
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var point: Vector2 = Vector2(-width * 0.5, top - 26.0)
		draw_string_outline(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, outline)
		draw_string(font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.lightened(0.3), 1.0))
	draw_set_transform_matrix(Transform2D.IDENTITY)
