extends Node2D
## Read-only feedback for this observer; independent of F1 diagnostics.

@export var visible_threshold: float = 5.0
@onready var actor: EnemyCharacter = get_parent() as EnemyCharacter
@onready var label: Label = $State
var _fill: float = 0.0
var _color: Color = Color.WHITE


func _process(_delta: float) -> void:
	var perception: PerceptionComponent = actor.perception
	var investigating: bool = actor.ai.state in [EnemyAIController.State.SUSPICIOUS, EnemyAIController.State.INVESTIGATE, EnemyAIController.State.SEARCH]
	var combat: bool = actor.ai.state == EnemyAIController.State.COMBAT
	visible = not actor.health.is_dead and (perception.detection_value > visible_threshold or investigating or combat)
	if not visible:
		return
	_fill = clampf(perception.detection_value / maxf(perception.detection_max, 1.0), 0.0, 1.0)
	label.text = "NOTICING"
	_color = Color(0.95, 0.9, 0.65)
	if investigating or perception.perception_state == PerceptionComponent.Awareness.SUSPICIOUS:
		label.text = "? SUSPICIOUS"
		_color = Color(1.0, 0.78, 0.25)
	if perception.perception_state == PerceptionComponent.Awareness.ALERT:
		label.text = "! NEARLY DETECTED"
		_color = Color(1.0, 0.5, 0.15)
	if combat or perception.perception_state == PerceptionComponent.Awareness.DETECTED:
		label.text = "! DETECTED"
		_color = Color(1.0, 0.3, 0.2)
		if combat and is_instance_valid(actor.ai.target) and actor.ai.target.is_in_group("allies"):
			label.text = "! ENGAGING FREMEN"
	label.modulate = _color
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(label):
		var text_width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		draw_rect(Rect2(-text_width * 0.5 - 4, -75, text_width + 8, 18), Color(0.08, 0.09, 0.09, 0.92))
	draw_rect(Rect2(-36, -53, 72, 8), Color(0.08, 0.09, 0.09, 0.95))
	draw_rect(Rect2(-34, -51, 68 * _fill, 4), _color)
	draw_rect(Rect2(-36, -53, 72, 8), Color(0.95, 0.9, 0.8), false, 1.0)
