class_name Banquet
extends RefCounted
## The rules of 1.2 The Banquet, played as Paul. Five courses, a guest each;
## Paul chooses one of three replies. What it does around the table (`beyond`)
## always lands, and how the guest takes it lands by his secret agenda.
##
## Two helps, a few of each per evening:
##   Jessica's face    how this guest will take each reply (and what he wants)
##   the Duke's memory what each reply means around the table
## Both on one course show every pro and con exactly. Paul's own prescience,
## once grown, glimpses everything at once. Otherwise the player reads the
## guest himself: every guest shows a small, fair tell of what he wants.
##
## A good reply earns a look from a parent; a poor one, a parent stepping in
## to smooth it - in words fitted to what Paul said. A good reply found with
## no help is Paul learning: it grows his statecraft.
##
## The table's composure falls with every blunder: at zero the Duke ends the
## dinner early. At the end, Thufir's note: name the informant, or not.
## Nothing is decided by dice: the seed only sets who wants what.

enum Phase { COURSE, REACTION, ACCUSE, DONE }

var agendas: Dictionary = {}
var informant: StringName = &""
## Guests whose agenda is known (a glance at Jessica, or a reply that showed it).
var revealed: Dictionary = {}
## Per course: which helps were used. {course_index: {"face": bool, "memory": bool, "glimpse": bool}}
var helped: Dictionary = {}
var faces_left: int = BanquetScript.FACES
var memories_left: int = BanquetScript.MEMORIES
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
## The last reply: the guest's reaction, its grade, and a parent's response.
var last_reaction: String = ""
var last_grade: StringName = &""
var last_parent: Dictionary = {}
var last_effects: Dictionary = {}
var last_unaided: bool = false
## Good replies found with no help: Paul reading the table himself.
var unaided_reads: int = 0
var grades: Array[StringName] = []
var accused: StringName = &""
## Plain-words record of what happened, for the results.
var record: PackedStringArray = []


## `seed_value` sets the hidden agendas and the informant; `extra_glimpses`
## comes from Paul's prescience growth, `extra_memories` from his statecraft.
static func create(seed_value: int, extra_glimpses: int = 0, extra_memories: int = 0) -> Banquet:
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
	banquet.memories_left += maxi(extra_memories, 0)
	return banquet


func current_course() -> Dictionary:
	return BanquetScript.COURSES[course_index] if course_index < BanquetScript.COURSES.size() else {}


func current_guest() -> StringName:
	return current_course().get("guest", &"")


func current_agenda() -> StringName:
	return agendas.get(current_guest(), &"")


func _help(kind: String) -> bool:
	return bool((helped.get(course_index, {}) as Dictionary).get(kind, false))


func _use(kind: String) -> void:
	var entry: Dictionary = helped.get(course_index, {})
	entry[kind] = true
	helped[course_index] = entry


## What anyone at the table can see of this guest: his tell.
func tell() -> String:
	var agenda: StringName = current_agenda()
	if agenda == &"informant":
		return BanquetScript.INFORMANT_TELL
	return (current_course().get("tells", {}) as Dictionary).get(agenda, "")


## A glance at Jessica: how this guest will take each reply, and what he wants.
func read_face() -> bool:
	if faces_left <= 0 or phase != Phase.COURSE or knows_guest():
		return false
	faces_left -= 1
	_use("face")
	revealed[current_guest()] = true
	return true


## The Duke's lesson recalled: what each reply means around the table.
func recall() -> bool:
	if memories_left <= 0 or phase != Phase.COURSE or knows_table():
		return false
	memories_left -= 1
	_use("memory")
	return true


## Paul's prescience: everything at once.
func glimpse() -> bool:
	if glimpses_left <= 0 or phase != Phase.COURSE or (knows_guest() and knows_table()):
		return false
	glimpses_left -= 1
	_use("glimpse")
	return true


