extends SceneTree
## Milestone 9: the Harvester Raid vertical slice, played against the real
## mission scene - real guards, real shields, real desert, real worm.
##
## Every scenario is a route a player could actually take. The point of the
## suite is that the mission survives all of them, including the ones that
## break the intended order.

class AimedPlayer extends PlayerController:
	# Synthetic mouse events do not move the OS cursor.
	var aim_point: Vector2 = Vector2.RIGHT

	func _update_aim() -> void:
		aim_direction = global_position.direction_to(aim_point)
		aim_pivot.rotation = aim_direction.angle()

var failures: int = 0
var completed: int = 0

var scene: Node2D
var mission: MissionManager
var raid: HarvesterRaidController
var player: PlayerController
var harvester: Harvester
var beacon: CommunicationsBeacon
var worm: WormThreatManager
var squad: SquadManager
var hud: CanvasLayer
var scout: AllyCharacter
var warrior: AllyCharacter

const START: Vector2 = Vector2(0, 1560)
const APPROACH: Vector2 = Vector2(0, 900)
const SAND: Vector2 = Vector2(-700, 400)
const ROCK: Vector2 = Vector2(0, -1540)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _scene_and_objectives()
	await _stealth_route()
	await _beacon_changes_the_response()
	await _combat_route()
	await _squad_and_command_range()
	await _prescience_and_shields()
	await _sabotage_escalation()
	await _escape_and_completion()
	await _worm_before_sabotage()
	await _worm_catches_paul()
	await _fremen_and_paul_down()
	await _checkpoints()
	await _results_and_debug()
	_check(completed == 13, "all mission scenarios completed (%d)" % completed)
	_check(Engine.time_scale == 1.0, "suite leaves normal game speed")
	print("MISSION SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


# --------------------------------------------------------------------------
# Harness
# --------------------------------------------------------------------------

func _load(quiet: bool = true) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await _frames(2)
	root.get_node("GameManager").debug_visible = false
	root.get_node("GameManager").mission_checkpoint = &""
	TimeScaleManager.reset()
	scene = load("res://scenes/missions/harvester_raid/harvester_raid.tscn").instantiate()
	scene.get_node("Player").set_script(AimedPlayer)
	root.add_child(scene)
	current_scene = scene
	mission = scene.get_node("Mission")
	raid = scene.get_node("RaidController")
	player = scene.get_node("Player")
	harvester = scene.get_node("Harvester")
	beacon = scene.get_node("Beacon")
	worm = scene.get_node("WormThreat")
	squad = scene.get_node("SquadManager")
	hud = scene.get_node("MissionHUD")
	scout = scene.get_node("Allies/Scout")
	warrior = scene.get_node("Allies/Warrior")
	if quiet:
		_quiet_garrison()
	_park_allies()
	await _frames(20)


## Most scenarios are about mission structure, not about the garrison. They
## stand the guards down so a route is reproducible; the combat scenarios put
## them back.
func _quiet_garrison() -> void:
	for enemy: EnemyCharacter in get_nodes_in_group("enemies"):
		_stand_down(enemy)


func _stand_down(enemy: EnemyCharacter) -> void:
	enemy.perception.stop()
	enemy.weapon.disable()
	enemy.ai.set_physics_process(false)
	enemy.set_physics_process(false)


func _park_allies() -> void:
	for ally: AllyCharacter in [scout, warrior]:
		ally.ai.set_physics_process(false)
		ally.set_physics_process(false)
		ally.weapon.disable()


func _place(point: Vector2) -> void:
	player.global_position = point
	player.velocity = Vector2.ZERO
	player.aim_point = point + Vector2.RIGHT * 100.0


## Stands at a hold point and holds F for real, exactly as a player does.
func _hold(point: InteractionPoint, frames: int) -> void:
	_place(point.global_position + Vector2(0, 60))
	await _frames(4)
	Input.action_press("interact")
	await _frames(frames)
	Input.action_release("interact")
	await _frames(2)


func _sabotage_point(id: StringName) -> InteractionPoint:
	for node: Node in get_nodes_in_group("sabotage_points"):
		var point: InteractionPoint = node as InteractionPoint
		if point.id == id:
			return point
	return null


func _objective(id: StringName) -> MissionObjective:
	return mission.objective(id)


func _state(id: StringName) -> int:
	return _objective(id).state


func _sabotage_both() -> void:
	for node: Node in get_nodes_in_group("sabotage_points"):
		(node as InteractionPoint).force_complete()
	await _frames(6)


# --------------------------------------------------------------------------
# Scenario 1 - the mission exists, and says what it wants
# --------------------------------------------------------------------------

func _scene_and_objectives() -> void:
	await _load()
	_check(mission != null and raid != null, "the mission composes a manager and a raid controller")
	_check(mission.mission_name == "HARVESTER RAID", "the mission names itself")
	_check(mission.all_objectives().size() == 6, "six objectives are declared")
	_check(_objective(&"fremen").optional, "keeping both Fremen alive is optional")
	_check(not _objective(&"sabotage").optional, "sabotaging the harvester is not")
	_check(mission.required_remaining() == 5, "five required objectives remain at the start")
	_check(mission.phase == &"APPROACH", "the mission opens in its approach phase")
	_check(_state(&"approach") == MissionObjective.State.ACTIVE, "the approach objective is active")
	_check(_state(&"comms") == MissionObjective.State.ACTIVE, "the communications objective is offered from the start")
	_check(_state(&"sabotage") == MissionObjective.State.INACTIVE, "sabotage is not yet listed")
	_check(get_nodes_in_group("sabotage_points").size() == 2, "the crawler has two sabotage points")
	_check(harvester.sabotage_total == 2, "the crawler counts both of them")
	_check(get_nodes_in_group("enemies").size() >= 8, "the site is garrisoned")
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	_check(safety != null and safety.is_safe(), "Paul starts on safe rock")
	_check(harvester.emitter.continuous_active, "the running crawler is already making sign")
	_check(worm.stage == WormThreatManager.Stage.CALM, "the desert starts calm")
	# The HUD renders the list without being told what mission this is.
	var list: Label = hud.get_node("Screen/Objectives/Margin/Rows/List")
	await _frames(4)
	_check(list.text.contains("Approach"), "the objective panel shows the live objective list")
	_check(not list.text.contains("Sabotage the harvester"), "and hides objectives the player has not been given yet")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 2 - the quiet route, start to finish, never seen
# --------------------------------------------------------------------------

func _stealth_route() -> void:
	await _load()
	_place(APPROACH)
	await _frames(10)
	_check(_state(&"approach") == MissionObjective.State.COMPLETE, "walking into the bowl completes the approach")
	_check(beacon.active, "the beacon starts broadcasting")
	await _hold(beacon.interaction, 170)
	_check(not beacon.active, "holding F at the mast takes communications down")
	_check(_state(&"comms") == MissionObjective.State.COMPLETE, "the communications objective completes")
	_check(_state(&"sabotage") == MissionObjective.State.ACTIVE, "and sabotage becomes the next thing asked for")
	_check(mission.results["Communications disabled"] == "YES", "the debrief records it")
	await _hold(_sabotage_point(&"sabotage_engine"), 160)
	_check(harvester.sabotage_done == 1, "the first panel is done")
	_check(_objective(&"sabotage").progress == "1 / 2", "the objective shows its own progress")
	_check(not harvester.is_sabotaged, "one panel is not enough")
	await _hold(_sabotage_point(&"sabotage_intake"), 160)
	_check(harvester.is_sabotaged, "the second panel cripples the crawler")
	_check(int(mission.results["Times fully detected"]) == 0, "the quiet route was never fully detected")
	_check(mission.results["Full combat before sabotage"] == "NO", "and never turned into a firefight")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 3 - the beacon is skippable, and skipping it costs
# --------------------------------------------------------------------------

func _beacon_changes_the_response() -> void:
	# Skipped: the full response comes.
	await _load()
	_place(APPROACH)
	await _frames(6)
	await _sabotage_both()
	_check(beacon.active, "the crawler can be sabotaged with the mast still up")
	_check(_state(&"comms") == MissionObjective.State.ACTIVE, "the skipped objective is left open, not failed")
	_check(raid.alarm_active, "sabotage raises the alarm")
	_check(raid.reinforcement_groups == 2, "an intact mast calls two groups of reinforcements")
	var loud: int = raid.reinforcement_groups
	_check(mission.results["Communications disabled"] == "NO", "the debrief records the mast was left up")
	# Cut first: half the response.
	await _load()
	_place(APPROACH)
	await _frames(6)
	beacon.interaction.force_complete()
	await _frames(6)
	_check(not beacon.active, "the mast can be cut before the crawler is touched")
	await _sabotage_both()
	_check(raid.reinforcement_groups == 1, "a cut mast calls one group instead")
	_check(raid.reinforcement_groups < loud, "cutting communications measurably reduces the response")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 4 - shooting the way in is a route, not a failure
# --------------------------------------------------------------------------

func _combat_route() -> void:
	await _load(false)
	_park_allies()
	var guard: EnemyCharacter = scene.get_node("Enemies/Guard_PerimWest")
	for enemy: EnemyCharacter in get_nodes_in_group("enemies"):
		if enemy != guard:
			_stand_down(enemy)
	guard.global_position = Vector2(-420, -340)
	_place(Vector2(-420, -180))
	await _frames(30)
	player.aim_point = guard.global_position
	# Stand in the open in front of it: being found is the start of this route.
	var waited: int = 0
	while guard.ai.state != EnemyAIController.State.COMBAT and waited < 420:
		await _frames(10)
		waited += 10
	_check(guard.ai.state == EnemyAIController.State.COMBAT, "standing in the open gets Paul found")
	# A rifle at this range wins; the point is that the mission notices.
	var shots: int = 0
	while not guard.health.is_dead and shots < 40:
		player.aim_point = guard.global_position
		Input.action_press("fire_primary")
		await _frames(3)
		Input.action_release("fire_primary")
		await _frames(12)
		shots += 1
	_check(guard.health.is_dead, "a perimeter guard can simply be killed")
	_check(int(mission.results["Enemies defeated"]) >= 1, "the debrief counts the dead")
	_check(int(mission.results["Times fully detected"]) >= 1, "and counts having been found")
	_check(raid.combat_before_sabotage, "the controller remembers the site went loud first")
	_check(mission.results["Full combat before sabotage"] == "YES", "the debrief says so plainly")
	_check(mission.running(), "a firefight before sabotage does not end the mission")
	_quiet_garrison()
	await _sabotage_both()
	_check(harvester.is_sabotaged, "and the crawler can still be sabotaged afterwards")
	_check(mission.results["Communications disabled"] == "NO", "with the mast never touched")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 5 - the squad works here, and so does its leash
# --------------------------------------------------------------------------

func _squad_and_command_range() -> void:
	await _load()
	_place(Vector2(-200, 300))
	scout.global_position = Vector2(-120, 380)
	warrior.global_position = Vector2(-60, 380)
	for ally: AllyCharacter in [scout, warrior]:
		ally.ai.set_physics_process(true)
		ally.set_physics_process(true)
	await _frames(20)
	_check(squad.members.size() == 2, "both Fremen register with the squad")
	_check(squad.can_command(scout) and squad.can_command(warrior), "both are inside the command link at the staging point")
	squad.select_slot(2)
	_check(squad.selected_members.size() == 1, "the scout can be selected")
	squad.issue_context(Vector2(-700, 200))
	await _frames(30)
	_check(scout.ai.current_order == AllyAIController.Order.MOVE_TO, "a flank order is accepted in the mission")
	# The leash is the same 700px it is everywhere else.
	scout.global_position = Vector2(-200, 300) + Vector2(1200, 0)
	await _frames(20)
	_check(not squad.can_command(scout), "an ally dragged beyond the command range falls out of the link")
	_check(squad.link_state(scout) == CommandLinkComponent.State.OUT_OF_RANGE, "and reports the link as out of range")
	squad.clear_selection()
	squad.select_ally(scout)
	squad.issue_hold()
	await _frames(6)
	_check(squad.rejection_active(), "ordering an out-of-range ally is refused, and says so")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 6 - prescience and shields behave here as they do in the arena
# --------------------------------------------------------------------------

func _prescience_and_shields() -> void:
	await _load()
	var elite: EnemyCharacter = scene.get_node("Enemies/Elite_Intake")
	elite.global_position = Vector2(300, 400)
	_place(Vector2(300, 560))
	player.aim_point = elite.global_position
	await _frames(20)
	# Prescience.
	var before: int = int(mission.results["Prescience uses"])
	player.prescience.activate()
	await _frames(6)
	_check(player.prescience.active, "prescience works inside the mission")
	_check(TimeScaleManager.holder_name() == "PRESCIENCE", "and owns the world clock while it runs")
	_check(int(mission.results["Prescience uses"]) == before + 1, "the debrief counts prescience uses")
	player.prescience.deactivate()
	await _frames(10)
	_check(Engine.time_scale == 1.0, "and gives the clock back")
	# The elite's shield.
	var shield: ShieldComponent = ShieldComponent.find_on(elite)
	_check(shield != null and shield.enabled, "the elite carries a Holtzman shield")
	var health_before: float = elite.health.current_health
	var shots: int = 0
	while shots < 6:
		player.aim_point = elite.global_position
		Input.action_press("fire_primary")
		await _frames(3)
		Input.action_release("fire_primary")
		await _frames(14)
		shots += 1
	_check(elite.health.current_health == health_before, "rifle rounds do not get through it")
	_check(shield.last_result == ShieldComponent.Result.BLOCKED, "the shield reports the block")
	_check(shield.current_energy >= shield.minimum_energy, "and never brute-forces open")
	# A slow blade does.
	var slow: HitContext = HitContext.new()
	slow.damage = 30.0
	slow.source = player
	slow.source_team = &"atreides"
	slow.attack_velocity = 80.0
	slow.attack_type = HitContext.Type.MELEE
	slow.label = "slow blade"
	slow.position = elite.global_position
	DamageResolver.resolve(elite, slow)
	await _frames(4)
	_check(elite.health.current_health < health_before, "a slow blade goes through the shield")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 7 - sabotage is what escalates the mission
# --------------------------------------------------------------------------

func _sabotage_escalation() -> void:
	await _load()
	_place(APPROACH)
	await _frames(6)
	var quiet_sign: float = harvester.emitter.continuous_sign
	var before_sign: float = worm.worm_sign
	var alarms: Array[int] = [0]
	raid.mission_event.connect(func(event_name: StringName) -> void:
		if event_name == &"alarm":
			alarms[0] += 1)
	await _sabotage_both()
	_check(harvester.is_sabotaged, "both panels cripple the crawler")
	_check(_state(&"sabotage") == MissionObjective.State.COMPLETE, "the objective completes")
	_check(alarms[0] == 1, "sabotage raises the alarm exactly once")
	_check(worm.worm_sign > before_sign + 30.0, "the crawler tearing open spikes worm sign hard")
	_check(harvester.emitter.continuous_sign > quiet_sign, "and a crippled crawler keeps shaking harder than a working one")
	_check(raid.escape_active, "the escape opens the moment the crawler is broken")
	_check(mission.phase == &"ESCAPE", "the mission moves to its escape phase")
	_check(_state(&"escape") == MissionObjective.State.ACTIVE, "and asks for the rock")
	_check(_state(&"survive") == MissionObjective.State.ACTIVE, "and for surviving what comes")
	# Reinforcements arrive on a delay, not instantly.
	var garrison: int = get_nodes_in_group("enemies").size()
	_check(raid.reinforcements_spawned == 0, "reinforcements do not appear the same frame")
	await _frames(int(raid.reinforcement_delay * 60.0) + 30)
	_check(raid.reinforcements_spawned >= 1, "they arrive after the delay")
	_check(get_nodes_in_group("enemies").size() > garrison, "and they are real enemies in the world")
	# Distance still matters: the far side of the map did not hear it.
	var far: EnemyCharacter = scene.get_node("Enemies/Guard_OuterWest")
	_check(far.global_position.distance_to(harvester.global_position) > raid.alarm_radius, "the outer patrol is out of earshot")
	_check(far.ai.current_disturbance != "ALARM", "so it is not handed the player's position")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 8 - the rock, the worm, and the end of the mission
# --------------------------------------------------------------------------

func _escape_and_completion() -> void:
	await _load()
	_place(APPROACH)
	await _frames(6)
	await _sabotage_both()
	_place(ROCK)
	await _frames(20)
	_check(_state(&"escape") == MissionObjective.State.COMPLETE, "reaching the northern rock completes the escape")
	_check(mission.running(), "but the mission is not over until the desert has answered")
	_check(_state(&"survive") == MissionObjective.State.ACTIVE, "surviving the worm is still outstanding")
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	_check(safety.is_safe(), "the extraction point is genuine safe rock")
	var finished: Array[Dictionary] = []
	mission.mission_completed.connect(func(data: Dictionary) -> void: finished.append(data))
	worm.force_arrival()
	await _frames(20)
	_check(harvester.destroyed, "the worm takes the crippled crawler")
	_check(not harvester.emitter.continuous_active, "and the desert goes quiet where it stood")
	await _frames(300)
	_check(mission.outcome == MissionManager.Outcome.COMPLETE, "the mission completes")
	_check(_state(&"survive") == MissionObjective.State.COMPLETE, "with the survival objective met")
	_check(finished.size() == 1, "and reports its results exactly once")
	_check(mission.checkpoint() == &"", "a finished mission clears its checkpoint")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 9 - sequence break: a worm before the crawler is touched
# --------------------------------------------------------------------------

func _worm_before_sabotage() -> void:
	await _load()
	_place(ROCK)
	await _frames(90)
	_check(worm.strongest_label == "Harvester", "the running crawler is the loudest thing out there")
	worm.force_arrival()
	await _frames(20)
	_check(not harvester.destroyed, "a worm drawn early does not destroy an intact crawler")
	_check(int(mission.results["Worm events before sabotage"]) == 1, "the mission records the early event instead")
	await _frames(300)
	_check(mission.running(), "and the mission does not hand itself to the player")
	_check(_state(&"sabotage") != MissionObjective.State.COMPLETE, "sabotage is still owed")
	_check(_state(&"survive") != MissionObjective.State.COMPLETE, "and so is surviving")
	# The mission remains finishable afterwards.
	_place(APPROACH)
	await _frames(6)
	await _sabotage_both()
	_check(harvester.is_sabotaged, "the crawler can still be sabotaged after an early worm")
	_place(ROCK)
	await _frames(20)
	worm.reset_threat()
	await _frames(6)
	worm.force_arrival()
	await _frames(20)
	_check(harvester.destroyed, "and the next worm takes it")
	await _frames(300)
	_check(mission.outcome == MissionManager.Outcome.COMPLETE, "the mission can still be completed")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 10 - open sand during the escape is fatal
# --------------------------------------------------------------------------

func _worm_catches_paul() -> void:
	await _load()
	_place(APPROACH)
	await _frames(6)
	await _sabotage_both()
	_place(SAND)
	await _frames(20)
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	_check(not safety.is_safe(), "Paul is standing on open sand")
	worm.reset_threat()
	await _frames(6)
	worm.report_sign(player.global_position, 90.0, "Test bait")
	await _frames(10)
	worm.force_arrival()
	await _frames(30)
	_check(player.health.is_dead, "the worm takes whoever is on the sand")
	_check(mission.outcome == MissionManager.Outcome.FAILED, "and that ends the mission")
	_check(mission.failure_reason.length() > 0, "with a stated reason")
	await _frames(6)
	var results: PanelContainer = hud.get_node("Screen/Results")
	_check(results.visible, "the debrief comes up on failure too")
	var body: Label = hud.get_node("Screen/Results/Margin/Rows/Body")
	_check(body.text.contains("TAKEN BY THE WORM"), "and states what went wrong")
	# Two restart paths that do different things, so the debrief says which.
	_check(body.text.contains("ENTER resumes from the last checkpoint"), "and explains that ENTER resumes rather than restarts")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 11 - the optional objective, and losing Paul
# --------------------------------------------------------------------------

func _fremen_and_paul_down() -> void:
	await _load()
	_check(_state(&"fremen") == MissionObjective.State.ACTIVE, "the optional objective is live from the start")
	scout.health.die()
	await _frames(10)
	_check(_state(&"fremen") == MissionObjective.State.FAILED, "losing a Fremen fails the optional objective")
	_check(mission.results["Both Fremen survived"] == "NO", "the debrief records it")
	_check(mission.running(), "but does not end the mission")
	_place(APPROACH)
	await _frames(6)
	await _sabotage_both()
	_place(ROCK)
	await _frames(20)
	worm.force_arrival()
	await _frames(320)
	_check(mission.outcome == MissionManager.Outcome.COMPLETE, "the mission can be completed with a Fremen lost")
	_check(mission.results["Both Fremen survived"] == "NO", "and the debrief still says what happened")
	# Paul is not optional.
	await _load()
	player.health.die()
	await _frames(10)
	_check(mission.outcome == MissionManager.Outcome.FAILED, "losing Paul fails the mission")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 12 - checkpoints survive a restart
# --------------------------------------------------------------------------

func _checkpoints() -> void:
	await _load()
	_check(mission.checkpoint() == &"", "a fresh mission has no checkpoint")
	_place(APPROACH)
	await _frames(6)
	beacon.interaction.force_complete()
	await _frames(6)
	_check(mission.checkpoint() == &"comms", "cutting the mast sets a checkpoint")
	_sabotage_point(&"sabotage_engine").force_complete()
	await _frames(6)
	_check(mission.checkpoint() == &"sabotage", "the first panel moves it on")
	_sabotage_point(&"sabotage_intake").force_complete()
	await _frames(6)
	_check(mission.checkpoint() == &"escape", "crippling the crawler moves it again")
	# The checkpoint lives on the autoload, so a fresh scene restores it.
	var saved: StringName = mission.checkpoint()
	scene.queue_free()
	await _frames(2)
	root.get_node("GameManager").mission_checkpoint = saved
	scene = load("res://scenes/missions/harvester_raid/harvester_raid.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	mission = scene.get_node("Mission")
	raid = scene.get_node("RaidController")
	player = scene.get_node("Player")
	harvester = scene.get_node("Harvester")
	beacon = scene.get_node("Beacon")
	scout = scene.get_node("Allies/Scout")
	warrior = scene.get_node("Allies/Warrior")
	_quiet_garrison()
	_park_allies()
	await _frames(20)
	_check(not beacon.active, "the restored mission remembers the mast was cut")
	_check(harvester.is_sabotaged, "and that the crawler was already crippled")
	_check(raid.escape_active, "and puts the player back into the escape")
	_check(player.global_position.distance_to(START) > 1000.0, "Paul restarts at the checkpoint, not at the staging rocks")
	_check(not player.health.is_dead and player.health.current_health == player.health.max_health, "and restarts intact")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 13 - the debrief states facts, and the debug surfaces are there
# --------------------------------------------------------------------------

func _results_and_debug() -> void:
	await _load()
	# This scenario is about the debrief and the debug surfaces. Reinforcements
	# are scenario 7's business; letting armed ones spawn here only means Paul
	# is sometimes shot before the debrief can be read.
	raid.reinforcement_delay = 9999.0
	root.get_node("GameManager").debug_visible = true
	_place(APPROACH)
	await _frames(10)
	var metrics: Dictionary = scene.get_node("UI").metric_labels
	for row in ["Mission state", "Current objective", "Beacon active", "Sabotage progress",
			"Alarm active", "Reinforcements", "Harvester state", "Escape active",
			"Paul safe", "Mission checkpoint", "Mission time"]:
		_check(metrics.has(row), "F1 debug overlay shows '%s'" % row)
	_check(InputMap.has_action("mission_debug_advance"), "the mission declares its debug controls")
	_check(InputMap.has_action("mission_debug_alarm"), "including a manual alarm")
	_check(InputMap.has_action("mission_debug_restart"), "and a restart")
	await _tap(KEY_F7)
	_check(not beacon.active, "F7 completes whatever the mission is waiting on")
	await _tap(KEY_F7)
	await _tap(KEY_F7)
	_check(harvester.is_sabotaged, "and keeps advancing it")
	await _capture("m9_raid_sabotaged")
	_place(ROCK)
	await _frames(20)
	worm.force_arrival()
	await _frames(20)
	await _capture("m9_raid_worm")
	await _frames(320)
	_check(not player.health.is_dead, "Paul is alive on the rock when the worm has finished")
	_check(mission.outcome == MissionManager.Outcome.COMPLETE, "the mission completes")
	# The debrief: facts, not a grade.
	var body: Label = hud.get_node("Screen/Results/Margin/Rows/Body")
	var heading: Label = hud.get_node("Screen/Results/Margin/Rows/Heading")
	_check(hud.get_node("Screen/Results").visible, "the results panel appears")
	_check(heading.text.contains("HARVESTER RAID"), "headed with the mission's own name")
	for row in ["Communications disabled", "Enemies defeated", "Times fully detected",
			"Both Fremen survived", "Prescience uses", "Mission time"]:
		_check(body.text.contains(row), "the debrief reports '%s'" % row)
	for word in ["RANK", "GRADE", "SCORE", "STARS"]:
		_check(not body.text.to_upper().contains(word), "the debrief does not grade the player ('%s')" % word)
	_check(hud.get_node("Screen/Results/Margin/Rows/Buttons/Retry").visible, "the debrief offers a restart")
	_check(hud.get_node("Screen/Results/Margin/Rows/Buttons/Launcher").visible, "and a way back to the launcher")
	await _capture("m9_raid_results")
	root.get_node("GameManager").debug_visible = false
	completed += 1


# --------------------------------------------------------------------------
# Utilities
# --------------------------------------------------------------------------

func _key(code: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)


func _tap(code: Key) -> void:
	_key(code)
	await _frames(6)


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
