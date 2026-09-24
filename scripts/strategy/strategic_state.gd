class_name StrategicState
extends RefCounted
## The strategic layer: Arrakis week by week. First pass, Act II, the raid
## campaign. The Fremen strangle Harkonnen spice until the Emperor can no
## longer ignore it.
##
## Each week: the player orders operations (a hero leads each) or plays them
## as missions; then end_week() resolves the orders, moves the storm, lets
## the worms feed, counts Harkonnen spice against Rabban's quota, and lets
## the Harkonnen answer. Resources, standings and heat live in CampaignState
## and change only through MissionOutcome, as everywhere else.

signal changed

const QUOTA: int = 70
const ATTENTION_MAX: float = 100.0
const OPEN_SIDE_OPERATIONS: int = 4
const WOUNDED_WEEKS: int = 2
## Act II's leaders. Gurney joins at 2.6 once that mission exists.
const HEROES: Array[StringName] = [&"paul", &"jessica", &"stilgar", &"chani"]
const HERO_PATHS: Dictionary = {
	&"paul": "res://resources/heroes/paul.tres", &"jessica": "res://resources/heroes/jessica.tres",
	&"stilgar": "res://resources/heroes/stilgar.tres", &"chani": "res://resources/heroes/chani.tres",
}

## Act II's story, in order. Built ones can be played; the rest are shown so
## the player sees where the act is going.
const STORY: Array[Dictionary] = [
	{"code": "2.1", "title": "Into the Storm"},
	{"code": "2.2", "title": "Tahaddi"},
	{"code": "2.3", "title": "The Way of the Desert"},
	{"code": "2.4", "title": "Water of Life"},
	{"code": "2.5", "title": "First Raids", "region": &"funeral_plain", "mission": OperationTemplates.HARVESTER_RAID,
		"briefing": "Stilgar's fighters have never struck a crawler under Paul. Strike this one, and let the Harkonnen learn what the desert can do."},
	{"code": "2.6", "title": "The Smuggler's Crawler"},
	{"code": "2.7", "title": "The Judge of the Change"},
	{"code": "2.8", "title": "The Water of Life, Drunk"},
]

var act: int = 2
var week: int = 1
var regions: Dictionary = {}
var operations: Array[StrategicOperation] = []
## Fremen fighters the sietches can put in the field.
var fighters: int = 20
var attention: float = 0.0
var greening: float = 0.0
var production: int = 0
var wounded: Dictionary = {}
var story_done: Dictionary = {}
var act_complete: bool = false
var report: PackedStringArray = []
var campaign: CampaignState
## An operation being played as a mission; its outcome is read on return.
var pending_op: int = -1
var pending_history: int = 0
var storm_phase: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _next_id: int = 1


static func new_act_two(state_campaign: CampaignState, seed_value: int = -1) -> StrategicState:
	var state: StrategicState = StrategicState.new()
	state.campaign = state_campaign
	if seed_value >= 0:
		state.rng.seed = seed_value
	else:
		state.rng.randomize()
	state._seed_regions()
	state._move_storm()
	state.production = state._count_production()
	state.generate_operations()
	state.report = PackedStringArray(["Two years of raids begin. Rabban must send %d spice a week to Carthag; every week he falls short, the Emperor looks closer." % QUOTA])
	return state


func _seed_regions() -> void:
	var H: RegionState.Holder = RegionState.Holder.HARKONNEN
	var F: RegionState.Holder = RegionState.Holder.FREMEN
	var S: RegionState.Holder = RegionState.Holder.SMUGGLERS
	var seeds: Array = [
		[&"polar_sink", H, 3, 0], [&"arrakeen", H, 4, 0], [&"carthag", H, 5, 0], [&"imperial_basin", H, 3, 0],
		[&"shield_wall", H, 2, 0], [&"old_gap", H, 2, 0], [&"tuono_basin", H, 3, 0], [&"harg_pass", H, 1, 0],
		[&"funeral_plain", H, 2, 3], [&"great_flat", H, 3, 4], [&"cielago", H, 1, 2], [&"wind_pass", S, 0, 0],
		[&"broken_land", S, 0, 0], [&"cave_of_birds", F, 0, 0], [&"false_wall", F, 0, 0], [&"sietch_tabr", F, 0, 0],
		[&"red_chasm", F, 0, 0], [&"deep_desert", F, 0, 0], [&"plaster_basin", F, 0, 0], [&"habbanya_ridge", F, 0, 0],
		[&"southern_gardens", F, 0, 0],
	]
	for entry in seeds:
		regions[entry[0]] = RegionState.create(entry[0], entry[1], entry[2], entry[3])