## Jessica's face for this course, once read.
func face_line() -> String:
	if not _help("face"):
		return ""
	if current_agenda() == &"informant":
		return BanquetScript.INFORMANT_FACE
	return (current_course().get("face", {}) as Dictionary).get(current_agenda(), "")


func memory_line() -> String:
	return current_course().get("memory", "") if _help("memory") else ""


## Paul is watching his mother this course (her face, not a glimpse).
func watching_mother() -> bool:
	return _help("face")


## What her face does as Paul weighs a reply: warm for a good one, cool for a
## poor one, doubtful for a half-good one. Empty unless he is watching her.
func mother_expression(reply_index: int) -> StringName:
	if not watching_mother():
		return &""
	var reply: Dictionary = current_course().replies[reply_index]
	match String(reply.reactions.get(current_agenda(), {}).get("grade", "")):
		"good":
			return &"approve"
		"poor":
			return &"warn"
		_:
			return &"doubt"


## Her face at rest: composed - or, across from the Baron's man, too still.
func mother_at_rest() -> StringName:
	return &"still" if current_agenda() == &"informant" else &"neutral"


## How this guest takes the replies is known: Jessica's face, or a glimpse.
func knows_guest() -> bool:
	return _help("face") or _help("glimpse")


## What the replies mean around the table is known: the Duke's memory, or a glimpse.
func knows_table() -> bool:
	return _help("memory") or _help("glimpse")


func agenda_text(guest_id: StringName) -> String:
	return BanquetScript.AGENDAS.get(agendas.get(guest_id, &""), "") if revealed.has(guest_id) else ""


## What a reply is known to do before it is said:
## {"guest": {...} or null, "table": {...} or null, "line": "", "grade": &""}.
func preview(reply_index: int) -> Dictionary:
	var reply: Dictionary = current_course().replies[reply_index]
	var reaction: Dictionary = reply.reactions.get(current_agenda(), {})
	var seen: Dictionary = {"guest": null, "table": null, "line": "", "grade": &""}
	if knows_guest():
		seen.guest = reaction.get("effects", {})
		seen.line = reaction.get("line", "")
		seen.grade = reaction.get("grade", &"")
	if knows_table():
		seen.table = reply.get("beyond", {})
	return seen


func choose(reply_index: int) -> void:
	if phase != Phase.COURSE:
		return
	var reply: Dictionary = current_course().replies[reply_index]
	var reaction: Dictionary = reply.reactions.get(current_agenda(), {})
	last_effects = _merge(reply.get("beyond", {}), reaction.get("effects", {}))
	_apply(last_effects)
	if bool((reaction.get("effects", {}) as Dictionary).get("reveal", false)):
		revealed[current_guest()] = true
	last_reaction = reaction.get("line", "")
	last_grade = reaction.get("grade", &"mixed")
	grades.append(last_grade)
	last_unaided = last_grade == &"good" and not (knows_guest() or knows_table())
	if last_unaided:
		unaided_reads += 1
	last_parent = _parent_response(reply)
	record.append("Paul: \"%s\"" % reply.text)
	phase = Phase.REACTION


## A look, a word, or a parent stepping in - chosen without dice: by course.
func _parent_response(reply: Dictionary) -> Dictionary:
	match last_grade:
		&"poor":
			return reply.get("rescue", {})
		&"good":
			return BanquetScript.APPROVAL[course_index % BanquetScript.APPROVAL.size()]
		_:
			return BanquetScript.NUDGE[course_index % BanquetScript.NUDGE.size()]


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
	result.stats = {"composure": composure, "kynes_trust": kynes_trust, "read_unaided": unaided_reads,
		"faces_used": BanquetScript.FACES - faces_left, "memories_used": maxi(BanquetScript.MEMORIES - memories_left, 0)}
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
		elif b[key] is bool:
			result[key] = bool(result.get(key, false)) or b[key]
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
	if bool(effects.get("reveal", false)):
		parts.append("Shows what he is")
	return "  ·  ".join(parts) if not parts.is_empty() else "No clear effect"
