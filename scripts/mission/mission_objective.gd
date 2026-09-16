class_name MissionObjective
extends RefCounted
## One tracked mission goal. Data and state only: what it means is decided by
## the mission controller, so the same structure serves any later mission.

enum State { INACTIVE, ACTIVE, COMPLETE, FAILED }

var id: StringName = &""
var title: String = ""
var description: String = ""
var optional: bool = false
var state: State = State.INACTIVE
## Free-form progress text, e.g. "1 / 2", shown beside the title when set.
var progress: String = ""


static func create(id: StringName, title: String, description: String = "", optional: bool = false) -> MissionObjective:
	var objective: MissionObjective = MissionObjective.new()
	objective.id = id
	objective.title = title
	objective.description = description
	objective.optional = optional
	return objective


func is_required() -> bool:
	return not optional


func state_name() -> String:
	return State.keys()[state]


func display_title() -> String:
	return title if progress == "" else "%s  %s" % [title, progress]
