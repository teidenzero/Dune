extends SceneTree
## Milestone 6.1: the Arrakeen tutorial driven end to end.
##
## Every step is satisfied by performing the real action through the real
## systems, so a pass here is also an integration test of Milestones 1-6.

const Order = AllyAIController.Order
const Link = CommandLinkComponent.State
const TUTORIAL: String = "res://scenes/missions/tutorial/tutorial_arrakeen.tscn"

class AimedPlayer extends PlayerController:
	# Synthetic mouse events do not move the OS cursor; aim is driven by an
	# explicit world point. Every other player path is production code.
	var aim_point: Vector2 = Vector2.RIGHT

	func _update_aim() -> void:
		aim_direction = global_position.direction_to(aim_point)
		aim_pivot.rotation = aim_direction.angle()

var failures: int = 0
var completed: int = 0
var mission: Node2D
var tutorial: TutorialManager
var player: PlayerController
var squad: SquadManager
var scout: AllyCharacter
var warrior: AllyCharacter


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	mission.get_node("Player").set_script(AimedPlayer)
	root.add_child(mission)
	current_scene = mission
	await _frames(20)
	_bind()


func _bind() -> void:
	mission = current_scene as Node2D
	tutorial = mission.get_node("TutorialManager")
	player = mission.get_node("Player")
	squad = mission.get_node("SquadManager")
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


func _place(point: Vector2) -> void:
	player.global_position = point
	player.velocity = Vector2.ZERO
	_aim_at(point + Vector2.RIGHT * 100.0)


## A scene reload restores the production player script, and no step after the
## stealth course needs a controlled aim.
func _aim_at(point: Vector2) -> void:
	if player is AimedPlayer:
		player.aim_point = point
		player._update_aim()


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


func _fire_once() -> void:
	Input.action_press("fire_primary")
	await _frames(3)
	Input.action_release("fire_primary")
	await _frames(3)


func _swing(hold: float) -> void:
	_key(KEY_E, true)
	await _frames(maxi(int(hold * 60.0), 1))
	_key(KEY_E, false)
	for index in range(200):
		if player.melee.state == MeleeController.State.IDLE:
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
	# Abilities not yet taught are withheld, and the section gate is shut.
	_check(not player.weapon_controller.enabled, "the pistol is withheld before the firing range")
	_check(not player.melee.enabled, "the crysknife is withheld before the blade yard")
	_check(not squad.commands_enabled, "squad commands are withheld before the squad yard")
	var gate: TutorialGate = tutorial.find(&"Gate_movement") as TutorialGate
	_check(gate != null and not gate.is_open, "the next section is gated shut")
	_check((tutorial.find(&"Marker_MoveA") as TutorialMarker).active, "the current step's marker is highlighted")
	_check(not (tutorial.find(&"Marker_Overlook") as TutorialMarker).active, "later markers stay hidden")
	# Hints appear only after the configured delay.
	_check(not tutorial.hint_shown, "no hint is shown immediately")
	tutorial.step_time = tutorial.current_step().hint_delay + 0.1
	await _frames(2)
	_check(tutorial.hint_shown, "an unfinished step eventually offers a hint")
	# Walk to the marker.
	_place((tutorial.actor(&"Marker_MoveA")).global_position)
	_check(await _await_step(&"move_sprint"), "reaching the marker completes the movement step")
	_check(gate.is_open == false, "the gate stays shut until the section is finished")
	# Sprint.
	Input.action_press("sprint")
	Input.action_press("move_up")
	await _frames(70)
	Input.action_release("move_up")
	Input.action_release("sprint")
	_check(tutorial.counter(&"sprint") >= 0.8, "sprinting is measured from the real sprint state")
	_place((tutorial.actor(&"Marker_MoveB")).global_position)
	_check(await _await_step(&"move_crouch"), "sprinting to the far marker completes the sprint step")
	# Crouch and move.
	await _tap(KEY_CTRL)
	_check(player.is_crouching, "CTRL enters the real crouch state")
	Input.action_press("move_down")
	await _frames(70)
	Input.action_release("move_down")
	_check(await _await_step(&"aim_target"), "crouching and moving completes the crouch step")
	_check(tutorial.current_section() == &"ranged", "the tutorial advanced into the ranged section")
	_check(gate.is_open, "finishing a section opens its gate")
	_check(player.weapon_controller.enabled, "the pistol is issued for the firing range")
	_check(root.get_node("GameManager").tutorial_checkpoint == &"aim_target", "entering a section records a checkpoint")
	await _tap(KEY_CTRL)
	completed += 1


