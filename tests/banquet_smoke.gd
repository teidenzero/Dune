extends SceneTree
## Run: godot --headless --path . --script res://tests/banquet_smoke.gd
##
## 1.2 The Banquet: the table is set by a seed and nothing else; readings and
## glimpses show how a guest takes a reply before it is said; the table's
## composure ends the evening early at zero; naming the informant (right,
## wrong, or not at all); Kynes's trust; every reply written for every agenda;
## and the screen played through inside the campaign.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_the_data_is_complete()
	_seeded_and_fair()
	_reading_and_glimpsing()
	_composure_ends_it()
	_naming_the_informant()
	_kynes_trust()
	await _played_in_the_campaign()
	print("BANQUET SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _the_data_is_complete() -> void:
	var complete: bool = true
	for course in BanquetScript.COURSES:
		var guest: Dictionary = BanquetScript.guest(course.guest)
		var agendas: Array = guest.agendas.duplicate()
		if guest.may_inform:
			agendas.append(&"informant")
		for reply in course.replies:
			for agenda in agendas:
				complete = complete and reply.reactions.has(agenda)
			complete = complete and BanquetScript.AGENDAS.has(agendas[0])
	_check(complete, "every reply is written for every agenda its guest could have")
	_check(BanquetScript.COURSES.size() == 5 and BanquetScript.GUESTS.size() == 5, "five guests, five courses")


func _seeded_and_fair() -> void:
	var a: Banquet = Banquet.create(11)
	var b: Banquet = Banquet.create(11)
	_check(a.agendas == b.agendas and a.informant == b.informant, "the same seed sets the same table")
	var informants: Dictionary = {}
	for seed_value in range(40):
		var table: Banquet = Banquet.create(seed_value)
		informants[table.informant] = true
		_check(BanquetScript.guest(table.informant).may_inform and table.agendas[table.informant] == &"informant", "the informant is one who could be (%d)" % seed_value) if seed_value < 3 else null
	_check(informants.size() == 3, "over many dinners, any of the three suspects may be the informant")


func _reading_and_glimpsing() -> void:
	var table: Banquet = Banquet.create(3)
	var plain: Dictionary = table.preview(0)
	_check(not plain.known and plain.effects == BanquetScript.COURSES[0].replies[0].effects, "unread, a reply shows only what is certain")
	_check(table.read(&"water") and table.knows_reactions(), "Jessica reads the guest: how he will take it shows")
	_check(table.preview(0).known and table.preview(0).line != "", "and each reply now shows his reaction")
	_check(table.agenda_text(&"water") != "" and table.agenda_text(&"guild") == "", "his agenda shows; the others' do not")
	_check(not table.read(&"water"), "a guest is read once")
	_check(table.read(&"guild") and not table.read(&"choam"), "two readings, no more")
	table.choose(0)
	table.next()
	table.choose(0)
	table.next()
	_check(not table.knows_reactions(), "an unread guest's course is guesswork")
	_check(table.glimpse() and table.knows_reactions(), "Paul's glimpse shows this course's reactions")
	_check(not table.glimpse(), "one glimpse, spent")
	var grown: Banquet = Banquet.create(3, 2)
	_check(grown.glimpses_left == BanquetScript.GLIMPSES + 2, "prescience grown with spice gives more glimpses")


func _composure_ends_it() -> void:
	var table: Banquet = Banquet.create(5)
	table.composure = 1
	# Paul's sharp reply always costs the table.
	table.choose(2)
	table.next()
	_check(table.phase == Banquet.Phase.DONE and table.ended_early, "the table goes cold: the Duke ends the dinner")
	var outcome: MissionOutcome = table.outcome()
	_check(outcome.tier == MissionOutcome.Tier.PARTIAL, "an evening cut short is a partial success")
	_check(int(outcome.standings.get(&"smugglers", 0)) < 0, "the guests not heard leave offended")
	_check(outcome.flags.has("kynes_doubts") or outcome.flags.has("kynes_undecided") or outcome.flags.has("kynes_trusts"), "Kynes still leaves with an opinion")


func _play_to_accusation(table: Banquet) -> void:
	for index in range(BanquetScript.COURSES.size()):
		table.choose(1)
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
	var innocent: StringName = &"smuggler"
	wrong.accuse(innocent)
	_check(wrong.flags.has("wrong_accusation") and int(wrong.standings.get(&"smugglers", 0)) <= -1, "an innocent man named: his people remember it")
	var silent: Banquet = Banquet.create(9)
	_play_to_accusation(silent)
	silent.accuse(&"")
	_check(silent.flags.has("informant_hidden") and not silent.flags.has("wrong_accusation"), "naming no one is safe, and he keeps listening")


func _kynes_trust() -> void:
	var warm: Banquet = Banquet.create(2)
	# Water for the thirsty, men before spice, the planet's thirst.
	for choice in [2, 0, 1, 2, 1]:
		warm.choose(choice)
		warm.next()
	warm.accuse(&"")
	_check(warm.kynes_trust >= BanquetScript.KYNES_TRUSTS and warm.flags.has("kynes_trusts"), "spoken for water and people, Kynes trusts the House")
	var swing: bool = true
	for faction in warm.outcome().standings:
		swing = swing and absi(int(warm.outcome().standings[faction])) <= BanquetScript.MAX_SWING
	_check(swing, "one evening moves a faction two steps at most")
	var cold: Banquet = Banquet.create(2)
	for choice in [1, 2, 0, 0, 0]:
		cold.choose(choice)
		cold.next()
	if cold.phase == Banquet.Phase.ACCUSE:
		cold.accuse(&"")
	_check(cold.flags.has("kynes_doubts"), "spoken for spice, Kynes doubts it")


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
	await _press("BEGIN THE DINNER")
	_check(screen._briefed and screen.banquet.phase == Banquet.Phase.COURSE, "after Jessica's word, the first course")
	# Choose with the number keys, continue with the button, five times.
	for course in range(BanquetScript.COURSES.size()):
		_key(KEY_1)
		await _frames(3)
		if screen.banquet.phase == Banquet.Phase.REACTION:
			await _press("CONTINUE")
		if screen.banquet.phase == Banquet.Phase.DONE:
			break
	if screen.banquet.phase == Banquet.Phase.ACCUSE:
		await _press("Say nothing")
	_check(screen.banquet.phase == Banquet.Phase.DONE, "the evening ends")
	var outcome: MissionOutcome = game.campaign.last_outcome(&"act1_banquet")
	_check(outcome != null and outcome.scopes.has(MissionOutcome.Scope.POLITICAL), "and goes into the campaign's record, once")
	await _press("CONTINUE")
	await _frames(10)
	_check(game.flow.current().id == "to_be_continued", "then on to the next chapter")


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
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
