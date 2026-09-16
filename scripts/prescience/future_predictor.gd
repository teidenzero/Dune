class_name FuturePredictor
extends RefCounted
## Read-only short-term prediction.
##
## It never simulates the game forward and never touches an actor or its
## NavigationAgent. It reads the intent the AI has *already* committed to - the
## current navigation path, the patrol route, the weapon cooldown - and walks
## that intent forward on paper. Prescience visualises a decision that has been
## made, it does not compute a new one.

## Presentational confidence, not statistics: it tells the player how settled
## the enemy's intent is, nothing more.
const ENEMY_CERTAINTY: Dictionary = {
	EnemyAIController.State.PATROL: 1.0,
	EnemyAIController.State.RETURN: 0.9,
	EnemyAIController.State.INVESTIGATE: 0.85,
	EnemyAIController.State.SUSPICIOUS: 0.9,
	EnemyAIController.State.SEARCH: 0.65,
	EnemyAIController.State.COMBAT: 0.55,
}
const ALLY_CERTAINTY: Dictionary = {
	AllyAIController.Order.HOLD: 1.0,
	AllyAIController.Order.MOVE_TO: 0.95,
	AllyAIController.Order.FOLLOW: 0.8,
	AllyAIController.Order.ATTACK: 0.6,
}


## One actor's projected near future. `positions` holds one entry per requested
## offset; `fires` is only ever true for an enemy already shooting at something.
class FutureTrack extends RefCounted:
	var actor: Node2D
	var friendly: bool = false
	var state_name: String = "UNKNOWN"
	var certainty: float = 1.0
	var positions: PackedVector2Array = PackedVector2Array()
	var path: PackedVector2Array = PackedVector2Array()
	var fires: bool = false
	var fire_from: Vector2 = Vector2.ZERO
	var fire_to: Vector2 = Vector2.ZERO
	var fire_delay: float = 0.0


static func predict_enemy(actor: EnemyCharacter, offsets: PackedFloat32Array, horizon: float) -> FutureTrack:
	var projection: FutureTrack = FutureTrack.new()
	projection.actor = actor
	projection.state_name = EnemyAIController.State.keys()[actor.ai.state]
	projection.certainty = float(ENEMY_CERTAINTY.get(actor.ai.state, 0.7))
	var speed: float = actor.move_speed if actor.has_destination else 0.0
	var route: PackedVector2Array = PackedVector2Array()
	if actor.ai.state == EnemyAIController.State.PATROL and actor.patrol_route != null:
		route = _route_from(actor.patrol_route.get_points(), actor.ai.patrol_index)
	projection.path = _forward_path(actor, speed, horizon, route)
	projection.positions = _sample(actor.global_position, projection.path, speed, offsets)
	_predict_fire(actor, projection, horizon)
	return projection


static func predict_ally(actor: AllyCharacter, offsets: PackedFloat32Array, horizon: float) -> FutureTrack:
	var projection: FutureTrack = FutureTrack.new()
	projection.actor = actor
	projection.friendly = true
	projection.state_name = AllyAIController.Order.keys()[actor.ai.current_order]
	projection.certainty = float(ALLY_CERTAINTY.get(actor.ai.current_order, 0.7))
	var speed: float = actor.move_speed if actor.has_destination else 0.0
	projection.path = _forward_path(actor, speed, horizon, PackedVector2Array())
	projection.positions = _sample(actor.global_position, projection.path, speed, offsets)
	return projection


## The remaining navigation path, optionally continued along a patrol route so a
## guard can be projected past the waypoint he is currently walking to.
static func _forward_path(actor: Node2D, speed: float, horizon: float, route: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array([actor.global_position])
	var agent: NavigationAgent2D = actor.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if agent != null and speed > 0.0:
		var path: PackedVector2Array = agent.get_current_navigation_path()
		var index: int = agent.get_current_navigation_path_index()
		for i in range(index, path.size()):
			if path[i].is_finite():
				result.append(path[i])
	for point in route:
		if point.is_finite():
			result.append(point)
	# A path that cannot cover the horizon is not extrapolated into open space.
	return result


static func _sample(origin: Vector2, path: PackedVector2Array, speed: float, offsets: PackedFloat32Array) -> PackedVector2Array:
	var samples: PackedVector2Array = PackedVector2Array()
	for offset in offsets:
		samples.append(_walk(path, speed * maxf(offset, 0.0), origin))
	return samples


## Walks `distance` along a polyline, stopping at its end rather than running on.
static func _walk(path: PackedVector2Array, distance: float, fallback: Vector2) -> Vector2:
	if path.size() < 2 or distance <= 0.0:
		return path[0] if path.size() > 0 else fallback
	var remaining: float = distance
	for index in range(1, path.size()):
		var segment: Vector2 = path[index] - path[index - 1]
		var length: float = segment.length()
		if length <= 0.001:
			continue
		if remaining <= length:
			return path[index - 1] + segment / length * remaining
		remaining -= length
	return path[path.size() - 1]


static func _route_from(points: PackedVector2Array, start: int) -> PackedVector2Array:
	var ordered: PackedVector2Array = PackedVector2Array()
	if points.is_empty():
		return ordered
	for step in range(points.size()):
		ordered.append(points[(start + step) % points.size()])
	return ordered


## A shot is projected only when the guard is already engaging something he can
## see and his weapon will be ready inside the horizon.
static func _predict_fire(actor: EnemyCharacter, projection: FutureTrack, horizon: float) -> void:
	if actor.ai.state != EnemyAIController.State.COMBAT or not is_instance_valid(actor.ai.target):
		return
	if not actor.weapon.enabled or actor.weapon.is_reloading or actor.weapon.current_ammo <= 0:
		return
	var delay: float = actor.weapon.cooldown_remaining
	if delay > horizon or not actor.perception.can_see_target:
		return
	var target: Vector2 = actor.ai.last_known_target_position
	if not target.is_finite():
		return
	var speed: float = actor.move_speed if actor.has_destination else 0.0
	projection.fires = true
	projection.fire_delay = delay
	projection.fire_from = _walk(projection.path, speed * delay, actor.global_position)
	projection.fire_to = target
