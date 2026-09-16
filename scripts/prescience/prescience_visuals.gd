extends Node2D
## Draws the projected futures.
##
## One drawing node rather than a spawned ghost scene per sample: there is
## nothing to leak, so "no ghost objects remain when prescience ends" is true by
## construction rather than by careful cleanup.

@export var controller: PrescienceController

const HOSTILE: Color = Color(0.72, 0.86, 1.0)
const FRIENDLY: Color = Color(0.65, 1.0, 0.82)
const FIRE: Color = Color(1.0, 0.55, 0.42)

var _flicker: float = 0.0


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	_flicker = fmod(_flicker + TimeScaleManager.unscaled(delta), TAU)
	queue_redraw()


func _draw() -> void:
	if controller == null or not controller.active:
		return
	var font: Font = ThemeDB.fallback_font
	var debug: bool = _debug_visible()
	for projection: FuturePredictor.FutureTrack in controller.projections:
		if not is_instance_valid(projection.actor):
			continue
		var tint: Color = FRIENDLY if projection.friendly else HOSTILE
		_draw_thread(projection, tint)
		if debug:
			_draw_full_path(projection, tint)
		for index in range(projection.positions.size()):
			_draw_ghost(projection, index, tint, font)
		if projection.fires:
			_draw_fire(projection, font)


## A line from the actor through each sample, so the order of the ghosts reads
## as a sequence rather than three unrelated shapes.
func _draw_thread(projection: FuturePredictor.FutureTrack, tint: Color) -> void:
	var previous: Vector2 = to_local(projection.actor.global_position)
	for point in projection.positions:
		var next: Vector2 = to_local(point)
		draw_line(previous, next, Color(tint, 0.25 * projection.certainty + 0.12), 1.5)
		previous = next


func _draw_full_path(projection: FuturePredictor.FutureTrack, tint: Color) -> void:
	for index in range(1, projection.path.size()):
		draw_line(to_local(projection.path[index - 1]), to_local(projection.path[index]), Color(tint, 0.35), 1.0)


## Each ghost fades and shrinks with distance in time, and low-certainty
## projections jitter and widen so uncertainty reads without a percentage.
func _draw_ghost(projection: FuturePredictor.FutureTrack, index: int, tint: Color, font: Font) -> void:
	var offsets: PackedFloat32Array = controller.projection_offsets
	var seconds: float = offsets[index] if index < offsets.size() else float(index + 1)
	var span: float = maxf(offsets[offsets.size() - 1], 1.0)
	var age: float = clampf(seconds / span, 0.0, 1.0)
	var certainty: float = clampf(projection.certainty, 0.05, 1.0)
	var alpha: float = (0.85 - 0.4 * age) * certainty
	var radius: float = 17.0 - 4.0 * age
	var wobble: float = (1.0 - certainty) * 6.0
	var jitter: Vector2 = Vector2(sin(_flicker * 3.1 + index), cos(_flicker * 2.7 + index)) * wobble
	var point: Vector2 = to_local(projection.positions[index]) + jitter
	# Silhouette, then a widening ring for anything the AI might still change.
	draw_circle(point, radius, Color(tint, alpha * 0.35))
	draw_arc(point, radius, 0, TAU, 24, Color(tint, alpha), 2.0, true)
	if certainty < 0.95:
		draw_arc(point, radius + wobble + 3.0, 0, TAU, 24, Color(tint, alpha * 0.3), 1.0, true)
	var label: String = "+%ds" % int(roundf(seconds))
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(font, point + Vector2(-width * 0.5, -radius - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.04, 0.06, 0.09, alpha))
	draw_string(font, point + Vector2(-width * 0.5, -radius - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(tint, alpha))


## One readable trajectory, not a cloud of future bullets.
func _draw_fire(projection: FuturePredictor.FutureTrack, font: Font) -> void:
	var from: Vector2 = to_local(projection.fire_from)
	var to: Vector2 = to_local(projection.fire_to)
	var direction: Vector2 = from.direction_to(to)
	var travelled: float = 0.0
	var length: float = from.distance_to(to)
	while travelled < length:
		var end: float = minf(travelled + 18.0, length)
		draw_line(from + direction * travelled, from + direction * end, Color(FIRE, 0.75), 2.0)
		travelled = end + 12.0
	var head: Vector2 = to - direction * 10.0
	draw_colored_polygon(PackedVector2Array([
		to, head + direction.orthogonal() * 6.0, head - direction.orthogonal() * 6.0]), Color(FIRE, 0.85))
	var label: String = "FIRES +%.1fs" % projection.fire_delay
	draw_string_outline(font, from + Vector2(10, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.05, 0.03, 0.03))
	draw_string(font, from + Vector2(10, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, FIRE)


func _debug_visible() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	return manager != null and manager.debug_visible