# --------------------------------------------------------------------------
# Scenario 2 - ranged training
# --------------------------------------------------------------------------

func _ranged_section() -> void:
	var target: Node2D = tutorial.actor(&"Target_Aim")
	_place(target.global_position + Vector2(0, 260))
	_aim_at(target.global_position)
	_check(await _await_step(&"fire_target"), "holding aim on the target completes the aiming step")
	await _fire_once()
	_check(await _await_step(&"reload_weapon"), "damaging the target completes the shooting step")
	_check(HealthComponent.find_on(target).current_health < 100.0, "the training target actually took damage")
	await _tap(KEY_R)
	_check(await _await_step(&"cover_target", 260), "reload_finished completes the reload step")
	# The covered target needs a new angle: the pillar really blocks the shot.
	var covered: Node2D = tutorial.actor(&"Target_Cover")
	var blocked_hp: float = HealthComponent.find_on(covered).current_health
	_place(Vector2(-560, 0))
	_aim_at(covered.global_position)
	await _fire_once()
	await _frames(40)
	_check(HealthComponent.find_on(covered).current_health == blocked_hp, "the pillar stops the shot from the firing line")
	_check(_step_id() == &"cover_target", "the cover step is not satisfied by a blocked shot")
	_place(covered.global_position + Vector2(0, -230))
	_aim_at(covered.global_position)
	await _fire_once()
	_check(await _await_step(&"melee_fast"), "a clear angle completes the cover step")
	_check(tutorial.current_section() == &"melee" and player.melee.enabled, "the crysknife is issued for the blade yard")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 3 - crysknife and shields
# --------------------------------------------------------------------------

func _melee_and_shields() -> void:
	var dummy: Node2D = tutorial.actor(&"Target_Melee")
	_place(dummy.global_position + Vector2(0, 52))
	_aim_at(dummy.global_position)
	await _swing(0.05)
	_check(await _await_step(&"melee_slow"), "a fast crysknife hit completes the fast melee step")
	await _swing(0.6)
	_check(await _await_step(&"shield_shot"), "a slow crysknife hit completes the slow melee step")
	# The shielded instructor teaches all three outcomes.
	var instructor: Node2D = tutorial.actor(&"Target_Shield")
	var shield: ShieldComponent = ShieldComponent.find_on(instructor)
	var health: HealthComponent = HealthComponent.find_on(instructor)
	_check(shield != null and shield.enabled, "the shield instructor carries a personal shield")
	_place(instructor.global_position + Vector2(0, -220))
	_aim_at(instructor.global_position)
	var before: float = health.current_health
	await _fire_once()
	await _frames(40)
	_check(await _await_step(&"shield_fast"), "a blocked round completes the shield gunfire lesson")
	_check(health.current_health == before, "the blocked round dealt no damage")
	_place(instructor.global_position + Vector2(0, 52))
	_aim_at(instructor.global_position)
	await _swing(0.05)
	_check(await _await_step(&"shield_slow"), "a blocked fast blade completes the fast melee shield lesson")
	_check(health.current_health == before, "the fast blade dealt no damage either")
	await _swing(0.6)
	_check(await _await_step(&"stealth_cross", 300), "a penetrating slow blade completes the shield lesson")
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
	_check(player.weapon_controller.enabled and player.melee.enabled, "already-taught abilities survive the restart")
	_check(HealthComponent.find_on(player).current_health == 100.0, "the restart restores Paul's health")
	# Cross unseen: the sentries cannot build detection through the stone.
	for guard: EnemyCharacter in tutorial.find(&"StealthGuards").get_children():
		guard.perception.stop()
	_place((tutorial.actor(&"Marker_StealthExit")).global_position)
	_check(await _await_step(&"squad_select_scout", 300), "reaching the exit completes the stealth course")
	_check(squad.commands_enabled, "squad commands are unlocked for the squad yard")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 5 - squad selection and orders
# --------------------------------------------------------------------------

