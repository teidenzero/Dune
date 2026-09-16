class_name PrescienceEnergyComponent
extends Node
## Paul's prescience reserve. It is the only thing limiting how often he can
## look ahead, so there is no separate cooldown beyond a short anti-double-tap
## lockout on the controller.

signal energy_changed(current: float, maximum: float)
signal energy_spent(cost: float)

@export var max_energy: float = 100.0
@export var activation_cost: float = 35.0
## Game-time regeneration, matching every other gameplay timer in the project.
@export var regen_per_second: float = 8.0
## Paused while prescience is active, so a look cannot pay for itself.
@export var regenerating: bool = true

var current_energy: float = 0.0


func _ready() -> void:
	reset_energy()


func _physics_process(delta: float) -> void:
	if not regenerating or current_energy >= max_energy:
		return
	current_energy = minf(current_energy + regen_per_second * delta, max_energy)
	energy_changed.emit(current_energy, max_energy)


func can_spend() -> bool:
	return current_energy >= activation_cost


func spend() -> bool:
	if not can_spend():
		return false
	current_energy = maxf(current_energy - activation_cost, 0.0)
	energy_spent.emit(activation_cost)
	energy_changed.emit(current_energy, max_energy)
	return true


func reset_energy() -> void:
	max_energy = maxf(max_energy, 1.0)
	current_energy = max_energy
	regenerating = true
	energy_changed.emit(current_energy, max_energy)


func ratio() -> float:
	return clampf(current_energy / maxf(max_energy, 1.0), 0.0, 1.0)


static func find_on(actor: Node) -> PrescienceEnergyComponent:
	return actor.get_node_or_null("PrescienceEnergy") as PrescienceEnergyComponent if is_instance_valid(actor) else null
