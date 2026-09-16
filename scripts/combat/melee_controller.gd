class_name MeleeController
extends Node
## Reusable melee driver: holds the swing state machine, drives an Area2D
## hitbox, and reports every contact through DamageResolver. It reads no input
## itself, so Paul, a Fremen, or a Harkonnen could all mount one.
##
## Input contract (hold to commit):
##   begin_input()  - button pressed, start charging
##   release_input() - button released, swing FAST below the charge threshold
##                     or SLOW at or above it
##   cancel()       - abandon a charge or wind-up without striking

signal attack_started(data: MeleeAttackData)
signal attack_landed(target: Node, data: MeleeAttackData, outcome: int)
signal attack_finished(data: MeleeAttackData, hits: int)
signal charge_ready_changed(slow_ready: bool)
signal state_changed(state: int)

enum State { IDLE, CHARGING, WINDUP, ACTIVE, RECOVERY }

@export var fast_attack: MeleeAttackData
@export var slow_attack: MeleeAttackData
@export var owner_actor: PhysicsBody2D
@export var hitbox: Area2D
## Reach the authored hitbox polygon represents; other ranges scale from it.
@export var hitbox_base_range: float = 70.0
## Hold this long to commit to the slow, shield-penetrating strike.
@export_range(0.05, 3.0, 0.01) var slow_charge_threshold: float = 0.35

var state: State = State.IDLE
var enabled: bool = true
var current_attack: MeleeAttackData
var charge_time: float = 0.0
var slow_ready: bool = false
var last_result: String = "none"
var last_target: String = "none"
var last_attack_name: String = "none"
var last_result_time: int = 0
var _phase_remaining: float = 0.0
var _hits_this_swing: int = 0
var _struck: Array[Node] = []
var _wedge: ConvexPolygonShape2D


func _ready() -> void:
	if hitbox != null:
		hitbox.monitoring = false


func begin_input() -> void:
	if not enabled or state != State.IDLE:
		return
	charge_time = 0.0
	_set_slow_ready(false)
	_set_state(State.CHARGING)
	# Warm the area up during the charge so the active window sees fresh overlaps.
	if hitbox != null:
		hitbox.monitoring = true


func release_input() -> void:
	if state != State.CHARGING:
		return
	var chosen: MeleeAttackData = slow_attack if slow_ready and slow_attack != null else fast_attack
	if chosen == null:
		cancel()
		return
	_start_attack(chosen)


## Abandons a charge or wind-up. An active or recovering swing cannot be taken
## back; the commitment is the point.
func cancel() -> void:
	if state == State.CHARGING or state == State.WINDUP:
		_reset()


func disable() -> void:
	set_enabled(false)


## Reversible, unlike disable(): the tutorial withholds the blade until taught.
func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_reset()
	set_physics_process(enabled)


func can_attack() -> bool:
	return enabled and state == State.IDLE


func charge_ratio() -> float:
	if state != State.CHARGING:
		return 0.0
	return clampf(charge_time / maxf(slow_charge_threshold, 0.01), 0.0, 1.0)


## Movement allowance for the owning character; a committed slow strike is slow.
func get_move_speed_multiplier() -> float:
	match state:
		State.CHARGING:
			return slow_attack.move_speed_multiplier if slow_ready and slow_attack != null else 1.0
		State.WINDUP, State.ACTIVE:
			return current_attack.move_speed_multiplier if current_attack != null else 1.0
		_:
			return 1.0


func state_name() -> String:
	return State.keys()[state]


func attack_name() -> String:
	return current_attack.attack_name if current_attack != null else "none"


func attack_velocity() -> float:
	if current_attack != null:
		return current_attack.attack_velocity
	if state == State.CHARGING and slow_ready and slow_attack != null:
		return slow_attack.attack_velocity
	return fast_attack.attack_velocity if fast_attack != null else 0.0


func _physics_process(delta: float) -> void:
	match state:
		State.CHARGING:
			charge_time += delta
			if not slow_ready and charge_time >= slow_charge_threshold:
				_set_slow_ready(true)
		State.WINDUP:
			_phase_remaining -= delta
			if _phase_remaining <= 0.0:
				_set_state(State.ACTIVE)
				_phase_remaining = maxf(current_attack.active_time, 0.01)
				_scan_hits()
		State.ACTIVE:
			_scan_hits()
			_phase_remaining -= delta
			if _phase_remaining <= 0.0:
				if hitbox != null:
					hitbox.monitoring = false
				attack_finished.emit(current_attack, _hits_this_swing)
				_set_state(State.RECOVERY)
				_phase_remaining = maxf(current_attack.recovery_time, 0.0)
		State.RECOVERY:
			_phase_remaining -= delta
			if _phase_remaining <= 0.0:
				_reset()
		_:
			pass


