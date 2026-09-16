class_name MeleeAttackData
extends Resource
## One configurable melee swing. `attack_velocity` is the blade speed a shield
## judges; nothing here declares "penetrating" as a flag, because the shield
## compares speed against its own threshold.

@export var attack_name: String = "Crysknife Fast"
@export_range(0.0, 1000.0, 1.0) var damage: float = 25.0
@export_range(8.0, 400.0, 1.0) var attack_range: float = 70.0
@export_range(0.0, 5.0, 0.01) var windup_time: float = 0.10
@export_range(0.01, 5.0, 0.01) var active_time: float = 0.12
@export_range(0.0, 5.0, 0.01) var recovery_time: float = 0.25
## Blade speed compared against ShieldComponent.velocity_threshold.
@export_range(1.0, 5000.0, 1.0) var attack_velocity: float = 400.0
## Movement allowed while this swing is committed.
@export_range(0.05, 1.0, 0.01) var move_speed_multiplier: float = 0.85
@export_range(0.0, 1000.0, 10.0) var noise_radius: float = 140.0


## True when a shield with this threshold lets the blade through.
func penetrates(velocity_threshold: float) -> bool:
	return attack_velocity <= velocity_threshold


func total_duration() -> float:
	return windup_time + active_time + recovery_time
