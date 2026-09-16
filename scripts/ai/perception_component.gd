class_name PerceptionComponent
extends Node2D

signal target_spotted(target: Node2D)
signal target_lost
signal noise_heard(position: Vector2, source: Node, type: int, priority: int)
signal detection_changed(value: float, maximum: float)
signal perception_state_changed(state: Awareness)

enum Awareness { UNAWARE, SUSPICIOUS, ALERT, DETECTED }

@export var actor: PhysicsBody2D
@export var facing: Node2D
@export var target_group: StringName = &"player"
@export_range(1.0, 2000.0, 1.0) var vision_distance: float = 500.0
@export_range(1.0, 360.0, 1.0) var field_of_view_degrees: float = 90.0
@export_range(0.05, 1.0, 0.01) var update_interval: float = 0.15
@export_range(0.0, 3.0, 0.1) var hearing_multiplier: float = 1.0
@export var base_detection_rate: float = 45.0
@export var detection_max: float = 100.0
@export var suspicion_threshold: float = 25.0
@export var alert_threshold: float = 60.0
@export var suspicion_release_threshold: float = 10.0
@export var detection_decay_rate: float = 25.0
@export var low_suspicion_decay_multiplier: float = 1.35
@export var forgotten_after: float = 3.0
@export var forgotten_decay_multiplier: float = 1.5
@export var near_distance_modifier: float = 1.8
@export var far_distance_modifier: float = 0.4
@export var peripheral_modifier: float = 0.5
@export var close_distance: float = 90.0
@export var close_multiplier: float = 8.0
@export var suspicious_detection_multiplier: float = 1.25

var target: Node2D
var player_target: Node2D
var priority_target: Node2D
var player_visible: bool = false
var can_see_target: bool = false
var observed_position: Vector2 = Vector2.ZERO
var detection_value: float = 0.0
var perception_state: Awareness = Awareness.UNAWARE
var detection_gain_per_second: float = 0.0
var detection_decay_per_second: float = 0.0
var distance_modifier: float = 1.0
var movement_modifier: float = 1.0
var stance_modifier: float = 1.0
var exposure_modifier: float = 1.0
var facing_modifier: float = 1.0
var combat_tracking: bool = false
var _elapsed: float = 0.0
var _unseen: float = 0.0
var _peak_detection: float = 0.0


func _ready() -> void:
	var bus: DisturbanceBus = get_tree().get_first_node_in_group("disturbance_bus") as DisturbanceBus
	if bus != null:
		bus.noise_emitted.connect(_on_noise)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= update_interval:
		scan()
		update_detection(_elapsed)
		_elapsed = 0.0


func update_detection(elapsed: float) -> void:
	if not is_finite(elapsed) or elapsed <= 0.0:
		return
	detection_gain_per_second = 0.0
	detection_decay_per_second = 0.0
	_unseen = 0.0 if player_visible else _unseen + elapsed
	if combat_tracking:
		_set_detection(detection_max)
	elif player_visible and is_instance_valid(player_target):
		_calculate_modifiers()
		var focus: float = suspicious_detection_multiplier if detection_value >= suspicion_threshold else 1.0
		detection_gain_per_second = base_detection_rate * distance_modifier * movement_modifier * stance_modifier * exposure_modifier * facing_modifier * focus
		if not is_finite(detection_gain_per_second):
			detection_gain_per_second = 0.0
		_set_detection(detection_value + maxf(0.0, detection_gain_per_second) * elapsed)
	else:
		detection_decay_per_second = detection_decay_rate
		if _peak_detection < alert_threshold:
			detection_decay_per_second *= low_suspicion_decay_multiplier
		if _unseen >= forgotten_after:
			detection_decay_per_second *= forgotten_decay_multiplier
		_set_detection(detection_value - maxf(0.0, detection_decay_per_second) * elapsed)


