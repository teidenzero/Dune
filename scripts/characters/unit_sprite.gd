class_name UnitSprite
extends AnimatedSprite2D
## Drawn character art for a unit, built from named horizontal animation strips.
##
## The art is side-on, so it never rotates: it flips to face left or right and
## the unit's aim marker still shows the exact facing. The animation is picked
## every frame from what the unit is actually doing, highest priority first:
##
##   death > hit > reload > shoot / crouch_shoot > run / walk / crouch_walk
##   > aim > crouch_idle / idle
##
## Any strip that is missing falls back to the nearest one that exists, so a
## unit can ship with only idle and walk and gain the rest later.

## name: [fps, loops]
const PLAYBACK: Dictionary = {
	&"idle": [6.0, true], &"walk": [12.0, true], &"run": [14.0, true],
	&"crouch_walk": [10.0, true], &"crouch_idle": [5.0, true], &"aim": [6.0, true],
	&"shoot": [16.0, false], &"crouch_shoot": [16.0, false], &"reload": [7.0, false],
	&"hit": [12.0, false], &"death": [10.0, false],
}
const FALLBACK: Dictionary = {
	&"run": &"walk", &"crouch_walk": &"walk", &"crouch_idle": &"idle", &"aim": &"idle",
	&"crouch_shoot": &"shoot", &"shoot": &"aim", &"reload": &"aim", &"hit": &"idle", &"death": &"idle",
}
## Faster than this share of the unit's walking pace plays the run cycle.
const RUN_THRESHOLD: float = 1.25

var actor: CharacterBody2D
var walk_speed: float = 180.0
var _one_shot: StringName = &""
var _dead: bool = false


## `sheets` maps animation names to strips of `frame_size` frames. `feet_y` is
## where the soles sit inside a frame; the sprite is placed so they land
## `foot_offset` world pixels below the unit's centre.
func setup(owner_actor: CharacterBody2D, sheets: Dictionary, frame_size: Vector2i, world_height: float, feet_y: float, foot_offset: float = 12.0) -> void:
	actor = owner_actor
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for key in sheets:
		var name: StringName = StringName(key)
		var playback: Array = PLAYBACK.get(name, [10.0, true])
		_add_strip(frames, name, sheets[key], frame_size, playback[0], playback[1])
	sprite_frames = frames
	var base_scale: float = world_height / float(frame_size.y)
	scale = Vector2.ONE * base_scale
	centered = true
	position = Vector2(0.0, foot_offset - (feet_y - frame_size.y * 0.5) * base_scale)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	animation_finished.connect(_on_animation_finished)
	_bind_signals()
	_play(&"idle")


func _add_strip(frames: SpriteFrames, animation: StringName, strip: Texture2D, frame_size: Vector2i, fps: float, loop: bool) -> void:
	if strip == null:
		return
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
	var count: int = maxi(strip.get_width() / frame_size.x, 1)
	for index in range(count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(index * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame(animation, atlas)


func _bind_signals() -> void:
	var health: HealthComponent = HealthComponent.find_on(actor)
	if health != null:
		health.damaged.connect(func(_amount: float) -> void: _trigger(&"hit"))
		health.died.connect(_on_died)
	var weapon: WeaponController = actor.get_node_or_null("WeaponController") as WeaponController
	if weapon != null:
		weapon.weapon_fired.connect(func() -> void: _trigger(&"crouch_shoot" if _crouching() else &"shoot"))


## One-shot animations interrupt the state loop and hand back when they end.
func _trigger(animation: StringName) -> void:
	if _dead:
		return
	# A hit does not cut a shot short, and nothing cuts a hit short.
	if _one_shot == &"hit" and animation != &"hit":
		return
	_one_shot = animation
	_play(animation, true)


## A one-shot action played on demand (turn-based combat's shots and cuts).
func play_action(animation: StringName) -> void:
	_trigger(animation)


## Back on his feet: a rewound vision.
func revive() -> void:
	_dead = false
	_one_shot = &""
	_play(&"idle", true)


func _on_animation_finished() -> void:
	if not _dead:
		_one_shot = &""


func _on_died() -> void:
	_dead = true
	_one_shot = &""
	speed_scale = 1.0
	_play(&"death", true)


func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or _dead:
		return
	var speed: float = actor.velocity.length()
	var moving: bool = speed > 12.0
	_update_facing(moving)
	if _one_shot != &"":
		return
	var weapon: WeaponController = actor.get_node_or_null("WeaponController") as WeaponController
	var wanted: StringName
	speed_scale = 1.0
	if weapon != null and weapon.is_reloading:
		wanted = &"reload"
		# Stretch the reload to the weapon's real reload time.
		var frames: int = _frame_count(_resolve(&"reload"))
		var fps: float = sprite_frames.get_animation_speed(_resolve(&"reload"))
		speed_scale = (frames / maxf(fps, 0.1)) / maxf(weapon.weapon_data.reload_time, 0.1)
	elif moving:
		if _crouching():
			wanted = &"crouch_walk"
		elif speed > walk_speed * RUN_THRESHOLD:
			wanted = &"run"
		else:
			wanted = &"walk"
		# The cycle keeps pace with the ground actually covered.
		speed_scale = clampf(speed / maxf(walk_speed, 1.0), 0.6, 1.6) if wanted != &"run" else 1.0
	elif _in_combat():
		wanted = &"aim"
	else:
		wanted = &"crouch_idle" if _crouching() else &"idle"
	_play(wanted)


func _update_facing(moving: bool) -> void:
	var facing: Vector2 = actor.velocity if moving and not _in_combat() else Vector2.RIGHT.rotated(_aim_rotation())
	# Left or right as the player sees it, in the isometric view too.
	facing = IsoView.screen_direction(facing)
	if absf(facing.x) > 0.05:
		flip_h = facing.x < 0.0


func _play(wanted: StringName, restart: bool = false) -> void:
	var resolved: StringName = _resolve(wanted)
	if resolved == &"":
		return
	if restart or animation != resolved:
		play(resolved)
		if restart:
			frame = 0


## The requested animation, or the nearest one this unit actually has.
func _resolve(wanted: StringName) -> StringName:
	var name: StringName = wanted
	for step in range(4):
		if sprite_frames != null and sprite_frames.has_animation(name):
			return name
		name = FALLBACK.get(name, &"idle")
	return &"idle" if sprite_frames != null and sprite_frames.has_animation(&"idle") else &""


func _frame_count(name: StringName) -> int:
	return sprite_frames.get_frame_count(name) if sprite_frames != null and sprite_frames.has_animation(name) else 1


func _crouching() -> bool:
	return actor.get("is_crouching") == true


func _in_combat() -> bool:
	if actor.get("turn_based") == true:
		return true
	var ai: Node = actor.get("ai") as Node
	if ai != null and ai.get("behavior") != null:
		return ai.get("behavior") == AllyAIController.Behavior.COMBAT
	return actor.get("order") == PlayerController.Order.ATTACK


func _aim_rotation() -> float:
	var pivot: Node2D = actor.get_node_or_null("AimPivot") as Node2D
	return pivot.global_rotation if pivot != null else 0.0
