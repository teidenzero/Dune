class_name StealthProfile
extends Node
## Actor-owned visibility and movement noise. Detection belongs to observers.

@export var still_visibility: float = 0.65
@export var walking_visibility: float = 1.0
@export var sprint_visibility: float = 1.6
@export var crouch_visibility: float = 0.6
@export_range(0.0, 1.0) var crouch_exposure: float = 0.75
@export var crouch_noise_radius: float = 40.0
@export var walk_noise_radius: float = 80.0
@export var sprint_noise_radius: float = 160.0
@export var walk_pulse_interval: float = 0.5
@export var sprint_pulse_interval: float = 0.3
@export var movement_threshold: float = 5.0

var stance_visibility_modifier: float = 1.0
var movement_visibility_modifier: float = 0.65
var exposure: float = 1.0
var current_noise_radius: float = 0.0
var stance: String = "STANDING"
var movement_mode: String = "STILL"
var _pulse_elapsed: float = 0.0


func update_profile(crouched: bool, sprinting: bool, speed: float, delta: float, alive: bool = true) -> void:
	stance = "CROUCHED" if crouched else "STANDING"
	stance_visibility_modifier = crouch_visibility if crouched else 1.0
	exposure = crouch_exposure if crouched else 1.0
	var moving: bool = speed > movement_threshold and alive
	movement_mode = "SPRINTING" if moving and sprinting else ("WALKING" if moving else "STILL")
	movement_visibility_modifier = still_visibility if not moving else (sprint_visibility if sprinting else walking_visibility)
	current_noise_radius = 0.0
	if not moving:
		_pulse_elapsed = 0.0
		return
	current_noise_radius = crouch_noise_radius if crouched else (sprint_noise_radius if sprinting else walk_noise_radius)
	_pulse_elapsed += delta
	var interval: float = sprint_pulse_interval if sprinting else walk_pulse_interval
	if _pulse_elapsed >= maxf(interval, 0.05):
		_pulse_elapsed = 0.0
		var bus: DisturbanceBus = get_tree().get_first_node_in_group("disturbance_bus") as DisturbanceBus
		var actor: Node2D = get_parent() as Node2D
		if bus != null:
			bus.emit_noise(actor.global_position, current_noise_radius, actor, DisturbanceBus.Type.FOOTSTEP, 2 if sprinting else 1)
