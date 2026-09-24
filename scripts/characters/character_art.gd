class_name CharacterArt
extends Resource
## A character's drawn look: animation strips, squad-card portrait, and how
## the frames sit on the ground. Shared by Paul and the Fremen so every unit
## is dressed the same way. Frames face right; the engine flips them.

## Squad-card portrait. Without one the card shows the class glyph.
@export var portrait: Texture2D
## Horizontal animation strips by name (idle, walk, run, crouch_walk,
## crouch_idle, aim, shoot, crouch_shoot, reload, hit, death). Without an
## "idle" strip the placeholder shapes are drawn. Missing ones fall back.
@export var sheets: Dictionary = {}
@export var frame_size: Vector2i = Vector2i(400, 336)
## Pixels from the top of a frame down to the soles of the feet.
@export var feet_y: float = 312.0
## On-screen figure height in world pixels (the body collider is ~26 across).
@export var world_height: float = 72.0


func has_sprites() -> bool:
	return sheets.has("idle") and sheets["idle"] != null


## Builds the sprite for `actor` and returns it (not yet in the tree).
func make_sprite(actor: CharacterBody2D, walk_speed: float) -> UnitSprite:
	var sprite: UnitSprite = UnitSprite.new()
	sprite.name = "Sprite"
	sprite.walk_speed = walk_speed
	sprite.set_meta(&"art", self)
	return sprite


func apply_to(sprite: UnitSprite, actor: CharacterBody2D) -> void:
	sprite.setup(actor, sheets, frame_size, world_height, feet_y)
