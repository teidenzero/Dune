class_name SpiceMachine
extends StaticBody2D
## A standing vibration source. Right-clicking it sends Paul to toggle it, which is what
## makes threat escalation observable without anyone moving.

signal machine_toggled(running: bool)

@export var running: bool = false
@export var interact_radius: float = 150.0
@export var machine_name: String = "SPICE RIG"

var _pulse: float = 0.0
@onready var emitter: WormSignEmitter = $WormSignEmitter


func _ready() -> void:
	add_to_group("worm_machines")
	emitter.set_continuous(running)


func set_running(value: bool) -> void:
	if running == value:
		return
	running = value
	emitter.set_continuous(running)
	machine_toggled.emit(running)


func toggle() -> void:
	set_running(not running)


func player_in_range() -> bool:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	return is_instance_valid(player) and player.global_position.distance_to(global_position) <= interact_radius


func _process(delta: float) -> void:
	if running:
		_pulse = fmod(_pulse + delta * 6.0, TAU)
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if running:
		# Visible shudder, so a running rig reads as the loud thing it is.
		var swell: float = 1.0 + 0.08 * sin(_pulse)
		for index in range(3):
			draw_arc(Vector2.ZERO, (70.0 + index * 34.0) * swell, 0, TAU, 32, Color(0.95, 0.72, 0.35, 0.28 - index * 0.07), 3.0, true)
	var label: String = "%s: %s" % [machine_name, "RUNNING" if running else "IDLE"]
	if player_in_range():
		label += "   RIGHT-CLICK"
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(font, Vector2(-width * 0.5, -78), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.08, 0.07, 0.05))
	draw_string(font, Vector2(-width * 0.5, -78), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.82, 0.5) if running else Color(0.78, 0.76, 0.7))
