class_name AllyAIController
extends Node
## Persistent orders are independent from temporary, leashed combat.

signal order_changed
enum Order { FOLLOW, MOVE_TO, HOLD, ATTACK }
enum Behavior { FOLLOW, MOVE_TO, HOLD, COMBAT, DEAD }

@export var decision_interval: float = 0.2
@export var unreachable_timeout: float = 8.0
var actor: AllyCharacter
var current_order: Order = Order.FOLLOW
var behavior: Behavior = Behavior.FOLLOW
var order_position: Vector2
var hold_position: Vector2
var order_target: Node2D
var combat_target: Node2D
var previous_order: Order = Order.FOLLOW
var previous_position: Vector2
var attack_origin: Vector2
var _combat_origin: Vector2
var _last_seen: Vector2
var _unseen: float = 0.0
var _decision: float = 0.0
var _following: bool = false
var _visible: bool = false
var _combat_leash: float = 360.0
var _stalled: float = 0.0
var _progress_position: Vector2


func setup(character: AllyCharacter) -> void:
	actor = character
	hold_position = actor.global_position


func issue_order(order: Order, point: Vector2 = Vector2.ZERO, target: Node2D = null) -> void:
	if behavior == Behavior.DEAD:
		return
	if order == Order.ATTACK:
		if not _valid_hostile(target):
			return
		if current_order != Order.ATTACK:
			previous_order = current_order
			previous_position = hold_position if current_order == Order.HOLD else order_position
		attack_origin = actor.global_position
		_last_seen = target.global_position
	current_order = order
	order_target = target if order == Order.ATTACK else null
	order_position = point
	if order == Order.HOLD:
		hold_position = point
	combat_target = order_target
	_unseen = 0.0
	_stalled = 0.0
	_progress_position = actor.global_position
	_decision = 0.0
	_following = false
	actor.stop_moving()
	order_changed.emit()


func _physics_process(delta: float) -> void:
	if actor == null or behavior == Behavior.DEAD or not actor.navigation_ready():
		return
	_decision -= delta
	if _decision <= 0:
		_decision = decision_interval
		_decide()
	if behavior == Behavior.COMBAT and _valid_hostile(combat_target):
		_visible = actor.has_line_of_sight(combat_target)
		_unseen = 0.0 if _visible else _unseen + delta
		if actor.has_destination:
			_stalled += delta
			if actor.global_position.distance_to(_progress_position) > 12:
				_progress_position = actor.global_position
				_stalled = 0.0
		else:
			_stalled = 0.0
		if _visible:
			_last_seen = combat_target.global_position
			actor.face_position(_last_seen)
			if actor.global_position.distance_to(_last_seen) <= 500:
				if actor.weapon.current_ammo == 0:
					actor.weapon.start_reload()
				elif actor.weapon.can_fire:
					actor.weapon.try_fire()


func _decide() -> void:
	if current_order == Order.ATTACK:
		if not _valid_hostile(order_target) or attack_origin.distance_to(order_target.global_position) > actor.data.attack_leash or _unseen > unreachable_timeout or _stalled > unreachable_timeout:
			_resume_previous()
		else:
			combat_target = order_target
	elif not _valid_hostile(combat_target) or _unseen > 2.0 or _combat_origin.distance_to(combat_target.global_position) > _combat_leash:
		combat_target = null
		_acquire_nearby()
	if _valid_hostile(combat_target):
		_fight()
	else:
		_execute_order()


