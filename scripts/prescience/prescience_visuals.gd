extends Node2D
## Draws the projected futures.
##
## One drawing node rather than a spawned ghost scene per sample: there is
## nothing to leak, so "no ghost objects remain when prescience ends" is true by
## construction rather than by careful cleanup.
##
## Everything is sized in screen pixels and converted through the camera zoom,
## so the future reads the same at any zoom, and every stroke sits on a dark
## outline so it stands out on pale sand.

@export var controller: PrescienceController

const HOSTILE: Color = Color(0.3, 0.72, 1.0)
const FRIENDLY: Color = Color(0.45, 1.0, 0.65)
const FIRE: Color = Color(1.0, 0.45, 0.3)
## A plan waiting for the signal, and a plan that would be seen.
const PLANNED: Color = Color(1.0, 0.82, 0.4)
const SEEN: Color = Color(1.0, 0.3, 0.25)
const OUTLINE: Color = Color(0.03, 0.05, 0.1, 0.85)

var _flicker: float = 0.0
var _px: float = 1.0


func _ready() -> void:
	z_index = 6
	# On the ground under the figures, whatever depth Paul is drawn at.
	z_as_relative = false


func _process(delta: float) -> void:
	_flicker = fmod(_flicker + TimeScaleManager.unscaled(delta), TAU)
	queue_redraw()


func _draw() -> void:
	if controller == null or not controller.active:
		return
	# World units per screen pixel at the current zoom.
	_px = 1.0 / maxf(get_canvas_transform().get_scale().x, 0.05)
	var font: Font = ThemeDB.fallback_font
	var debug: bool = _debug_visible()
	for projection: FuturePredictor.FutureTrack in controller.projections:
		if not is_instance_valid(projection.actor):
			continue
		var tint: Color = FRIENDLY if projection.friendly else HOSTILE
		if projection.planned:
			tint = PLANNED
		if debug:
			_draw_full_path(projection, tint)
		if not projection.friendly:
			_draw_future_cone(projection, tint)
		if projection.planned:
			_draw_plan_route(projection, font)
		else:
			_draw_thread(projection, tint)
		for index in range(projection.positions.size()):
			var seen: bool = projection.planned and projection.seen_at >= 0 and index >= projection.seen_at
			_draw_ghost(projection, index, SEEN if seen else tint, font)
		if projection.fires:
			_draw_fire(projection, font)


## A plan's whole route: gold while it is clear, red from the moment a guard
## would see it, with that moment marked - and the guard's cone as it would be
## then, so the player sees who.
func _draw_plan_route(projection: FuturePredictor.FutureTrack, font: Font) -> void:
	var route: PackedVector2Array = projection.path
	if route.size() < 2:
		return
	var seen: bool = projection.seen_time >= 0.0
	var split: float = projection.speed * projection.seen_time if seen else INF
	var clear: PackedVector2Array = [to_local(route[0])]
	var danger: PackedVector2Array = []
	var walked: float = 0.0
	for index in range(1, route.size()):
		var a: Vector2 = route[index - 1]
		var b: Vector2 = route[index]
		var length: float = a.distance_to(b)
		if danger.is_empty() and walked + length >= split:
			var cut: Vector2 = a.lerp(b, clampf((split - walked) / maxf(length, 0.001), 0.0, 1.0))
			clear.append(to_local(cut))
			danger.append(to_local(cut))
			danger.append(to_local(b))
		elif danger.is_empty():
			clear.append(to_local(b))
		else:
			danger.append(to_local(b))
		walked += length
	if clear.size() >= 2:
		draw_polyline(clear, OUTLINE, 7.0 * _px, true)
		draw_polyline(clear, Color(PLANNED, 0.9), 3.5 * _px, true)
	if danger.size() >= 2:
		draw_polyline(danger, OUTLINE, 7.0 * _px, true)
		draw_polyline(danger, Color(SEEN, 0.95), 3.5 * _px, true)
	if not seen:
		return
	# Who sees him: the guard where he will be, his cone the way he will face.
	var guard: EnemyCharacter = projection.seen_guard
	if is_instance_valid(guard):
		var origin: Vector2 = to_local(projection.seen_by)
		var half: float = deg_to_rad(guard.perception.field_of_view_degrees) * 0.5
		var facing: float = projection.seen_facing.angle()
		var cone: PackedVector2Array = [origin]
		for step in range(17):
			cone.append(origin + Vector2.from_angle(facing - half + half * 2.0 * step / 16.0) * guard.perception.vision_distance)
		cone.append(origin)
		draw_colored_polygon(cone, Color(SEEN, 0.12))
		draw_polyline(cone, Color(SEEN, 0.6), 2.0 * _px, true)
		draw_circle(origin, 12.0 * _px, Color(SEEN, 0.5))
	var at: Vector2 = to_local(projection.seen_point)
	draw_arc(at, 24.0 * _px, 0, TAU, 28, OUTLINE, 6.0 * _px, true)
	draw_arc(at, 24.0 * _px, 0, TAU, 28, SEEN, 3.0 * _px, true)
	var size: int = maxi(int(round(17.0 * _px)), 1)
	var label: String = "SEEN +%.1fs" % projection.seen_time
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	IsoView.draw_text(self, font, at, Vector2(-width * 0.5, -30.0 * _px), label, size, SEEN, maxi(int(5.0 * _px), 1), OUTLINE)


