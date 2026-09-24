class_name CommunicationsBeacon
extends StaticBody2D
## Harkonnen comms mast. Disabling it is optional; it buys a quieter alarm.

signal beacon_disabled

@export var active: bool = true
var _pulse: float = 0.0
@onready var interaction: InteractionPoint = $Interaction


func _ready() -> void:
	add_to_group("communications_beacon")
	interaction.interaction_completed.connect(_on_used)


func _on_used(_id: StringName) -> void:
	disable()


func disable() -> void:
	if not active:
		return
	active = false
	interaction.enabled = false
	beacon_disabled.emit()
	queue_redraw()


func _process(delta: float) -> void:
	if active:
		_pulse = fmod(_pulse + delta * 2.2, TAU)
		queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if active:
		# A live mast reads from across the valley.
		for index in range(3):
			var radius: float = 44.0 + index * 34.0 + 10.0 * sin(_pulse - index * 0.7)
			draw_arc(Vector2.ZERO, radius, -PI * 0.85, -PI * 0.15, 20, Color(1.0, 0.55, 0.45, 0.35 - index * 0.09), 3.0, true)
	var text: String = "COMMS ACTIVE" if active else "COMMS DOWN"
	var color: Color = Color(1.0, 0.6, 0.45) if active else Color(0.6, 0.7, 0.72)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	IsoView.draw_text(self, font, Vector2.ZERO, Vector2(-width * 0.5, -96), text, 13, color, 4, Color(0.06, 0.06, 0.08))
