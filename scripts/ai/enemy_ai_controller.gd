class_name EnemyAIController
extends Node

signal state_changed(previous: State, current: State)

enum State { PATROL, SUSPICIOUS, INVESTIGATE, COMBAT, SEARCH, RETURN, DEAD }

@export var patrol_speed: float = 95.0
@export var combat_speed: float = 145.0
@export var patrol_wait_time: float = 1.0
@export var suspicious_delay: float = 0.5
@export var search_duration: float = 6.0
@export var lost_sight_grace_time: float = 1.5
@export var decision_interval: float = 0.25
@export var minimum_combat_range: float = 150.0
@export var preferred_combat_range: float = 300.0
@export var maximum_combat_range: float = 500.0
@export var search_radius: float = 100.0
@export var search_point_wait: float = 0.6
@export var investigation_timeout: float = 12.0
@export var arrival_distance: float = 20.0

var state: State = State.PATROL
var last_known_target_position: Vector2
var has_last_known_position: bool = false
var suspicious_position: Vector2
var target: Node2D
var patrol_index: int = 0
var actor: EnemyCharacter
var disturbance_priority: int = 0
var current_disturbance: String = "none"
var _visual_episode_handled: bool = false
var _state_time: float = 0.0
var _unseen_time: float = 0.0
var _decision_timer: float = 0.0
var _wait: float = 0.0
var _search_index: int = 0
var _search_points: PackedVector2Array
var _route: PackedVector2Array


func setup(character: EnemyCharacter) -> void:
	actor = character
	if actor.patrol_route != null:
		_route = actor.patrol_route.get_points()
	if _route.is_empty():
		_route.append(actor.global_position)
	actor.perception.noise_heard.connect(_on_noise_heard)
	actor.perception.perception_state_changed.connect(_on_perception_state_changed)
	actor.perception.target_spotted.connect(_on_target_spotted)


func _physics_process(delta: float) -> void:
	if actor == null or state == State.DEAD or not actor.navigation_ready():
		return
	_state_time += delta
	_wait = maxf(0.0, _wait - delta)
	_unseen_time = 0.0 if _has_target_sight() else _unseen_time + delta
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = decision_interval
		_decide()
	if state == State.COMBAT and _has_target_sight() and is_instance_valid(target):
		actor.face_position(actor.perception.observed_position)
		if actor.weapon.current_ammo == 0:
			actor.weapon.start_reload()
		elif actor.weapon.can_fire and actor.global_position.distance_to(target.global_position) <= maximum_combat_range:
			# Recheck geometry at the firing instant instead of shooting on stale LOS.
			if actor.perception.has_line_of_sight(target):
				actor.weapon.try_fire()
	elif state == State.SEARCH and not actor.has_destination:
		actor.aim_pivot.rotation += delta


func _on_target_spotted(_candidate: Node2D) -> void:
	if is_physics_processing() and can_process() and state != State.DEAD:
		_update_visual_awareness()


func _on_perception_state_changed(_awareness: PerceptionComponent.Awareness) -> void:
	# Preserve threshold crossings between slower AI decision ticks.
	if is_physics_processing() and can_process() and state != State.DEAD:
		_update_visual_awareness()


## Two armed Fremen in the open are obviously hostile - that is why allies used
## to skip the detection ramp entirely. But "obvious" has to depend on how they
## are moving, or a crouched companion is identified from maximum vision range
## and the player is given away before they have taken ten steps.
@export_range(0.1, 1.0, 0.05) var ally_identification_fraction: float = 0.8
## Floor on how much stance and movement can shrink that range. Without it a
## crouched, stationary Fremen becomes invisible rather than merely hard to
## make out, which is not the trade the stealth systems are supposed to offer.
@export_range(0.1, 1.0, 0.05) var ally_identification_floor: float = 0.35


func _ally_is_obvious(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate) or not candidate.is_in_group("allies"):
		return false
	var conspicuousness: float = 1.0
	var profile: StealthProfile = candidate.get_node_or_null("StealthProfile") as StealthProfile
	if profile != null:
		conspicuousness = clampf(
			profile.stance_visibility_modifier * profile.movement_visibility_modifier,
			ally_identification_floor, 1.0)
	var reach: float = actor.perception.vision_distance * ally_identification_fraction * conspicuousness
	return actor.global_position.distance_to(candidate.global_position) <= reach


func _update_visual_awareness() -> void:
	var perception: PerceptionComponent = actor.perception
	if not perception.can_see_target and perception.detection_value <= perception.suspicion_release_threshold:
		_visual_episode_handled = false
	var clear_hostile: bool = _ally_is_obvious(perception.target)
	if perception.can_see_target and (clear_hostile or (state == State.COMBAT and target == perception.target) or perception.detection_value >= perception.detection_max):
		target = actor.perception.target
		last_known_target_position = actor.perception.observed_position
		has_last_known_position = true
		change_state(State.COMBAT)
		perception.combat_tracking = target == perception.player_target
	elif perception.can_see_target and perception.target == perception.player_target and perception.detection_value >= perception.suspicion_threshold and state != State.COMBAT:
		suspicious_position = perception.observed_position
		disturbance_priority = 5
		current_disturbance = "VISUAL"
		if not _visual_episode_handled:
			_visual_episode_handled = true
			change_state(State.SUSPICIOUS)
	elif perception.can_see_target and is_instance_valid(perception.target) and perception.target.is_in_group("allies") and state != State.COMBAT:
		# Movement out there, too far off to name. Worth walking over to.
		suspicious_position = perception.observed_position
		disturbance_priority = 4
		current_disturbance = "MOVEMENT"
		if not _visual_episode_handled:
			_visual_episode_handled = true
			change_state(State.SUSPICIOUS)


