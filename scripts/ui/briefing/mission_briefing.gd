class_name MissionBriefing
extends Node
## The briefing for a scene that has no MissionManager of its own: the
## trainings, the Council lesson, the Banquet. Launched on purpose, the scene
## opens on it with the world paused from its first frame; I reopens it.
## (Missions proper get the same from their MissionManager.)

signal shown

@export var definition: MissionDefinition
## Set when the scene is a code-built screen with no file of its own.
@export var scene_path: String = ""
var opened_at_start: bool = false


func _ready() -> void:
	add_to_group("mission_briefing")
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game: Node = get_node_or_null("/root/GameManager")
	if game == null or not game.pending_briefing:
		return
	game.pending_briefing = false
	if has_briefing():
		opened_at_start = true
		get_tree().paused = true
		call_deferred("show_briefing", true)


func has_briefing() -> bool:
	return definition != null and definition.has_briefing(_path())


func show_briefing(at_start: bool = false) -> BriefingScreen:
	if not has_briefing() or get_tree().get_first_node_in_group("briefing_screen") != null:
		return null
	var screen: BriefingScreen = BriefingScreen.open(definition, get_parent(), _path(), at_start)
	shown.emit()
	return screen


func _path() -> String:
	if scene_path != "":
		return scene_path
	return owner.scene_file_path if owner != null else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("show_briefing") and not event.is_echo() and has_briefing():
		get_viewport().set_input_as_handled()
		show_briefing()
