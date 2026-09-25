extends SceneTree
## Run: godot --headless --path . --script res://tests/pause_menu_smoke.gd
##
## Escape in play opens the pause menu over a stopped world, and Escape again
## gives back exactly the pause it found. Escape already spent elsewhere (an
## armed knife target, a briefing) does not open it; the main menu has its
## own QUIT. Leaving asks once before going.

var failures: int = 0
var menu: PauseMenu


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	menu = root.get_node("GameManager/PauseMenu")
	await _in_play()
	await _escape_spent_elsewhere()
	await _main_menu_has_its_own()
	print("PAUSE MENU SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load(path: String, briefed: bool = false) -> Node:
	if current_scene != null:
		current_scene.queue_free()
		await _frames(3)
	paused = false
	root.get_node("GameManager").pending_briefing = briefed
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(15)
	return scene


func _escape() -> void:
	for pressed in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = pressed
		Input.parse_input_event(key)
		await _frames(2)


func _in_play() -> void:
	await _load("res://scenes/missions/harvester_raid/harvester_raid.tscn")
	_check(not paused, "in play, running")
	await _escape()
	_check(menu.is_open() and paused, "Escape: the pause menu, the world stopped")
	var labels: PackedStringArray = []
	for node in menu.find_children("*", "Button", true, false):
		labels.append((node as Button).text)
	var text: String = " | ".join(labels)
	_check("RESUME" in text and "MAIN MENU" in text and "QUIT GAME" in text, "resume, main menu, quit (%s)" % text)
	await _escape()
	_check(not menu.is_open() and not paused, "Escape again: back to play, running")
	# Opened while the player had paused (SPACE), it gives that pause back.
	(current_scene.get_node("SquadManager") as SquadManager).set_paused(true)
	await _escape()
	await _escape()
	_check(paused, "a pause the player set is still there after the menu closes")
	(current_scene.get_node("SquadManager") as SquadManager).set_paused(false)
	# QUIT asks first.
	await _escape()
	for node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "QUIT GAME":
			(node as Button).pressed.emit()
	await _frames(3)
	var confirm: bool = false
	for node in menu.find_children("*", "Button", true, false):
		if "YES, QUIT" in (node as Button).text:
			confirm = true
	_check(confirm, "quitting asks once more")
	menu.close()
	await _frames(2)


func _escape_spent_elsewhere() -> void:
	var scene: Node = await _load("res://scenes/missions/harvester_raid/harvester_raid.tscn")
	var squad: SquadManager = scene.get_node("SquadManager")
	squad.set_targeting(SquadManager.Targeting.STRIKE)
	await _escape()
	_check(not menu.is_open() and squad.targeting == SquadManager.Targeting.NONE, "Escape cancelling a knife target does not open the menu")
	await _load("res://scenes/missions/act1/harvester_open.tscn", true)
	_check(get_first_node_in_group("briefing_screen") != null, "a briefing is up")
	await _escape()
	_check(not menu.is_open() and get_first_node_in_group("briefing_screen") == null, "Escape closes a briefing, not into the menu")
	menu.close()


func _main_menu_has_its_own() -> void:
	await _load("res://scenes/menu/main_menu.tscn")
	await _escape()
	_check(not menu.is_open(), "the main menu keeps its own QUIT; no pause menu over it")


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
