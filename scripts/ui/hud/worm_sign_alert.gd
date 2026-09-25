class_name WormSignAlert
extends Control
## The moment a worm commits: a big WORM SIGN! across the screen, with an
## arrow from the centre toward the ridge and its arrival time. While the
## ridge travels off-screen, an arrow at the screen edge keeps pointing at it;
## on screen, a ring marks it. A worm turned by a thumper announces itself as
## turning. Click-through; made by the worm warning director on every map
## that has a worm.

## Kept clear of the HUD, as the squad's edge arrows are.
const MARGIN_TOP: float = 130.0
const MARGIN_BOTTOM: float = 250.0
const MARGIN_SIDE: float = 60.0
const BANNER_SECONDS: float = 3.5

var manager: WormThreatManager
var headline: String = ""
var _banner_left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Paused to plan, the player still sees where it is coming from.
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(threat: WormThreatManager) -> void:
	manager = threat
	manager.worm_approach_started.connect(_on_approach)


func _on_approach(_target: Vector2) -> void:
	# A worm already travelling that changes course was turned (a thumper).
	var turning: bool = manager.event != null and manager.event.phase == WormApproachEvent.Phase.TRAVEL
	announce("THE WORM TURNS" if turning else "WORM SIGN!")


func announce(text: String) -> void:
	headline = text
	_banner_left = BANNER_SECONDS


func banner_visible() -> bool:
	return _banner_left > 0.0


## The ridge while it travels, or INF.
func ridge() -> Vector2:
	if not is_instance_valid(manager) or manager.event == null or manager.event.phase != WormApproachEvent.Phase.TRAVEL:
		return Vector2.INF
	return manager.event.position_on_path


func _process(delta: float) -> void:
	# Real time: a paused or slowed world still shows the warning out.
	_banner_left = maxf(_banner_left - TimeScaleManager.unscaled(delta), 0.0)
	queue_redraw()


func _draw() -> void:
	var at: Vector2 = ridge()
	if not at.is_finite():
		if banner_visible():
			_draw_banner(Vector2.INF)
		return
	var view: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var screen: Vector2 = get_viewport().get_canvas_transform() * at
	if banner_visible():
		_draw_banner(screen)
	var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
	var font: Font = HudStyle.body_font(800)
	var eta: String = "WORM  %ds" % ceili(manager.event.eta())
	if view.grow(-20.0).has_point(screen):
		# On screen: a ring over the ridge.
		draw_arc(screen, 46.0, 0, TAU, 36, Color(HudStyle.DANGER, pulse), 3.0, true)
		_text(font, screen + Vector2(0, -58), eta, 15, HudStyle.DANGER)
		return
	var inner: Rect2 = Rect2(Vector2(MARGIN_SIDE, MARGIN_TOP), view.size - Vector2(MARGIN_SIDE * 2.0, MARGIN_TOP + MARGIN_BOTTOM))
	var center: Vector2 = view.get_center()
	var edge: Vector2 = _edge_point(center, screen, inner)
	var direction: Vector2 = center.direction_to(screen)
	_arrow(edge, direction, 30.0, Color(HudStyle.DANGER, pulse))
	_text(font, edge - direction * 44.0, eta, 15, HudStyle.DANGER)


func _draw_banner(screen: Vector2) -> void:
	var size: Vector2 = get_viewport_rect().size
	var fade: float = clampf(_banner_left / 0.6, 0.0, 1.0) * clampf((BANNER_SECONDS - _banner_left) / 0.2, 0.0, 1.0)
	var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 90.0)
	var middle: Vector2 = Vector2(size.x * 0.5, size.y * 0.36)
	draw_rect(Rect2(Vector2(0, middle.y - 70), Vector2(size.x, 150)), Color(0, 0, 0, 0.45 * fade))
	var font: Font = HudStyle.display_font()
	_text(font, middle + Vector2(0, 10), headline, 72, Color(HudStyle.DANGER, fade * pulse), 8)
	if not screen.is_finite():
		return
	var small: Font = HudStyle.body_font(700)
	_text(small, middle + Vector2(0, 50), "ARRIVES IN %d SECONDS  ·  GET OFF THE OPEN SAND" % ceili(manager.event.eta()), 18, Color(HudStyle.TEXT, fade))
	# The big arrow, inside the banner beside the headline: toward where it comes from.
	var half: float = font.get_string_size(headline, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x * 0.5
	var anchor: Vector2 = middle + Vector2(half + 90.0, -14.0)
	var direction: Vector2 = anchor.direction_to(screen)
	draw_circle(anchor, 52.0, Color(0, 0, 0, 0.35 * fade))
	_arrow(anchor - direction * 26.0, direction, 56.0, Color(HudStyle.DANGER, fade * pulse))


func _arrow(at: Vector2, direction: Vector2, length: float, color: Color) -> void:
	var side: Vector2 = direction.orthogonal()
	var tip: Vector2 = at + direction * length
	draw_colored_polygon(PackedVector2Array([tip, at + side * length * 0.55, at + direction * length * 0.25, at - side * length * 0.55]), color)
	draw_polyline(PackedVector2Array([tip, at + side * length * 0.55, at + direction * length * 0.25, at - side * length * 0.55, tip]), Color(0, 0, 0, color.a * 0.7), 2.0, true)


func _text(font: Font, center: Vector2, text: String, size: int, color: Color, outline: int = 4) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at: Vector2 = center + Vector2(-width * 0.5, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.85 * color.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Where the line from the centre toward `target` leaves `box`.
func _edge_point(center: Vector2, target: Vector2, box: Rect2) -> Vector2:
	var direction: Vector2 = center.direction_to(target)
	var scale_x: float = INF if is_zero_approx(direction.x) else ((box.end.x if direction.x > 0 else box.position.x) - center.x) / direction.x
	var scale_y: float = INF if is_zero_approx(direction.y) else ((box.end.y if direction.y > 0 else box.position.y) - center.y) / direction.y
	return center + direction * minf(scale_x, scale_y)
