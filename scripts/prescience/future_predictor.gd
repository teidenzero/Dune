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
	## A plan waiting for the signal, projected as if it went now.
	var planned: bool = false
	## First sample at which a guard's projected cone would hold this unit.
	var seen_at: int = -1
	var strike_label: String = "FIRES"
	## Walking speed along `path`, for positions at any moment (rehearsal).
	var speed: float = 0.0
	## When and where a guard would first see this plan (-1: never), and that
	## guard's own place and facing at that moment, to show who sees it.
	var seen_time: float = -1.0
	var seen_point: Vector2 = Vector2.ZERO
	var seen_by: Vector2 = Vector2.ZERO
	var seen_facing: Vector2 = Vector2.RIGHT
	var seen_guard: EnemyCharacter


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
	# A patrol pausing at a waypoint still walks on: rehearsal needs his pace.
	projection.speed = speed if speed > 0.0 else (actor.ai.patrol_speed if actor.ai.state == EnemyAIController.State.PATROL else 0.0)
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


## A planned order (SquadManager.staged) walked forward as if the signal went
## now: the path is a read-only navigation query, the speed the unit's own. An
## attack stops where the unit would open fire; a knife goes all the way.
static func predict_plan(unit: Node2D, order: Dictionary, offsets: PackedFloat32Array, horizon: float, speed: float, reach: float) -> FutureTrack:
	var projection: FutureTrack = FutureTrack.new()
	projection.actor = unit
	projection.friendly = true
	projection.planned = true
	projection.certainty = 1.0
	var target: Node2D = order.target if is_instance_valid(order.target) else null
	var goal: Vector2 = target.global_position if target != null else order.point
	projection.state_name = "ON SIGNAL"
	var path: PackedVector2Array = PackedVector2Array([unit.global_position, goal])
	var agent: NavigationAgent2D = unit.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if agent != null and NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		var route: PackedVector2Array = NavigationServer2D.map_get_path(agent.get_navigation_map(), unit.global_position, goal, true)
		if route.size() >= 2:
			path = route
	var strikes: bool = order.kind == &"attack" or order.kind == &"melee"
	if strikes and target != null:
		path = _trim_to_reach(path, goal, reach)
	projection.path = path
	projection.speed = speed
	projection.positions = _sample(unit.global_position, path, speed, offsets)
	if strikes and target != null:
		var arrival: float = _length(path) / maxf(speed, 1.0)
		if arrival <= horizon:
			projection.fires = true
			projection.fire_delay = arrival
			projection.fire_from = path[path.size() - 1]
			projection.fire_to = goal
			projection.strike_label = "KNIFE" if order.kind == &"melee" else "FIRES"
	return projection


## Where a track's actor is `seconds` from now, along its projected path.
static func position_at(track: FutureTrack, seconds: float) -> Vector2:
	return _walk(track.path, track.speed * maxf(seconds, 0.0), track.actor.global_position)


## The whole plan against every guard's walked-forward future, a quarter of a
## second at a time until the unit arrives (or `limit` seconds): the first
## moment one of them would have it in his cone, with no wall between.
static func rehearse(plan: FutureTrack, guards: Array[FutureTrack], limit: float, space: PhysicsDirectSpaceState2D) -> void:
	var arrival: float = _length(plan.path) / maxf(plan.speed, 1.0)
	var until: float = minf(arrival + 0.5, limit)
	var step: float = 0.25
	var moment: float = 0.0
	while moment <= until:
		var point: Vector2 = position_at(plan, moment)
		for guard in guards:
			var enemy: EnemyCharacter = guard.actor as EnemyCharacter
			if enemy == null:
				continue
			var at: Vector2 = position_at(guard, moment)
			var before: Vector2 = position_at(guard, moment - step)
			var facing: Vector2 = before.direction_to(at) if before.distance_squared_to(at) > 1.0 else Vector2.RIGHT.rotated(enemy.aim_pivot.global_rotation)
			if sees_from(enemy, at, facing, point, space):
				plan.seen_time = moment
				plan.seen_point = point
				plan.seen_by = at
				plan.seen_facing = facing
				plan.seen_guard = enemy
				return
		moment += step


## Whether `enemy`, standing at `from` and facing `facing`, would see `point`:
## inside his cone and reach, and no wall between.
static func sees_from(enemy: EnemyCharacter, from: Vector2, facing: Vector2, point: Vector2, space: PhysicsDirectSpaceState2D) -> bool:
	var offset: Vector2 = point - from
	if offset.length() > enemy.perception.vision_distance:
		return false
	if not offset.is_zero_approx() and facing.dot(offset.normalized()) < cos(deg_to_rad(enemy.perception.field_of_view_degrees * 0.5)):
		return false
	# Walls only: bodies will have moved by then.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, point, 1)
	return space.intersect_ray(query).is_empty()


## Whether `enemy`'s projected self at sample `index` would see `point`: inside
## his cone, facing the way he will be walking, with no wall between.
static func sees_at(enemy_track: FutureTrack, index: int, point: Vector2, space: PhysicsDirectSpaceState2D) -> bool:
	var enemy: EnemyCharacter = enemy_track.actor as EnemyCharacter
	if enemy == null or index >= enemy_track.positions.size():
		return false
	var from: Vector2 = enemy_track.positions[index]
	var offset: Vector2 = point - from
	if offset.length() > enemy.perception.vision_distance:
		return false
	var previous: Vector2 = enemy.global_position if index == 0 else enemy_track.positions[index - 1]
	var forward: Vector2 = previous.direction_to(from) if previous.distance_squared_to(from) > 4.0 else Vector2.RIGHT.rotated(enemy.aim_pivot.global_rotation)
	if not offset.is_zero_approx() and forward.dot(offset.normalized()) < cos(deg_to_rad(enemy.perception.field_of_view_degrees * 0.5)):
		return false
	# Walls only: bodies will have moved by then.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, point, 1)
	return space.intersect_ray(query).is_empty()


## The path cut at the first point within `reach` of `goal`.
static func _trim_to_reach(path: PackedVector2Array, goal: Vector2, reach: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array([path[0]])
	if path[0].distance_to(goal) <= reach:
		return result
	for index in range(1, path.size()):
		var a: Vector2 = path[index - 1]
		var b: Vector2 = path[index]
		if b.distance_to(goal) > reach:
			result.append(b)
			continue
		# Step along this segment to where it enters reach.
		var length: float = a.distance_to(b)
		var steps: int = maxi(int(length / 8.0), 1)
		for step in range(1, steps + 1):
			var point: Vector2 = a.lerp(b, float(step) / steps)
			if point.distance_to(goal) <= reach:
				result.append(point)
				return result
		result.append(b)
		return result
	return result


static func _length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


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
