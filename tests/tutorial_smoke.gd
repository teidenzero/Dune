extends SceneTree
## Milestone 6.1: the Arrakeen tutorial driven end to end.
##
## Every step is satisfied by performing the real action through the real
## systems - right-click orders, selection keys, C / E / F / Space / Q - so a
## pass here is also an integration test of Milestones 1-6 under RTS control.

const Order = AllyAIController.Order
const Link = CommandLinkComponent.State
const TUTORIAL: String = "res://scenes/missions/tutorial/tutorial_arrakeen.tscn"

var failures: int = 0
var completed: int = 0
var mission: Node2D
var tutorial: TutorialManager
var player: PlayerController
var squad: SquadManager
var camera: TacticalCamera
var scout: AllyCharacter
var warrior: AllyCharacter


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Reading time is checked once, below; elsewhere lessons move on at once.
	TutorialStep.read_scale = 0.0
	await _framework_and_movement()
	await _ranged_section()
	await _melee_and_shields()
	await _stealth_section()
	await _squad_section()
	await _recon_section()
	await _prescience_section()
	await _desert_section()
	await _combined_and_finish()
	await _developer_navigation()
	_check(completed == 10, "all tutorial scenarios completed")
	_check(Engine.time_scale == 1.0, "suite leaves normal game speed")
	_check(not paused, "suite leaves the game unpaused")
	print("TUTORIAL SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


# --------------------------------------------------------------------------
# Harness
# --------------------------------------------------------------------------

func _load(reset_checkpoint: bool = true) -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	if reset_checkpoint:
		root.get_node("GameManager").tutorial_checkpoint = &""
	root.get_node("GameManager").debug_visible = false
	mission = load(TUTORIAL).instantiate()
	root.add_child(mission)
	current_scene = mission
	await _frames(20)
	_bind()


func _bind() -> void:
	mission = current_scene as Node2D
	tutorial = mission.get_node("TutorialManager")
	player = mission.get_node("Player")
	squad = mission.get_node("SquadManager")
	camera = player.get_node("TacticalCamera")
	scout = mission.get_node("Allies/Scout")
	warrior = mission.get_node("Allies/Warrior")


func _step_id() -> StringName:
	var step: TutorialStep = tutorial.current_step()
	return step.id if step != null else &""


## Waits for the sequencer to arrive at a step, allowing for completion holds.
func _await_step(id: StringName, limit: int = 400) -> bool:
	for index in range(limit):
		if _step_id() == id:
			return true
		await _frames(1)
	return _step_id() == id


## Waits for Paul to finish his current order.
func _await_idle(limit: int = 900) -> bool:
	for index in range(limit):
		if player.order == PlayerController.Order.IDLE:
			return true
		await _frames(1)
	return player.order == PlayerController.Order.IDLE


## Direct placement, kept for the failure and restart scenarios only.
func _place(point: Vector2) -> void:
	player.teleport_to(point)


## Faces Paul somewhere without an order, for a single scripted shot.
func _face(point: Vector2) -> void:
	player.aim_direction = player.global_position.direction_to(point)
	player.aim_pivot.rotation = player.aim_direction.angle()


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(2)


## Window coordinates for a world point. Input events arrive in window space,
## which the 1920 x 1080 canvas is stretched into.
func _screen(world: Vector2) -> Vector2:
	var viewport: Viewport = mission.get_viewport()
	return viewport.get_screen_transform() * (viewport.get_canvas_transform() * world)


## The camera does not follow Paul: pan to what the player is about to click.
func _look_at(world: Vector2) -> void:
	if not camera.sees(world, 120.0):
		camera.snap_to(world)
		await _frames(2)


func _mouse(button: MouseButton, world: Vector2, pressed: bool, ctrl: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	event.position = _screen(world)
	event.global_position = event.position
	Input.parse_input_event(event)


func _right_click(world: Vector2) -> void:
	await _look_at(world)
	_mouse(MOUSE_BUTTON_RIGHT, world, true)
	_mouse(MOUSE_BUTTON_RIGHT, world, false)
	await _frames(1)


## Ctrl + right-click: plan an order for the signal.
func _plan_click(world: Vector2) -> void:
	await _look_at(world)
	_mouse(MOUSE_BUTTON_RIGHT, world, true, true)
	_mouse(MOUSE_BUTTON_RIGHT, world, false, true)
	await _frames(1)


func _double_right_click(world: Vector2) -> void:
	await _right_click(world)
	await _right_click(world)


func _left_click(world: Vector2) -> void:
	await _look_at(world)
	_mouse(MOUSE_BUTTON_LEFT, world, true)
	_mouse(MOUSE_BUTTON_LEFT, world, false)
	await _frames(1)


## Left-click on the target: a quick click, or held past the charge threshold
## for the slow strike - the crysknife through its real input.
func _strike(target: Node2D, slow: bool) -> void:
	if slow:
		await _look_at(target.global_position)
		_mouse(MOUSE_BUTTON_LEFT, target.global_position, true)
		await _frames(1)
		var until: int = Time.get_ticks_msec() + int((squad.slow_hold_seconds() + 0.1) * 1000.0)
		while Time.get_ticks_msec() < until:
			await process_frame
		_mouse(MOUSE_BUTTON_LEFT, target.global_position, false)
		await _frames(1)
	else:
		await _left_click(target.global_position)
	await _frames(2)
	for index in range(400):
		if player.order != PlayerController.Order.MELEE and player.melee.state == MeleeController.State.IDLE:
			break
		await _frames(1)


# --------------------------------------------------------------------------
# Scenario 1 - framework and movement
# --------------------------------------------------------------------------

func _framework_and_movement() -> void:
	await _load()
	_check(tutorial != null and tutorial.running, "tutorial manager starts running")
	_check(tutorial.steps.size() >= 20 and tutorial.sections.size() == 9, "step sequence and nine sections are built")
	_check(_step_id() == &"move_marker" and tutorial.current_section() == &"movement", "the first movement step is active")
	_check(tutorial.current_step().state == TutorialStep.State.ACTIVE, "the active step reports ACTIVE")
	_check(squad.paul_selected and squad.selected_members.size() == 2, "the whole squad starts selected: Paul and both Fremen")
	var beside: bool = true
	for member in squad.members:
		beside = beside and member.global_position.distance_to(player.global_position) < 160.0
	_check(beside, "the Fremen start right beside Paul, not across the yard")
	# Abilities not yet taught are withheld, and the section gate is shut.
	_check(not player.weapon_controller.enabled, "the pistol is withheld before the firing range")
	_check(not player.melee.enabled, "the crysknife is withheld before the blade yard")
	_check(squad.commands_enabled, "the squad takes orders from the first step")
	var gate: TutorialGate = tutorial.find(&"Gate_movement") as TutorialGate
	_check(gate != null and not gate.is_open, "the next section is gated shut")
	_check((tutorial.find(&"Marker_MoveA") as TutorialMarker).active, "the current step's marker is highlighted")
	_check(not (tutorial.find(&"Marker_Overlook") as TutorialMarker).active, "later markers stay hidden")
	# The Fremen answer from the start.
	await _tap(KEY_2)
	_check(squad.selected_members.size() == 1 and not squad.paul_selected, "2 selects the Scout alone, from the first yard")
	await _tap(KEY_4)
	await _tap(KEY_1)
	_check(squad.paul_selected, "1 selects Paul")
	# Hints appear only after the configured delay.
	_check(not tutorial.hint_shown, "no hint is shown immediately")
	tutorial.step_time = tutorial.current_step().hint_delay + 0.1
	await _frames(2)
	_check(tutorial.hint_shown, "an unfinished step eventually offers a hint")
	# The prompt folds away with Tab and keeps a log on L.
	var prompt: Node = mission.get_node("TutorialPrompt")
	await _tap(KEY_TAB)
	await _frames(2)
	_check(prompt.collapsed and not prompt.panel.visible and prompt._tab.visible, "Tab folds the lesson away to a small tab")
	await _tap(KEY_TAB)
	await _frames(2)
	_check(not prompt.collapsed and prompt.panel.visible and not prompt._tab.visible, "Tab again brings it back")
	await _tap(KEY_L)
	_check(prompt._log.visible and prompt._log_text.text.contains(tutorial.current_step().title.to_upper()), "L opens the log of lessons so far")
	await _tap(KEY_L)
	_check(not prompt._log.visible, "L again closes it")
	# Walk to the marker with a right-click. Done fast, the lesson still stays
	# on screen, ticked, until it could have been read.
	TutorialStep.read_scale = 1.0
	tutorial.step_time = 0.0
	await _right_click(tutorial.actor(&"Marker_MoveA").global_position)
	_check(player.order == PlayerController.Order.MOVE and not player.running, "a single right-click walks Paul")
	for index in range(600):
		if tutorial.current_step().state == TutorialStep.State.COMPLETE:
			break
		await _frames(1)
	var reading: float = TutorialStep.reading_seconds(tutorial.current_step().title + " " + tutorial.current_step().instruction)
	var shown_before: float = tutorial.step_time
	var held_frames: int = 0
	while _step_id() == &"move_marker" and held_frames < 900:
		await _frames(1)
		held_frames += 1
		if held_frames == 10:
			_check(prompt.title.text.begins_with("✓"), "the finished lesson shows its tick while it is held")
	_check(held_frames >= 60 and float(held_frames) / 60.0 >= reading - shown_before - 0.5 and _step_id() == &"move_sprint", "the next lesson waits until this one could be read (%.1f s held)" % (held_frames / 60.0))
	TutorialStep.read_scale = 0.0
	_check(gate.is_open == false, "the gate stays shut until the section is finished")
	# Run with a double right-click.
	await _double_right_click(tutorial.actor(&"Marker_MoveB").global_position)
	await _frames(20)
	_check(player.running and player.is_sprinting, "a double right-click runs")
	_check(await _await_step(&"move_crouch", 600), "running to the far marker completes the sprint step")
	_check(tutorial.counter(&"sprint") == 0.0, "the next step starts its own measurements")
	# Sneak and move.
	await _tap(KEY_C)
	_check(player.is_crouching, "C puts the selected Paul into the real crouch state")
	await _right_click(tutorial.actor(&"Marker_MoveC").global_position)
	await _frames(30)
	_check(absf(player.current_speed - player.crouch_speed) < 2.0, "crouched Paul moves at crouch speed")
	_check(await _await_step(&"fire_target", 600), "crouching and moving completes the crouch step")
	_check(tutorial.current_section() == &"ranged", "the tutorial advanced into the ranged section")
	_check(gate.is_open, "finishing a section opens its gate")
	_check(player.weapon_controller.enabled, "the pistol is issued for the firing range")
	_check(root.get_node("GameManager").tutorial_checkpoint == &"fire_target", "entering a section records a checkpoint")
	await _tap(KEY_C)
	_check(not player.is_crouching, "C again stands Paul up")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 2 - ranged training
# --------------------------------------------------------------------------

func _ranged_section() -> void:
	var target: Node2D = tutorial.actor(&"Target_Aim")
	_check(squad.hostile_at(target.global_position) == target, "the training target is a valid right-click target")
	await _right_click(target.global_position)
	_check(player.order == PlayerController.Order.ATTACK and player.order_target == target, "right-clicking the target gives Paul an attack order")
	_check(await _await_step(&"reload_weapon", 900), "damaging the target completes the shooting step")
	_check(HealthComponent.find_on(target).current_health < 100.0, "the training target actually took damage")
	# One click, one shot: Paul fires what he was told to and no more.
	await _frames(90)
	var shots: Array[int] = [0]
	var count_shot: Callable = func() -> void: shots[0] += 1
	player.weapon_controller.weapon_fired.connect(count_shot)
	await _frames(90)
	_check(shots[0] == 0 and player.order == PlayerController.Order.IDLE, "one click fired one shot: Paul holds fire after it")
	for click in range(3):
		await _right_click(target.global_position)
		await _frames(2)
	await _frames(150)
	_check(shots[0] == 3, "three clicks, three shots")
	player.weapon_controller.weapon_fired.disconnect(count_shot)
	await _tap(KEY_H)
	_check(player.order == PlayerController.Order.IDLE, "H stops Paul")
	await _tap(KEY_R)
	_check(await _await_step(&"cover_target", 260), "reload_finished completes the reload step")
	# The covered target needs a new angle: the pillar really blocks the shot.
	var covered: Node2D = tutorial.actor(&"Target_Cover")
	var blocked_hp: float = HealthComponent.find_on(covered).current_health
	_place(Vector2(-560, 0))
	await _frames(3)
	_check(not player.has_line_of_sight(covered), "the pillar hides the covered target from the firing line")
	_face(covered.global_position)
	player.fire_weapon()
	await _frames(40)
	_check(HealthComponent.find_on(covered).current_health == blocked_hp, "the pillar stops the shot from the firing line")
	_check(_step_id() == &"cover_target", "the cover step is not satisfied by a blocked shot")
	await _tap(KEY_1)
	await _right_click(covered.global_position)
	_check(player.order == PlayerController.Order.ATTACK, "right-clicking the covered target orders an attack")
	# He walks for a clean line and fires once; a miss wants another click.
	var covered_hit: bool = false
	for attempt in range(6):
		covered_hit = await _await_step(&"melee_fast", 300)
		if covered_hit:
			break
		await _right_click(covered.global_position)
	_check(covered_hit, "Paul finding a clear angle completes the cover step")
	_check(player.has_line_of_sight(covered), "Paul fired from a position with a clean line")
	_check(tutorial.current_section() == &"melee" and player.melee.enabled, "the crysknife is issued for the blade yard")
	await _tap(KEY_H)
	completed += 1


# --------------------------------------------------------------------------
# Scenario 3 - crysknife and shields
# --------------------------------------------------------------------------

func _melee_and_shields() -> void:
	var dummy: Node2D = tutorial.actor(&"Target_Melee")
	# Regression: shooting the practice dummy to pieces must not soft-lock the
	# blade lessons. Training targets get back up.
	var dummy_health: HealthComponent = HealthComponent.find_on(dummy)
	dummy_health.take_damage(dummy_health.max_health * 2.0, player)
	await _frames(2)
	_check(dummy_health.is_dead, "the practice dummy can be destroyed by mistake")
	await _frames(150)
	_check(not dummy_health.is_dead and dummy_health.current_health == dummy_health.max_health, "a destroyed practice dummy stands back up at full health")
	_check(dummy.collision_layer != 0 and not dummy.get_node("CollisionShape2D").disabled, "and can be hit again")
	await _tap(KEY_E)
	_check(squad.targeting == SquadManager.Targeting.STRIKE, "E arms the crysknife")
	await _right_click(dummy.global_position)
	_check(squad.targeting == SquadManager.Targeting.NONE and player.order == PlayerController.Order.IDLE, "right-click cancels targeting without an order")
	await _strike(dummy, false)
	_check(await _await_step(&"melee_slow"), "a fast crysknife hit completes the fast melee step")
	await _strike(dummy, true)
	_check(await _await_step(&"shield_shot", 600), "a slow crysknife hit completes the slow melee step")
	# The shielded instructor teaches all three outcomes.
	var instructor: Node2D = tutorial.actor(&"Target_Shield")
	var shield: ShieldComponent = ShieldComponent.find_on(instructor)
	var health: HealthComponent = HealthComponent.find_on(instructor)
	_check(shield != null and shield.enabled, "the shield instructor carries a personal shield")
	var before: float = health.current_health
	await _right_click(instructor.global_position)
	_check(await _await_step(&"shield_fast", 900), "a blocked round completes the shield gunfire lesson")
	_check(health.current_health == before, "the blocked round dealt no damage")
	await _strike(instructor, false)
	_check(await _await_step(&"shield_slow", 600), "a blocked fast blade completes the fast melee shield lesson")
	_check(health.current_health == before, "the fast blade dealt no damage either")
	await _strike(instructor, true)
	_check(await _await_step(&"stealth_cross", 600), "a penetrating slow blade completes the shield lesson")
	_check(health.current_health < before, "the slow blade finally damaged the shielded target")
	_check(shield.enabled, "penetration leaves the shield running")
	_check(tutorial.current_section() == &"stealth", "the tutorial advanced into the stealth course")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 4 - stealth course, failure, and checkpoint restart
# --------------------------------------------------------------------------

func _stealth_section() -> void:
	var guards: Node = tutorial.find(&"StealthGuards")
	_check(guards != null and guards.get_child_count() == 2, "the stealth course has patrolling sentries")
	for guard: EnemyCharacter in guards.get_children():
		_check(not guard.weapon.enabled, "training sentries carry no live weapon")
	# Partial detection must not fail the course.
	var sentry: EnemyCharacter = guards.get_child(0)
	sentry.perception._set_detection(sentry.perception.alert_threshold)
	await _frames(4)
	_check(_step_id() == &"stealth_cross" and tutorial.failed_reason == "", "partial detection does not fail the course")
	# Full detection fails the section and restarts it from the checkpoint.
	sentry.perception._set_detection(sentry.perception.detection_max)
	await _frames(4)
	_check(tutorial.failed_reason == "SPOTTED", "full detection fails the stealth course")
	await _frames(int(tutorial.restart_delay * 60.0) + 40)
	_bind()
	await _frames(20)
	_check(_step_id() == &"stealth_cross", "failing restarts at the stealth checkpoint, not the start")
	_check(tutorial.current_section() == &"stealth", "the restart stays inside the stealth section")
	var checkpoint: Node2D = tutorial.actor(&"Checkpoint_stealth")
	_check(player.global_position.distance_to(checkpoint.global_position) < 40.0, "Paul is returned to the section checkpoint")
	_check(camera.sees(player.global_position, 60.0), "the restart puts the camera on Paul")
	_check(player.weapon_controller.enabled and player.melee.enabled, "already-taught abilities survive the restart")
	_check(HealthComponent.find_on(player).current_health == 100.0, "the restart restores Paul's health")
	_check(squad.paul_selected, "Paul is selected again after the restart")
	# Cross unseen: the sentries cannot build detection through the stone.
	for guard: EnemyCharacter in tutorial.find(&"StealthGuards").get_children():
		guard.perception.stop()
	await _tap(KEY_C)
	_check(player.is_crouching, "C sneaks for the crossing")
	await _right_click(tutorial.actor(&"Marker_StealthExit").global_position)
	_check(await _await_step(&"squad_select_scout", 1800), "reaching the exit completes the stealth course")
	_check(squad.commands_enabled, "squad commands are unlocked for the squad yard")
	await _tap(KEY_C)
	completed += 1


# --------------------------------------------------------------------------
# Scenario 5 - squad selection, pause, and orders
# --------------------------------------------------------------------------

func _squad_section() -> void:
	_check(scout.global_position.distance_to(player.global_position) < 260.0, "the Fremen form up for the squad yard")
	await _tap(KEY_2)
	_check(not squad.paul_selected and squad.selected_members == [scout], "2 selects only the Scout")
	_check(await _await_step(&"squad_select_both"), "pressing 2 completes the Scout selection step")
	await _tap(KEY_3)
	await _frames(4)
	_check(_step_id() == &"squad_select_both", "selecting one Fremen does not complete the group step")
	await _tap(KEY_4)
	_check(squad.paul_selected and squad.selected_members.size() == 2, "4 selects Paul and both Fremen")
	_check(await _await_step(&"squad_pause"), "pressing 4 completes the group selection step")
	# Pause: the world stops, orders are still accepted.
	await _tap(KEY_SPACE)
	_check(squad.paused and paused, "SPACE really pauses the game")
	var paul_at: Vector2 = player.global_position
	var scout_at: Vector2 = scout.global_position
	await _right_click(player.global_position + Vector2(160, 0))
	_check(player.order == PlayerController.Order.MOVE, "Paul accepts a move order while paused")
	_check(scout.ai.current_order == Order.MOVE_TO, "the Fremen accept a move order while paused")
	await _frames(30)
	_check(player.global_position.distance_to(paul_at) < 1.0 and scout.global_position.distance_to(scout_at) < 1.0, "nobody moves while paused")
	_check(_step_id() == &"squad_pause", "the pause step waits for the world to run again")
	await _tap(KEY_SPACE)
	_check(not squad.paused and not paused, "SPACE again resumes")
	await _frames(20)
	_check(player.global_position.distance_to(paul_at) > 10.0, "the order given while paused runs on resume")
	_check(await _await_step(&"squad_move"), "pausing and resuming completes the pause step")
	var marker: Node2D = tutorial.actor(&"Marker_SquadMove")
	await _tap(KEY_2)
	await _right_click(marker.global_position)
	_check(scout.ai.current_order == Order.MOVE_TO, "the Scout received a real MOVE_TO order")
	_check(await _await_step(&"squad_hold", 1400), "the Scout reaching the marker completes the move step")
	_check(scout.ai.current_order == Order.HOLD, "the completed move settled into HOLD")
	await _tap(KEY_3)
	await _tap(KEY_H)
	_check(await _await_step(&"squad_follow"), "H completes the hold step")
	_check(warrior.ai.current_order == Order.HOLD, "the Warrior holds through the real order system")
	await _tap(KEY_G)
	_check(await _await_step(&"squad_discipline", 900), "G and a return to Paul complete the recall step")
	_check(warrior.ai.current_order == Order.FOLLOW, "the Warrior is following again")
	# Fire discipline: return fire by default; crouching holds everyone.
	_check(scout.ai.fire_discipline == AllyAIController.Fire.HOLD and warrior.ai.fire_discipline == AllyAIController.Fire.HOLD, "the Fremen start on HOLD FIRE, the quietest")
	await _tap(KEY_4)
	await _tap(KEY_B)
	_check(scout.ai.fire_discipline == AllyAIController.Fire.RETURN and squad.notice.contains("RETURN FIRE"), "B moves the selected Fremen on, and says so")
	_check(await _await_step(&"squad_signal", 300), "B to RETURN for both completes the discipline step")
	await _tap(KEY_C)
	_check(scout.ai.holding_fire() and warrior.ai.holding_fire(), "crouching puts the squad on HOLD FIRE")
	var foe_ai: EnemyAIController = (tutorial.actor(&"Target_SquadEnemy") as EnemyCharacter).ai
	var foe_state: EnemyAIController.State = foe_ai.state
	foe_ai.state = EnemyAIController.State.COMBAT
	await _frames(2)
	_check(scout.ai.fire_discipline == AllyAIController.Fire.RETURN, "spotted while low: they return fire")
	foe_ai.state = foe_state
	await _tap(KEY_C)
	_check(scout.ai.fire_discipline == AllyAIController.Fire.RETURN and not scout.ai.holding_fire(), "standing gives each his own discipline back")
	await _tap(KEY_B)
	_check(scout.ai.fire_discipline == AllyAIController.Fire.AT_WILL, "B again: FIRE AT WILL")
	await _tap(KEY_B)
	_check(scout.ai.fire_discipline == AllyAIController.Fire.HOLD and warrior.ai.fire_discipline == AllyAIController.Fire.HOLD, "and round to HOLD FIRE")
	# On my signal: plan with Ctrl, nothing moves; F sends everything at once.
	var plan_a: Vector2 = player.global_position + Vector2(260, -120)
	var plan_b: Vector2 = player.global_position + Vector2(260, 120)
	var scout_before: Order = scout.ai.current_order
	var warrior_before: Order = warrior.ai.current_order
	await _tap(KEY_2)
	await _plan_click(plan_a)
	_check(squad.staged.has(scout) and squad.staged_kind(scout) == "MOVE" and scout.ai.current_order == scout_before, "Ctrl + right-click plans the Scout's move; he waits (%s)" % Order.keys()[scout.ai.current_order])
	await _tap(KEY_H)
	_check(not squad.staged.has(scout), "H calls the plan off")
	await _plan_click(plan_a)
	await _tap(KEY_3)
	await _plan_click(plan_b)
	await _frames(20)
	_check(squad.staged.size() == 2 and scout.ai.current_order == scout_before and warrior.ai.current_order == warrior_before, "two plans held, nobody has moved")
	await _tap(KEY_F)
	_check(scout.ai.current_order == Order.MOVE_TO and warrior.ai.current_order == Order.MOVE_TO and squad.staged.is_empty(), "F: both go at the same instant")
	_check(squad.notice.contains("ON MY SIGNAL"), "and the signal is announced")
	_check(await _await_step(&"squad_attack", 300), "a signal that sends both completes the signal step")
	await _tap(KEY_F)
	_check(squad.notice.contains("NOTHING PLANNED"), "a signal with nothing planned says how to plan")
	await _tap(KEY_4)
	await _tap(KEY_G)
	# Attack order: Paul closes enough to command, then the Scout does the work.
	var foe: Node2D = tutorial.actor(&"Target_SquadEnemy")
	await _tap(KEY_1)
	await _right_click(Vector2(3220, 60))
	_check(await _await_idle(), "Paul walks up to the yard")
	await _tap(KEY_2)
	await _right_click(foe.global_position)
	_check(scout.ai.current_order == Order.ATTACK and scout.ai.holding_fire(), "the Scout, holding fire, still takes a real ATTACK order")
	_check(await _await_step(&"recon_send", 2200), "the Scout defeating the target completes the attack step")
	_check(HealthComponent.find_on(foe).is_dead, "the training foe was defeated")
	_check(tutorial.current_section() == &"recon", "the tutorial advanced into the reconnaissance run")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 6 - free camera and command range
# --------------------------------------------------------------------------

func _recon_section() -> void:
	_check(scout.global_position.distance_to(player.global_position) < 260.0, "the squad regroups for the reconnaissance run")
	var overlook: Node2D = tutorial.actor(&"Marker_Overlook")
	var anchor: Vector2 = player.global_position
	await _tap(KEY_2)
	await _right_click(overlook.global_position)
	_check(player.order == PlayerController.Order.IDLE, "with only the Scout selected, Paul stays put")
	_check(await _await_step(&"recon_camera"), "ordering the Scout to the overlook completes the send step")
	# Double-tapping 2 glides the free camera to the Scout.
	camera.snap_to(player.global_position)
	await _frames(2)
	await _tap(KEY_2)
	await _tap(KEY_2)
	_check(camera.mode_name() == "CENTERING", "pressing 2 twice glides the camera to the Scout")
	await _frames(60)
	_check(camera.sees(scout.global_position, 60.0), "the camera arrives on the Scout")
	# WASD pans the view and never moves anyone.
	var view: Vector2 = camera.anchor
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	_check(camera.anchor.x > view.x + 50.0, "WASD pans the free camera")
	_check(player.global_position.distance_to(anchor) < 1.0, "panning does not move Paul")
	_check(await _await_step(&"recon_weak", 1800), "the Scout walking far from Paul completes the camera step")
	_check(await _await_step(&"recon_lost", 1800), "a weakening link completes the weak-link step")
	_check(squad.link_state(scout) != Link.CONNECTED, "the Scout's link really degraded")
	_check(await _await_step(&"recon_rejected", 1800), "losing the link completes the command-range step")
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE, "the Scout is genuinely out of command range")
	_check(player.global_position.distance_to(anchor) < 40.0, "Paul stayed in cover while the Scout scouted")
	var kept: Order = scout.ai.current_order
	await _tap(KEY_2)
	await _right_click(player.global_position + Vector2(0, 200))
	await _frames(2)
	# Checked at the moment of refusal: the banner is a short wall-clock timer.
	_check(squad.rejection_active() and squad.rejection_message.contains("LINK LOST"), "the refusal produced the normal command-rejection feedback")
	_check(scout.ai.current_order == kept, "the refused order left the Scout's current order untouched")
	_check(await _await_step(&"recon_restore"), "a refused order completes the rejection step")
	# Select Paul and walk him toward the Scout; the link repairs on the way.
	await _tap(KEY_1)
	await _tap(KEY_1)
	await _frames(40)
	_check(camera.sees(player.global_position, 60.0), "pressing 1 twice brings the camera back to Paul")
	await _right_click(scout.global_position)
	_check(player.order == PlayerController.Order.MOVE, "Paul walks toward the Scout")
	for index in range(1200):
		if squad.link_state(scout) != Link.OUT_OF_RANGE:
			break
		await _frames(1)
	_check(squad.link_state(scout) != Link.OUT_OF_RANGE, "closing the distance restored the link")
	_check(await _await_step(&"route_plan", 400), "restoring the link completes the reconnection step")
	# Routes: two stops, one dragged, carried beyond command range.
	player.stop()
	await _frames(5)
	await _tap(KEY_2)
	await _right_click(tutorial.actor(&"Marker_Route1").global_position)
	squad.issue_context(tutorial.actor(&"Marker_Route2").global_position, true)
	_check(scout.ai.waypoints().size() == 2, "SHIFT + right-click adds a second stop")
	_check(await _await_step(&"route_change", 300), "a two-stop route completes the planning step")
	var stops: Array[Vector2] = scout.ai.waypoints()
	_check(squad.grab_waypoint(stops.back()) and squad.drop_waypoint(stops.back() + Vector2(40, -40)), "a stop is dragged somewhere new")
	_check(await _await_step(&"route_carry", 300), "changing a stop completes the change step")
	var carried: bool = false
	for index in range(2400):
		if squad.link_state(scout) == Link.OUT_OF_RANGE and scout.ai.current_order == Order.MOVE_TO:
			carried = true
		if _step_id() == &"presc_observe":
			break
		await _frames(1)
	_check(carried, "out of range, he kept walking his route")
	_check(_step_id() == &"presc_observe", "the route walked to its end completes the lesson")
	_check(tutorial.current_section() == &"prescience", "the tutorial advanced into the prescience yard")
	await _tap(KEY_H)
	completed += 1


# --------------------------------------------------------------------------
# Scenario 7 - prescience taught through the real ability
# --------------------------------------------------------------------------

func _prescience_section() -> void:
	var sentry: EnemyCharacter = tutorial.find(&"PrescienceSentry") as EnemyCharacter
	_check(sentry != null and not sentry.weapon.enabled, "the prescience yard sentry is a trainer, not a shooter")
	await _tap(KEY_1)
	await _tap(KEY_C)
	await _right_click(tutorial.actor(&"Marker_PrescienceWatch").global_position)
	_check(await _await_step(&"presc_activate", 1500), "reaching the watch post completes the observe step")
	# Regression: the post itself must be safe. A full patrol cycle, sneaking,
	# with the sentry's real perception running.
	var peak: float = 0.0
	for index in range(900):
		peak = maxf(peak, sentry.perception.detection_value)
		await _frames(1)
	_check(peak < sentry.perception.suspicion_threshold and sentry.ai.state == EnemyAIController.State.PATROL, "the sentry never notices Paul at the watch post (peak %.1f)" % peak)
	_check(tutorial.failed_reason == "", "nothing failed while Paul watched")
	for member in squad.members:
		_check(member.ai.current_order == AllyAIController.Order.HOLD and member.global_position.x < 5900.0, "the Fremen wait at their staging post, out of sight: " + member.data.display_name)
	# The real ability, through the real key.
	var energy: PrescienceEnergyComponent = player.prescience_energy
	var full: float = energy.current_energy
	await _tap(KEY_Q)
	_check(player.prescience.active, "Q activates prescience inside the tutorial")
	_check(await _await_step(&"presc_study", 200), "activating prescience completes its step")
	_check(energy.current_energy < full, "the activation spent reserve")
	var sentry_track: FuturePredictor.FutureTrack = null
	for track: FuturePredictor.FutureTrack in player.prescience.projections:
		if track.actor == sentry:
			sentry_track = track
	_check(sentry_track != null, "the sentry's future is projected for the player to read")
	_check(await _await_step(&"presc_energy", 400), "holding the vision completes the study step")
	_check(await _await_step(&"presc_pause", 400), "the energy lesson advances on its own")
	# Prescience and pause together.
	await _await_prescience_ready()
	await _tap(KEY_Q)
	_check(player.prescience.active, "a second vision opens")
	await _tap(KEY_SPACE)
	_check(squad.paused and player.prescience.active, "SPACE pauses inside the vision")
	var held: float = player.prescience.remaining
	await _frames(240)
	_check(is_equal_approx(player.prescience.remaining, held) and player.prescience.active, "paused, the vision does not run down")
	_check(_step_id() == &"presc_pause", "the step waits for the player to resume")
	await _tap(KEY_SPACE)
	_check(not squad.paused, "SPACE resumes")
	_check(await _await_step(&"presc_scout", 300), "resuming after a paused vision completes the pause lesson")
	# The Scout lesson: first a badly timed crossing, straight into the cone.
	var scout: AllyCharacter = tutorial.ally(2)
	var exit: Vector2 = tutorial.actor(&"Marker_PrescienceExit").global_position
	await _await_sentry(sentry, false, 120.0)
	# A standing Scout, badly timed: the crossing the lesson warns against.
	squad.set_stance(false)
	await _tap(KEY_2)
	await _right_click(exit)
	_check(scout.ai.current_order == AllyAIController.Order.MOVE_TO, "the Scout takes the crossing order")
	for index in range(900):
		if tutorial.failed_reason != "":
			break
		await _frames(1)
	_check(tutorial.failed_reason == "THE SENTRY SAW THE SCOUT", "a Scout walking into the sentry's cone fails the lesson")
	await _frames(int(tutorial.restart_delay * 60.0) + 40)
	_bind()
	await _frames(20)
	sentry = tutorial.find(&"PrescienceSentry") as EnemyCharacter
	scout = tutorial.ally(2)
	_check(_step_id() == &"presc_scout", "the retry starts at the Scout lesson, not the top of the yard")
	# Now timed against the future: go once he is walking away, north.
	await _await_sentry(sentry, true, 380.0)
	await _tap(KEY_2)
	await _right_click(exit)
	await _await_prescience_ready()
	await _tap(KEY_Q)
	var scout_track: FuturePredictor.FutureTrack = null
	for track: FuturePredictor.FutureTrack in player.prescience.projections:
		if track.actor == scout:
			scout_track = track
	_check(scout_track != null and scout_track.friendly, "the selected Scout's future is projected beside the sentry's")
	_check(await _await_step(&"presc_cross", 1500), "a well-timed Scout crossing completes his lesson")
	_check(sentry.ai.state == EnemyAIController.State.PATROL, "the sentry never broke his patrol")
	# Paul's crossing. Being seen fails it and retries right here.
	sentry.perception._set_detection(sentry.perception.detection_max)
	await _frames(4)
	_check(tutorial.failed_reason == "SPOTTED", "being seen fails Paul's crossing")
	_check(not player.prescience.active and Engine.time_scale == 1.0, "a failed crossing clears prescience and restores time")
	await _frames(int(tutorial.restart_delay * 60.0) + 40)
	_bind()
	await _frames(20)
	sentry = tutorial.find(&"PrescienceSentry") as EnemyCharacter
	_check(_step_id() == &"presc_cross", "the retry starts at Paul's crossing")
	await _tap(KEY_1)
	await _await_sentry(sentry, true, 380.0)
	await _right_click(exit)
	_check(await _await_step(&"desert_cross", 1500), "crossing behind the sentry completes the prescience section")
	_check(tutorial.current_section() == &"desert", "the tutorial advanced into the desert yard")
	completed += 1


## Wait for the sentry heading north (away from the crossing) and past
## `y_below`, or heading south and north of `y_below`.
func _await_sentry(sentry: EnemyCharacter, north: bool, y_limit: float) -> void:
	for index in range(1800):
		var heading_north: bool = sentry.velocity.y < -5.0
		var heading_south: bool = sentry.velocity.y > 5.0
		if north and heading_north and sentry.global_position.y < y_limit:
			return
		if not north and heading_south and sentry.global_position.y < y_limit:
			return
		await _frames(1)


func _await_prescience_ready() -> void:
	for index in range(900):
		if player.prescience.can_activate() == "":
			return
		await _frames(1)


# --------------------------------------------------------------------------
# Scenario 8 - desert survival taught through the real worm system
# --------------------------------------------------------------------------

func _desert_section() -> void:
	var worm: WormThreatManager = tutorial.worm()
	_check(worm != null, "the tutorial mission carries a worm threat manager")
	_check(worm.worm_sign == 0.0, "entering the desert yard starts from a calm desert")
	# Walking the sand to the next rock.
	await _right_click(tutorial.actor(&"Marker_MidRock").global_position)
	_check(await _await_step(&"desert_sprint", 1200), "reaching the rock completes the crossing step")
	await _await_idle(300)
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	_check(safety != null and safety.is_safe(), "the marked rock reads as safe ground")
	# Running the longer patch.
	await _double_right_click(tutorial.actor(&"Marker_FarRock").global_position)
	await _frames(10)
	_check(player.is_sprinting, "the double right-click runs across the sand")
	_check(await _await_step(&"desert_fire", 900), "running to the far rock completes the sprint step")
	# Gunfire on the sand: the spike is the lesson, wherever the round lands.
	# A player standing on the far rock right-clicks the target as instructed.
	var target: Node2D = tutorial.actor(&"Target_Desert")
	await _right_click(target.global_position)
	_check(player.order == PlayerController.Order.ATTACK or tutorial.count(&"weapon_fired") > 0, "right-clicking the desert target orders Paul to fire")
	await _frames(120)
	_check(tutorial.count(&"weapon_fired") > 0 and TerrainSafetyComponent.find_on(player).is_safe(), "Paul opened fire from the rock")
	_check(_step_id() == &"desert_fire", "a shot from the rock does not teach the lesson: the step waits")
	if _step_id() == &"desert_fire":
		# As instructed: step off the rock onto the sand and fire from there.
		await _right_click(target.global_position + Vector2(0, -220))
		await _await_idle(600)
		_check(not TerrainSafetyComponent.find_on(player).is_safe(), "Paul stands on open sand for the shot")
		var before: float = worm.worm_sign
		_face(target.global_position)
		player.fire_weapon()
		await _frames(2)
		_check(worm.worm_sign > before, "a shot on open sand spikes worm sign")
		for shot in range(8):
			if _step_id() != &"desert_fire":
				break
			await _frames(30)
			player.fire_weapon()
		_check(await _await_step(&"desert_machine", 400), "gunfire from open sand completes the gunfire step")
	# The rig, through the real interaction: right-click it.
	var machine: SpiceMachine = tutorial.find(&"Machine") as SpiceMachine
	_check(machine != null and not machine.running, "the training rig starts idle")
	_check(squad.interactable_at(machine.global_position) == machine and squad.context_kind(machine.global_position) == "USE", "the rig reads as usable under the cursor")
	await _right_click(machine.global_position)
	_check(player.order == PlayerController.Order.INTERACT, "right-clicking the rig sends Paul to use it")
	await _await_idle(900)
	_check(machine.running, "Paul walked to the rig and started it")
	_check(await _await_step(&"desert_shelter", 3000), "the rig escalating the threat completes the machinery step")
	_check(worm.stage >= WormThreatManager.Stage.INTERESTED, "the rig really escalated the threat")
	# Shelter, then let the worm take the rig.
	await _double_right_click(tutorial.actor(&"Marker_Haven").global_position)
	await _await_idle(900)
	_check(TerrainSafetyComponent.find_on(player).is_safe(), "Paul reaches the safe rock")
	worm.force_arrival()
	for index in range(900):
		if worm.state == WormThreatManager.EventState.COOLDOWN:
			break
		await _frames(1)
	_check(not player.health.is_dead, "safe rock carried Paul through the arrival")
	_check(await _await_step(&"combined_clear", 600), "surviving the worm completes the desert section")
	_check(tutorial.current_section() == &"combined", "the tutorial advanced into the combined exercise")
	_check(worm.worm_sign == 0.0, "entering the next section resets the desert")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 9 - combined exercise and completion
# --------------------------------------------------------------------------

func _combined_and_finish() -> void:
	var group: Node = tutorial.find(&"CombinedEnemies")
	_check(group != null and group.get_child_count() == 4, "the combined exercise fields live opposition")
	var shielded: int = 0
	for enemy: Node in group.get_children():
		if ShieldComponent.find_on(enemy) != null:
			shielded += 1
	_check(shielded == 1, "one of the combined opponents is shielded")
	for enemy: Node in group.get_children():
		HealthComponent.find_on(enemy).die()
	_check(await _await_step(&"combined_extract", 300), "clearing the yard completes the combat step")
	await _tap(KEY_1)
	await _right_click(tutorial.actor(&"Marker_Extraction").global_position)
	for index in range(1500):
		if tutorial.finished:
			break
		await _frames(1)
	_check(tutorial.finished, "walking to extraction completes the tutorial")
	_check(root.get_node("GameManager").tutorial_checkpoint == &"", "finishing clears the checkpoint")
	var summary: Control = mission.get_node("TutorialPrompt/Screen/Summary")
	_check(summary.visible, "the completion summary is shown")
	await _capture("m61_tutorial_complete")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 10 - developer navigation and death restart
# --------------------------------------------------------------------------

func _developer_navigation() -> void:
	await _load()
	root.get_node("GameManager").debug_visible = true
	await _frames(4)
	var metrics: Dictionary = mission.get_node("UI").metric_labels
	for row in ["Tutorial active", "Tutorial section", "Tutorial step", "Tutorial step state", "Tutorial checkpoint", "Tutorial hint timer"]:
		_check(metrics.has(row), "F1 debug overlay shows '%s'" % row)
	# Skip forward, back, and restart the current section.
	await _tap(KEY_PAGEDOWN)
	await _frames(6)
	_check(tutorial.current_section() == &"ranged", "PageDown skips to the next section")
	_check(player.weapon_controller.enabled, "skipping forward applies that section's unlocks")
	await _tap(KEY_PAGEDOWN)
	await _frames(6)
	await _tap(KEY_PAGEDOWN)
	await _frames(6)
	_check(tutorial.current_section() == &"stealth", "repeated skips advance section by section")
	await _tap(KEY_PAGEUP)
	await _frames(6)
	_check(tutorial.current_section() == &"melee", "PageUp steps back a section")
	_check(_step_id() == &"melee_fast", "stepping back restarts that section at its first step")
	var moved: Vector2 = player.global_position
	_place(moved + Vector2(0, 200))
	await _tap(KEY_F6)
	await _frames(40)
	_bind()
	await _frames(20)
	_check(tutorial.current_section() == &"melee" and _step_id() == &"melee_fast", "F6 restarts the current section")
	_check(player.global_position.distance_to(moved) < 40.0, "the restart returns Paul to the section checkpoint")
	await _capture("m61_tutorial_prompt")
	# Paul's death routes through the existing restart, resuming at the checkpoint.
	HealthComponent.find_on(player).die()
	await _frames(6)
	_check(tutorial.failed_reason == "PAUL IS DOWN", "Paul's death reports a training failure")
	_check(not tutorial.running, "the sequencer stops while Paul is down")
	await _tap(KEY_ENTER)
	await _frames(40)
	_bind()
	await _frames(20)
	_check(tutorial.running and tutorial.current_section() == &"melee", "Enter restarts the mission at the current checkpoint")
	_check(HealthComponent.find_on(player).current_health == 100.0, "the checkpoint restart restores Paul")
	root.get_node("GameManager").debug_visible = false
	root.get_node("GameManager").tutorial_checkpoint = &""
	completed += 1


func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.validation/" + label + ".png")


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
