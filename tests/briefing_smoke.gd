extends SceneTree
## Run: godot --headless --path . --script res://tests/briefing_smoke.gd
##
## Pre-mission briefings: a mission launched on purpose opens on its briefing
## with the world paused from the first frame (no clock runs behind it) and
## spoken lines held; it shows the situation, what we know for this scene
## (the solo scene has its own), the objectives, the party with its slots,
## and the quartermaster's stock, not yet for sale. BEGIN gives the world
## back; I opens it again mid-mission. A retry, or a scene loaded without the
## launch flag, goes straight in.

var failures: int = 0
var scene: Node
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = root.get_node("GameManager")
	await _straight_in()
	await _harvester_briefing()
	await _solo_briefings()
	await _training_and_councils()
	print("BRIEFING SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load(path: String, briefed: bool) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await _frames(2)
	paused = false
	game.pending_briefing = briefed
	scene = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(10)


func _briefing() -> BriefingScreen:
	return get_first_node_in_group("briefing_screen") as BriefingScreen


## Every label's text on the briefing, joined.
func _text() -> String:
	var screen: BriefingScreen = _briefing()
	if screen == null:
		return ""
	var words: PackedStringArray = []
	for node in screen.find_children("*", "Label", true, false):
		words.append((node as Label).text)
	return "\n".join(words)


func _straight_in() -> void:
	await _load("res://scenes/missions/act1/harvester_open.tscn", false)
	_check(_briefing() == null, "loaded without the launch flag (a retry): straight in, no briefing")


func _harvester_briefing() -> void:
	await _load("res://scenes/missions/act1/harvester_open.tscn", true)
	var screen: BriefingScreen = _briefing()
	_check(screen != null and paused, "launched on purpose: the briefing, the world paused")
	_check(not game.pending_briefing, "and only once")
	var worm: WormThreatManager = scene.get_node("WormThreat")
	var eta: float = worm.event.eta()
	await _frames(30)
	_check(is_equal_approx(worm.event.eta(), eta), "no clock runs behind the briefing (worm %.1fs)" % eta)
	var bar: DialogueBar = scene.get_node("Dialogue")
	_check(not bar.visible and bar.process_mode == Node.PROCESS_MODE_DISABLED, "spoken lines wait")
	var text: String = _text()
	_check("THE HARVESTER IN THE OPEN" in text and "DUKE LETO" in text, "the title and the briefer")
	_check("two men at a time" in text and "injured man must be carried" in text and "seat nine" in text, "what we know: the rules of the place")
	_check("Get the crew to the ornithopters" in text and "(optional)" in text, "the objectives")
	_check(screen.party().size() == 3 and "GURNEY HALLECK" in text and "ATREIDES TROOPER" in text, "the party: Paul, Gurney and the trooper")
	_check("QUARTERMASTER" in text and "Thumper" in text and "HOUSE STORES" in text, "the quartermaster's stock and the House's stores")
	var buttons: Array[Node] = screen.find_children("*", "Button", true, false)
	var requisitions: int = 0
	var open_ones: int = 0
	for node in buttons:
		var button: Button = node as Button
		if button.text == "REQUISITION":
			requisitions += 1
			if not button.disabled:
				open_ones += 1
	_check(requisitions == BriefingScreen.STOCK.size() and open_ones == 0, "requisitions laid out, not yet open")
	screen.close()
	await _frames(20)
	# 1.3 then opens on a plan: the world stopped, Gurney's reminder, SPACE.
	var squad: SquadManager = scene.get_node("SquadManager")
	_check(_briefing() == null and paused and squad.paused, "BEGIN: the field, stopped, to plan in")
	_check("SPACE to execute" in bar.current_text and bar.visible, "Gurney: pause, think, plan, execute")
	squad.set_paused(false)
	await _frames(20)
	_check(not paused, "SPACE: the world goes on")
	_check(bar.process_mode == Node.PROCESS_MODE_ALWAYS, "and the lines with it")
	_check(worm.is_worm_approaching(), "the worm's clock runs now")
	# I, mid-mission: the briefing again, paused, then back.
	var mission: MissionManager = scene.get_node("Mission")
	_check(mission.show_briefing() != null, "I reopens the briefing")
	await _frames(2)
	_check(paused, "paused while it is read")
	_briefing().close()
	await _frames(2)
	_check(not paused, "and back")


func _solo_briefings() -> void:
	await _load("res://scenes/missions/act1/hunter_seeker.tscn", true)
	var text: String = _text()
	_check("THUFIR" in text and "homes on movement" in text, "1.1: Thufir's warning and what we know")
	_check(_briefing() != null and _briefing().party().size() == 1, "1.1: Paul goes alone")
	_briefing().close()
	await _load("res://scenes/missions/harvester_raid/harvester_interior.tscn", true)
	text = _text()
	_check("relay console" in text and not "staging rocks" in text, "the raid's interior has its own intel")
	_briefing().close()
	await _load("res://scenes/missions/harvester_raid/harvester_raid.tscn", true)
	text = _text()
	_check("STILGAR" in text and "staging rocks" in text, "the raid outside has the squad's")
	_briefing().close()
	await _frames(2)


## The trainings, the Council lesson and the Banquet: no mission manager, the
## same briefing. The political ones leave out the party and equipment.
func _training_and_councils() -> void:
	await _load("res://scenes/missions/tutorial/solo_training.tscn", true)
	var text: String = _text()
	_check(_briefing() != null and paused, "the training hall opens on its briefing, paused")
	_check("GURNEY" in text and "master of arms" in text and "WHAT YOU WILL PRACTISE" in text, "Gurney, who he is, and what the lessons are")
	_check("Solo scope" in text and "THE PARTY" in text, "what happens here, and the party")
	_briefing().close()
	await _frames(3)
	_check(not paused, "and the lessons begin")
	await _load("res://scenes/missions/tutorial/tutorial_arrakeen.tscn", true)
	text = _text()
	_check("DUKE LETO" in text and "Duncan Idaho" in text and "Squad scope" in text, "the yard: the Duke, his people, and the squad")
	_briefing().close()
	await _load("res://scenes/missions/tutorial/tutorial_arrakeen.tscn", false)
	_check(_briefing() == null and not paused, "a restarted lesson goes straight in")
	# The Council lesson, as the story reaches it.
	var chapter: int = 0
	for index in range(CampaignFlow.CHAPTERS.size()):
		if CampaignFlow.CHAPTERS[index].id == "council_lesson":
			chapter = index
	game.flow.active = true
	game.flow.index = chapter
	await _load("res://scenes/campaign/council.tscn", true)
	text = _text()
	_check(_briefing() != null and "Political scope" in text and "THE DECISION" in text, "the Council lesson opens on its briefing")
	_check(not "THE PARTY" in text and not "QUARTERMASTER" in text, "no party or equipment at a council table")
	_briefing().close()
	game.flow.active = false
	await _load("res://scenes/campaign/banquet.tscn", true)
	text = _text()
	_check("JESSICA" in text and "Bene Gesserit" in text and "TONIGHT" in text, "the Banquet: Jessica, who she is, and the evening")
	_check(not "THE PARTY" in text, "no equipment at dinner")
	_briefing().close()
	await _frames(3)
	_check((scene as BanquetScreen).get("_briefed") == true and not paused, "her briefing replaces her words at the table")
	await _load("res://scenes/campaign/banquet.tscn", false)
	_check(_briefing() == null and (scene as BanquetScreen).get("_briefed") == false, "without it, she says them at the table as before")


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
