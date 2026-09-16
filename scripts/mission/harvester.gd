class_name Harvester
extends StaticBody2D
## The spice crawler: the loudest thing in the desert, and the reason a worm
## eventually comes. It is a worm-sign emitter first and a set-piece second.

signal sabotage_progressed(done: int, total: int)
signal sabotaged

@export var running: bool = true
## Raised once sabotaged: a crippled crawler shakes far harder than a working one.
@export var sabotaged_sign: float = 9.0
@export var destroyed: bool = false

var sabotage_done: int = 0
var sabotage_total: int = 0
var is_sabotaged: bool = false

var _pulse: float = 0.0
var _smoke: float = 0.0
@onready var emitter: WormSignEmitter = $WormSignEmitter


func _ready() -> void:
	add_to_group("harvester")
	add_to_group("worm_machines")
	emitter.set_continuous(running)
	for point: Node in get_tree().get_nodes_in_group("sabotage_points"):
		sabotage_total += 1
		(point as InteractionPoint).interaction_completed.connect(_on_point_used)


func set_running(value: bool) -> void:
	running = value
	emitter.set_continuous(running)


func _on_point_used(_id: StringName) -> void:
	sabotage_done += 1
	sabotage_progressed.emit(sabotage_done, sabotage_total)
	if sabotage_done >= maxi(sabotage_total, 1) and not is_sabotaged:
		_break()


func _break() -> void:
	is_sabotaged = true
	# The crawler does not stop: it tears itself apart, and the desert hears it.
	emitter.continuous_sign = sabotaged_sign
	emitter.set_continuous(true)
	sabotaged.emit()
	queue_redraw()


func destroy() -> void:
	if destroyed:
		return
	destroyed = true
	set_running(false)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * (5.0 if is_sabotaged else 2.0), TAU)
	if is_sabotaged and not destroyed:
		_smoke = fmod(_smoke + delta, 4.0)
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if destroyed:
		for index in range(7):
			var angle: float = TAU * index / 7.0
			draw_circle(Vector2.RIGHT.rotated(angle) * (200.0 + index * 24.0), 70.0 + index * 12.0, Color(0.55, 0.45, 0.33, 0.28))
		_label(font, "HARVESTER DESTROYED", Color(0.75, 0.72, 0.68))
		return
	if running:
		var swell: float = 1.0 + 0.05 * sin(_pulse)
		for index in range(3):
			draw_arc(Vector2.ZERO, (300.0 + index * 70.0) * swell, 0, TAU, 40, Color(0.95, 0.75, 0.4, 0.16 - index * 0.04), 3.0, true)
	if is_sabotaged:
		for index in range(5):
			var offset: Vector2 = Vector2(-120.0 + index * 60.0, -150.0 - _smoke * 30.0 - index * 18.0)
			draw_circle(offset, 26.0 + _smoke * 9.0, Color(0.22, 0.19, 0.17, 0.32 - _smoke * 0.06))
		for index in range(4):
			var spark: Vector2 = Vector2(sin(_pulse * 3.0 + index) * 150.0, cos(_pulse * 2.0 + index) * 90.0)
			draw_circle(spark, 6.0, Color(1.0, 0.8, 0.35, 0.85))
	_label(font, "SPICE HARVESTER" if not is_sabotaged else "HARVESTER FAILING", Color(0.95, 0.82, 0.5) if is_sabotaged else Color(0.82, 0.8, 0.72))


func _label(font: Font, text: String, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var point: Vector2 = Vector2(-width * 0.5, -250)
	draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0.06, 0.05, 0.04))
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