func _start_attack(data: MeleeAttackData) -> void:
	current_attack = data
	_struck.clear()
	_hits_this_swing = 0
	if hitbox != null:
		hitbox.monitoring = true
		hitbox.scale = Vector2.ONE * (data.attack_range / maxf(hitbox_base_range, 1.0))
	_set_state(State.WINDUP)
	_phase_remaining = maxf(data.windup_time, 0.0)
	attack_started.emit(data)
	if _phase_remaining <= 0.0:
		_set_state(State.ACTIVE)
		_phase_remaining = maxf(data.active_time, 0.01)
		_scan_hits()


## The authored Area2D supplies the wedge shape, mask, and armed window, but the
## test itself is a direct shape query: Godot never pairs an area with a static
## body that has not moved, which would silently miss stationary targets.
func _scan_hits() -> void:
	if hitbox == null or current_attack == null:
		return
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _wedge_shape()
	if query.shape == null:
		return
	query.transform = hitbox.global_transform
	query.collision_mask = hitbox.collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if owner_actor is CollisionObject2D:
		query.exclude = [owner_actor.get_rid()]
	for contact: Dictionary in hitbox.get_world_2d().direct_space_state.intersect_shape(query, 16):
		var body: Node2D = contact.get("collider") as Node2D
		# One contact per target per swing, whatever the outcome.
		if body == null or body == owner_actor or _struck.has(body):
			continue
		_struck.append(body)
		var direction: Vector2 = Vector2.RIGHT.rotated(hitbox.global_rotation)
		var hit: HitContext = HitContext.melee(current_attack, owner_actor, body.global_position, direction)
		var outcome: DamageResolver.Outcome = DamageResolver.resolve(body, hit)
		if outcome == DamageResolver.Outcome.FRIENDLY or outcome == DamageResolver.Outcome.MISSED:
			continue
		_hits_this_swing += 1
		last_attack_name = current_attack.attack_name
		last_target = str(body.name)
		last_result = "BLOCKED" if outcome == DamageResolver.Outcome.BLOCKED else "DAMAGED"
		last_result_time = Time.get_ticks_msec()
		_emit_impact_noise(body)
		_log(body, outcome)
		attack_landed.emit(body, current_attack, outcome)


func _wedge_shape() -> ConvexPolygonShape2D:
	if _wedge != null:
		return _wedge
	for child in hitbox.get_children():
		if child is CollisionPolygon2D and child.polygon.size() >= 3:
			_wedge = ConvexPolygonShape2D.new()
			_wedge.points = child.polygon
			return _wedge
	return null


func _emit_impact_noise(body: Node2D) -> void:
	if current_attack.noise_radius <= 0.0:
		return
	var bus: DisturbanceBus = get_tree().get_first_node_in_group("disturbance_bus") as DisturbanceBus
	if bus != null:
		bus.emit_noise(body.global_position, current_attack.noise_radius, owner_actor, DisturbanceBus.Type.IMPACT)


func _log(body: Node2D, outcome: DamageResolver.Outcome) -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null or not manager.debug_visible:
		return
	var shield: ShieldComponent = ShieldComponent.find_on(body)
	var threshold: String = "%.0f" % shield.velocity_threshold if shield != null and shield.enabled else "none"
	print("%s -> %s | velocity: %.0f | shield threshold: %s | result: %s" % [
		current_attack.attack_name, body.name, current_attack.attack_velocity, threshold,
		"BLOCKED" if outcome == DamageResolver.Outcome.BLOCKED else "PENETRATED" if shield != null and shield.enabled else "HIT",
	])


func _reset() -> void:
	current_attack = null
	charge_time = 0.0
	_phase_remaining = 0.0
	_struck.clear()
	_set_slow_ready(false)
	if hitbox != null:
		hitbox.monitoring = false
	_set_state(State.IDLE)


func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	state_changed.emit(state)


func _set_slow_ready(value: bool) -> void:
	if slow_ready == value:
		return
	slow_ready = value
	charge_ready_changed.emit(slow_ready)