func _calculate_modifiers() -> void:
	var offset: Vector2 = player_target.global_position - global_position
	var distance: float = offset.length()
	distance_modifier = lerpf(near_distance_modifier, far_distance_modifier, clampf(distance / maxf(vision_distance, 1.0), 0.0, 1.0))
	if distance < close_distance:
		distance_modifier *= close_multiplier
	var angle: float = absf(Vector2.RIGHT.rotated(facing.global_rotation).angle_to(offset))
	facing_modifier = lerpf(1.0, peripheral_modifier, clampf(angle / maxf(deg_to_rad(field_of_view_degrees * 0.5), 0.01), 0.0, 1.0))
	movement_modifier = 1.0
	stance_modifier = 1.0
	exposure_modifier = 1.0
	var profile: StealthProfile = player_target.get_node_or_null("StealthProfile") as StealthProfile
	if profile != null:
		movement_modifier = profile.movement_visibility_modifier
		stance_modifier = profile.stance_visibility_modifier
		exposure_modifier = clampf(profile.exposure, 0.0, 1.0)


func _set_detection(value: float) -> void:
	var maximum: float = maxf(1.0, detection_max) if is_finite(detection_max) else 100.0
	detection_value = clampf(value, 0.0, maximum) if is_finite(value) else 0.0
	_peak_detection = maxf(_peak_detection, detection_value) if detection_value > 0.0 else 0.0
	var next: Awareness = Awareness.UNAWARE
	if detection_value >= maximum:
		next = Awareness.DETECTED
	elif detection_value >= alert_threshold:
		next = Awareness.ALERT
	elif detection_value >= suspicion_threshold:
		next = Awareness.SUSPICIOUS
	if next != perception_state:
		perception_state = next
		perception_state_changed.emit(next)
	detection_changed.emit(detection_value, maximum)


func scan() -> void:
	if not is_instance_valid(player_target):
		player_target = get_tree().get_first_node_in_group(target_group) as Node2D
	player_visible = is_candidate_visible(player_target)
	var previous: Node2D = target
	var best: Node2D
	var best_score: float = INF
	var candidates: Array[Node] = get_tree().get_nodes_in_group("allies")
	if is_instance_valid(player_target):
		candidates.append(player_target)
	for candidate: Node2D in candidates:
		if candidate != player_target and not candidate.can_process():
			continue
		var seen: bool = player_visible if candidate == player_target else is_candidate_visible(candidate)
		if not seen:
			continue
		var score: float = global_position.distance_to(candidate.global_position)
		if candidate == player_target:
			score = score * 0.9 if detection_value >= detection_max else score + vision_distance
		if candidate == target:
			score *= 0.8
		if candidate == priority_target:
			score = -1.0
		if score < best_score:
			best_score = score
			best = candidate
	if best != null:
		target = best
	elif not is_instance_valid(target):
		target = player_target
	var visible_now: bool = is_target_visible()
	if visible_now:
		observed_position = target.global_position
	if visible_now != can_see_target or target != previous:
		can_see_target = visible_now
		if visible_now:
			target_spotted.emit(target)
		else:
			target_lost.emit()


func is_target_visible() -> bool:
	return is_candidate_visible(target)


func is_candidate_visible(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate) or candidate.get_meta("team_id", &"") == actor.get_meta("team_id", &""):
		return false
	var health: HealthComponent = HealthComponent.find_on(candidate)
	if health != null and health.is_dead:
		return false
	var offset: Vector2 = candidate.global_position - global_position
	if offset.length_squared() > vision_distance * vision_distance:
		return false
	var forward: Vector2 = Vector2.RIGHT.rotated(facing.global_rotation)
	if not offset.is_zero_approx() and forward.dot(offset.normalized()) < cos(deg_to_rad(field_of_view_degrees * 0.5)):
		return false
	return has_line_of_sight(candidate)


func has_line_of_sight(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate):
		return false
	# World geometry and character bodies can both obstruct a shot.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, candidate.global_position, 3, [actor.get_rid()])
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == candidate


func stop() -> void:
	set_physics_process(false)
	can_see_target = false
	target = null
	player_target = null
	priority_target = null
	player_visible = false
	combat_tracking = false
	detection_gain_per_second = 0.0
	detection_decay_per_second = 0.0


func _on_noise(position: Vector2, radius: float, source: Node, type: int, priority: int) -> void:
	# Self-noise is irrelevant; another guard's rifle can draw local attention.
	if not is_physics_processing() or not can_process() or source == actor:
		return
	if global_position.distance_to(position) <= radius * hearing_multiplier:
		noise_heard.emit(position, source, type, priority)
