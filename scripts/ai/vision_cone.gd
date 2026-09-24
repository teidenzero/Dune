class_name VisionCone
extends Node2D
## The Commandos read: an enemy's field of view, drawn on the ground, always -
## so "stay out of their cones" is an instruction the player can actually act on
## instead of a rule they have to infer.
##
## This is not a debug view. F1 draws paths, rays and numbers on top of it; this
## is the one the player is meant to plan against, so it never lies about the
## numbers perception is really using and it is cut short by walls.

@export var actor: EnemyCharacter
@export var perception: PerceptionComponent
@export var enabled: bool = true
## More segments is a smoother edge and one raycast each.
@export_range(6, 48, 1) var segments: int = 24
## Rebuilt on a timer rather than every frame: this is `segments` raycasts.
@export_range(2.0, 60.0, 1.0) var updates_per_second: float = 12.0
@export_range(0.0, 0.6, 0.01) var calm_fill_alpha: float = 0.20
## An alarmed cone should be harder to ignore than a bored one.
@export_range(0.0, 0.8, 0.01) var alarmed_fill_alpha: float = 0.38
@export_range(0.0, 1.0, 0.01) var edge_alpha: float = 0.75

## Environment only. Perception also lets characters block a sight line, but a
## guard-shaped bite taken out of the cone every time someone walks past reads
## as a glitch rather than as information.
const OCCLUDER_MASK: int = 1

## Draw order, owned here because the cone is the only thing that needs a band
## between the floor and the actors. Anything that is ground art - sand, paving,
## painted rock slabs - sits at GROUND_Z or below, or it will cover the cones.
const GROUND_Z: int = -10
const CONE_Z: int = -1

var _shape: PackedVector2Array = PackedVector2Array()
var _color: Color = DetectionIndicator.CALM
var _alarm: float = 0.0
var _wait: float = 0.0


func _ready() -> void:
	# Above the ground, below every actor, so it reads as painted on the sand.
	z_index = CONE_Z
	# Painted on the ground whatever depth its guard is drawn at.
	z_as_relative = false
	if actor == null:
		actor = get_parent() as EnemyCharacter
	if perception == null and is_instance_valid(actor):
		perception = actor.perception
	visible = false


## A cone is a claim that this guard can see. Nothing should draw one for a body,
## or for an observer whose perception has been switched off.
func should_draw() -> bool:
	if not enabled or not is_instance_valid(actor) or perception == null:
		return false
	if actor.health != null and actor.health.is_dead:
		return false
	return perception.is_physics_processing()


func _physics_process(delta: float) -> void:
	if not should_draw():
		if visible:
			visible = false
			queue_redraw()
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 1.0 / maxf(updates_per_second, 1.0)
	_rebuild()
	visible = true
	queue_redraw()


func _rebuild() -> void:
	var origin: Vector2 = actor.global_position
	var facing: float = perception.facing.global_rotation if is_instance_valid(perception.facing) else actor.global_rotation
	var half_fov: float = deg_to_rad(perception.field_of_view_degrees * 0.5)
	var reach: float = perception.vision_distance
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var exclude: Array[RID] = [actor.get_rid()]
	_shape = PackedVector2Array([to_local(origin)])
	for index in range(segments + 1):
		var angle: float = facing - half_fov + 2.0 * half_fov * index / float(segments)
		var far: Vector2 = origin + Vector2.RIGHT.rotated(angle) * reach
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, far, OCCLUDER_MASK, exclude)
		var hit: Dictionary = space.intersect_ray(query)
		_shape.append(to_local(hit.position if not hit.is_empty() else far))
	_color = DetectionIndicator.alert_color(actor)
	_alarm = clampf(perception.detection_value / maxf(perception.detection_max, 1.0), 0.0, 1.0)
	if _color == DetectionIndicator.DETECTED or _color == DetectionIndicator.ALERT:
		_alarm = 1.0


func _draw() -> void:
	if _shape.size() < 3:
		return
	var fill: Color = _color
	fill.a = lerpf(calm_fill_alpha, alarmed_fill_alpha, _alarm)
	draw_colored_polygon(_shape, fill)
	var edge: Color = _color
	edge.a = edge_alpha
	# Outline the arc and both flanks, so the boundary the player has to respect
	# is a line rather than the place a gradient happens to fade out.
	for index in range(1, _shape.size()):
		draw_line(_shape[index - 1], _shape[index], edge, 1.5)
	draw_line(_shape[_shape.size() - 1], _shape[0], edge, 1.5)
