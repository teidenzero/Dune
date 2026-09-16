class_name WeaponData
extends Resource

@export var weapon_name: String = "Maula Pistol"
@export_range(0.0, 1000.0, 1.0) var damage: float = 30.0
@export_range(0.1, 60.0, 0.1) var fire_rate: float = 3.0
@export_range(1, 100, 1) var magazine_size: int = 8
@export_range(0.01, 30.0, 0.01) var reload_time: float = 1.25
@export_range(1.0, 10000.0, 1.0) var projectile_speed: float = 900.0
@export_range(0.01, 30.0, 0.01) var projectile_lifetime: float = 1.5
@export_range(0.0, 180.0, 0.1) var spread_degrees: float = 1.5
@export var automatic: bool = false
@export_range(0.0, 2000.0, 10.0) var noise_radius: float = 650.0
@export_range(0.0, 1000.0, 10.0) var impact_noise_radius: float = 220.0
## Desert vibration, separate from enemy hearing: a shot is both a sound a guard
## can hear and a shock the sand feels, and the two travel by different rules.
@export_range(0.0, 100.0, 0.5) var worm_sign_shot: float = 4.0
@export_range(0.0, 100.0, 0.5) var worm_sign_impact: float = 6.0