func region(id: StringName) -> RegionState:
	return regions.get(id)


func hero(id: StringName) -> HeroDefinition:
	return load(HERO_PATHS.get(id, "")) as HeroDefinition if HERO_PATHS.has(id) else null


func operation(op_id: int) -> StrategicOperation:
	for op in operations:
		if op.id == op_id:
			return op
	return null


func open_operations() -> Array[StrategicOperation]:
	var result: Array[StrategicOperation] = []
	for op in operations:
		if op.is_open():
			result.append(op)
	return result


# --------------------------------------------------------------------------
# Operations
# --------------------------------------------------------------------------

## Keep the board stocked: the next story mission, and a handful of side
## operations wherever they fit.
func generate_operations() -> void:
	for entry in STORY:
		if entry.has("mission") and not story_done.has(entry.code) and not _has_story(entry.code):
			_add_story(entry)
	var kinds: Array[StringName] = [OperationTemplates.WATER, OperationTemplates.VILLAGE, OperationTemplates.AMBUSH, OperationTemplates.RECRUIT, OperationTemplates.PLANT]
	# The raid campaign opens once the first raid has been struck.
	if story_done.has("2.5"):
		kinds.append(OperationTemplates.RAID)
		kinds.append(OperationTemplates.RAID)
	var attempts: int = 0
	while _side_count() < OPEN_SIDE_OPERATIONS and attempts < 60:
		attempts += 1
		var kind: StringName = kinds[rng.randi_range(0, kinds.size() - 1)]
		var candidates: Array[StringName] = []
		for id: StringName in regions:
			var state: RegionState = regions[id]
			if OperationTemplates.fits(kind, state) and not _taken(id):
				candidates.append(id)
		if candidates.is_empty():
			continue
		_add(OperationTemplates.build(kind, regions[candidates[rng.randi_range(0, candidates.size() - 1)]]))


func _add(op: StrategicOperation) -> StrategicOperation:
	op.id = _next_id
	_next_id += 1
	operations.append(op)
	return op


func _add_story(entry: Dictionary) -> void:
	var op: StrategicOperation = StrategicOperation.new()
	op.kind = &"story"
	op.story = true
	op.story_code = entry.code
	op.title = "%s  %s" % [entry.code, entry.title]
	op.briefing = entry.get("briefing", "")
	op.region = entry.get("region", &"sietch_tabr")
	op.mission_path = entry.get("mission", "")
	op.fighters = 3
	op.weeks_left = 99
	_add(op)


func _has_story(code: String) -> bool:
	for op in operations:
		if op.story and op.story_code == code and op.is_open():
			return true
	return false


func _side_count() -> int:
	var count: int = 0
	for op in operations:
		if op.is_open() and not op.story:
			count += 1
	return count


func _taken(id: StringName) -> bool:
	for op in operations:
		if op.is_open() and op.region == id:
			return true
	return false


## Heroes free to lead this week: not wounded, and not already leading
## (or back from leading) an operation this week.
func available_heroes() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in HEROES:
		if int(wounded.get(id, 0)) > 0:
			continue
		var busy: bool = false
		for op in operations:
			if op.leader == id and op.status != StrategicOperation.Status.OPEN and op.status != StrategicOperation.Status.EXPIRED:
				busy = true
		if not busy:
			result.append(id)
	return result


## Fighters not already committed to this week's orders.
func free_fighters() -> int:
	var committed: int = 0
	for op in operations:
		if op.status == StrategicOperation.Status.ORDERED:
			committed += op.fighters
	return fighters - committed


## Why an operation cannot go ahead with this leader, or "" if it can.
func blocked(op: StrategicOperation, leader: StringName) -> String:
	if not op.is_open():
		return "Already settled"
	if leader == &"" or not available_heroes().has(leader):
		return "Choose a leader who is free"
	if region(op.region).storm and not op.story:
		return "The storm is on it this week"
	if free_fighters() < op.fighters:
		return "Not enough fighters"
	if int(campaign.resources.get(&"water", 0)) < op.water_cost:
		return "Not enough water"
	return ""


