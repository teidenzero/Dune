class_name StrategicOperation
extends RefCounted
## Something to do on the map this week: a raid on a harvester, a village to
## free, a sietch to rally. A hero leads it. Some can be played as a mission
## (Squad, Solo or the Council); every one can be sent as an order and
## resolved at the end of the week.

enum Status { OPEN, ORDERED, IN_PLAY, SUCCEEDED, FAILED, EXPIRED }

var id: int = 0
var kind: StringName = &""
var region: StringName = &""
var title: String = ""
var briefing: String = ""
## A story mission: gold on the map, never expires.
var story: bool = false
var story_code: String = ""
## Playable as a mission through this definition; empty means orders only.
var mission_path: String = ""
var weeks_left: int = 2
## Fremen fighters committed; some are lost if it goes badly.
var fighters: int = 2
var water_cost: int = 0
var status: Status = Status.OPEN
var leader: StringName = &""
## What happened, for the week's report.
var result_text: String = ""


func is_open() -> bool:
	return status == Status.OPEN or status == Status.ORDERED


func playable() -> bool:
	return mission_path != ""


func definition() -> MissionDefinition:
	return load(mission_path) as MissionDefinition if playable() else null


func status_name() -> String:
	return ["OPEN", "ORDERED", "UNDER WAY", "SUCCEEDED", "FAILED", "EXPIRED"][status]
