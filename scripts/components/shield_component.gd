class_name ShieldComponent
extends Node
## Holtzman personal shield. It judges one property of an incoming attack:
## speed. Anything faster than `velocity_threshold` is stopped dead; anything
## slower slides through untouched, shield still running.
##
## This is deliberately not armour. There is no damage reduction and no
## "shoot it until it breaks" path: energy floors at `minimum_energy` so
## sustained gunfire can never become the answer to a shielded enemy. Energy
## exists to drive visuals.

signal shield_blocked(hit: HitContext)
signal shield_penetrated(hit: HitContext)
signal shield_recharged

enum Result { NO_SHIELD, BLOCKED, PENETRATED }

@export var enabled: bool = true
## Attacks above this speed are blocked; at or below it they pass through.
@export var velocity_threshold: float = 150.0
@export var max_energy: float = 100.0
## Cosmetic drain per blocked impact.
@export var block_energy_cost: float = 8.0
@export var recharge_rate: float = 20.0
@export var recharge_delay: float = 1.0
## Energy never falls below this, so the shield never fails from brute force.
@export var minimum_energy: float = 25.0

var current_energy: float = 0.0
var last_result: Result = Result.NO_SHIELD
var last_attack_label: String = "none"
var last_attack_velocity: float = 0.0
var _recharge_wait: float = 0.0


func _ready() -> void:
	current_energy = max_energy


## Judges one attack and reports whether it was stopped. Callers apply health
## damage only when this does not return BLOCKED.
func evaluate(hit: HitContext) -> Result:
	if not enabled:
		last_result = Result.NO_SHIELD
		return last_result
	last_attack_label = hit.label
	last_attack_velocity = hit.attack_velocity
	if hit.attack_velocity > velocity_threshold:
		last_result = Result.BLOCKED
		current_energy = maxf(current_energy - block_energy_cost, minimum_energy)
		_recharge_wait = recharge_delay
		shield_blocked.emit(hit)
	else:
		last_result = Result.PENETRATED
		# The blade passes through a running shield; it does not break it.
		shield_penetrated.emit(hit)
	return last_result


func would_block(velocity: float) -> bool:
	return enabled and velocity > velocity_threshold


func energy_ratio() -> float:
	return 0.0 if max_energy <= 0.0 else clampf(current_energy / max_energy, 0.0, 1.0)


func result_name() -> String:
	return Result.keys()[last_result]


func shut_down() -> void:
	enabled = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not enabled or current_energy >= max_energy:
		return
	if _recharge_wait > 0.0:
		_recharge_wait = maxf(_recharge_wait - delta, 0.0)
		return
	current_energy = minf(current_energy + recharge_rate * delta, max_energy)
	if current_energy >= max_energy:
		shield_recharged.emit()


static func find_on(actor: Node) -> ShieldComponent:
	# Shielded bodies compose a direct child with this stable name.
	return actor.get_node_or_null("ShieldComponent") as ShieldComponent if is_instance_valid(actor) else null