func odds(op: StrategicOperation, leader: StringName) -> float:
	return OperationTemplates.chance(op, region(op.region), leader)


## Send it as an order: resolved at the end of the week.
func order(op: StrategicOperation, leader: StringName) -> bool:
	if blocked(op, leader) != "":
		return false
	op.status = StrategicOperation.Status.ORDERED
	op.leader = leader
	changed.emit()
	return true


func cancel(op: StrategicOperation) -> void:
	if op.status == StrategicOperation.Status.ORDERED:
		op.status = StrategicOperation.Status.OPEN
		op.leader = &""
		changed.emit()


## Play it as a mission. The outcome is read back when the map room returns.
func launch(op: StrategicOperation, leader: StringName) -> bool:
	if not op.playable() or not op.is_open():
		return false
	if leader == &"" or not available_heroes().has(leader):
		return false
	op.status = StrategicOperation.Status.IN_PLAY
	op.leader = leader
	pending_op = op.id
	pending_history = campaign.history.size()
	changed.emit()
	return true


## Back from a mission: apply what it did to the map. An abandoned mission
## (no new outcome recorded) leaves the operation open.
func absorb_mission_result() -> String:
	var op: StrategicOperation = operation(pending_op)
	pending_op = -1
	if op == null:
		return ""
	if campaign.history.size() <= pending_history:
		op.status = StrategicOperation.Status.OPEN
		op.leader = &""
		changed.emit()
		return ""
	var outcome: MissionOutcome = campaign.history[campaign.history.size() - 1]
	var success: bool = outcome.tier == MissionOutcome.Tier.CLEAN or outcome.tier == MissionOutcome.Tier.NOISY
	var partial: bool = outcome.tier == MissionOutcome.Tier.PARTIAL
	for name in outcome.heroes_wounded:
		_wound_by_name(name)
	var text: String = _settle(op, success or partial, outcome.tier == MissionOutcome.Tier.CLEAN, false)
	if op.story and (success or partial):
		story_done[op.story_code] = outcome.tier
		generate_operations()
	report.append(text)
	changed.emit()
	return text


# --------------------------------------------------------------------------
# The week
# --------------------------------------------------------------------------

func end_week() -> PackedStringArray:
	report = PackedStringArray()
	for op in operations.duplicate():
		if op.status == StrategicOperation.Status.ORDERED:
			var success: bool = rng.randf() < odds(op, op.leader)
			report.append(_settle(op, success, success and rng.randf() < 0.4, true))
	for op in operations:
		if op.status == StrategicOperation.Status.OPEN and not op.story:
			op.weeks_left -= 1
			if op.weeks_left <= 0:
				op.status = StrategicOperation.Status.EXPIRED
				if op.kind == OperationTemplates.DEFEND:
					report.append(_sietch_falls(op))
	_move_storm()
	_worms()
	_harkonnen_turn()
	_fremen_turn()
	for id in wounded.keys():
		wounded[id] = maxi(int(wounded[id]) - 1, 0)
	week += 1
	operations = operations.filter(func(op: StrategicOperation) -> bool: return op.is_open())
	generate_operations()
	if attention >= ATTENTION_MAX and not act_complete:
		act_complete = true
		report.append("THE EMPEROR MOVES. Rabban's spice has failed too long. Sardaukar are coming to Arrakis - Act III begins.")
	changed.emit()
	return report


