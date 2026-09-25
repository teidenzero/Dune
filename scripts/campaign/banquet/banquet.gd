class_name Banquet
extends RefCounted
## The rules of 1.2 The Banquet. Five courses, a guest each; a reply is chosen,
## its certain effects land, and its hidden part lands by the guest's secret
## agenda. Jessica's readings reveal a guest's agenda (and whether he is the
## Harkonnen informant); Paul's glimpses show one course's reactions. The
## table's composure falls with every blunder: at zero the Duke ends the
## dinner early. At the end, Thufir's note: name the informant, or not.
##
## Nothing is decided by dice. The seed only sets who wants what; what the
## player knows decides how well the evening goes.

enum Phase { COURSE, REACTION, ACCUSE, DONE }

var agendas: Dictionary = {}
var informant: StringName = &""
var revealed: Dictionary = {}
var glimpsed: Dictionary = {}
var readings_left: int = BanquetScript.READINGS
var glimpses_left: int = BanquetScript.GLIMPSES
var composure: int = BanquetScript.START_COMPOSURE
var kynes_trust: int = 0
var course_index: int = 0
var phase: Phase = Phase.COURSE
var ended_early: bool = false
## What the evening added up to, applied to the campaign once at the end.
var standings: Dictionary = {}
var resources: Dictionary = {}
var heat: int = 0
var flags: PackedStringArray = []
## The last reply's reaction line, for the screen.
var last_reaction: String = ""
var accused: StringName = &""
## Plain-words record of what happened, for the results.
var record: PackedStringArray = []


## `seed_value` sets the hidden agendas and the informant; `extra_glimpses`
## comes from Paul's prescience growth.
static func create(seed_value: int, extra_glimpses: int = 0) -> Banquet:
	var banquet: Banquet = Banquet.new()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	var suspects: Array[StringName] = []
	for guest in BanquetScript.GUESTS:
		var options: Array = guest.agendas
		banquet.agendas[guest.id] = options[random.randi_range(0, options.size() - 1)]
		if guest.may_inform:
			suspects.append(guest.id)
	banquet.informant = suspects[random.randi_range(0, suspects.size() - 1)]
	banquet.agendas[banquet.informant] = &"informant"
	banquet.glimpses_left += maxi(extra_glimpses, 0)
	return banquet


func current_course() -> Dictionary:
	return BanquetScript.COURSES[course_index] if course_index < BanquetScript.COURSES.size() else {}


func current_guest() -> StringName:
	return current_course().get("guest", &"")


## Jessica reads a guest: his agenda shows, and with it how he will take
## every reply. Returns false with none left or already read.
func read(guest_id: StringName) -> bool:
	if readings_left <= 0 or revealed.has(guest_id) or phase == Phase.DONE:
		return false
	readings_left -= 1
	revealed[guest_id] = true
	record.append("Jessica read %s." % BanquetScript.guest(guest_id).name)
	return true


## Paul glimpses how this course's guest will take each reply.
func glimpse() -> bool:
	if glimpses_left <= 0 or phase != Phase.COURSE or knows_reactions():
		return false
	glimpses_left -= 1
	glimpsed[course_index] = true
	return true


## Whether this course's reactions are known before choosing.
func knows_reactions() -> bool:
	return revealed.has(current_guest()) or glimpsed.has(course_index)


func agenda_text(guest_id: StringName) -> String:
	return BanquetScript.AGENDAS.get(agendas.get(guest_id, &""), "") if revealed.has(guest_id) else ""


## Everything a reply would do, if the guest's agenda is known; otherwise
## only its certain part. {"effects": {...}, "line": "", "known": bool}.
func preview(reply_index: int) -> Dictionary:
	var reply: Dictionary = current_course().replies[reply_index]
	if not knows_reactions():
		return {"effects": reply.effects, "line": "", "known": false}
	var reaction: Dictionary = reply.reactions.get(agendas[current_guest()], {})
	return {"effects": _merge(reply.effects, reaction.get("effects", {})), "line": reaction.get("line", ""), "known": true}


func choose(reply_index: int) -> void:
	if phase != Phase.COURSE:
		return
	var reply: Dictionary = current_course().replies[reply_index]
	var reaction: Dictionary = reply.reactions.get(agendas[current_guest()], {})
	_apply(_merge(reply.effects, reaction.get("effects", {})))
	last_reaction = reaction.get("line", "")
	record.append("%s: \"%s\"" % [reply.speaker.capitalize(), reply.text])
	phase = Phase.REACTION


## After the reaction: the next course, or - the table lost - the dinner ends.
func next() -> void:
	if phase != Phase.REACTION:
		return
	course_index += 1
	if composure <= 0 and course_index < BanquetScript.COURSES.size():
		ended_early = true
		# The guests not yet heard leave offended.
		for index in range(course_index, BanquetScript.COURSES.size()):
			var skipped: Dictionary = BanquetScript.guest(BanquetScript.COURSES[index].guest)
			_add(standings, skipped.faction, -1)
		record.append("The table grew too cold; the Duke ended the dinner early.")
		phase = Phase.DONE
		_finish()
		return
	phase = Phase.COURSE if course_index < BanquetScript.COURSES.size() else Phase.ACCUSE


