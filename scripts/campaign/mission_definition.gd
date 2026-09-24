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
## Political approaches arrive with the Council of Factions milestone.
@export var political_available: bool = false


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
	if political_available:
		scopes.append(MissionOutcome.Scope.POLITICAL)
	if squad_scene != "":
		scopes.append(MissionOutcome.Scope.SQUAD)
	if solo_scene != "":
		scopes.append(MissionOutcome.Scope.SOLO)
	return scopes
