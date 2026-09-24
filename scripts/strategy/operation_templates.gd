class_name OperationTemplates
extends RefCounted
## The kinds of side operation the map offers in Act II, the raid campaign:
## where each can appear, how hard it is, who is good at it, and what it does
## to the map when it succeeds or fails. Numbers live here so balance is in
## one place.

const RAID: StringName = &"raid"
const WATER: StringName = &"water"
const VILLAGE: StringName = &"village"
const AMBUSH: StringName = &"ambush"
const RECRUIT: StringName = &"recruit"
const PLANT: StringName = &"plant"
const DEFEND: StringName = &"defend"

const HARVESTER_RAID: String = "res://resources/missions/harvester_raid.tres"

const TEMPLATES: Dictionary = {
	RAID: {"title": "Raid a harvester", "base": 0.55, "fighters": 3, "water": 0, "weeks": 2,
		"briefing": "A Harkonnen crawler works the spice here. Cripple it and the worm does the rest.",
		"heroes": {&"paul": 0.1, &"stilgar": 0.1, &"chani": 0.05}},
	WATER: {"title": "Steal a water cache", "base": 0.6, "fighters": 2, "water": 0, "weeks": 2,
		"briefing": "The garrison keeps water it does not need. The sietch needs it.",
		"heroes": {&"chani": 0.15, &"jessica": 0.05}},
	VILLAGE: {"title": "Free a village", "base": 0.5, "fighters": 3, "water": 2, "weeks": 3,
		"briefing": "The pan villages bleed for Rabban's tax. Break the garrison's hold and the people remember who did it.",
		"heroes": {&"jessica": 0.15, &"paul": 0.1}},
	AMBUSH: {"title": "Ambush a patrol", "base": 0.6, "fighters": 3, "water": 0, "weeks": 2,
		"briefing": "A patrol runs this route on a schedule. Harkonnen are creatures of habit.",
		"heroes": {&"stilgar": 0.15, &"chani": 0.1}},
	RECRUIT: {"title": "Rally a sietch", "base": 0.65, "fighters": 0, "water": 3, "weeks": 3,
		"briefing": "The naib listens, but water speaks louder than words. Bring both.",
		"heroes": {&"stilgar": 0.2, &"jessica": 0.1, &"paul": 0.05}},
	PLANT: {"title": "Tend the plantings", "base": 0.75, "fighters": 1, "water": 4, "weeks": 3,
		"briefing": "Kynes's dream, one dew-collector at a time. Water in, green out.",
		"heroes": {&"chani": 0.1, &"stilgar": 0.05}},
	DEFEND: {"title": "Hold the sietch", "base": 0.55, "fighters": 4, "water": 0, "weeks": 1,
		"briefing": "Harkonnen troops are sweeping for this sietch. Meet them before they find the door.",
		"heroes": {&"stilgar": 0.15, &"paul": 0.1, &"jessica": 0.05}},
}


static func info(kind: StringName) -> Dictionary:
	return TEMPLATES.get(kind, {})


## Whether a kind of operation makes sense in this region right now.
static func fits(kind: StringName, region: RegionState) -> bool:
	var ground: ArrakisAtlas.Kind = ArrakisAtlas.kind(region.id)
	var harkonnen: bool = region.control == RegionState.Holder.HARKONNEN
	match kind:
		RAID:
			return harkonnen and region.harvesters > 0
		WATER:
			return harkonnen and ground in [ArrakisAtlas.Kind.CITY, ArrakisAtlas.Kind.ROCK, ArrakisAtlas.Kind.POLAR]
		VILLAGE:
			return harkonnen and ground == ArrakisAtlas.Kind.VILLAGE
		AMBUSH:
			return harkonnen and ground == ArrakisAtlas.Kind.ROCK
		RECRUIT:
			return ground == ArrakisAtlas.Kind.SIETCH and region.control == RegionState.Holder.FREMEN
		PLANT:
			return region.control == RegionState.Holder.FREMEN and ground in [ArrakisAtlas.Kind.SAND, ArrakisAtlas.Kind.HIDDEN]
	return false


static func build(kind: StringName, region: RegionState) -> StrategicOperation:
	var data: Dictionary = info(kind)
	var op: StrategicOperation = StrategicOperation.new()
	op.kind = kind
	op.region = region.id
	op.title = data.get("title", String(kind))
	op.briefing = data.get("briefing", "")
	op.fighters = data.get("fighters", 2)
	op.water_cost = data.get("water", 0)
	op.weeks_left = data.get("weeks", 2)
	if kind == RAID:
		op.mission_path = HARVESTER_RAID
	return op


## Odds of an order succeeding: the kind's base, the leader's knack, the
## Harkonnen grip, and the storm (which hides whoever moves inside it).
static func chance(op: StrategicOperation, region: RegionState, leader: StringName) -> float:
	var data: Dictionary = info(op.kind)
	var value: float = data.get("base", 0.5)
	value += (data.get("heroes", {}) as Dictionary).get(leader, 0.0)
	value -= 0.06 * maxi(region.grip - 1, 0)
	if region.storm:
		value += 0.1
	return clampf(value, 0.1, 0.95)
