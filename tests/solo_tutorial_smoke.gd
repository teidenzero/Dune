extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/solo_tutorial_smoke.gd
##
## Plays solo training from the first click to the hatch. The first rooms go
## through real input (clicks and keys); the fights are driven through
## TurnCombat's commands with fixed dice. Also checks that the sentry catches
## a hero who walks into his cone, and that a restart resumes at the room.

const TRAINING: String = "res://scenes/missions/tutorial/solo_training.tscn"

var failures: int = 0
var scene: Node
var tutorial: SoloTutorial
var player: PlayerController
var combat: TurnCombat


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameManager").tutorial_checkpoint = &""
	TutorialStep.read_scale = 0.0
	await _load()
	await _moving()
	await _walls_and_console()
	await _sneaking()
	await _silent_kill()
	await _taking_it_back()
	await _spotted()
	await _shields()
	await _fuel_and_exit()
	await _caught_by_the_sentry()
	await _restart_resumes()
	await _tank_in_real_time()
	await _tank_in_prescience()
	await _timing_is_possible()
	print("SOLO TUTORIAL SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await _frames(2)
	scene = (load(TRAINING) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(25)
	tutorial = scene.get_node("Tutorial")
	player = scene.get_node("World/Player")
	combat = tutorial.combat


func _step() -> StringName:
	var step: TutorialStep = tutorial.current_step()
	return step.id if step != null else &""


## The Timing lesson can be done as taught: from the door, standing, the knife
## reaches his back in one turn wherever he is on his round; crouched, the
## readout says to stand.
func _timing_is_possible() -> void:
	root.get_node("GameManager").tutorial_checkpoint = &"fire"
	await _load()
	var soldier: EnemyCharacter = tutorial.guards["r"]
	soldier.set_physics_process(false)
	soldier.ai.set_physics_process(false)
	soldier.perception.set_physics_process(false)
	var all_fit: bool = true
	var worst: int = 0
	for cell in [Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9)]:
		soldier.global_position = IsoMath.cell_to_world(cell)
		soldier.face_position(IsoMath.cell_to_world(cell + Vector2i(-3, 0)))
		player.teleport_to(IsoMath.cell_to_world(Vector2i(17, 9)))
		player.set_crouching(false)
		await _frames(30)
		combat.begin(true, [], false)
		await _frames(5)
		soldier.face_position(IsoMath.cell_to_world(cell + Vector2i(-3, 0)))
		combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
		var plan: Dictionary = combat.preview_attack(soldier)
		all_fit = all_fit and plan.ok and plan.note == "FROM BEHIND: SILENT KILL"
		worst = maxi(worst, plan.cost)
		if cell == Vector2i(10, 9):
			player.set_crouching(true)
			var low: Dictionary = combat.preview_attack(soldier)
			_check(not low.ok and low.note.contains("STAND (C)"), "crouched at the far end it is too far - and the readout says to stand")
			player.set_crouching(false)
		combat._finish()
		await _frames(5)
	_check(all_fit and worst <= 9, "from the door, standing, a silent kill fits in one turn at every point of his round, with room to spare (worst %d AP)" % worst)
	# Waiting low at the door for two whole rounds, he never sees the doorway.
	soldier.set_physics_process(true)
	soldier.ai.set_physics_process(true)
	soldier.perception.set_physics_process(true)
	soldier.ai.change_state(EnemyAIController.State.PATROL)
	player.teleport_to(IsoMath.cell_to_world(Vector2i(17, 9)))
	player.set_crouching(true)
	var spotted: bool = false
	for index in range(60 * 12):
		if soldier.perception.detection_value > soldier.perception.detection_max * 0.5 or combat.active():
			spotted = true
			break
		await _frames(1)
	_check(not spotted, "crouched at the door he does not spot you, through two whole rounds")
	root.get_node("GameManager").tutorial_checkpoint = &""


## Waits for the tutorial to move on to `id` (or finish), up to `seconds`.
func _until_step(id: StringName, seconds: float = 12.0) -> bool:
	for index in range(int(seconds * 60.0)):
		if _step() == id or (id == &"" and not tutorial.running):
			return true
		await _frames(1)
	return _step() == id


func _until(condition: Callable, seconds: float = 12.0) -> bool:
	for index in range(int(seconds * 60.0)):
		if condition.call():
			return true
		await _frames(1)
	return bool(condition.call())


func _cell_point(cell: Vector2i) -> Vector2:
	return IsoMath.cell_to_world(cell)


func _moving() -> void:
	_check(_step() == &"move" and IsoMath.world_to_cell(player.global_position) == Vector2i(2, 3), "training starts in the first room, on the first lesson")
	var door: IsoDoor = tutorial.level.door_at(SoloTutorial.DOORS[0])
	_check(door.locked, "its door is locked")
	_click(tutorial.level.mark("a") + Vector2(10, 4), MOUSE_BUTTON_LEFT)
	_check(await _until_step(&"run"), "a click walks him to the marked tile")
	await _frames(90)
	var heading: Label = scene.get_node("TutorialPrompt/Screen/Prompt/Margin/Line/Rows/Title")
	_check(heading.text == "RUNNING", "the prompt shows the new lesson's name, not the last one's")
	_click(tutorial.level.mark("b"), MOUSE_BUTTON_LEFT)
	await _frames(3)
	_click(tutorial.level.mark("b"), MOUSE_BUTTON_LEFT)
	_check(await _until_step(&"dodge"), "two clicks: he runs to the far marker")
	_key(KEY_SPACE)
	_check(await _until_step(&"walls"), "Space dodges")
	_check(not door.locked, "and the door opens")


func _walls_and_console() -> void:
	player.move_to(tutorial.level.mark("c"))
	_check(await _until_step(&"use", 15.0), "behind the pillar")
	_click(tutorial.level.mark("u"), MOUSE_BUTTON_RIGHT)
	_check(await _until_step(&"sneak", 15.0), "a right-click on the console works it")
	_check(not tutorial.level.door_at(SoloTutorial.DOORS[1]).locked, "and it opens the next door")


func _sneaking() -> void:
	_check(not combat.auto_engage and not combat.allow_voluntary, "in the sentry's room, being seen restarts the room instead of a fight")
	player.move_to(_cell_point(Vector2i(17, 3)))
	await _until(func() -> bool: return player.order == PlayerController.Order.IDLE, 15.0)
	_key(KEY_C)
	await _frames(3)
	_check(player.is_crouching, "C: sneaking")
	player.move_to(_cell_point(Vector2i(17, 5)))
	await _until(func() -> bool: return player.order == PlayerController.Order.IDLE, 15.0)
	player.move_to(tutorial.level.mark("d"))
	_check(await _until_step(&"prescience", 15.0), "crouched, behind the pillars, to the marker unseen")
	_check(combat.auto_engage and tutorial.guards["s"].get_meta("dormant"), "the sentry is out of the lesson now")


func _silent_kill() -> void:
	player.move_to(_cell_point(Vector2i(20, 7)))
	await _until(func() -> bool: return player.order == PlayerController.Order.IDLE, 15.0)
	_key(KEY_Q)
	_check(await _until_step(&"silent_kill"), "Q: into a fight, as a vision")
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
	_key(KEY_2)
	await _frames(2)
	var soldier: EnemyCharacter = tutorial.guards["k"]
	_check(combat.preview_attack(soldier).note == "FROM BEHIND: SILENT KILL", "the readout promises a silent kill")
	_click(soldier.global_position + Vector2(0, -30), MOUSE_BUTTON_LEFT)
	_check(await _until_step(&"accept"), "one click: he dies without a sound")
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
	_key(KEY_SPACE)
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PROMPT)
	_key(KEY_ENTER)
	_check(await _until_step(&"try_door"), "end the turn, accept the future: back to real time")


