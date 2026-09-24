class_name OffscreenIndicators
extends Control
## An arrow at the screen edge for every Fremen in trouble out of view - hit,
## fighting on his own - pointing the way, with his number. Click-through.

## Kept clear of the HUD: the title at the top, cards and action bar below.
const MARGIN_TOP: float = 120.0
const MARGIN_BOTTOM: float = 250.0
const MARGIN_SIDE: float = 50.0

var squad: SquadManager


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Where each alerted Fremen off-screen is pointed at: {ally: edge point}.
func indicated() -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(squad):
		return result
	var view: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var world_to_screen: Transform2D = get_viewport().get_canvas_transform()
	var inner: Rect2 = Rect2(Vector2(MARGIN_SIDE, MARGIN_TOP), view.size - Vector2(MARGIN_SIDE * 2.0, MARGIN_TOP + MARGIN_BOTTOM))
	var center: Vector2 = view.get_center()
	for ally in squad.members:
		if not is_instance_valid(ally) or not ally.alert_active():
			continue
		var screen: Vector2 = world_to_screen * ally.global_position
		if view.has_point(screen):
			continue
		result[ally] = _edge_point(center, screen, inner)
	return result


## Where the line from the centre toward `target` leaves `box`.
func _edge_point(center: Vector2, target: Vector2, box: Rect2) -> Vector2:
	var direction: Vector2 = center.direction_to(target)
	var scale_x: float = INF if is_zero_approx(direction.x) else ((box.end.x if direction.x > 0 else box.position.x) - center.x) / direction.x
	var scale_y: float = INF if is_zero_approx(direction.y) else ((box.end.y if direction.y > 0 else box.position.y) - center.y) / direction.y
	return center + direction * minf(scale_x, scale_y)


func _draw() -> void:
	var font: Font = HudStyle.body_font(700)
	var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 110.0)
	var center: Vector2 = get_viewport_rect().size * 0.5
	var marks: Dictionary = indicated()
	for ally: AllyCharacter in marks:
		var at: Vector2 = marks[ally]
		var direction: Vector2 = center.direction_to(at)
		var tip: Vector2 = at + direction * 22.0
		var side: Vector2 = direction.orthogonal() * 14.0
		var arrow: PackedVector2Array = [tip, at + side, at - side]
		draw_colored_polygon(arrow, Color(HudStyle.DANGER, pulse))
		draw_circle(at - direction * 18.0, 17.0, Color(HudStyle.PANEL, 0.92))
		draw_arc(at - direction * 18.0, 17.0, 0, TAU, 24, Color(HudStyle.DANGER, pulse), 2.0, true)
		var number: String = str(ally.selection_slot)
		var width: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, at - direction * 18.0 + Vector2(-width * 0.5, 6), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, HudStyle.TEXT)
		var label: String = ally.alert_text
		var label_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var label_at: Vector2 = at - direction * 48.0 + Vector2(-label_width * 0.5, 5)
		draw_string_outline(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HudStyle.DANGER)
