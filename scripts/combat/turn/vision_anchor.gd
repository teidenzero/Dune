class_name VisionAnchor
extends Node2D
## The hero as he really stands while a prescient vision plays out. The body
## that walks and fights in the vision is shown as a blue shadow; this is a
## still copy of him left where the vision began. Accepting the future slides
## him into his shadow; taking it back simply removes the shadow's story.

const SHADOW: Color = Color(0.6, 0.88, 1.7, 0.58)

var hero: PlayerController
var _sprite: AnimatedSprite2D


## Leave a copy of `player` where he stands and turn him into his shadow.
static func leave(player: PlayerController, parent: Node) -> VisionAnchor:
	var anchor: VisionAnchor = VisionAnchor.new()
	anchor.name = "VisionAnchor"
	anchor.hero = player
	anchor.position = player.global_position
	parent.add_child(anchor)
	anchor._copy_look()
	player.modulate = SHADOW
	return anchor


func _copy_look() -> void:
	var source: AnimatedSprite2D = hero.get_node_or_null("Sprite") as AnimatedSprite2D
	if source != null and source.sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = source.sprite_frames
		_sprite.animation = source.animation
		_sprite.frame = source.frame
		_sprite.flip_h = source.flip_h
		_sprite.centered = source.centered
		_sprite.offset = source.offset
		_sprite.position = source.position
		_sprite.scale = source.scale
		_sprite.texture_filter = source.texture_filter
		add_child(_sprite)
		# Standing still, as he is.
		var idle: StringName = &"crouch_idle" if hero.is_crouching else &"idle"
		if _sprite.sprite_frames.has_animation(idle):
			_sprite.play(idle)
		return
	# No drawn art: the placeholder body.
	for part in ["Body", "Hood"]:
		var shape: Polygon2D = hero.get_node_or_null(part) as Polygon2D
		if shape != null:
			var copy: Polygon2D = shape.duplicate(0) as Polygon2D
			add_child(copy)


## Future accepted: the hero steps into his shadow, and the two are one.
func reunite() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", hero.global_position, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_property(hero, "modulate", Color.WHITE, 0.35)
	tween.chain().tween_callback(queue_free)


## Future taken back: the shadow was never real.
func dissolve() -> void:
	hero.modulate = Color.WHITE
	queue_free()
