extends SceneTree
## Run: godot --headless --path . --script res://tests/banquet_smoke.gd
##
## 1.2 The Banquet, played as Paul: the table is set by a seed and nothing
## else; for every agenda a guest could have, exactly one reply is good, one
## mixed and one poor, and no reply is never right; unhelped, a reply shows
## nothing but the guest shows his tell; Jessica's face shows how he will take
## it, the Duke's memory what it means around the table, both together
## everything; Paul's parents answer a good reply with a look, a poor one by
## stepping in; a guest read right without help is statecraft learned; the
## table's composure ends the evening early at zero; naming the informant
## (right, wrong, or not at all) and the probe that can unmask him; Kynes's
## trust; and the screen played through inside the campaign.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_the_data_is_complete()
	_every_reply_is_a_real_choice()
	_seeded_and_fair()
	_the_helps()
	_parents_react()
	_composure_ends_it()
	_naming_the_informant()
	_kynes_trust()
	await _played_in_the_campaign()
	print("BANQUET SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _agendas_of(course: Dictionary) -> Array:
	var guest: Dictionary = BanquetScript.guest(course.guest)
	var agendas: Array = guest.agendas.duplicate()
	if guest.may_inform:
		agendas.append(&"informant")
	return agendas


func _the_data_is_complete() -> void:
	var complete: bool = true
	var rescued: bool = true
	var seen: bool = true
	for course in BanquetScript.COURSES:
		for reply in course.replies:
			rescued = rescued and reply.has("rescue") and String(reply.rescue.get("line", "")) != ""
			for agenda in _agendas_of(course):
				complete = complete and reply.reactions.has(agenda) and String(reply.reactions[agenda].get("grade", "")) in ["good", "mixed", "poor"]
		for agenda in BanquetScript.guest(course.guest).agendas:
			seen = seen and course.tells.has(agenda) and course.face.has(agenda) and BanquetScript.AGENDAS.has(agenda)
		seen = seen and String(course.get("memory", "")) != ""
	_check(complete, "every reply is written and graded for every agenda its guest could have")
	_check(rescued, "every reply has its own rescue, for when it lands badly")
	_check(seen, "every agenda has its tell and Jessica's face; every course a lesson of the Duke's")
	_check(BanquetScript.COURSES.size() == 5 and BanquetScript.GUESTS.size() == 5, "five guests, five courses")


## One good, one mixed, one poor for each agenda; and no reply that is never right.
func _every_reply_is_a_real_choice() -> void:
	var shaped: bool = true
	var never_right: PackedStringArray = []
	for course in BanquetScript.COURSES:
		for agenda in _agendas_of(course):
			var grades: Array = []
			for reply in course.replies:
				grades.append(String(reply.reactions[agenda].grade))
			grades.sort()
			shaped = shaped and grades == ["good", "mixed", "poor"]
		for reply in course.replies:
			var best: bool = false
			for agenda in _agendas_of(course):
				best = best or String(reply.reactions[agenda].grade) != "poor"
			# A reply poor for this guest whatever he wants must still buy
			# something around the table: a trade, never a trap.
			var gains: bool = int(reply.beyond.get("kynes", 0)) > 0
			for faction in reply.beyond.get("standings", {}):
				gains = gains or int(reply.beyond.standings[faction]) > 0
			if not best and not gains:
				never_right.append(String(reply.text).left(30))
	_check(shaped, "for every agenda: exactly one good, one mixed and one poor reply")
	_check(never_right.is_empty(), "no reply is pure loss: poor for this guest means a gain elsewhere %s" % str(never_right))


func _seeded_and_fair() -> void:
	var a: Banquet = Banquet.create(11)
	var b: Banquet = Banquet.create(11)
	_check(a.agendas == b.agendas and a.informant == b.informant, "the same seed sets the same table")
	var informants: Dictionary = {}
	var kynes_moods: Dictionary = {}
	for seed_value in range(60):
		var table: Banquet = Banquet.create(seed_value)
		informants[table.informant] = true
		kynes_moods[table.agendas[&"kynes"]] = true
	_check(informants.size() == 3, "over many dinners, any of the three suspects may be the informant")
	_check(kynes_moods.size() == 2, "and even Kynes does not always want the same answer")


func _the_helps() -> void:
	var table: Banquet = Banquet.create(3)
	var blind: Dictionary = table.preview(0)
	_check(blind.guest == null and blind.table == null, "unhelped, a reply shows nothing of what it will do")
	_check(table.tell() != "", "but the guest shows his tell, to anyone who looks")
	_check(table.read_face() and table.knows_guest() and not table.knows_table(), "Jessica's face: how this guest will take it")
	var guest_only: Dictionary = table.preview(0)
	_check(guest_only.guest != null and guest_only.line != "" and guest_only.table == null and table.face_line() != "", "her face, and his reaction to each reply - not the table")
	_check(table.agenda_text(&"water") != "", "and what he wants shows on his card")
	_check(table.recall() and table.knows_table() and table.memory_line() != "", "the Duke's memory: what each reply means around the table")
	var both: Dictionary = table.preview(0)
	_check(both.guest != null and both.table != null, "both together: every pro and con, exactly")
	_check(not table.read_face() and not table.recall(), "each help once a course")
	table.choose(0)
	table.next()
	_check(table.read_face() and not table.read_face(), "two glances at Jessica an evening, no more")
	_check(table.recall(), "")
	table.choose(0)
	table.next()
	_check(not table.recall() and table.memories_left == 0, "two of the Duke's lessons an evening, no more")
	_check(table.glimpses_left == 0 and not table.glimpse(), "no prescience of his own yet")
	var grown: Banquet = Banquet.create(3, 1, 1)
	_check(grown.glimpses_left == 1 and grown.memories_left == BanquetScript.MEMORIES + 1, "prescience and statecraft, grown, give more help")
	_check(grown.glimpse() and grown.knows_guest() and grown.knows_table(), "a glimpse shows it all")


## The reply that is good (or poor) for this course's guest, as the table was set.
func _reply_graded(table: Banquet, grade: String) -> int:
	var course: Dictionary = table.current_course()
	for index in range(course.replies.size()):
		if String(course.replies[index].reactions[table.current_agenda()].grade) == grade:
			return index
	return 0


func _parents_react() -> void:
	var table: Banquet = Banquet.create(7)
	table.choose(_reply_graded(table, "good"))
	_check(table.last_grade == &"good" and table.last_unaided and table.unaided_reads == 1, "read right with no help: Paul learning")
	_check(BanquetScript.APPROVAL.has(table.last_parent), "and a look from his father or mother")
	table.next()
	table.read_face()
	table.choose(_reply_graded(table, "good"))
	_check(not table.last_unaided and table.unaided_reads == 1, "helped to the right answer: good, but not his own reading")
	table.next()
	var index: int = _reply_graded(table, "poor")
	table.choose(index)
	var rescue: Dictionary = table.current_course().replies[index].rescue
	_check(table.last_grade == &"poor" and table.last_parent == rescue and String(rescue.speaker) in ["DUKE LETO", "JESSICA"], "a misstep: the Duke or Jessica steps in, in words fitted to it")
	table.next()
	table.choose(_reply_graded(table, "mixed"))
	_check(BanquetScript.NUDGE.has(table.last_parent), "half right: a small correction")


func _composure_ends_it() -> void:
	var table: Banquet = Banquet.create(5)
	table.composure = 1
	table.choose(_reply_graded(table, "poor"))
	table.next()
	_check(table.phase == Banquet.Phase.DONE and table.ended_early, "the table goes cold: the Duke ends the dinner")
	var outcome: MissionOutcome = table.outcome()
	_check(outcome.tier == MissionOutcome.Tier.PARTIAL, "an evening cut short is a partial success")
	_check(int(outcome.standings.get(&"smugglers", 0)) < 0, "the guests not heard leave offended")


func _play_to_accusation(table: Banquet, grade: String = "good") -> void:
	for index in range(BanquetScript.COURSES.size()):
		table.choose(_reply_graded(table, grade))
		table.next()


func _naming_the_informant() -> void:
	var right: Banquet = Banquet.create(9)
	_play_to_accusation(right)
	_check(right.phase == Banquet.Phase.ACCUSE, "after the coffee, Thufir's note")
	var heat_before: int = right.heat
	right.accuse(right.informant)
	_check(right.flags.has("informant_exposed") and int(right.resources.get(&"intel", 0)) >= 2 and right.heat == heat_before - 1, "naming the informant: exposed, Intel, the Baron deafened")
	var wrong: Banquet = Banquet.create(9)
	_play_to_accusation(wrong)
	wrong.accuse(&"smuggler")
	_check(wrong.flags.has("wrong_accusation") and int(wrong.standings.get(&"smugglers", 0)) <= -1, "an innocent man named: his people remember it")
	var silent: Banquet = Banquet.create(9)
	_play_to_accusation(silent)
	silent.accuse(&"")
	_check(silent.flags.has("informant_hidden") and not silent.flags.has("wrong_accusation"), "naming no one is safe, and he keeps listening")
	# The sharp question to the banker unmasks him - if he is the one.
	for seed_value in range(60):
		var probe: Banquet = Banquet.create(seed_value)
		if probe.informant != &"guild":
			continue
		probe.choose(_reply_graded(probe, "good"))
		probe.next()
		probe.choose(1)
		_check(probe.revealed.has(&"guild") and probe.agenda_text(&"guild") == BanquetScript.AGENDAS[&"informant"], "the jab at the Guild unmasks a Harkonnen informant")
		break


func _kynes_trust() -> void:
	# The warmest reply every course, and the coldest: Kynes's verdict follows.
	var warm: Banquet = _play_for_kynes(4, true)
	_check(warm.flags.has("kynes_trusts"), "spoken for water and people, Kynes trusts the House (%d)" % warm.kynes_trust)
	var swing: bool = true
	for faction in warm.outcome().standings:
		swing = swing and absi(int(warm.outcome().standings[faction])) <= BanquetScript.MAX_SWING
	_check(swing, "one evening moves a faction two steps at most")
	var cold: Banquet = _play_for_kynes(4, false)
	_check(cold.flags.has("kynes_doubts"), "spoken for spice, Kynes doubts it (%d)" % cold.kynes_trust)


func _play_for_kynes(seed_value: int, warm: bool) -> Banquet:
	var table: Banquet = Banquet.create(seed_value)
	while table.phase != Banquet.Phase.ACCUSE and table.phase != Banquet.Phase.DONE:
		var course: Dictionary = table.current_course()
		var pick: int = 0
		var best: int = -99 if warm else 99
		for index in range(course.replies.size()):
			var reply: Dictionary = course.replies[index]
			var kynes: int = int(reply.beyond.get("kynes", 0)) + int(reply.reactions[table.current_agenda()].effects.get("kynes", 0))
			if (warm and kynes > best) or (not warm and kynes < best):
				best = kynes
				pick = index
		table.composure = BanquetScript.MAX_COMPOSURE
		table.choose(pick)
		table.next()
	if table.phase == Banquet.Phase.ACCUSE:
		table.accuse(&"")
	return table


func _played_in_the_campaign() -> void:
	var game: Node = root.get_node("GameManager")
	game.flow.start(self)
	await _frames(3)
	for index in range(game.flow.CHAPTERS.size()):
		if game.flow.CHAPTERS[index].id == "banquet":
			game.flow.index = index
	game.flow.go(self)
	await _frames(10)
	var screen: BanquetScreen = current_scene as BanquetScreen
	_check(screen != null, "the Banquet is a chapter of the campaign")
	if screen == null:
		return
	var briefing: BriefingScreen = get_first_node_in_group("briefing_screen") as BriefingScreen
	_check(briefing != null and paused, "the campaign's Banquet opens on Jessica's briefing")
	if briefing != null:
		briefing.close()
		await _frames(3)
	_check(screen._briefed and screen.banquet.phase == Banquet.Phase.COURSE and not paused, "after Jessica's word, the first course")
	# The first course read right, unhelped, with the number keys.
	var good: int = _reply_graded(screen.banquet, "good")
	_key([KEY_1, KEY_2, KEY_3][good])
	await _frames(3)
	_check(screen.banquet.last_unaided, "a guest read right by Paul alone")
	await _press("CONTINUE")
	await _press("LOOK AT YOUR MOTHER")
	_check(screen.banquet.knows_guest(), "the glance at Jessica, from the screen")
	# Her face, large: it answers each reply Paul weighs, and holds.
	_check(screen._mother.visible and screen._face.has_frames(), "her face appears beside the table")
	_check(screen._face.showing == screen.banquet.mother_at_rest(), "at rest: composed (or, across from the Baron's man, too still)")
	var answers: Dictionary = {}
	var reply_buttons: Array = []
	for node in screen.find_children("*", "Button", true, false):
		if (node as Button).text.contains("PAUL:"):
			reply_buttons.append(node)
	for index in range(reply_buttons.size()):
		(reply_buttons[index] as Button).mouse_entered.emit()
		await _frames(2)
		answers[screen._face.showing] = true
		_check(screen._face.showing == screen.banquet.mother_expression(index), "weighing reply %d, her face shows %s" % [index + 1, screen.banquet.mother_expression(index)])
		(reply_buttons[index] as Button).mouse_exited.emit()
	_check(answers.has(&"approve") and answers.has(&"warn") and answers.has(&"doubt"), "one reply warms her, one cools her, one leaves her doubtful")
	_check(screen._face.showing == screen.banquet.mother_at_rest(), "looking away, she settles")
	var worded: bool = false
	for node in reply_buttons:
		worded = worded or (node as Button).text.contains("He takes it")
	_check(not worded, "the reading is on her face, not spelled out in words")
	for course in range(1, BanquetScript.COURSES.size()):
		if screen.banquet.phase != Banquet.Phase.COURSE:
			break
		_key(KEY_1)
		await _frames(3)
		if screen.banquet.phase == Banquet.Phase.REACTION:
			await _press("CONTINUE")
	if screen.banquet.phase == Banquet.Phase.ACCUSE:
		await _press("Say nothing")
	_check(screen.banquet.phase == Banquet.Phase.DONE, "the evening ends")
	var outcome: MissionOutcome = game.campaign.last_outcome(&"act1_banquet")
	_check(outcome != null and outcome.scopes.has(MissionOutcome.Scope.POLITICAL), "and goes into the campaign's record, once")
	_check(int(game.campaign.hero_progress(&"paul").xp.get(&"statecraft", 0)) >= 5, "Paul's own reading grows his statecraft")
	await _press("CONTINUE")
	await _frames(10)
	_check(game.flow.current().id == "harvester_card", "then on to the next chapter")


func _press(text: String) -> void:
	for node in current_scene.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text.begins_with(text) and not button.disabled and button.is_visible_in_tree():
			button.pressed.emit()
			await _frames(3)
			return
	_check(false, "found a button: " + text)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if description == "":
		return
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
