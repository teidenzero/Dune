extends SceneTree
## Run: godot --headless --path . --script res://tests/training_jump_smoke.gd
##
## F10 in either training lists every lesson; picking one reloads the training
## straight into it, without the briefing, with the world running again.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_training("res://scenes/missions/tutorial/tutorial_arrakeen.tscn", "tutorial_manager", &"route_plan")
	await _check_training("res://scenes/missions/tutorial/solo_training.tscn", "solo_tutorial", &"slow_blade")
	print("TRAINING JUMP SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _check_training(path: String, group: String, target: StringName) -> void:
	var game: Node = root.get_node("GameManager")
	game.tutorial_checkpoint = &""
	if current_scene != null:
		current_scene.queue_free()
		await _frames(3)
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(20)
	var host: Node = get_first_node_in_group(group)
	var menu: TrainingJumpMenu = host.get_node("JumpMenu")
	menu.open()
	await _frames(2)
	var buttons: int = menu.find_children("*", "Button", true, false).size()
	_check(menu.visible and paused, "%s: F10 opens the lesson list, paused" % path.get_file())
	_check(buttons == (host.get("steps") as Array).size(), "every lesson is listed (%d)" % buttons)
	menu.jump_to(target)
	await _frames(30)
	var fresh: Node = get_first_node_in_group(group)
	var step: TutorialStep = fresh.call("current_step")
	_check(step != null and step.id == target, "picking %s reloads straight into it" % target)
	_check(not paused and get_first_node_in_group("briefing_screen") == null, "running, with no briefing in the way")
	game.tutorial_checkpoint = &""


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