func _taking_it_back() -> void:
	var soldier: EnemyCharacter = tutorial.guards["r"]
	player.move_to(_cell_point(Vector2i(17, 9)))
	await _until(func() -> bool: return player.order == PlayerController.Order.IDLE, 15.0)
	# Freeze him mid-round, facing the door, for the lesson in refusing a future.
	soldier.global_position = _cell_point(Vector2i(11, 9))
	soldier.face_position(_cell_point(Vector2i(16, 9)))
	_key(KEY_Q)
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
	soldier.face_position(_cell_point(Vector2i(16, 9)))
	combat.forced_roll = 0.0
	combat.command_move(Vector2i(14, 9))
	_check(await _until_step(&"rewind"), "through the door, in the vision: the soldier sees him")
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
	_key(KEY_Q)
	_check(await _until_step(&"fire"), "Q takes it back")
	_check(not combat.active() and IsoMath.world_to_cell(player.global_position) == Vector2i(17, 9), "and he is back at the door, unseen")
	_check(soldier.patrol_route != null and soldier.patrol_route.get_points().size() == 2, "the soldier walks a round between two posts")
	# Crouch at the door and wait for his back, as the lesson says.
	_key(KEY_C)
	await _frames(3)
	var turned: bool = await _until(func() -> bool:
		var forward: Vector2 = Vector2.RIGHT.rotated(soldier.aim_pivot.global_rotation)
		return forward.x < -0.3 and soldier.ai.state == EnemyAIController.State.PATROL, 20.0)
	_check(turned, "on his round he turns his back to the door")
	_key(KEY_Q)
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
	combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
	var plan: Dictionary = combat.preview_attack(soldier)
	_check(plan.note == "FROM BEHIND: SILENT KILL", "timed right, the readout promises a silent kill")
	if plan.ok:
		await combat.command_attack(soldier)
	else:
		# Too far for one turn: close the distance, then cut.
		await combat.command_move(IsoMath.world_to_cell(soldier.global_position) + Vector2i(2, 0))
		combat.end_turn()
		await _until(func() -> bool: return combat.phase in [TurnCombat.Phase.PLAYER, TurnCombat.Phase.PROMPT])
		if combat.phase == TurnCombat.Phase.PROMPT:
			combat.accept_vision()
			_key(KEY_Q)
			await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
		combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
		await combat.command_attack(soldier)
	_check(soldier.health.is_dead and not combat.aware.has(soldier), "the knife in his back: dead, never having seen Paul")
	await _finish_quiet_fight()
	_check(await _until_step(&"spotted"), "the lesson done: next room")