func _decide() -> void:
	_update_visual_awareness()
	var perception: PerceptionComponent = actor.perception
	match state:
		State.PATROL:
			_patrol()
		State.SUSPICIOUS:
			actor.stop_moving()
			actor.face_travel = false
			actor.face_position(suspicious_position)
			var watching: bool = current_disturbance == "VISUAL" and perception.can_see_target
			if _state_time >= suspicious_delay and (not watching or perception.detection_value >= perception.alert_threshold):
				change_state(State.INVESTIGATE)
		State.INVESTIGATE:
			actor.face_travel = true
			actor.navigate_to(suspicious_position, combat_speed)
			if _arrived(suspicious_position) or _state_time >= investigation_timeout:
				_begin_search(suspicious_position)
		State.COMBAT:
			_combat()
		State.SEARCH:
			_search()
		State.RETURN:
			actor.face_travel = true
			actor.navigate_to(_route[patrol_index], patrol_speed)
			if _arrived(_route[patrol_index]):
				change_state(State.PATROL)


func _patrol() -> void:
	actor.face_travel = true
	if _wait > 0.0:
		actor.stop_moving()
		return
	actor.navigate_to(_route[patrol_index], patrol_speed)
	if _arrived(_route[patrol_index]):
		actor.stop_moving()
		patrol_index = (patrol_index + 1) % _route.size()
		_wait = patrol_wait_time


func _combat() -> void:
	actor.face_travel = false
	actor.face_position(last_known_target_position)
	if not _has_target_sight():
		actor.navigate_to(last_known_target_position, combat_speed)
		if _unseen_time >= lost_sight_grace_time:
			_begin_search(last_known_target_position)
		return
	var distance: float = actor.global_position.distance_to(last_known_target_position)
	if distance > preferred_combat_range:
		actor.navigate_to(last_known_target_position, combat_speed)
	elif distance < minimum_combat_range:
		var away: Vector2 = last_known_target_position.direction_to(actor.global_position)
		var desired: Vector2 = last_known_target_position + away * preferred_combat_range
		actor.navigate_to(NavigationServer2D.map_get_closest_point(actor.agent.get_navigation_map(), desired), combat_speed)
	else:
		actor.stop_moving()


func _has_target_sight() -> bool:
	return actor.perception.can_see_target and actor.perception.target == target


func _begin_search(center: Vector2) -> void:
	_search_points = PackedVector2Array([center])
	for index in range(3):
		var offset: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * search_radius
		_search_points.append(NavigationServer2D.map_get_closest_point(actor.agent.get_navigation_map(), center + offset))
	_search_index = 0
	change_state(State.SEARCH)


func _search() -> void:
	if _state_time >= search_duration:
		patrol_index = _nearest_patrol_point()
		change_state(State.RETURN)
		return
	if _wait > 0.0:
		actor.stop_moving()
		return
	actor.face_travel = true
	var point: Vector2 = _search_points[_search_index]
	actor.navigate_to(point, patrol_speed)
	if _arrived(point):
		actor.stop_moving()
		_search_index = (_search_index + 1) % _search_points.size()
		_wait = search_point_wait


func _arrived(point: Vector2) -> bool:
	return actor.global_position.distance_to(point) <= arrival_distance or actor.reached_destination()


func _nearest_patrol_point() -> int:
	var nearest: int = 0
	for index in range(_route.size()):
		if actor.global_position.distance_squared_to(_route[index]) < actor.global_position.distance_squared_to(_route[nearest]):
			nearest = index
	return nearest


func _on_noise_heard(position: Vector2, _source: Node, type: int, priority: int) -> void:
	if state in [State.COMBAT, State.DEAD]:
		return
	if priority < disturbance_priority:
		return
	disturbance_priority = priority
	current_disturbance = DisturbanceBus.Type.keys()[type]
	suspicious_position = position
	if state == State.SUSPICIOUS:
		return # Repeated shots update the location without postponing investigation.
	if state == State.INVESTIGATE:
		return
	change_state(State.SUSPICIOUS)


func change_state(next: State) -> void:
	if next == state or state == State.DEAD:
		return
	var previous: State = state
	state = next
	actor.perception.combat_tracking = state == State.COMBAT and target == actor.perception.player_target
	if state == State.RETURN:
		disturbance_priority = 0
		current_disturbance = "none"
	_state_time = 0.0
	_wait = 0.0
	actor.stop_moving()
	if get_node("/root/GameManager").debug_visible:
		print("%s: %s -> %s" % [actor.name, State.keys()[previous], State.keys()[state]])
	state_changed.emit(previous, state)


func die() -> void:
	change_state(State.DEAD)
	target = null
	set_physics_process(false)

