class_name ObjectiveDefinition
extends Resource
## One mission goal as authored data. The id is shared by every scope, so a
## political operation and a squad raid can both report "sabotage: complete".

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var optional: bool = false
## Primary objectives decide whether the mission's purpose was achieved; the
## rest (escape, survival) decide how cleanly.
@export var primary: bool = false


func to_objective() -> MissionObjective:
	return MissionObjective.create(id, title, description, optional)
