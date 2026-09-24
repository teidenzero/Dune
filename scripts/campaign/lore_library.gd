class_name LoreLibrary
extends RefCounted
## Every piece of lore the player can find, and every cache. All text is
## original to this prototype, written in the spirit of the novels. Lore is
## never needed to finish a mission; each piece pays a small reward the
## first time it is read (see FindPoint), and fills the Codex.
##
## A reward is any of: "xp" {skill: amount}, "resources" {id: amount},
## "saturation" amount, "items" {id: amount}.

const CATEGORIES: Array[StringName] = [&"houses", &"arrakis", &"fremen", &"spice", &"faith", &"technology", &"people"]
const CATEGORY_NAMES: Dictionary = {
	&"houses": "The Great Houses", &"arrakis": "Arrakis", &"fremen": "The Fremen", &"spice": "The Spice",
	&"faith": "Faith", &"technology": "Technology", &"people": "People",
}

const ENTRIES: Dictionary = {
	# --- The training hall (prologue) --------------------------------------
	&"harkonnen_tally": {"category": &"houses", "title": "A Harkonnen Tally, Left Behind", "where": "The training hall",
		"text": "A page torn from a garrison book, in a clerk's cramped hand: water issued to the Residency guard, water sold to the town, water \"lost to evaporation\". The last column is the largest. At the foot, a note: \"The Baron asks that the figures agree. See that they agree.\"",
		"reward": {"resources": {&"intel": 1}}},
	&"shield_drill": {"category": &"technology", "title": "Shield Drill, Atreides Armoury", "where": "The training hall",
		"text": "Chalked on a practice board: THE FIELD STOPS WHAT COMES FAST. A bullet is fast. A hurried blade is fast. Go slow, and go in - the shield will let you. Below it, in another hand, somebody has drawn a very slow snail wearing a very large sword.",
		"reward": {"xp": {&"blade": 5}}},
	&"gurney_verse": {"category": &"people", "title": "Lines in Gurney's Hand", "where": "The training hall",
		"text": "Scratched inside a lid of a baliset case: \"New sand, old enemy. / The wind takes our footprints and gives back none. / Tune the strings, lad. / A man who can still sing has not yet been beaten.\"",
		"reward": {"xp": {&"firearms": 4}}},
	&"garrison_water": {"category": &"arrakis", "title": "Standing Orders: Water", "where": "The training hall",
		"text": "Posted by the door of the lower level: No water to be spilled in drill. Sweat is to be wiped with the cloth provided and the cloth returned. On Arrakis a man who wastes water is not merely careless. He is a thief, and the one he robs is the man beside him.",
		"reward": {"xp": {&"desert_craft": 4}}},
	# --- 1.1 The Residency ----------------------------------------------------
	&"residency_plans": {"category": &"houses", "title": "The Residency's Old Plans", "where": "The Arrakeen Residency",
		"text": "A builder's drawing of the Residency, older than the Harkonnen tenure. Several walls are drawn thicker than any wall needs to be. A later hand has pencilled small marks inside them, and one word, twice underlined: \"listen\".",
		"reward": {"resources": {&"intel": 1}}},
	&"water_ring": {"category": &"fremen", "title": "A Ring of Water Rings", "where": "The Arrakeen Residency",
		"text": "Metal rings of different sizes on a cord, left in a kitchen drawer. Among the Fremen, water is counted in rings like these: a man's wealth, a debt, a dowry. That a servant would carry her fortune in a Harkonnen house says she trusted no bank but her own neck.",
		"reward": {"xp": {&"desert_craft": 4}}},
	&"catholic_page": {"category": &"faith", "title": "A Page of Scripture", "where": "The Arrakeen Residency",
		"text": "A single page of the Orange Catholic Bible, the book the old faiths of the Empire made together. The verse is about the desert: that it empties a man until only what is true in him is left. Someone has pressed a pinch of red-brown dust between the pages. It smells of cinnamon.",
		"reward": {"saturation": 3.0}},
	# --- The harvester -------------------------------------------------------
	&"crawler_log": {"category": &"spice", "title": "Harvester Log, Night Shift", "where": "Inside the harvester",
		"text": "Yield good. Wormsign at the third hour, carryall slow to answer. We lifted with nine minutes to spare. Foreman says nine is plenty. Foreman has never been under one. Request: better carryall pilots, or better pay, or a priest.",
		"reward": {"resources": {&"intel": 1}}},
	&"kynes_notes": {"category": &"arrakis", "title": "Notes in a Planetologist's Hand", "where": "Inside the harvester",
		"text": "Pinned under the relay: Dew at dawn on the north faces of the rock - measurable. Plantings would take, if protected. The planet is not dead. It is waiting. Every man who calls it barren is standing on a sea that has not yet been let out.",
		"reward": {"saturation": 3.0}},
	&"wormsign_bulletin": {"category": &"arrakis", "title": "CHOAM Bulletin: Wormsign", "where": "Inside the harvester",
		"text": "Procedure on wormsign: stop all non-essential machinery. Walk, do not run; if you must move, move without rhythm. The worm answers to rhythm and to shields. It does not answer to prayer, although crews are permitted to try.",
		"reward": {"xp": {&"desert_craft": 4}}},
}

## Caches: practical finds, taken every time they are found.
const CACHES: Dictionary = {
	&"spice_dose": {"title": "A Twist of Spice", "reward": {"items": {&"spice_dose": 1}}},
	&"solari": {"title": "Hidden Solari", "reward": {"resources": {&"solari": 10}}},
	&"water": {"title": "A Water Flask", "reward": {"resources": {&"water": 3}}},
}


static func entry(id: StringName) -> Dictionary:
	return ENTRIES.get(id, {})


static func in_category(category: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in ENTRIES:
		if ENTRIES[id].category == category:
			ids.append(id)
	return ids


## Pay a reward to the campaign (for `hero`). Returns lines describing it.
static func grant(campaign: CampaignState, hero: StringName, reward: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	if campaign == null:
		return lines
	var xp: Dictionary = reward.get("xp", {})
	for skill: StringName in xp:
		Progression.add_xp(campaign, hero, skill, int(xp[skill]), &"lore")
		lines.append("%s +%d" % [Progression.SKILL_NAMES.get(skill, String(skill)), int(xp[skill])])
	var resources: Dictionary = reward.get("resources", {})
	if not resources.is_empty():
		var record: MissionOutcome = MissionOutcome.new()
		record.mission_id = &"find"
		record.tier = MissionOutcome.Tier.CLEAN
		record.resources = resources
		campaign.apply(record, false)
		for key: StringName in resources:
			lines.append("%s +%d" % [CampaignState.RESOURCE_NAMES.get(key, String(key)), int(resources[key])])
	var saturation: float = reward.get("saturation", 0.0)
	if saturation > 0.0:
		Progression.saturate(campaign, hero, saturation)
		lines.append("Spice saturation +%d" % roundi(saturation))
	var items: Dictionary = reward.get("items", {})
	for key: StringName in items:
		campaign.add_item(key, int(items[key]))
		lines.append("Spice dose +%d" % int(items[key]) if key == &"spice_dose" else "%s +%d" % [key, int(items[key])])
	return lines
