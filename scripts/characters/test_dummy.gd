extends StaticBody2D
## A practice target: a board on a post for the rifle, a padded dummy for the
## blade. Drawn from its painted art when present, standing up in the
## isometric view like any figure; the flat shapes remain as the fallback.

enum Look { BOARD, DUMMY }

const ART: Dictionary = {
	Look.BOARD: {"idle": "res://assets/environment/yard/target_board.png"},
	Look.DUMMY: {
		"idle": "res://assets/characters/training_dummy/training_dummy_idle.png",
		"hit": "res://assets/characters/training_dummy/training_dummy_hit.png",
		"broken": "res://assets/characters/training_dummy/training_dummy_broken.png",
	},
}
## The characters' cell, anchor and scale, so targets stand beside them true.
const FRAME: Vector2i = Vector2i(400, 336)
const FEET_Y: float = 312.0
const WORLD_HEIGHT: float = 72.0
const HIT_FPS: float = 12.0

@export var target_name: String = "TARGET"
@export var look: Look = Look.BOARD
@export_range(0.05, 1.0, 0.01) var hit_flash_duration: float = 0.16
## Seconds before a destroyed dummy stands back up; 0 keeps it down for good.
## The tutorial turns this on so a lesson can never lose its target.
@export var respawn_seconds: float = 0.0

var _flash: Tween
var _sway: Tween
var _art: Sprite2D
var _collision_layer: int = 2

@onready var health: HealthComponent = $HealthComponent
@onready var visuals: Node2D = $Visuals
@onready var status_label: Label = $Status


func _ready() -> void:
	add_to_group("iso_sorted")
	_dress()
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_on_health_changed(health.current_health, health.max_health)


## The painted target, feet on the ground, in place of the flat shapes.
func _dress() -> void:
	var idle: Texture2D = _texture("idle")
	if idle == null:
		return
	_art = Sprite2D.new()
	_art.name = "Art"
	var scale_to: float = WORLD_HEIGHT / float(FRAME.y)
	_art.scale = Vector2.ONE * scale_to
	_art.position = Vector2(0.0, 12.0 - (FEET_Y - FRAME.y * 0.5) * scale_to)
	visuals.add_child(_art)
	_show("idle")
	for part in ["Base", "Target", "Center"]:
		var shape: Node2D = visuals.get_node_or_null(part) as Node2D
		if shape != null:
			shape.visible = false


func _texture(state: String) -> Texture2D:
	var path: String = ART[look].get(state, "")
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null


## Shows a state's strip (falling back to idle); returns its frame count.
func _show(state: String) -> int:
	if _art == null:
		return 0
	var texture: Texture2D = _texture(state)
	if texture == null:
		texture = _texture("idle")
	_art.texture = texture
	_art.hframes = maxi(texture.get_width() / FRAME.x, 1)
	_art.frame = 0
	return _art.hframes


func _on_health_changed(current: float, maximum: float) -> void:
	status_label.text = "%s\n%.0f / %.0f HP" % [target_name, current, maximum]


func _on_damaged(_amount: float) -> void:
	if _flash != null:
		_flash.kill()
	visuals.modulate = Color(2.5, 2.5, 2.5)
	_flash = create_tween()
	_flash.tween_property(visuals, "modulate", Color.WHITE, hit_flash_duration)
	# The dummy rocks back on its post and returns.
	if _art != null and look == Look.DUMMY and not health.is_dead:
		if _sway != null:
			_sway.kill()
		var frames: int = _show("hit")
		_sway = create_tween()
		_sway.tween_property(_art, "frame", frames - 1, (frames - 1) / HIT_FPS).from(0)
		_sway.tween_interval(1.0 / HIT_FPS)
		_sway.tween_callback(func() -> void:
			if not health.is_dead:
				_show("idle"))


func _on_died() -> void:
	if _flash != null:
		_flash.kill()
	if _sway != null:
		_sway.kill()
	if _art != null and look == Look.DUMMY:
		# Crossbar snapped, torso split, still on its post.
		_show("broken")
		visuals.modulate = Color(0.8, 0.8, 0.8)
	else:
		visuals.modulate = Color(0.45, 0.45, 0.45)
		visuals.scale = Vector2(1.0, 0.25)
	status_label.text = "%s\nDESTROYED" % target_name
	_collision_layer = collision_layer if collision_layer != 0 else _collision_layer
	set_deferred("collision_layer", 0)
	$CollisionShape2D.set_deferred("disabled", true)
	if respawn_seconds > 0.0:
		get_tree().create_timer(respawn_seconds).timeout.connect(respawn)


## Back on its feet at full health, solid again.
func respawn() -> void:
	if not is_inside_tree() or not health.is_dead:
		return
	health.reset_health()
	visuals.scale = Vector2.ONE
	visuals.modulate = Color.WHITE
	_show("idle")
	collision_layer = _collision_layer
	$CollisionShape2D.disabled = false
	_on_health_changed(health.current_health, health.max_health)