## End a fight nobody else knows about: end the turn, accept the vision.
func _finish_quiet_fight() -> void:
	for attempt in range(6):
		if not combat.active():
			return
		if combat.phase == TurnCombat.Phase.PROMPT:
			combat.accept_vision()
		elif combat.phase == TurnCombat.Phase.PLAYER:
			combat.end_turn()
		await _frames(20)


func _spotted() -> void:
	var g: EnemyCharacter = tutorial.guards["g"]
	var h: EnemyCharacter = tutorial.guards["h"]
	player.move_to(_cell_point(Vector2i(7, 9)))
	await _until(func() -> bool: return player.order == PlayerController.Order.IDLE, 20.0)
	await _frames(60)
	_check(not combat.active(), "the doorway is out of both soldiers' sight")
	_key(KEY_Q)
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
	combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
	var before: Dictionary = combat.preview_attack(g)
	var stone_cell: Vector2i = Vector2i(1, 9)
	_key(KEY_4)
	await _frames(2)
	_check(combat.distract_armed, "4 readies a stone")
	var throw: Dictionary = combat.preview_distract(stone_cell)
	_check(throw.ok and throw.listeners.has(g) and throw.listeners.has(h), "both soldiers are in earshot of the far wall")
	_click(_cell_point(stone_cell), MOUSE_BUTTON_LEFT)
	await _frames(3)
	var target: Vector2 = _cell_point(stone_cell)
	var facing_g: Vector2 = Vector2.RIGHT.rotated(g.aim_pivot.global_rotation)
	var facing_h: Vector2 = Vector2.RIGHT.rotated(h.aim_pivot.global_rotation)
	_check(facing_g.dot(g.global_position.direction_to(target)) > 0.9 and facing_h.dot(h.global_position.direction_to(target)) > 0.9, "a thrown stone: both turn to look at the wall")
	_check(combat.points == 8, "two points for the stone")
	await _silent_knife(g)
	_check(g.health.is_dead and not combat.aware.has(h), "the first dies silently; the second, looking away, never sees it")
	await _silent_knife(h)
	_check(h.health.is_dead, "and then the second")
	await _finish_quiet_fight()
	_check(await _until_step(&"shield_up"), "both down without a shot fired")


