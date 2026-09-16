class_name InteractionPoint
extends Area2D
## Hold-to-use point: the beacon, a sabotage panel, anything the player has to
## stand still at for a moment. No minigame - the cost is the exposure.
##
## Usable during combat on purpose. Whether to risk standing here while being
## shot at is the decision.

signal interaction_started
signal interaction_progress(ratio: float)
signal interaction_cancelled(reason: String)
signal interaction_completed(id: StringName)

@export var id: StringName = &"interaction"
@export var label: String = "USE"
@export var hold_seconds: float = 2.0
@export var interact_radius: float = 110.0
@export var enabled: bool = true
@export var one_shot: bool = true
## Taking a hit breaks concentration; the player can simply start again.
@export var interrupt_on_damage: bool = true

var used: bool = false
var holding: bool = false
var progress: float = 0.0

var _player: PlayerController
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group("interaction_points")
	monitoring = false
	z_index = 2
	call_deferred("_bind")


func _bind() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	if is_instance_valid(_player) and interrupt_on_damage:
		_player.health.damaged.connect(_on_player_damaged)


func available() -> bool:
	return enabled and not (one_shot and used)


func player_in_range() -> bool:
	if not is_instance_valid(_player) or _player.health.is_dead:
		return false
	return _player.global_position.distance_to(global_position) <= interact_radius


func ratio() -> float:
	return clampf(progress / maxf(hold_seconds, 0.05), 0.0, 1.0)


func cancel(reason: String = "INTERRUPTED") -> void:
	if not holding:
		return
	holding = false
	progress = 0.0
	interaction_cancelled.emit(reason)


func _on_player_damaged(_amount: float) -> void:
	cancel("UNDER FIRE")


func _physics_process(delta: float) -> void:
	if not available():
		if holding:
			cancel("UNAVAILABLE")
		return
	var wants: bool = InputMap.has_action("interact") and Input.is_action_pressed("interact") and player_in_range()
	if not wants:
		if holding:
			cancel("RELEASED")
		return
	if not holding:
		holding = true
		progress = 0.0
		interaction_started.emit()
	progress += delta
	interaction_progress.emit(ratio())
	if progress >= hold_seconds:
		holding = false
		progress = 0.0
		used = true
		interaction_completed.emit(id)


## Development shortcut so tests and debug controls do not have to simulate a
## two-second hold at a specific spot.
func force_complete() -> void:
	if not available():
		return
	holding = false
	progress = 0.0
	used = true
	interaction_completed.emit(id)


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 2.0, TAU)
	queue_redraw()


func _draw() -> void:
	if not available():
		return
	var font: Font = ThemeDB.fallback_font
	var near: bool = player_in_range()
	var swell: float = 1.0 + 0.06 * sin(_pulse)
	draw_arc(Vector2.ZERO, 34.0 * swell, 0, TAU, 32, Color(0.6, 0.95, 1.0, 0.7 if near else 0.3), 2.0, true)
	if holding:
		draw_arc(Vector2.ZERO, 42.0, -PI * 0.5, -PI * 0.5 + TAU * ratio(), 32, Color(1.0, 0.85, 0.4), 5.0, true)
	if not near:
		return
	var text: String = "[F] %s" % label
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var point: Vector2 = Vector2(-width * 0.5, -52.0)
	draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0.05, 0.07, 0.08))
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.97, 1.0))