func _execute_order() -> void:
	actor.face_travel = true
	match current_order:
		Order.FOLLOW:
			behavior = Behavior.FOLLOW
			if not is_instance_valid(actor.player) or actor.player.health.is_dead:
				actor.stop_moving()
				return
			var crouched: bool = actor.player.is_crouching
			var offset: Vector2 = actor.follow_offset * (0.65 if crouched else 1.0)
			var desired: Vector2 = actor.player.global_position + offset
			var distance: float = actor.global_position.distance_to(desired)
			if distance > actor.data.follow_distance * 0.6:
				_following = true
			elif distance < 18.0:
				_following = false
			if _following:
				var speed: float = actor.data.move_speed
				if crouched:
					speed = minf(speed, actor.player.crouch_speed)
				elif distance > actor.data.catchup_distance:
					speed *= actor.data.catchup_multiplier
				actor.navigate_to(_nav_point(desired), speed)
			else:
				actor.stop_moving()
		Order.MOVE_TO:
			behavior = Behavior.MOVE_TO
			actor.navigate_to(order_position, actor.data.move_speed)
			if actor.global_position.distance_to(order_position) < 20:
				issue_order(Order.HOLD, order_position)
		Order.HOLD:
			behavior = Behavior.HOLD
			if actor.global_position.distance_to(hold_position) > 22:
				actor.navigate_to(hold_position, actor.data.move_speed)
			else:
				actor.stop_moving()


func _fight() -> void:
	behavior = Behavior.COMBAT
	actor.face_travel = false
	_visible = actor.has_line_of_sight(combat_target)
	if _visible:
		_last_seen = combat_target.global_position
	var distance: float = actor.global_position.distance_to(_last_seen)
	if not _visible or distance > actor.data.preferred_combat_range + 20:
		actor.navigate_to(_nav_point(_last_seen), actor.data.move_speed)
	elif distance < actor.data.preferred_combat_range * 0.5:
		var away: Vector2 = _last_seen.direction_to(actor.global_position)
		actor.navigate_to(_nav_point(_last_seen + away * actor.data.preferred_combat_range * 0.75), actor.data.move_speed)
	else:
		actor.stop_moving()
	actor.face_position(_last_seen)


func _acquire_nearby() -> void:
	var closest: float = actor.data.aggression_radius
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if not _valid_hostile(enemy):
			continue
		# Quiet FOLLOW does not initiate a fight beside crouching Paul.
		if current_order == Order.FOLLOW and is_instance_valid(actor.player) and actor.player.is_crouching:
			if enemy is EnemyCharacter and enemy.ai.state != EnemyAIController.State.COMBAT:
				continue
		var distance: float = actor.global_position.distance_to(enemy.global_position)
		if _autonomy_anchor().distance_to(enemy.global_position) > actor.data.aggression_radius + 80:
			continue
		if distance < closest and actor.has_line_of_sight(enemy):
			closest = distance
			combat_target = enemy
	if is_instance_valid(combat_target):
		_combat_leash = actor.data.aggression_radius + 80.0
		_combat_origin = _autonomy_anchor()
		_last_seen = combat_target.global_position
		_unseen = 0.0


func defend_against(source: Node2D) -> void:
	if current_order == Order.ATTACK or not _valid_hostile(source):
		return
	if actor.global_position.distance_to(source.global_position) > actor.data.attack_leash:
		return
	combat_target = source
	_combat_leash = actor.data.attack_leash
	_combat_origin = actor.global_position
	_last_seen = source.global_position
	_unseen = 0.0
	_decision = 0.0


func _autonomy_anchor() -> Vector2:
	if current_order == Order.HOLD:
		return hold_position
	if current_order == Order.FOLLOW and is_instance_valid(actor.player):
		return actor.player.global_position
	return order_position


func _resume_previous() -> void:
	var restore: Order = previous_order
	issue_order(restore, previous_position)


func _valid_hostile(candidate: Variant) -> bool:
	# A freed target must reach this validity check before typed Node coercion.
	if not is_instance_valid(candidate) or not candidate.can_process() or candidate.get_meta("team_id", &"") != &"harkonnen":
		return false
	var health: HealthComponent = HealthComponent.find_on(candidate)
	return health != null and not health.is_dead


func _nav_point(point: Vector2) -> Vector2:
	return NavigationServer2D.map_get_closest_point(actor.agent.get_navigation_map(), point)


func die() -> void:
	behavior = Behavior.DEAD
	combat_target = null
	order_target = null
	set_physics_process(false)
	order_changed.emit()
