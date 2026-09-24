class_name MissionOutcome
extends RefCounted
## What happened on a mission, in the one shape every scope produces. The
## campaign applies it and never looks inside a mission scene.

enum Tier { CLEAN, NOISY, PARTIAL, FAILURE }
enum Scope { POLITICAL, SQUAD, SOLO }

const TIER_KEYS: Array[String] = ["clean", "noisy", "partial", "failure"]
const TIER_TITLES: Array[String] = ["CLEAN SUCCESS", "NOISY SUCCESS", "PARTIAL SUCCESS", "FAILURE"]

var mission_id: StringName = &""
var tier: Tier = Tier.FAILURE
## Every scope used, in order; more than one means the mission was escalated.
var scopes: Array[Scope] = []
## objective id -> MissionObjective.State
var objectives: Dictionary = {}
## Names of recruits killed, heroes wounded, heroes captured.
var recruits_dead: PackedStringArray = []
var heroes_wounded: PackedStringArray = []
var heroes_captured: PackedStringArray = []
## Consequences, filled from the mission's stakes for this tier plus anything
## the scope adds (a burned contact, a bribe paid).
var resources: Dictionary = {}
var standings: Dictionary = {}
var heat: int = 0
## Story facts later missions can read: &"alarm_raised", &"comms_intact"...
var flags: PackedStringArray = []
## The scope's own factual numbers, for the debrief (not read by the campaign).
var stats: Dictionary = {}
var failure_reason: String = ""
var time_seconds: float = 0.0


static func tier_key(value: Tier) -> String:
	return TIER_KEYS[value]


func tier_title() -> String:
	return TIER_TITLES[tier]


func succeeded() -> bool:
	return tier == Tier.CLEAN or tier == Tier.NOISY


func add_flag(flag: StringName) -> void:
	if not flags.has(flag):
		flags.append(flag)


## Merge the definition's consequences for this tier into the record.
func apply_stakes(definition: MissionDefinition) -> void:
	var stakes: Dictionary = definition.stakes_for(tier)
	for key in stakes["resources"]:
		resources[key] = int(resources.get(key, 0)) + int(stakes["resources"][key])
	for key in stakes["standings"]:
		standings[key] = int(standings.get(key, 0)) + int(stakes["standings"][key])
	heat += int(stakes["heat"])


## Human-readable consequence lines for the debrief, e.g. "Fremen +1".
func consequence_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for key in standings:
		if int(standings[key]) != 0:
			lines.append("%s standing %+d" % [CampaignState.faction_name(key), int(standings[key])])
	if heat != 0:
		lines.append("Harkonnen heat %+d" % heat)
	for key in resources:
		if int(resources[key]) != 0:
			lines.append("%s %+d" % [CampaignState.resource_name(key), int(resources[key])])
	for name in recruits_dead:
		lines.append("%s killed" % name)
	for name in heroes_wounded:
		lines.append("%s wounded" % name)
	for name in heroes_captured:
		lines.append("%s captured" % name)
	return lines


func to_dict() -> Dictionary:
	var states: Dictionary = {}
	for key in objectives:
		states[String(key)] = MissionObjective.State.keys()[objectives[key]]
	var scope_names: PackedStringArray = []
	for scope in scopes:
		scope_names.append(Scope.keys()[scope])
	return {
		"mission": String(mission_id), "tier": tier_key(tier), "scopes": scope_names,
		"objectives": states, "recruits_dead": recruits_dead, "heroes_wounded": heroes_wounded,
		"heroes_captured": heroes_captured, "resources": resources, "standings": standings,
		"heat": heat, "flags": flags, "failure_reason": failure_reason, "time": time_seconds,
	}
