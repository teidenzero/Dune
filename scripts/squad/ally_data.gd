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

@export_group("Art")
## Squad-card portrait. Without one the card shows the class glyph.
@export var portrait: Texture2D
## Horizontal animation strips by name (idle, walk, run, crouch_walk,
## crouch_idle, aim, shoot, crouch_shoot, reload, hit, death). Without an
## "idle" strip the placeholder shapes are drawn. Missing ones fall back.
@export var sprite_sheets: Dictionary = {}
@export var sprite_frame_size: Vector2i = Vector2i(400, 336)
## Pixels from the top of a frame down to the soles of the feet.
@export var sprite_feet_y: float = 312.0
## On-screen figure height in world pixels (the body collider is ~26 across).
@export var sprite_world_height: float = 72.0