func _squad_section() -> void:
	_check(scout.global_position.distance_to(player.global_position) < 260.0, "the Fremen form up for the squad yard")
	await _tap(KEY_2)
	_check(await _await_step(&"squad_select_both"), "pressing 2 completes the Scout selection step")
	await _tap(KEY_4)
	_check(await _await_step(&"squad_command_mode"), "pressing 4 completes the group selection step")
	await _tap(KEY_TAB)
	_check(squad.command_mode, "TAB entered the real command mode")
	_check(await _await_step(&"squad_move"), "command mode completes its step")
	var marker: Node2D = tutorial.actor(&"Marker_SquadMove")
	squad.select_slot(2)
	squad.issue_context(marker.global_position)
	_check(scout.ai.current_order == Order.MOVE_TO, "the Scout received a real MOVE_TO order")
	_check(await _await_step(&"squad_hold", 1400), "the Scout reaching the marker completes the move step")
	_check(scout.ai.current_order == Order.HOLD, "the completed move settled into HOLD")
	squad.select_slot(3)
	squad.issue_hold()
	_check(await _await_step(&"squad_follow"), "H completes the hold step")
	_check(warrior.ai.current_order == Order.HOLD, "the Warrior holds through the real order system")
	squad.issue_follow()
	_check(await _await_step(&"squad_attack", 900), "G and a return to Paul complete the recall step")
	_check(warrior.ai.current_order == Order.FOLLOW, "the Warrior is following again")
	# Attack order: Paul closes enough to command, then the Scout does the work.
	var foe: Node2D = tutorial.actor(&"Target_SquadEnemy")
	_place(Vector2(3220, 60))
	await _frames(6)
	squad.select_slot(2)
	squad.issue_context(foe.global_position)
	_check(scout.ai.current_order == Order.ATTACK, "the Scout received a real ATTACK order")
	_check(await _await_step(&"recon_send", 2200), "the Scout defeating the target completes the attack step")
	_check(HealthComponent.find_on(foe).is_dead, "the training foe was defeated by the squad, not by Paul")
	_check(tutorial.current_section() == &"recon", "the tutorial advanced into the reconnaissance run")
	squad.set_command_mode(false)
	completed += 1


# --------------------------------------------------------------------------
# Scenario 6 - tactical camera and command range
# --------------------------------------------------------------------------

func _recon_section() -> void:
	_check(scout.global_position.distance_to(player.global_position) < 260.0, "the squad regroups for the reconnaissance run")
	var overlook: Node2D = tutorial.actor(&"Marker_Overlook")
	var anchor: Vector2 = player.global_position
	squad.select_slot(2)
	squad.issue_context(overlook.global_position)
	_check(await _await_step(&"recon_camera"), "ordering the Scout to the overlook completes the send step")
	var camera: TacticalCamera = player.get_node("TacticalCamera")
	squad.set_command_mode(true)
	_check(await _await_step(&"recon_weak", 1800), "the Scout outranging the camera completes the camera step")
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_SELECTION, "the tactical camera is framing the selected Scout")
	_check(await _await_step(&"recon_lost", 1800), "a weakening link completes the weak-link step")
	_check(squad.link_state(scout) != Link.CONNECTED, "the Scout's link really degraded")
	_check(await _await_step(&"recon_rejected", 1800), "losing the link completes the command-range step")
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE, "the Scout is genuinely out of command range")
	_check(player.global_position.distance_to(anchor) < 40.0, "Paul stayed in cover while the Scout scouted")
	var kept: Order = scout.ai.current_order
	squad.select_slot(2)
	squad.issue_context(player.global_position + Vector2(0, 200))
	await _frames(2)
	# Checked at the moment of refusal: the banner is a short wall-clock timer.
	_check(squad.rejection_active() and squad.rejection_message.contains("LINK LOST"), "the refusal produced the normal command-rejection feedback")
	_check(scout.ai.current_order == kept, "the refused order left the Scout's current order untouched")
	_check(await _await_step(&"recon_restore"), "a refused order completes the rejection step")
	squad.set_command_mode(false)
	# Walk Paul back into range along the open centre of the corridor.
	player.global_position = Vector2(player.global_position.x, 0.0)
	await _frames(2)
	for index in range(400):
		if squad.link_state(scout) != Link.OUT_OF_RANGE:
			break
		player.global_position += Vector2(16.0, 0.0)
		await _frames(1)
	_check(squad.link_state(scout) != Link.OUT_OF_RANGE, "closing the distance restored the link")
	_check(await _await_step(&"presc_observe", 400), "restoring the link completes the reconnection step")
	_check(tutorial.current_section() == &"prescience", "the tutorial advanced into the prescience yard")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 7 - prescience taught through the real ability
# --------------------------------------------------------------------------

