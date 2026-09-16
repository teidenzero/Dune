class_name WormApproachEvent
extends Node2D
## The spectacle: a ridge of displaced sand travelling toward whatever the
## desert committed to, then an eruption.
##
## It carries no mission knowledge - it announces `erupted` and `finished` and
## lets the threat manager and, later, a mission decide what that means.

signal erupted(position: Vector2, radius: float)
signal finished

enum Phase { IDLE, TRAVEL, ERUPT, SUBSIDE }

## Where the ridge surfaces from, relative to the target.
@export var approach_distance: float = 1500.0
@export var travel_speed: float = 420.0
@export var erupt_seconds: float = 2.6
@export var subside_seconds: float = 1.6
@export var ridge_length: float = 220.0
@export var ridge_width: float = 62.0
@export var maw_radius: float = 150.0

var phase: Phase = Phase.IDLE
var target: Vector2 = Vector2.INF
var origin: Vector2 = Vector2.INF
var position_on_path: Vector2 = Vector2.INF
var danger_radius: float = 260.0
var phase_time: float = 0.0
var _ripple: float = 0.0


func _ready() -> void:
	z_index = 3


func begin(point: Vector2, radius: float) -> void:
	if phase != Phase.IDLE or not point.is_finite():
		return
	target = point
	danger_radius = radius
	# Arrive from open desert rather than through whatever is behind the player.
	var bearing: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	origin = target + bearing * approach_distance
	position_on_path = origin
	phase = Phase.TRAVEL
	phase_time = 0.0


## Cuts the approach short and surfaces now; the threat reached its threshold.
func erupt() -> void:
	if phase == Phase.IDLE or phase == Phase.ERUPT or phase == Phase.SUBSIDE:
		return
	position_on_path = target
	phase = Phase.ERUPT
	phase_time = 0.0
	erupted.emit(target, danger_radius)


func cancel() -> void:
	if phase == Phase.IDLE:
		return
	phase = Phase.IDLE
	phase_time = 0.0
	target = Vector2.INF
	origin = Vector2.INF
	position_on_path = Vector2.INF
	queue_redraw()


func erupting() -> bool:
	return phase == Phase.ERUPT or phase == Phase.SUBSIDE


func active() -> bool:
	return phase != Phase.IDLE


func travel_ratio() -> float:
	if not origin.is_finite() or not target.is_finite():
		return 0.0
	var total: float = origin.distance_to(target)
	return 1.0 if total <= 1.0 else clampf(1.0 - position_on_path.distance_to(target) / total, 0.0, 1.0)


## Seconds until the ridge reaches its target at the current rate.
func eta() -> float:
	if phase != Phase.TRAVEL:
		return 0.0
	return position_on_path.distance_to(target) / maxf(travel_speed, 1.0)


func _physics_process(delta: float) -> void:
	_ripple = fmod(_ripple + delta * 3.0, TAU)
	if phase == Phase.IDLE:
		return
	phase_time += delta
	match phase:
		Phase.TRAVEL:
			position_on_path = position_on_path.move_toward(target, travel_speed * delta)
			if position_on_path.distance_to(target) <= 1.0:
				erupt()
		Phase.ERUPT:
			if phase_time >= erupt_seconds:
				phase = Phase.SUBSIDE
				phase_time = 0.0
		Phase.SUBSIDE:
			if phase_time >= subside_seconds:
				cancel()
				finished.emit()
	queue_redraw()


func _draw() -> void:
	if phase == Phase.IDLE:
		return
	match phase:
		Phase.TRAVEL:
			_draw_ridge()
		Phase.ERUPT:
			_draw_eruption(clampf(phase_time / maxf(erupt_seconds, 0.1), 0.0, 1.0))
		Phase.SUBSIDE:
			_draw_settling(clampf(phase_time / maxf(subside_seconds, 0.1), 0.0, 1.0))


## A long swell of displaced sand with a wake, so the direction it comes from
## is readable from across the field.
func _draw_ridge() -> void:
	var heading: Vector2 = origin.direction_to(target)
	var centre: Vector2 = to_local(position_on_path)
	var along: Vector2 = heading * ridge_length * 0.5
	var across: Vector2 = heading.orthogonal() * ridge_width * 0.5
	draw_colored_polygon(PackedVector2Array([
		centre + along, centre + across * 0.7, centre - along * 0.8, centre - across * 0.7,
	]), Color(0.78, 0.63, 0.40, 0.85))
	draw_colored_polygon(PackedVector2Array([
		centre + along * 0.9, centre + across * 0.4, centre - along * 0.5, centre - across * 0.4,
	]), Color(0.90, 0.78, 0.55, 0.9))
	for index in range(5):
		var back: float = float(index + 1)
		var point: Vector2 = centre - heading * (ridge_length * 0.6 + back * 70.0)
		var swell: float = ridge_width * (0.9 - back * 0.13) * (0.85 + 0.15 * sin(_ripple + back))
		draw_arc(point, maxf(swell, 4.0), 0, TAU, 20, Color(0.82, 0.70, 0.48, 0.45 - back * 0.07), 3.0, true)
	draw_line(centre, to_local(target), Color(0.85, 0.72, 0.5, 0.25), 2.0)


## Scale over fidelity: a huge dark maw and a wall of dust, no worm artwork.
func _draw_eruption(progress: float) -> void:
	var centre: Vector2 = to_local(target)
	var rise: float = sin(clampf(progress, 0.0, 1.0) * PI)
	var radius: float = maw_radius * (0.35 + 0.65 * rise)
	draw_circle(centre, danger_radius, Color(0.72, 0.58, 0.38, 0.22 * rise))
	for index in range(3):
		var ring: float = danger_radius * (0.5 + 0.25 * index) * (0.7 + 0.3 * rise)
		draw_arc(centre, ring, 0, TAU, 44, Color(0.88, 0.76, 0.54, 0.35 * rise), 4.0, true)
	draw_circle(centre, radius * 1.25, Color(0.24, 0.18, 0.14, 0.75 * rise))
	draw_circle(centre, radius, Color(0.09, 0.07, 0.07, 0.95 * rise))
	# A ring of teeth reads as enormous without drawing a creature.
	for index in range(14):
		var angle: float = TAU * index / 14.0
		var base: Vector2 = centre + Vector2.RIGHT.rotated(angle) * radius
		var tip: Vector2 = centre + Vector2.RIGHT.rotated(angle) * (radius * 1.34)
		var side: Vector2 = Vector2.RIGHT.rotated(angle).orthogonal() * radius * 0.11
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(0.86, 0.80, 0.68, 0.9 * rise))


func _draw_settling(progress: float) -> void:
	var centre: Vector2 = to_local(target)
	var fade: float = 1.0 - progress
	draw_circle(centre, maw_radius * (1.0 + progress * 0.8), Color(0.72, 0.60, 0.42, 0.35 * fade))
	draw_arc(centre, danger_radius * (0.8 + progress * 0.3), 0, TAU, 44, Color(0.85, 0.74, 0.55, 0.3 * fade), 3.0, true)