## What an operation did to the map, and to the campaign when it was an
## order (a played mission has already reported to the campaign itself).
func _settle(op: StrategicOperation, success: bool, clean: bool, as_order: bool) -> String:
	var state: RegionState = region(op.region)
	var place: String = state.title()
	var leader: HeroDefinition = hero(op.leader)
	var who: String = leader.display_name if leader != null else "The Fremen"
	var effects: Dictionary = {"resources": {}, "standings": {}, "heat": 0}
	var text: String = ""
	var lost: int = 0
	if op.water_cost > 0 and as_order:
		effects.resources[&"water"] = -op.water_cost
	var kind: StringName = op.kind if not op.story else OperationTemplates.RAID
	match kind:
		OperationTemplates.RAID:
			if success:
				var wrecked: int = mini(2 if clean else 1, state.harvesters)
				state.harvesters -= wrecked
				state.rebuild_wait = 3
				state.worm_sign = minf(state.worm_sign + 30.0, RegionState.WORM_MAX)
				_gain(effects, &"spice", 8)
				_stand(effects, &"fremen", 1 if clean else 0)
				effects.heat = 0 if clean else 1
				text = "%s's raid on %s: %d harvester%s crippled." % [who, place, wrecked, "" if wrecked == 1 else "s"]
			else:
				lost = 2
				state.grip = mini(state.grip + 1, RegionState.GRIP_MAX)
				effects.heat = 1
				text = "The raid on %s failed. The Harkonnen are on alert." % place
		OperationTemplates.WATER:
			if success:
				_gain(effects, &"water", 6)
				effects.heat = 0 if clean else 1
				text = "%s's band brings back six literjons from %s." % [who, place]
			else:
				lost = 1
				state.grip = mini(state.grip + 1, RegionState.GRIP_MAX)
				text = "The water raid at %s was driven off." % place
		OperationTemplates.VILLAGE:
			if success:
				state.grip = maxi(state.grip - 2, 0)
				if state.grip == 0:
					state.control = RegionState.Holder.FREMEN
				fighters += 3
				_stand(effects, &"fremen", 1)
				effects.heat = 1
				text = "%s: the garrison at %s is broken%s. Three young fighters follow us home." % [who, place, " and the villages are ours" if state.grip == 0 else ""]
			else:
				lost = 2
				state.grip = mini(state.grip + 1, RegionState.GRIP_MAX)
				text = "The rising at %s failed. Rabban will make the villages pay." % place
		OperationTemplates.AMBUSH:
			if success:
				state.grip = maxi(state.grip - 1, 0)
				if state.grip == 0:
					state.control = RegionState.Holder.FREMEN
				_gain(effects, &"solari", 6)
				effects.heat = 1
				text = "%s's ambush at %s: a patrol gone, their weapons ours." % [who, place]
			else:
				lost = 2
				text = "The patrol at %s was ready for us." % place
		OperationTemplates.RECRUIT:
			if success:
				fighters += 5
				_stand(effects, &"fremen", 1)
				text = "%s rallies %s: five more fighters." % [who, place]
			else:
				text = "The naib of %s took our water and gave nothing." % place
		OperationTemplates.PLANT:
			greening += 6.0 if success else 1.0
			text = "The plantings at %s %s." % [place, "take hold" if success else "barely survive"]
		OperationTemplates.DEFEND:
			if success:
				effects.heat = -1
				lost = 1
				text = "%s turns the Harkonnen sweep away from %s." % [who, place]
			else:
				return _sietch_falls(op)
	fighters = maxi(fighters - lost, 0)
	if lost > 0:
		text += "  (%d fighter%s lost)" % [lost, "" if lost == 1 else "s"]
	op.status = StrategicOperation.Status.SUCCEEDED if success else StrategicOperation.Status.FAILED
	op.result_text = text
	if as_order:
		_apply(op, effects, success)
	return text


func _sietch_falls(op: StrategicOperation) -> String:
	var place: String = region(op.region).title()
	fighters = maxi(fighters - 4, 0)
	greening = maxf(greening - 3.0, 0.0)
	var effects: Dictionary = {"resources": {&"water": -3}, "standings": {&"fremen": -1}, "heat": 0}
	_apply(op, effects, false)
	op.status = StrategicOperation.Status.FAILED
	return "The Harkonnen found %s. Four fighters dead, the water stores burnt." % place


## Orders report to the campaign the same way missions do.
func _apply(op: StrategicOperation, effects: Dictionary, success: bool) -> void:
	var record: MissionOutcome = MissionOutcome.new()
	record.mission_id = StringName("op_%s" % op.kind)
	record.scopes.append(MissionOutcome.Scope.POLITICAL)
	record.tier = MissionOutcome.Tier.CLEAN if success else MissionOutcome.Tier.FAILURE
	record.resources = effects.resources
	record.standings = effects.standings
	record.heat = effects.heat
	campaign.apply(record)


func _gain(effects: Dictionary, resource: StringName, amount: int) -> void:
	effects.resources[resource] = int(effects.resources.get(resource, 0)) + amount


