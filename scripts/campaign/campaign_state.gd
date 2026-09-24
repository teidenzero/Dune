class_name CampaignState
extends RefCounted
## Everything that persists between missions: resources, faction standings,
## Harkonnen heat, and the record of what happened. Session-only for now; the
## save game arrives with the campaign loop.
##
## Missions never write here directly. They produce a MissionOutcome and the
## campaign applies it, once.

signal changed

const FACTIONS: Array[StringName] = [&"fremen", &"guild", &"choam", &"bene_gesserit", &"emperor", &"smugglers"]
const FACTION_NAMES: Dictionary = {
	&"fremen": "Fremen", &"guild": "Spacing Guild", &"choam": "CHOAM",
	&"bene_gesserit": "Bene Gesserit", &"emperor": "Emperor", &"smugglers": "Smugglers",
}
const RESOURCES: Array[StringName] = [&"spice", &"solari", &"water", &"intel", &"influence"]
const RESOURCE_NAMES: Dictionary = {
	&"spice": "Spice", &"solari": "Solari", &"water": "Water", &"intel": "Intel", &"influence": "Influence",
}
const STANDING_MIN: int = -2
const STANDING_MAX: int = 3
const STANDING_NAMES: Dictionary = {-2: "Hostile", -1: "Wary", 0: "Neutral", 1: "Friendly", 2: "Ally", 3: "Sworn"}
const HEAT_MAX: int = 10
## What House Atreides brings to Arrakis.
const STARTING_RESOURCES: Dictionary = {&"spice": 20, &"solari": 40, &"water": 10, &"intel": 3, &"influence": 2}

var resources: Dictionary = {}
var standings: Dictionary = {}
var heat: int = 0
var history: Array[MissionOutcome] = []
## Hero id -> HeroProgress: skills, ranks, spice saturation.
var progress: Dictionary = {}
## Lore found: entry id -> true. The Codex.
var codex: Dictionary = {}
## Carried items, by id: spice doses and whatever comes later.
var items: Dictionary = {}
## This mission's growth: gains per hero/skill (for the per-mission cap) and
## the lines the results screen shows.
var mission_gains: Dictionary = {}
var growth_log: PackedStringArray = []


func _init() -> void:
	reset()


func reset() -> void:
	resources.clear()
	standings.clear()
	for key in RESOURCES:
		resources[key] = int(STARTING_RESOURCES.get(key, 0))
	for key in FACTIONS:
		standings[key] = 0
	heat = 0
	history.clear()
	progress.clear()
	codex.clear()
	items = {&"spice_dose": 1}
	begin_mission()
	changed.emit()


## Applies a finished mission. Standings and heat clamp to their scales;
## resources never go below zero. `record` false is routine bookkeeping (a
## week's water) that changes the numbers but does not enter the chronicle.
func apply(outcome: MissionOutcome, record: bool = true) -> void:
	if outcome == null or history.has(outcome):
		return
	for key in outcome.resources:
		resources[key] = maxi(int(resources.get(key, 0)) + int(outcome.resources[key]), 0)
	for key in outcome.standings:
		standings[key] = clampi(int(standings.get(key, 0)) + int(outcome.standings[key]), STANDING_MIN, STANDING_MAX)
	heat = clampi(heat + outcome.heat, 0, HEAT_MAX)
	if record:
		history.append(outcome)
	changed.emit()


## A new mission (or tutorial) starts: its growth is counted afresh.
func begin_mission() -> void:
	mission_gains.clear()
	growth_log = PackedStringArray()


func hero_progress(hero: StringName) -> HeroProgress:
	if not progress.has(hero):
		progress[hero] = HeroProgress.create(hero)
	return progress[hero]


func item_count(id: StringName) -> int:
	return int(items.get(id, 0))


func add_item(id: StringName, amount: int = 1) -> void:
	items[id] = maxi(item_count(id) + amount, 0)
	changed.emit()


func standing(faction: StringName) -> int:
	return int(standings.get(faction, 0))


func standing_name(faction: StringName) -> String:
	return STANDING_NAMES.get(standing(faction), "Neutral")


func last_outcome(mission_id: StringName) -> MissionOutcome:
	for index in range(history.size() - 1, -1, -1):
		if history[index].mission_id == mission_id:
			return history[index]
	return null


## One line for menus: the numbers that changed from the start.
func summary() -> String:
	var parts: PackedStringArray = []
	for key in RESOURCES:
		if int(resources[key]) != 0:
			parts.append("%s %d" % [RESOURCE_NAMES[key], int(resources[key])])
	for key in FACTIONS:
		if standing(key) != 0:
			parts.append("%s %s" % [FACTION_NAMES[key], standing_name(key)])
	parts.append("Harkonnen heat %d / %d" % [heat, HEAT_MAX])
	return "  ·  ".join(parts)


static func faction_name(key: StringName) -> String:
	return FACTION_NAMES.get(key, String(key).capitalize())


static func resource_name(key: StringName) -> String:
	return RESOURCE_NAMES.get(key, String(key).capitalize())