## A thick line from the actor through each sample, on a dark outline, so the
## order of the ghosts reads as one path.
func _draw_thread(projection: FuturePredictor.FutureTrack, tint: Color) -> void:
	var points: PackedVector2Array = [to_local(projection.actor.global_position)]
	for point in projection.positions:
		points.append(to_local(point))
	if points.size() < 2:
		return
	draw_polyline(points, OUTLINE, 7.0 * _px, true)
	draw_polyline(points, Color(tint, 0.55 + 0.35 * projection.certainty), 3.5 * _px, true)


func _draw_full_path(projection: FuturePredictor.FutureTrack, tint: Color) -> void:
	for index in range(1, projection.path.size()):
		draw_line(to_local(projection.path[index - 1]), to_local(projection.path[index]), Color(tint, 0.35), 1.5 * _px)


## Each ghost is a ring with a chevron pointing the way he will be walking.
## Later ghosts are smaller and fainter; uncertain futures jitter and widen.
func _draw_ghost(projection: FuturePredictor.FutureTrack, index: int, tint: Color, font: Font, seen_here: bool = false) -> void:
	var offsets: PackedFloat32Array = controller.projection_offsets
	var seconds: float = offsets[index] if index < offsets.size() else float(index + 1)
	var span: float = maxf(offsets[offsets.size() - 1], 1.0)
	var age: float = clampf(seconds / span, 0.0, 1.0)
	var certainty: float = clampf(projection.certainty, 0.05, 1.0)
	var alpha: float = (1.0 - 0.35 * age) * (0.45 + 0.55 * certainty)
	var radius: float = (20.0 - 5.0 * age) * _px
	var wobble: float = (1.0 - certainty) * 8.0 * _px
	var jitter: Vector2 = Vector2(sin(_flicker * 3.1 + index), cos(_flicker * 2.7 + index)) * wobble
	var point: Vector2 = to_local(projection.positions[index]) + jitter
	draw_circle(point, radius, Color(tint, alpha * 0.3))
	draw_arc(point, radius, 0, TAU, 28, OUTLINE, 5.0 * _px, true)
	draw_arc(point, radius, 0, TAU, 28, Color(tint, alpha), 2.5 * _px, true)
	if certainty < 0.95:
		draw_arc(point, radius + wobble + 4.0 * _px, 0, TAU, 28, Color(tint, alpha * 0.4), 1.5 * _px, true)
	var heading: Vector2 = _heading(projection, index)
	if heading != Vector2.ZERO:
		var tip: Vector2 = point + heading * radius * 0.7
		var side: Vector2 = heading.orthogonal() * radius * 0.45
		var back: Vector2 = point - heading * radius * 0.15
		var chevron: PackedVector2Array = [back + side, tip, back - side]
		draw_polyline(chevron, OUTLINE, 5.0 * _px, true)
		draw_polyline(chevron, Color(tint, alpha), 2.5 * _px, true)
	var size: int = maxi(int(round(15.0 * _px)), 1)
	var label: String = "+%ds" % int(roundf(seconds))
	if seen_here:
		label = "SEEN +%ds" % int(roundf(seconds))
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	IsoView.draw_text(self, font, point, Vector2(-width * 0.5, -radius - 6.0 * _px), label, size, Color(tint.lightened(0.35), alpha), maxi(int(4.0 * _px), 1), OUTLINE)