func _stand(effects: Dictionary, faction: StringName, amount: int) -> void:
	if amount != 0:
		effects.standings[faction] = int(effects.standings.get(faction, 0)) + amount


func _wound_by_name(name: String) -> void:
	for id in HEROES:
		var data: HeroDefinition = hero(id)
		if data != null and data.display_name.begins_with(name):
			wounded[id] = WOUNDED_WEEKS


## The storm band's centre, in latitude (0 north pole .. 1 south). It roams
## the southern latitudes and never reaches the northern spice fields.
func storm_center() -> float:
	return 0.83 + 0.12 * sin(storm_phase * 0.9)


## The Coriolis storm: a band that roams the southern latitudes.
func _move_storm() -> void:
	storm_phase += 1.0
	var center: float = storm_center()
	for id: StringName in regions:
		var latitude: float = ArrakisAtlas.latitude(id)
		regions[id].storm = latitude > 0.6 and absf(latitude - center) < 0.1


## Harvesters draw worms; a full sign costs Rabban a crawler.
func _worms() -> void:
	for id: StringName in regions:
		var state: RegionState = regions[id]
		if ArrakisAtlas.kind(id) != ArrakisAtlas.Kind.SAND:
			continue
		state.worm_sign += state.harvesters * 6.0 + rng.randf_range(0.0, 6.0) - (10.0 if state.storm else 0.0)
		state.worm_sign = clampf(state.worm_sign, 0.0, RegionState.WORM_MAX)
		if state.worm_sign >= RegionState.WORM_MAX:
			state.worm_sign = 20.0
			if state.harvesters > 0 and state.control == RegionState.Holder.HARKONNEN:
				state.harvesters -= 1
				state.rebuild_wait = maxi(state.rebuild_wait, 2)
				report.append("Shai-Hulud takes a Harkonnen harvester in %s." % state.title())


func _count_production() -> int:
	var total: int = 0
	for id: StringName in regions:
		total += regions[id].harkonnen_production()
	return total


## Rabban answers: new harvesters, the quota, and sweeps for the sietches
## when the heat is high.
func _harkonnen_turn() -> void:
	production = _count_production()
	if production < QUOTA:
		attention = minf(attention + (QUOTA - production) * 0.6, ATTENTION_MAX)
		report.append("Rabban sends %d spice against a quota of %d. The Emperor's eye turns to Arrakis." % [production, QUOTA])
	else:
		attention = maxf(attention - 3.0, 0.0)
	for id: StringName in regions:
		var state: RegionState = regions[id]
		if state.control != RegionState.Holder.HARKONNEN or ArrakisAtlas.spice(id) <= 0:
			continue
		state.rebuild_wait = maxi(state.rebuild_wait - 1, 0)
		if state.rebuild_wait == 0 and state.harvesters < ArrakisAtlas.spice(id) + 1:
			state.harvesters += 1
			state.rebuild_wait = 2
			report.append("A new harvester arrives in %s." % state.title())
	if campaign.heat >= 4 and rng.randf() < campaign.heat * 0.08:
		var sietches: Array[StringName] = []
		for id: StringName in regions:
			if ArrakisAtlas.kind(id) == ArrakisAtlas.Kind.SIETCH and regions[id].control == RegionState.Holder.FREMEN and not _taken(id):
				sietches.append(id)
		if not sietches.is_empty():
			var target: StringName = sietches[rng.randi_range(0, sietches.size() - 1)]
			_add(OperationTemplates.build(OperationTemplates.DEFEND, regions[target]))
			report.append("Harkonnen troops sweep toward %s. Meet them this week, or lose it." % regions[target].title())
	if week % 2 == 0 and campaign.heat > 0:
		campaign.heat -= 1


func _fremen_turn() -> void:
	var sietches: int = 0
	for id: StringName in regions:
		if ArrakisAtlas.kind(id) == ArrakisAtlas.Kind.SIETCH and regions[id].control == RegionState.Holder.FREMEN:
			sietches += 1
	var record: MissionOutcome = MissionOutcome.new()
	record.mission_id = &"week"
	record.tier = MissionOutcome.Tier.CLEAN
	record.resources = {&"water": sietches}
	campaign.apply(record, false)