## Thufir's note: name the informant (a guest id) or say nothing (&"").
func accuse(guest_id: StringName) -> void:
	if phase != Phase.ACCUSE:
		return
	accused = guest_id
	if guest_id == &"":
		flags.append("informant_hidden")
		record.append("Nobody was named. The informant left with the rest.")
	elif guest_id == informant:
		flags.append("informant_exposed")
		_add(resources, &"intel", 2)
		heat -= 1
		record.append("%s was named, quietly, to Thufir. The Baron has lost his ears in Arrakeen." % BanquetScript.guest(guest_id).name)
	else:
		flags.append("wrong_accusation")
		_add(standings, BanquetScript.guest(guest_id).faction, -2)
		flags.append("informant_hidden")
		record.append("%s was accused, and was innocent. His people will remember it." % BanquetScript.guest(guest_id).name)
	phase = Phase.DONE
	_finish()


func _finish() -> void:
	if kynes_trust >= BanquetScript.KYNES_TRUSTS:
		flags.append("kynes_trusts")
	elif kynes_trust <= BanquetScript.KYNES_DOUBTS:
		flags.append("kynes_doubts")
	else:
		flags.append("kynes_undecided")


## The evening as a MissionOutcome for the campaign.
func outcome() -> MissionOutcome:
	var result: MissionOutcome = MissionOutcome.new()
	result.mission_id = &"act1_banquet"
	result.scopes = [MissionOutcome.Scope.POLITICAL]
	if ended_early:
		result.tier = MissionOutcome.Tier.PARTIAL
	elif flags.has("informant_exposed") and composure >= 3:
		result.tier = MissionOutcome.Tier.CLEAN
	else:
		result.tier = MissionOutcome.Tier.NOISY
	# One evening moves a faction two steps at most, whichever way.
	for faction: StringName in standings:
		result.standings[faction] = clampi(int(standings[faction]), -BanquetScript.MAX_SWING, BanquetScript.MAX_SWING)
	result.resources = resources.duplicate()
	result.heat = heat
	result.flags = flags.duplicate()
	result.stats = {"composure": composure, "kynes_trust": kynes_trust, "readings_used": BanquetScript.READINGS - readings_left}
	return result


func _apply(effects: Dictionary) -> void:
	for faction: StringName in effects.get("standings", {}):
		_add(standings, faction, int(effects.standings[faction]))
	for id: StringName in effects.get("resources", {}):
		_add(resources, id, int(effects.resources[id]))
	heat += int(effects.get("heat", 0))
	kynes_trust += int(effects.get("kynes", 0))
	composure = clampi(composure + int(effects.get("composure", 0)), 0, BanquetScript.MAX_COMPOSURE)
	for flag in effects.get("flags", []):
		if not flags.has(String(flag)):
			flags.append(String(flag))


static func _add(into: Dictionary, key: StringName, amount: int) -> void:
	into[key] = int(into.get(key, 0)) + amount


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var result: Dictionary = a.duplicate(true)
	for key in b:
		if b[key] is Dictionary:
			var inner: Dictionary = (result.get(key, {}) as Dictionary).duplicate()
			for sub in b[key]:
				inner[sub] = int(inner.get(sub, 0)) + int(b[key][sub])
			result[key] = inner
		elif b[key] is Array:
			result[key] = (result.get(key, []) as Array) + b[key]
		else:
			result[key] = int(result.get(key, 0)) + int(b[key])
	return result


## A short, plain description of effects for the screen.
static func describe(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	for faction: StringName in effects.get("standings", {}):
		var amount: int = int(effects.standings[faction])
		if amount != 0:
			parts.append("%s %+d" % [CampaignState.FACTION_NAMES.get(faction, String(faction)), amount])
	for id: StringName in effects.get("resources", {}):
		var amount: int = int(effects.resources[id])
		if amount != 0:
			parts.append("%s %+d" % [CampaignState.RESOURCE_NAMES.get(id, String(id)), amount])
	var kynes: int = int(effects.get("kynes", 0))
	if kynes != 0:
		parts.append("Kynes %s" % ("warms" if kynes > 0 else "cools"))
	var calm: int = int(effects.get("composure", 0))
	if calm != 0:
		parts.append("Table %+d" % calm)
	if int(effects.get("heat", 0)) > 0:
		parts.append("The Baron hears")
	if (effects.get("flags", []) as Array).has(&"smugglers_channel"):
		parts.append("Opens a channel to the smugglers")
	return "   ·   ".join(parts) if not parts.is_empty() else "No clear effect"
