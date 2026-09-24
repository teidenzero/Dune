class_name AllyData
extends Resource

@export var display_name: String = "Fremen Scout"
@export var max_health: float = 80.0
@export var move_speed: float = 190.0
@export var preferred_combat_range: float = 320.0
@export var aggression_radius: float = 280.0
@export var follow_distance: float = 100.0
@export var catchup_distance: float = 210.0
@export var catchup_multiplier: float = 1.5
@export var attack_leash: float = 600.0
## Reconnaissance sight radius; the Scout is structurally the best scout.
@export var vision_radius: float = 650.0
@export var weapon_data: WeaponData
@export var body_color: Color = Color(0.28, 0.48, 0.4)

## Drawn look (sprites and portrait). Without it the placeholder shapes draw.
@export var art: CharacterArt
