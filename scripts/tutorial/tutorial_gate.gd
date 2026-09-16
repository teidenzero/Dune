class_name TutorialGate
extends StaticBody2D
## Prototype section door. Closed it blocks the corridor and reads as solid;
## open it retracts into the jambs so the next section is visibly reachable.
## No interaction, keys, or animation system - the tutorial opens it.

@export var span: Vector2 = Vector2(36.0, 180.0)
@export var closed_color: Color = Color(0.29, 0.26, 0.31)
@export var open_color: Color = Color(0.29, 0.26, 0.31, 0.35)
@export var is_open: bool = false

@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("tutorial_gates")
	# Deliberately outside the navigation bake, which runs once at load: the
	# corridors must stay navigable so companions can follow through a gate the
	# player has already opened. A closed gate still blocks physically.
	_apply()


func open() -> void:
	if is_open:
		return
	is_open = true
	_apply()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_apply()


func _apply() -> void:
	if shape != null:
		shape.set_deferred("disabled", is_open)
	queue_redraw()


func _draw() -> void:
	var half: Vector2 = span * 0.5
	if is_open:
		# Retracted leaves: the doorway is visibly clear.
		draw_rect(Rect2(-half.x, -half.y - 14.0, span.x, 16.0), closed_color)
		draw_rect(Rect2(-half.x, half.y - 2.0, span.x, 16.0), closed_color)
		draw_rect(Rect2(-half, span), open_color, false, 2.0)
		return
	draw_rect(Rect2(-half, span), closed_color)
	draw_rect(Rect2(-half, span), Color(0.55, 0.5, 0.42), false, 2.0)
	for index in range(3):
		var y: float = -half.y + span.y * (index + 1) / 4.0
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(0.16, 0.14, 0.17), 2.0)