## Where he will be looking at the last sample: his real cone, placed at his
## future position and turned the way he will be walking.
func _draw_future_cone(projection: FuturePredictor.FutureTrack, tint: Color) -> void:
	var enemy: EnemyCharacter = projection.actor as EnemyCharacter
	if enemy == null or projection.positions.is_empty():
		return
	var last: int = projection.positions.size() - 1
	var heading: Vector2 = _heading(projection, last)
	if heading == Vector2.ZERO:
		heading = Vector2.RIGHT.rotated(enemy.aim_pivot.global_rotation)
	var reach: float = enemy.perception.vision_distance
	var half: float = deg_to_rad(enemy.perception.field_of_view_degrees) * 0.5
	var origin: Vector2 = to_local(projection.positions[last])
	var facing: float = heading.angle()
	var points: PackedVector2Array = [origin]
	for step in range(17):
		points.append(origin + Vector2.from_angle(facing - half + half * 2.0 * step / 16.0) * reach)
	points.append(origin)
	draw_colored_polygon(points, Color(tint, 0.1))
	draw_polyline(points, Color(tint, 0.55), 2.0 * _px, true)


## Direction of travel at sample `index`: from the previous sample (or the
## actor) toward this one.
func _heading(projection: FuturePredictor.FutureTrack, index: int) -> Vector2:
	var from: Vector2 = projection.actor.global_position if index == 0 else projection.positions[index - 1]
	var to: Vector2 = projection.positions[index]
	if from.distance_squared_to(to) < 4.0:
		return Vector2.ZERO
	return from.direction_to(to)


## One readable trajectory, not a cloud of future bullets.
func _draw_fire(projection: FuturePredictor.FutureTrack, font: Font) -> void:
	var from: Vector2 = to_local(projection.fire_from)
	var to: Vector2 = to_local(projection.fire_to)
	var direction: Vector2 = from.direction_to(to)
	var travelled: float = 0.0
	var length: float = from.distance_to(to)
	var dash: float = 18.0 * _px
	var gap: float = 12.0 * _px
	while travelled < length:
		var end: float = minf(travelled + dash, length)
		draw_line(from + direction * travelled, from + direction * end, OUTLINE, 6.0 * _px)
		draw_line(from + direction * travelled, from + direction * end, Color(FIRE, 0.9), 3.0 * _px)
		travelled = end + gap
	var head: Vector2 = to - direction * 12.0 * _px
	draw_colored_polygon(PackedVector2Array([
		to, head + direction.orthogonal() * 7.0 * _px, head - direction.orthogonal() * 7.0 * _px]), Color(FIRE, 0.95))
	var size: int = maxi(int(round(15.0 * _px)), 1)
	var label: String = "%s +%.1fs" % [projection.strike_label, projection.fire_delay]
	var at: Vector2 = from + Vector2(10, -12) * _px
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(int(4.0 * _px), 1), OUTLINE)
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, FIRE)


func _debug_visible() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	return manager != null and manager.debug_visible
