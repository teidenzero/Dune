class_name TutorialTriggerArea
extends Area2D
## Reusable tutorial volume. It only reports that the player reached it; the
## manager decides what that means for the current step.

signal player_entered(id: StringName)
signal player_exited(id: StringName)

@export var id: StringName = &"trigger"
## Reports once per entry unless re-armed by the manager.
@export var one_shot: bool = false

var triggered: bool = false


func _ready() -> void:
	add_to_group("tutorial_triggers")
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func rearm() -> void:
	triggered = false


func contains_player() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or (one_shot and triggered):
		return
	triggered = true
	player_entered.emit(id)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_exited.emit(id)
