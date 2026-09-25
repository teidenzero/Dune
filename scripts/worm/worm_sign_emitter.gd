class_name WormSignEmitter
extends Node
## Turns one actor's activity into desert vibration.
##
## Movement is emitted as rhythmic pulses rather than a per-frame trickle,
## because it is the rhythm that carries, and `movement_multiplier` is the seam
## a future Fremen sandwalk would lower without touching anything else here.
##
## This is separate from the enemy-hearing DisturbanceBus on purpose: a gunshot
## is both a sound a guard can hear and a vibration the desert feels, and the
## two travel by different rules.

## Every step, as the worm would feel it: footstep sounds follow it.
signal stepped(at: Vector2, profile: String, on_sand: bool)

@export var actor: Node2D
@export var terrain: TerrainSafetyComponent
@export var label: String = "Actor"
## Fremen move quieter on sand than Paul does; a sandwalk would lower it further.
@export_range(0.0, 2.0, 0.05) var movement_multiplier: float = 1.0

@export_group("Movement rhythm")
@export var crouch_sign: float = 0.15
@export var walk_sign: float = 0.55
@export var sprint_sign: float = 1.6
@export var crouch_interval: float = 0.7
@export var walk_interval: float = 0.5
@export var sprint_interval: float = 0.3
@export var movement_threshold: float = 5.0

@export_group("Continuous source")
## Machinery and other standing vibration, emitted every second while running.
@export var continuous_sign: float = 0.0
@export var continuous_active: bool = false

var last_pulse: float = 0.0
var last_profile: String = "STILL"
var _pulse_elapsed: float = 0.0
var _continuous_elapsed: float = 0.0
var _manager: Node


func _ready() -> void:
	add_to_group("worm_emitters")
	if actor == null:
		actor = get_parent() as Node2D
	if terrain == null:
		terrain = TerrainSafetyComponent.find_on(actor)
	call_deferred("_bind")


func _bind() -> void:
	_manager = get_tree().get_first_node_in_group("worm_threat")


## One-shot vibration: gunfire, an impact, an explosion. The terrain scales it
## like any other sign, and safe rock mutes it entirely.
func impulse(amount: float, source_label: String = "") -> void:
	if amount <= 0.0 or not is_instance_valid(actor):
		return
	_report(amount, source_label if source_label != "" else label)


func set_continuous(active: bool) -> void:
	continuous_active = active
	_continuous_elapsed = 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	if continuous_active and continuous_sign > 0.0:
		_continuous_elapsed += delta
		if _continuous_elapsed >= 1.0:
			_report(continuous_sign * _continuous_elapsed, label)
			_continuous_elapsed = 0.0
	_movement(delta)


func _movement(delta: float) -> void:
	var speed: float = _speed()
	var moving: bool = speed > movement_threshold and _alive()
	if not moving:
		_pulse_elapsed = 0.0
		last_profile = "STILL"
		return
	var crouching: bool = _flag("is_crouching")
	var sprinting: bool = _flag("is_sprinting") or speed > walk_speed_hint()
	last_profile = "CROUCH" if crouching else ("SPRINT" if sprinting else "WALK")
	var interval: float = crouch_interval if crouching else (sprint_interval if sprinting else walk_interval)
	var amount: float = crouch_sign if crouching else (sprint_sign if sprinting else walk_sign)
	_pulse_elapsed += delta
	if _pulse_elapsed < maxf(interval, 0.05):
		return
	_pulse_elapsed = 0.0
	stepped.emit(actor.global_position, last_profile, terrain != null and terrain.carries_sign())
	_report(amount * movement_multiplier, "%s %s" % [label, last_profile.to_lower()])


## Actors without an explicit sprint flag are judged by speed alone.
func walk_speed_hint() -> float:
	var hint: Variant = actor.get("walk_speed")
	return float(hint) * 1.15 if hint is float else 9999.0


func _speed() -> float:
	var velocity: Variant = actor.get("velocity")
	return (velocity as Vector2).length() if velocity is Vector2 else 0.0


func _flag(name: String) -> bool:
	var value: Variant = actor.get(name)
	return value if value is bool else false


func _alive() -> bool:
	var health: HealthComponent = HealthComponent.find_on(actor)
	return health == null or not health.is_dead


## Ground decides how much of the rhythm the desert actually feels.
func _report(amount: float, source_label: String) -> void:
	if _manager == null:
		_manager = get_tree().get_first_node_in_group("worm_threat")
		if _manager == null:
			return
	var scale: float = terrain.sign_multiplier if terrain != null else 1.0
	if terrain != null and terrain.is_safe():
		scale = 0.0
	var final: float = amount * scale
	if final <= 0.0:
		return
	last_pulse = final
	_manager.report_sign(actor.global_position, final, source_label, self)