func _prescience_section() -> void:
	var sentry: EnemyCharacter = tutorial.find(&"PrescienceSentry") as EnemyCharacter
	_check(sentry != null and not sentry.weapon.enabled, "the prescience yard sentry is a trainer, not a shooter")
	_place((tutorial.actor(&"Marker_PrescienceWatch")).global_position)
	_check(await _await_step(&"presc_activate", 400), "reaching the observation post completes the observe step")
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
	_check(await _await_step(&"presc_cross", 400), "the energy lesson advances on its own")
	# Being seen puts the player back at the section checkpoint.
	sentry.perception._set_detection(sentry.perception.detection_max)
	await _frames(4)
	_check(tutorial.failed_reason == "SPOTTED", "being seen fails the prescience crossing")
	_check(not player.prescience.active and Engine.time_scale == 1.0, "a failed crossing clears prescience and restores time")
	await _frames(int(tutorial.restart_delay * 60.0) + 40)
	_bind()
	await _frames(20)
	_check(_step_id() == &"presc_observe", "failing restarts at the prescience checkpoint")
	# Cross cleanly.
	for guard: EnemyCharacter in tutorial.find(&"PrescienceGuards").get_children():
		guard.perception.stop()
	_place((tutorial.actor(&"Marker_PrescienceWatch")).global_position)
	_check(await _await_step(&"presc_activate", 400), "the observation step can be repeated")
	await _tap(KEY_Q)
	_check(await _await_step(&"presc_cross", 900), "the lesson runs through to the crossing")
	_place((tutorial.actor(&"Marker_PrescienceExit")).global_position)
	_check(await _await_step(&"desert_cross", 400), "crossing unseen completes the prescience section")
	_check(tutorial.current_section() == &"desert", "the tutorial advanced into the desert yard")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 8 - desert survival taught through the real worm system
# --------------------------------------------------------------------------

func _desert_section() -> void:
	var worm: WormThreatManager = tutorial.worm()
	_check(worm != null, "the tutorial mission carries a worm threat manager")
	_check(worm.worm_sign == 0.0, "entering the desert yard starts from a calm desert")
	# Walking the sand to the next rock.
	_place((tutorial.actor(&"Marker_MidRock")).global_position)
	_check(await _await_step(&"desert_sprint", 400), "reaching the rock completes the crossing step")
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	_check(safety != null and safety.is_safe(), "the marked rock reads as safe ground")
	# Sprinting the longer patch.
	Input.action_press("sprint")
	Input.action_press("move_down")
	await _frames(50)
	Input.action_release("move_down")
	Input.action_release("sprint")
	_place((tutorial.actor(&"Marker_FarRock")).global_position)
	_check(await _await_step(&"desert_fire", 500), "sprinting to the far rock completes the sprint step")
	# Gunfire on the sand: the spike is the lesson, wherever the round lands.
	var target: Node2D = tutorial.actor(&"Target_Desert")
	_place(target.global_position + Vector2(0, -220))
	await _frames(20)
	var before: float = worm.worm_sign
	await _fire_once()
	await _frames(10)
	_check(worm.worm_sign > before, "a shot on open sand spikes worm sign")
	_check(await _await_step(&"desert_machine", 400), "the gunfire step completes on that spike")
	# The rig, through the real interaction.
	var machine: SpiceMachine = tutorial.find(&"Machine") as SpiceMachine
	_check(machine != null and not machine.running, "the training rig starts idle")
	_place(machine.global_position + Vector2(0, 120))
	await _frames(6)
	await _tap(KEY_F)
	_check(machine.running, "F starts the rig when Paul is beside it")
	_check(await _await_step(&"desert_shelter", 3000), "the rig escalating the threat completes the machinery step")
	_check(worm.stage >= WormThreatManager.Stage.INTERESTED, "the rig really escalated the threat")
	# Shelter, then let the worm take the rig.
	_place((tutorial.actor(&"Marker_Haven")).global_position)
	await _frames(30)
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
# Scenario 7 - combined exercise and completion
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
	_place((tutorial.actor(&"Marker_Extraction")).global_position)
	for index in range(300):
		if tutorial.finished:
			break
		await _frames(1)
	_check(tutorial.finished, "reaching extraction completes the tutorial")
	_check(root.get_node("GameManager").tutorial_checkpoint == &"", "finishing clears the checkpoint")
	var summary: Control = mission.get_node("TutorialPrompt/Screen/Summary")
	_check(summary.visible, "the completion summary is shown")
	await _capture("m61_tutorial_complete")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 8 - developer navigation and death restart
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
