class_name OperationResolver
extends RefCounted
## Resolves a mission in the Political scope. Pure rules, no UI: the Council
## screen and the tests both call it.
##
## Success chance = approach base + agent (affinity bonus when the approach
## goes through their faction, plus any general bonus) + standing with that
## faction x STANDING_STEP + Intel spent x INTEL_STEP + the dilemma choice.
## The roll then decides the tier: comfortably inside the chance is clean,
## just inside is noisy, just outside is partial, the rest is failure.

const STANDING_STEP: float = 0.08
const INTEL_STEP: float = 0.07
const MIN_CHANCE: float = 0.05
const MAX_CHANCE: float = 0.95
const CLEAN_MARGIN: float = 0.6
const PARTIAL_MARGIN: float = 0.15


## Why an approach cannot be tried right now, or "" when it can.
static func blocked_reason(approach: PoliticalApproach, campaign: CampaignState) -> String:
	if campaign.standing(approach.faction) < approach.min_standing:
		return "%s will not deal with us (need %s)" % [CampaignState.faction_name(approach.faction), CampaignState.STANDING_NAMES.get(approach.min_standing, str(approach.min_standing))]
	for key in approach.costs:
		if int(campaign.resources.get(key, 0)) < int(approach.costs[key]):
			return "Not enough %s (%d needed)" % [CampaignState.resource_name(key), int(approach.costs[key])]
	return ""


static func chance(approach: PoliticalApproach, agent: HeroDefinition, campaign: CampaignState, intel_spent: int, choice: PoliticalChoice = null) -> float:
	var value: float = approach.base_chance
	if agent != null:
		value += agent.general_bonus
		if agent.affinity == approach.faction:
			value += agent.affinity_bonus
	value += campaign.standing(approach.faction) * STANDING_STEP
	value += maxi(intel_spent, 0) * INTEL_STEP
	if choice != null:
		value += choice.chance_bonus
	return clampf(value, MIN_CHANCE, MAX_CHANCE)


static func tier_for(roll: float, success_chance: float) -> MissionOutcome.Tier:
	if roll < success_chance * CLEAN_MARGIN:
		return MissionOutcome.Tier.CLEAN
	if roll < success_chance:
		return MissionOutcome.Tier.NOISY
	if roll < success_chance + PARTIAL_MARGIN:
		return MissionOutcome.Tier.PARTIAL
	return MissionOutcome.Tier.FAILURE


## Builds the outcome record. `roll` in [0, 1); pass one in for tests.
static func resolve(definition: MissionDefinition, approach: PoliticalApproach, agent: HeroDefinition, campaign: CampaignState, intel_spent: int, choice: PoliticalChoice, roll: float) -> MissionOutcome:
	var odds: float = chance(approach, agent, campaign, intel_spent, choice)
	var record: MissionOutcome = MissionOutcome.new()
	record.mission_id = definition.id
	record.scopes.append(MissionOutcome.Scope.POLITICAL)
	record.tier = tier_for(roll, odds)
	var achieved: bool = record.tier != MissionOutcome.Tier.FAILURE
	for item in definition.objectives:
		if item.optional:
			continue
		if item.primary:
			record.objectives[item.id] = MissionObjective.State.COMPLETE if achieved else MissionObjective.State.FAILED
	record.apply_stakes(definition)
	# What the operation itself cost and stirred up, whatever the result.
	for key in approach.costs:
		record.resources[key] = int(record.resources.get(key, 0)) - int(approach.costs[key])
	if intel_spent > 0:
		record.resources[&"intel"] = int(record.resources.get(&"intel", 0)) - intel_spent
	_merge(record, approach.effects)
	if choice != null:
		_merge(record, choice.effects)
	record.add_flag(&"political")
	record.add_flag(StringName("approach_" + String(approach.id)))
	if record.tier == MissionOutcome.Tier.PARTIAL or record.tier == MissionOutcome.Tier.FAILURE:
		record.add_flag(&"operation_exposed")
	record.stats = {
		"Approach": approach.title,
		"Agent": agent.display_name if agent != null else "none",
		"Intel spent": intel_spent,
		"Dilemma": choice.text if choice != null else "-",
		"Odds": "%d%%" % roundi(odds * 100.0),
	}
	if record.tier == MissionOutcome.Tier.FAILURE:
		record.failure_reason = "THE OPERATION FAILED"
	return record


static func _merge(record: MissionOutcome, effects: Dictionary) -> void:
	var resources: Dictionary = effects.get("resources", {})
	for key in resources:
		record.resources[key] = int(record.resources.get(key, 0)) + int(resources[key])
	var standings: Dictionary = effects.get("standings", {})
	for key in standings:
		record.standings[key] = int(record.standings.get(key, 0)) + int(standings[key])
	record.heat += int(effects.get("heat", 0))


## One-line summary of an effects dictionary, e.g. "Guild +1 · Heat +1".
static func describe(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	var standings: Dictionary = effects.get("standings", {})
	for key in standings:
		parts.append("%s %+d" % [CampaignState.faction_name(key), int(standings[key])])
	if int(effects.get("heat", 0)) != 0:
		parts.append("Heat %+d" % int(effects["heat"]))
	var resources: Dictionary = effects.get("resources", {})
	for key in resources:
		parts.append("%s %+d" % [CampaignState.resource_name(key), int(resources[key])])
	return "  ·  ".join(parts)