## Knife `soldier` from behind, across as many turns (and visions) as it takes.
func _silent_knife(soldier: EnemyCharacter) -> void:
	for attempt in range(4):
		if soldier.health.is_dead:
			return
		if not combat.active():
			_key(KEY_Q)
			await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
		if combat.phase == TurnCombat.Phase.PROMPT:
			combat.accept_vision()
			await _frames(10)
			continue
		combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
		var plan: Dictionary = combat.preview_attack(soldier)
		if plan.ok:
			await combat.command_attack(soldier)
			await _frames(5)
		else:
			combat.end_turn()
			await _until(func() -> bool: return combat.phase in [TurnCombat.Phase.PLAYER, TurnCombat.Phase.PROMPT] or not combat.active())


func _shields() -> void:
	player.move_to(_cell_point(Vector2i(4, 13)))
	_check(await _until(func() -> bool: return combat.active(), 20.0), "the shielded soldier sees him")
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER, 20.0)
	_key(KEY_T)
	_check(await _until_step(&"slow_blade"), "T raises the shield")
	var soldier: EnemyCharacter = tutorial.guards["e"]
	combat.select_attack(TurnRules.Attack.FIRE)
	_check(combat.preview_attack(soldier).note == "SHIELD STOPS BULLETS", "the readout says a bullet will not pass")
	await _win_fight(TurnRules.Attack.SLOW_KNIFE)
	_check(await _until_step(&"tank"), "the slow blade finishes him")


func _fuel_and_exit() -> void:
	player.move_to(_cell_point(Vector2i(9, 15)))
	await _until(func() -> bool: return player.order == PlayerController.Order.IDLE, 15.0)
	_key(KEY_Q)
	_check(await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER, 20.0), "two more, by the tank, backs turned: Q")
	var tank: FuelTank = tutorial.level.tanks[0]
	await combat.command_attack(tank)
	await _frames(20)
	_check(tank.detonated, "one shot at the tank and it goes up")
	var hurt: bool = true
	for symbol in ["m", "n"]:
		var soldier: EnemyCharacter = tutorial.guards[symbol]
		hurt = hurt and (soldier.health.is_dead or soldier.health.current_health < soldier.health.max_health)
	_check(hurt, "taking both soldiers with it")
	await _win_fight()
	_check(await _until_step(&"exit"), "the last room")
	player.move_to(tutorial.hatch.global_position)
	_check(await _until_step(&"", 15.0), "out through the hatch: training complete")
	var summary: Control = scene.get_node("TutorialPrompt/Screen/Summary")
	await _frames(3)
	_check(summary.visible and (scene.get_node("TutorialPrompt/Screen/Summary/Margin/Rows/Buttons/Arena") as Button).text == "Inside the Harvester", "the summary offers the harvester next")


## The sentry catches a hero who simply walks across his room.
func _caught_by_the_sentry() -> void:
	root.get_node("GameManager").tutorial_checkpoint = &"sneak"
	await _load()
	_check(_step() == &"sneak" and IsoMath.world_to_cell(player.global_position) == Vector2i(17, 3), "a restart at the sentry's room puts him at its door")
	player.move_to(_cell_point(Vector2i(21, 2)))
	var failed: Array = [false]
	tutorial.tutorial_failed.connect(func(_reason: String) -> void: failed[0] = true)
	_check(await _until(func() -> bool: return failed[0], 20.0), "walking into the cone: he sees you")
	await _frames(120)
	_check(IsoMath.world_to_cell(player.global_position) == Vector2i(17, 3) and _step() == &"sneak", "back to the door, same lesson")


func _restart_resumes() -> void:
	root.get_node("GameManager").tutorial_checkpoint = &"shield_up"
	await _load()
	_check(_step() == &"shield_up", "a checkpoint resumes at its lesson")
	_check(not is_instance_valid(tutorial.guards["g"]) or tutorial.guards["g"].is_queued_for_deletion(), "earlier rooms are cleared")
	_check(not tutorial.level.door_at(SoloTutorial.DOORS[5]).locked and tutorial.level.door_at(SoloTutorial.DOORS[6]).locked, "their doors open, this room's exit still locked")
	root.get_node("GameManager").tutorial_checkpoint = &""


