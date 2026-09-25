class_name MissionDefinition
extends Resource
## A mission as the campaign knows it, defined once for all three scopes
## (political, squad, solo). Each scope resolves the same objectives and hands
## back a MissionOutcome; the campaign reads nothing else.
##
## `stakes` maps an outcome tier name ("clean", "noisy", "partial", "failure")
## to its consequences:
##   { "resources": { &"spice": 20 }, "standings": { &"fremen": 1 }, "heat": 2 }

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var briefing: String = ""
## The faction whose interests this mission touches most.
@export var faction_at_stake: StringName = &""
@export var objectives: Array[ObjectiveDefinition] = []
@export var stakes: Dictionary = {}
@export_group("Scopes")
## Map scene for the squad scope (and, later, the solo scope).
@export_file("*.tscn") var squad_scene: String = ""
@export_file("*.tscn") var solo_scene: String = ""
## Ways to resolve the mission through the Council. The Political scope is
## available when there is at least one.
@export var political_approaches: Array[PoliticalApproach] = []
@export_group("Briefing")
## The pre-mission briefing. `briefing` above is the situation, read aloud;
## these add who gives it, where the story stands, and what the player needs
## to know to make a plan - the rules of this place, never the plan itself.
@export var heading: String = ""
## Background, in the narrator's voice: who is who, a little of the world.
@export_multiline var lore: String = ""
## What the objectives list is called ("WHAT YOU WILL PRACTISE" for training).
@export var objectives_caption: String = ""
## The party and quartermaster column; off for scenes with no field party
## (a council, a dinner).
@export var show_party: bool = true
@export var briefing_speaker: String = ""
## A story image (assets/ui/story/<name>.png) behind the briefing.
@export var briefing_image: String = ""
## What we know, one point each: for the squad scene, and for the solo scene.
@export var intel: PackedStringArray = []
@export var solo_intel: PackedStringArray = []


## The intel for the scene being played: the solo scene has its own.
func intel_for(scene_path: String) -> PackedStringArray:
	if scene_path != "" and scene_path == solo_scene and not solo_intel.is_empty():
		return solo_intel
	return intel if not intel.is_empty() else solo_intel


func has_briefing(scene_path: String) -> bool:
	return not intel_for(scene_path).is_empty()


func objective(id_wanted: StringName) -> ObjectiveDefinition:
	for item in objectives:
		if item.id == id_wanted:
			return item
	return null


func primary_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for item in objectives:
		if item.primary:
			ids.append(item.id)
	return ids


## Consequences for a tier, always with all three keys present.
func stakes_for(tier: MissionOutcome.Tier) -> Dictionary:
	var entry: Dictionary = stakes.get(MissionOutcome.tier_key(tier), {})
	return {
		"resources": entry.get("resources", {}),
		"standings": entry.get("standings", {}),
		"heat": int(entry.get("heat", 0)),
	}


func available_scopes() -> Array[MissionOutcome.Scope]:
	var scopes: Array[MissionOutcome.Scope] = []
	if not political_approaches.is_empty():
		scopes.append(MissionOutcome.Scope.POLITICAL)
	if squad_scene != "":
		scopes.append(MissionOutcome.Scope.SQUAD)
	if solo_scene != "":
		scopes.append(MissionOutcome.Scope.SOLO)
	return scopes
