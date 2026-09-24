class_name Progression
extends RefCounted
## The growth rules, in one place: what earns experience, how much, the cap
## per mission, the ranks, and what each rank changes in play. Heroes grow
## three ways (see docs/design/campaign.md, 63.1):
##
##   by doing      blade, firearms and desert craft grow with use
##   by spice      saturation builds prescience ranks
##   by milestone  discipline and prescience ranks granted by the story
##
## Everything goes through CampaignState (its `progress`), so growth is kept
## between missions like resources and standings.

const SKILLS: Array[StringName] = [&"blade", &"firearms", &"desert_craft"]
const SKILL_NAMES: Dictionary = {&"blade": "Blade", &"firearms": "Firearms", &"desert_craft": "Desert craft"}
## Experience needed for ranks 1..5.
const RANK_AT: Array[int] = [10, 25, 45, 70, 100]
## No skill gains more than this in one mission: growth, not grinding.
const MISSION_CAP: int = 25
const SATURATION_PER_RANK: float = 25.0

## What each deed is worth. Clever play earns more than brute force.
const AWARDS: Dictionary = {
	&"knife_hit": {&"blade": 2},
	&"knife_kill": {&"blade": 4},
	&"silent_kill": {&"blade": 5, &"desert_craft": 6},
	&"shot_hit": {&"firearms": 1},
	&"shot_kill": {&"firearms": 3},
	&"unseen": {&"desert_craft": 1},
}


static func rank_for(points: int) -> int:
	var rank: int = 0
	for threshold in RANK_AT:
		if points >= threshold:
			rank += 1
	return rank


static func campaign_of(node: Node) -> CampaignState:
	var game: Node = node.get_tree().root.get_node_or_null("GameManager") if node != null and node.is_inside_tree() else null
	return game.campaign if game != null else null


## Experience for a deed, within this mission's cap. Returns what was gained.
static func award(campaign: CampaignState, hero: StringName, deed: StringName) -> Dictionary:
	var gained: Dictionary = {}
	if campaign == null or not AWARDS.has(deed):
		return gained
	for skill: StringName in AWARDS[deed]:
		gained[skill] = add_xp(campaign, hero, skill, int(AWARDS[deed][skill]), deed)
	return gained


## Raw experience (lore rewards use this too), capped per mission. Records
## rank-ups in the mission's growth log.
static func add_xp(campaign: CampaignState, hero: StringName, skill: StringName, amount: int, why: StringName = &"") -> int:
	var progress: HeroProgress = campaign.hero_progress(hero)
	var key: String = "%s/%s" % [hero, skill]
	var so_far: int = int(campaign.mission_gains.get(key, 0))
	var granted: int = mini(amount, maxi(MISSION_CAP - so_far, 0)) if why != &"lore" else amount
	if granted <= 0:
		return 0
	var before: int = progress.rank(skill)
	progress.xp[skill] = int(progress.xp.get(skill, 0)) + granted
	campaign.mission_gains[key] = so_far + granted
	var after: int = progress.rank(skill)
	if after > before:
		campaign.growth_log.append("%s: %s rank %d" % [_hero_name(hero), SKILL_NAMES.get(skill, String(skill)), after])
	return granted


## Spice saturation: permanent. A threshold crossed is a prescience rank.
static func saturate(campaign: CampaignState, hero: StringName, amount: float) -> void:
	if campaign == null or amount <= 0.0:
		return
	var progress: HeroProgress = campaign.hero_progress(hero)
	var before: int = progress.prescience_bonus()
	progress.saturation += amount
	campaign.mission_gains["%s/saturation" % hero] = float(campaign.mission_gains.get("%s/saturation" % hero, 0.0)) + amount
	if progress.prescience_bonus() > before:
		campaign.growth_log.append("%s: the spice deepens - prescience rank %d" % [_hero_name(hero), progress.prescience_bonus()])


## A story milestone: a great spice moment raises prescience for good.
static func raise_prescience(campaign: CampaignState, hero: StringName, reason: String) -> void:
	var progress: HeroProgress = campaign.hero_progress(hero)
	progress.prescience_rank += 1
	campaign.growth_log.append("%s: %s - prescience rank %d" % [_hero_name(hero), reason, progress.prescience_bonus()])


static func raise_discipline(campaign: CampaignState, hero: StringName, reason: String) -> void:
	var progress: HeroProgress = campaign.hero_progress(hero)
	progress.discipline += 1
	campaign.growth_log.append("%s: %s - discipline rank %d (+1 action point)" % [_hero_name(hero), reason, progress.discipline])


# --------------------------------------------------------------------------
# What ranks change
# --------------------------------------------------------------------------

static func _progress(campaign: CampaignState, hero: StringName) -> HeroProgress:
	return campaign.hero_progress(hero) if campaign != null else HeroProgress.create(hero)


static func action_points(campaign: CampaignState, hero_data: HeroDefinition) -> int:
	var base: int = hero_data.action_points if hero_data != null else 10
	return base + _progress(campaign, hero_data.id if hero_data != null else &"paul").discipline


static func visions(campaign: CampaignState, hero_data: HeroDefinition) -> int:
	var base: int = hero_data.prescience if hero_data != null else 0
	return base + _progress(campaign, hero_data.id if hero_data != null else &"paul").prescience_bonus()


## Percentage points added to knife / shot hit chances.
static func knife_bonus(campaign: CampaignState, hero: StringName) -> float:
	return 3.0 * _progress(campaign, hero).rank(&"blade")


static func fire_bonus(campaign: CampaignState, hero: StringName) -> float:
	return 3.0 * _progress(campaign, hero).rank(&"firearms")


static func quick_knife_cost(campaign: CampaignState, hero: StringName) -> int:
	return 2 if _progress(campaign, hero).rank(&"blade") >= 3 else TurnRules.QUICK_KNIFE_COST


static func reload_cost(campaign: CampaignState, hero: StringName) -> int:
	return 1 if _progress(campaign, hero).rank(&"firearms") >= 3 else TurnRules.RELOAD_COST


## Multiplies a watcher's chance to notice the hero moving.
static func detection_factor(campaign: CampaignState, hero: StringName) -> float:
	return maxf(1.0 - 0.08 * _progress(campaign, hero).rank(&"desert_craft"), 0.5)


## Multiplies the real-time slow-blade charge time.
static func slow_charge_factor(campaign: CampaignState, hero: StringName) -> float:
	return maxf(1.0 - 0.08 * _progress(campaign, hero).rank(&"blade"), 0.6)


static func _hero_name(hero: StringName) -> String:
	return String(hero).capitalize()