## Out of prescience: a right-click on the drum opens the fight with Paul's
## shot at it - he acts first, because he attacked first.
func _tank_in_real_time() -> void:
	root.get_node("GameManager").tutorial_checkpoint = &"tank"
	await _load()
	var tank: FuelTank = tutorial.level.tanks[0]
	var squad: SquadManager = scene.get_node("SquadManager")
	_check(squad.context_kind(tank.global_position) == "FIRE", "hovering the drum reads FIRE")
	tutorial.combat.forced_roll = 0.0
	_click(tank.global_position, MOUSE_BUTTON_RIGHT)
	await _frames(3)
	_check(tutorial.combat.active() and not tutorial.combat.in_vision and tutorial.combat.acting == player, "a right-click on the drum opens the fight on Paul's turn, with the shot")
	_check(await _until(func() -> bool: return tank.detonated, 8.0), "and it goes up")
	var hurt: bool = true
	for symbol in ["m", "n"]:
		var soldier: EnemyCharacter = tutorial.guards[symbol]
		hurt = hurt and (soldier.health.is_dead or soldier.health.current_health < soldier.health.max_health)
	_check(hurt and tutorial.guards["m"].health.is_dead and tutorial.guards["n"].health.is_dead, "taking the two soldiers with it: both dead")
	_check(await _until(func() -> bool: return not tutorial.combat.active() and not player.turn_based, 2.0), "and the fight is over: back to real time")
	root.get_node("GameManager").tutorial_checkpoint = &""


## In prescience: clicking the drum targets the drum, not the soldier by it.
func _tank_in_prescience() -> void:
	root.get_node("GameManager").tutorial_checkpoint = &"tank"
	await _load()
	var tank: FuelTank = tutorial.level.tanks[0]
	_key(KEY_Q)
	await _until(func() -> bool: return combat.phase == TurnCombat.Phase.PLAYER)
	_check(combat.target_at(tank.global_position) == tank, "a click on the drum picks the drum")
	combat.forced_roll = 0.0
	_click(tank.global_position, MOUSE_BUTTON_LEFT)
	_check(await _until(func() -> bool: return tank.detonated, 5.0), "one shot, and it goes up in the vision too")
	await _frames(20)
	_check(tutorial.guards["m"].health.is_dead and tutorial.guards["n"].health.is_dead, "and the blast kills both soldiers")
	root.get_node("GameManager").tutorial_checkpoint = &""


## Fight until nobody is left who knows about him: shoot (or cut) the
## nearest, reload when empty, end the turn when out of points.
func _win_fight(attack: TurnRules.Attack = TurnRules.Attack.FIRE) -> void:
	combat.forced_roll = 0.0
	for turn in range(20):
		if not await _until(func() -> bool: return combat.phase in [TurnCombat.Phase.PLAYER, TurnCombat.Phase.PROMPT] or not combat.active(), 20.0):
			return
		if not combat.active():
			return
		if combat.phase == TurnCombat.Phase.PROMPT:
			combat.accept_vision()
			await _frames(2)
			continue
		# Fixed dice hit both ways; the test is about the flow, not the odds.
		player.health.current_health = player.health.max_health
		combat.select_attack(attack)
		var acted: bool = true
		while acted and combat.phase == TurnCombat.Phase.PLAYER:
			acted = false
			if attack == TurnRules.Attack.FIRE and player.weapon_controller.current_ammo <= 0 and combat.points >= TurnRules.RELOAD_COST:
				await combat.command_reload()
				acted = true
				continue
			for enemy in combat._aware_living():
				if combat.preview_attack(enemy).ok:
					await combat.command_attack(enemy)
					acted = true
					break
		if combat.phase == TurnCombat.Phase.PROMPT:
			combat.accept_vision()
		elif combat.phase == TurnCombat.Phase.PLAYER:
			combat.end_turn()
		await _frames(2)


func _click(world: Vector2, button: MouseButton) -> void:
	var viewport: Viewport = scene.get_viewport()
	var screen: Vector2 = viewport.get_screen_transform() * (viewport.get_canvas_transform() * world)
	for pressed in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		Input.parse_input_event(event)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


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
		print("   state: step=%s phase=%d aware=%d vision=%s points=%d hero=%s hp=%d" % [_step(), combat.phase, combat._aware_living().size(), combat.in_vision, combat.points, IsoMath.world_to_cell(player.global_position), player.health.current_health])
		for enemy in combat._aware_living():
			print("     aware ", enemy.name, " at ", IsoMath.world_to_cell(enemy.global_position), " hp ", enemy.health.current_health, " preview ", combat.preview_attack(enemy))
