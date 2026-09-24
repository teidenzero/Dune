extends SceneTree
## Run: godot --headless --path . --script res://tests/story_flow_smoke.gd
##
## The campaign as a player walks it: the main menu, a new campaign, the
## intro's pages, the prologue (the training hall, the yard, the council
## lesson played for real), Act I's cards and 1.1, then back to the menu.
## Scenes are entered and handed on; the tutorials and 1.1 have suites of
## their own.

var failures: int = 0
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = root.get_node("GameManager")
	# The player's own setting must not decide the test - nor be changed by
	# it: music on to start, and whatever they had put back at the end.
	var players_music: bool = game.music_enabled
	game.music_enabled = true
	_check(ProjectSettings.get_setting("application/run/main_scene") == CampaignFlow.MAIN_MENU, "the game opens on the main menu")
	change_scene_to_file(CampaignFlow.MAIN_MENU)
	await _frames(5)
	var menu: MainMenu = current_scene as MainMenu
	_check(menu != null and menu._continue.disabled, "the menu: nothing to continue yet")
	_check(game.music_playing() == game.THEME_MUSIC, "Suspended Pressure plays over the title screen")
	menu.toggle_music()
	_check(not game.music_enabled and game.music_playing() == "" and menu._music.text == "MUSIC:  OFF", "MUSIC: OFF silences it")
	menu.toggle_music()
	_check(game.music_enabled and game.music_playing() == game.THEME_MUSIC and menu._music.text == "MUSIC:  ON", "MUSIC: ON brings it back")
	menu.new_campaign()
	await _frames(5)
	_check(game.flow.active and current_scene is StoryScreen, "NEW CAMPAIGN opens the intro")
	var story: StoryScreen = current_scene as StoryScreen
	_check(story.pages.size() == 4, "four pages of intro")
	_check(game.music_playing() == game.THEME_MUSIC, "and carries on, unbroken, into the story")
	await create_timer(0.8).timeout
	for index in range(4):
		await _press(KEY_SPACE)
	await _frames(5)
	_check(game.flow.current().id == "prologue" and current_scene is StoryScreen, "then the prologue's title card")
	await _press(KEY_SPACE)
	await _frames(15)
	_check(_scene() == "res://scenes/missions/tutorial/solo_training.tscn", "the training hall: Gurney's solo training")
	await create_timer(1.6).timeout
	_check(game.music_playing() == "", "the music fades out when play begins")
	var prompt: Node = current_scene.get_node("TutorialPrompt")
	_check((prompt.get_node("Screen/Summary/Margin/Rows/Buttons/Arena") as Button).text == "Continue", "its closing button carries the story on")
	prompt._on_open_arena()
	await _frames(5)
	_check(game.flow.current().id == "yard_card", "the yard's card")
	await _press(KEY_SPACE)
	await _frames(15)
	_check(_scene() == "res://scenes/missions/tutorial/tutorial_arrakeen.tscn", "the yard: the squad training")
	await _frames(10)
	var paul: Node2D = get_first_node_in_group("player")
	var beside: bool = paul != null and get_nodes_in_group("allies").size() == 2
	for ally: Node2D in get_nodes_in_group("allies"):
		beside = beside and ally.global_position.distance_to(paul.global_position) <= 150.0
	_check(beside, "after the training hall, both Fremen start at Paul's side")
	var squad_step: String = TutorialScript.build(current_scene.get_node("TutorialManager"))[12].speaker if current_scene.has_node("TutorialManager") else ""
	_check(squad_step == "DUKE LETO", "the Duke teaches command")
	game.flow.advance(self)
	await _frames(5)
	await _press(KEY_SPACE)
	await _frames(10)
	var council: CouncilScreen = current_scene as CouncilScreen
	_check(council != null and council.lesson_mission != null and council.lesson_mission.id == &"prologue_water_sellers", "the council chamber: the water-sellers' petition")
	_check(council.has_node("Lesson") and (council.get_node("Lesson/DukeLeto") as DialogueBar).current_speaker == "DUKE LETO", "the Duke talks Paul through it")
	# Play it for real.
	council.open_briefing(council.lesson_mission)
	council.open_operation()
	council.select_approach(council.lesson_mission.political_approaches[1])
	council.select_agent(HeroRoster.all()[0])
	council.forced_roll = 0.0
	council.commit_operation()
	await _frames(2)
	council.choose(council.lesson_mission.political_approaches[1].choices[0])
	await _frames(2)
	_check(game.campaign.last_outcome(&"prologue_water_sellers") != null, "Paul's first decision stands in the campaign")
	_check(council._return_button.text == "CONTINUE", "and the council carries on")
	council._return_button.pressed.emit()
	await _frames(5)
	_check(game.flow.current().id == "act1", "ACT I")
	await _press(KEY_SPACE)
	await _frames(5)
	_check(game.flow.current().id == "hunter_seeker_card", "1.1's card")
	await _press(KEY_SPACE)
	await _frames(20)
	_check(_scene() == "res://scenes/missions/act1/hunter_seeker.tscn", "1.1 The Hunter-Seeker")
	var hud: Node = current_scene.get_node("MissionHUD")
	_check((hud.get_node("Screen/Results/Margin/Rows/Buttons/Launcher") as Button).text == "Continue", "its results carry the story on")
	hud._on_launcher()
	await _frames(5)
	_check(game.flow.current().id == "to_be_continued", "to be continued")
	await _press(KEY_ESCAPE)
	await _frames(5)
	_check(current_scene is MainMenu and not game.flow.active, "and back to the menu")
	game.music_enabled = players_music
	print("STORY FLOW SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _scene() -> String:
	return current_scene.scene_file_path if current_scene != null else ""


func _press(code: Key) -> void:
	# Let the page finish fading in; a press during the fade only finishes it.
	await create_timer(0.8).timeout
	for pressed in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	await _frames(3)
	# A page fades in; a second press would only finish the fade.
	await create_timer(0.8).timeout


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
