extends SceneTree
## Plays the Harvester Raid the way a player does - real orders (move, run,
## sneak, attack, use), no teleporting - and reports what actually happens and
## how long it takes. This is for observation, not assertion: it is how
## M9_PLAYTEST.md gets written from facts instead of from guesses.
##
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/playthrough.gd -- mode=<stealth|combat|squad|careful> [trace]

var scene: Node2D
var mission: MissionManager
var raid: HarvesterRaidController
var player: PlayerController
var harvester: Harvester
var beacon: CommunicationsBeacon
var worm: WormThreatManager
var squad: SquadManager

var clock: float = 0.0
var notes: Array[String] = []
var stuck_events: int = 0
var detect_events: int = 0
var peak_sign: float = 0.0
var frame_samples: Array[float] = []
var trace_sign: bool = false
var _last_trace: float = -99.0

const START := Vector2(0, 1560)
const BEACON := Vector2(-1120, -60)
const SAB_A := Vector2(100, -470)
const SAB_B := Vector2(800, -100)
const ROCK := Vector2(0, -1500)


func _initialize() -> void:
	call_deferred("_run")


func _note(text: String) -> void:
	var line: String = "[%5.1fs] %s" % [clock, text]
	notes.append(line)
	print(line)


func _run() -> void:
	var mode: String = "stealth"
	trace_sign = "trace" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="):
			mode = arg.split("=")[1]
	await _load()
	_note("MODE: %s" % mode)
	match mode:
		"stealth": await _stealth_run()
		"combat": await _combat_run()
		"squad": await _squad_run()
		"careful": await _careful_run()
	_report()
	quit(0)


func _load() -> void:
	root.get_node("GameManager").mission_checkpoint = &""
	scene = load("res://scenes/missions/harvester_raid/harvester_raid.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	mission = scene.get_node("Mission")
	raid = scene.get_node("RaidController")
	player = scene.get_node("Player")
	harvester = scene.get_node("Harvester")
	beacon = scene.get_node("Beacon")
	worm = scene.get_node("WormThreat")
	squad = scene.get_node("SquadManager")
	for enemy: EnemyCharacter in get_nodes_in_group("enemies"):
		enemy.ai.state_changed.connect(func(_o: int, n: int) -> void:
			if n == EnemyAIController.State.COMBAT:
				detect_events += 1
				_note("DETECTED by %s from %.0f px (his vision %.0f), target=%s" % [
					enemy.name,
					enemy.global_position.distance_to(player.global_position),
					enemy.perception.vision_distance,
					str(enemy.ai.target.name) if is_instance_valid(enemy.ai.target) else "none"]))
	mission.objective_completed.connect(func(o: MissionObjective) -> void: _note("OBJECTIVE: %s" % o.title))
	mission.phase_changed.connect(func(p: StringName, _q: StringName) -> void: _note("PHASE: %s" % p))
	raid.mission_event.connect(func(e: StringName) -> void: _note("EVENT: %s" % e))
	await _wait(1.0)
	squad.select_slot(1)
	_note("loaded; %d enemies, Paul at %s" % [get_nodes_in_group("enemies").size(), str(player.global_position.round())])


func _alive() -> bool:
	return mission.running() and not player.health.is_dead


## A right-click order (double right-click to run, C first to sneak), reporting
## if Paul cannot make progress along his path.
func _walk_to(target: Vector2, limit: float = 40.0, sprint: bool = false, crouch: bool = false) -> bool:
	if not _alive():
		return false
	var spent: float = 0.0
	var last: Vector2 = player.global_position
	var still: float = 0.0
	player.set_crouching(crouch)
	player.move_to(target, sprint and not crouch)
	while player.order == PlayerController.Order.MOVE and spent < limit and _alive():
		await _wait(0.1)
		spent += 0.1
		if player.global_position.distance_to(last) < 3.0:
			still += 0.1
			if still > 2.0:
				stuck_events += 1
				_note("STUCK near %s heading for %s" % [str(player.global_position.round()), str(target.round())])
				still = 0.0
				# Re-issue the order, the way a player would click again.
				player.move_to(target, sprint and not crouch)
		else:
			still = 0.0
		last = player.global_position
	if player.order == PlayerController.Order.MOVE:
		player.stop()
	if crouch:
		player.set_crouching(false)
	await _wait(0.1)
	var arrived: bool = player.global_position.distance_to(target) <= 40.0
	if not arrived:
		_note("GAVE UP walking to %s, still %.0f px away" % [str(target.round()), player.global_position.distance_to(target)])
	return arrived


## Right-clicks a point to use it and reports how long it really took, from the
## order to completion, including the walk into range.
func _hold_point(point: InteractionPoint, label: String, limit: float = 10.0) -> bool:
	if not _alive() or point == null:
		return false
	var gap: float = player.global_position.distance_to(point.global_position)
	if not point.player_in_range():
		_note("%s: ordered from %.0f px (radius %.0f) - Paul walks in" % [label, gap, point.interact_radius])
	var began: float = clock
	# Lambdas capture locals by value; a one-slot array is shared.
	var interrupted: Array[int] = [0]
	var watch: Callable = func(reason: String) -> void:
		interrupted[0] += 1
		_note("%s hold interrupted: %s" % [label, reason])
	point.interaction_cancelled.connect(watch)
	player.interact_with(point)
	var spent: float = 0.0
	while spent < limit and not point.used and _alive():
		await _wait(0.1)
		spent += 0.1
		if player.order != PlayerController.Order.INTERACT and not point.used and _alive():
			# Retaliation or a stray order pulled him off; click it again.
			player.interact_with(point)
	point.interaction_cancelled.disconnect(watch)
	gap = player.global_position.distance_to(point.global_position)
	if player.order == PlayerController.Order.INTERACT:
		player.stop()
	await _wait(0.2)
	if point.used:
		_note("%s DONE in %.1fs (stood %.0f px away, %d interruptions)" % [label, clock - began, gap, interrupted[0]])
	else:
		_note("%s FAILED after %.1fs (stood %.0f px away, %d interruptions)" % [label, clock - began, gap, interrupted[0]])
	return point.used


func _point(id: StringName) -> InteractionPoint:
	for node in get_nodes_in_group("interaction_points"):
		var p: InteractionPoint = node as InteractionPoint
		if p.id == id:
			return p
	return null


func _stealth_run() -> void:
	_note("--- approach ---")
	await _walk_to(Vector2(0, 900), 30.0, false, true)
	_note("--- cross to the mast ---")
	await _walk_to(Vector2(-700, 500), 30.0)
	await _walk_to(Vector2(-1120, 120), 30.0)
	await _hold_point(_point(&"beacon"), "beacon", 8.0)
	_note("beacon active=%s" % str(beacon.active))
	_note("--- cross to the crawler ---")
	await _walk_to(Vector2(-600, -200), 30.0)
	await _hold_point(_point(&"sabotage_engine"), "sabotage A", 8.0)
	await _walk_to(Vector2(750, -300), 30.0)
	await _hold_point(_point(&"sabotage_intake"), "sabotage B", 8.0)
	_note("crawler sabotaged=%s" % str(harvester.is_sabotaged))
	_note("--- escape ---")
	await _walk_to(Vector2(0, -900), 30.0, true)
	await _walk_to(ROCK, 30.0, true)
	_note("on safe rock, waiting for the worm")
	var waited: float = 0.0
	while mission.running() and waited < 90.0:
		await _wait(0.5)
		waited += 0.5
	_note("outcome=%s after %.1fs" % [mission.outcome_name(), clock])


## The route a player who has read the tutorial would actually take: leave the
## Fremen holding out of sight, stay crouched, and go round the west edge
## rather than straight through the middle of a garrisoned bowl.
## A player who is shot at shoots back. Walking in a straight line while being
## fired on is not a route, it is a harness bug.
func _fight_back(limit: float = 12.0) -> void:
	var spent: float = 0.0
	while spent < limit and _alive():
		var foe: EnemyCharacter = null
		for e: EnemyCharacter in get_nodes_in_group("enemies"):
			if e.health.is_dead or e.ai.state != EnemyAIController.State.COMBAT:
				continue
			if e.global_position.distance_to(player.global_position) < 600.0:
				foe = e
				break
		if foe == null:
			break
		# Right-click the shooter: Paul closes to range, fires, and reloads.
		if player.order_target != foe:
			player.attack(foe)
		await _wait(0.3)
		spent += 0.3
	if player.order == PlayerController.Order.ATTACK:
		player.stop()
	if spent > 0.0:
		_note("returned fire for %.1fs, Paul HP %.0f" % [spent, player.health.current_health])


func _careful_run() -> void:
	var scout: AllyCharacter = scene.get_node("Allies/Scout")
	var warrior: AllyCharacter = scene.get_node("Allies/Warrior")
	squad.select_slot(4)
	squad.issue_hold()
	await _wait(1.0)
	_note("Fremen holding on the start rock: scout crouched=%s warrior crouched=%s" % [
		str(scout.is_crouching), str(warrior.is_crouching)])
	_note("--- crouched approach down the west side ---")
	await _walk_to(Vector2(-700, 1200), 40.0, false, true)
	await _walk_to(Vector2(-1300, 700), 40.0, false, true)
	await _fight_back()
	await _walk_to(Vector2(-1300, 120), 40.0, false, true)
	await _fight_back()
	_note("worm sign after the approach: %.1f/%.0f (%s)" % [worm.worm_sign, worm.threshold, worm.stage_name()])
	await _hold_point(_point(&"beacon"), "beacon", 8.0)
	_note("--- crouched to the crawler ---")
	await _walk_to(Vector2(-700, -500), 40.0, false, true)
	await _fight_back()
	await _hold_point(_point(&"sabotage_engine"), "sabotage A", 8.0)
	await _walk_to(Vector2(900, -300), 40.0, false, true)
	await _fight_back()
	await _hold_point(_point(&"sabotage_intake"), "sabotage B", 8.0)
	_note("crawler sabotaged=%s, Paul HP %.0f, sign %.1f" % [
		str(harvester.is_sabotaged), player.health.current_health, worm.worm_sign])
	_note("--- escape ---")
	await _walk_to(Vector2(800, -900), 30.0, true)
	await _walk_to(ROCK, 30.0, true)
	_note("on the rock; sign %.1f stage %s" % [worm.worm_sign, worm.stage_name()])
	var waited: float = 0.0
	while mission.running() and waited < 120.0:
		await _wait(0.5)
		waited += 0.5
	_note("outcome=%s after %.1fs" % [mission.outcome_name(), clock])


func _combat_run() -> void:
	_note("--- loud approach ---")
	await _walk_to(Vector2(0, 900), 30.0, true)
	await _walk_to(Vector2(-400, 300), 30.0, true)
	# Shoot to draw attention, as a loud player would: right-click the nearest.
	var shots: Array[int] = [0]
	var fired: Callable = func() -> void: shots[0] += 1
	player.weapon_controller.weapon_fired.connect(fired)
	var spent: float = 0.0
	while shots[0] < 6 and spent < 8.0 and _alive():
		var foe: EnemyCharacter = _nearest_enemy()
		if foe != null and player.order_target != foe:
			player.attack(foe)
		await _wait(0.1)
		spent += 0.1
	player.weapon_controller.weapon_fired.disconnect(fired)
	player.stop()
	_note("fired %d shots; worm sign %.1f" % [shots[0], worm.worm_sign])
	await _wait(6.0)
	_note("after firefight: %d enemies alive, Paul HP %.0f" % [_alive_enemies(), player.health.current_health])
	await _hold_point(_point(&"sabotage_engine"), "sabotage A", 10.0)
	await _hold_point(_point(&"sabotage_intake"), "sabotage B", 10.0)
	_note("crawler sabotaged=%s, Paul HP %.0f" % [str(harvester.is_sabotaged), player.health.current_health])
	await _walk_to(ROCK, 40.0, true)
	var waited: float = 0.0
	while mission.running() and waited < 90.0:
		await _wait(0.5)
		waited += 0.5
	_note("outcome=%s after %.1fs" % [mission.outcome_name(), clock])


func _squad_run() -> void:
	_note("--- squad handling ---")
	await _walk_to(Vector2(0, 1100), 20.0)
	var scout: AllyCharacter = scene.get_node("Allies/Scout")
	var warrior: AllyCharacter = scene.get_node("Allies/Warrior")
	_note("scout %.0f px behind Paul, warrior %.0f px" % [
		scout.global_position.distance_to(player.global_position),
		warrior.global_position.distance_to(player.global_position)])
	_note("scout link=%s warrior link=%s" % [
		CommandLinkComponent.State.keys()[squad.link_state(scout)],
		CommandLinkComponent.State.keys()[squad.link_state(warrior)]])
	squad.select_slot(2)
	squad.issue_context(Vector2(-600, 700))
	await _wait(6.0)
	_note("scout ordered to (-600,700); now at %s, order=%s" % [
		str(scout.global_position.round()),
		AllyAIController.Order.keys()[scout.ai.current_order]])
	_note("scout link after order=%s" % CommandLinkComponent.State.keys()[squad.link_state(scout)])
	# Walk away and see whether the follow-up is reliable.
	await _walk_to(Vector2(600, 700), 25.0)
	_note("after Paul moved: scout %.0f px away, warrior %.0f px away" % [
		scout.global_position.distance_to(player.global_position),
		warrior.global_position.distance_to(player.global_position)])
	squad.select_slot(4)
	squad.issue_follow()
	await _wait(8.0)
	_note("after FOLLOW: scout %.0f px, warrior %.0f px" % [
		scout.global_position.distance_to(player.global_position),
		warrior.global_position.distance_to(player.global_position)])
	var blocked: bool = false
	for ally: AllyCharacter in [scout, warrior]:
		if ally.global_position.distance_to(player.global_position) < 30.0:
			blocked = true
	_note("ally crowding Paul: %s" % str(blocked))


func _nearest_enemy() -> EnemyCharacter:
	var best: EnemyCharacter = null
	var near: float = 1e9
	for e: EnemyCharacter in get_nodes_in_group("enemies"):
		if e.health.is_dead:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < near:
			near = d
			best = e
	return best


func _alive_enemies() -> int:
	var count: int = 0
	for e: EnemyCharacter in get_nodes_in_group("enemies"):
		if not e.health.is_dead:
			count += 1
	return count


func _wait(seconds: float) -> void:
	var frames: int = int(seconds * 60.0)
	for i in range(frames):
		await physics_frame
		await process_frame
		clock += 1.0 / 60.0
		peak_sign = maxf(peak_sign, worm.worm_sign)
		if i % 30 == 0:
			frame_samples.append(Engine.get_frames_per_second())
		if trace_sign and clock - _last_trace >= 2.0:
			_last_trace = clock
			_note("  sign %.1f/%.0f stage %s state %s strongest %s" % [
				worm.worm_sign, worm.threshold, worm.stage_name(), worm.state_name(), worm.strongest_label])


func _report() -> void:
	print("\n================ PLAYTHROUGH REPORT ================")
	print("elapsed real seconds: %.1f" % clock)
	print("mission clock: %s" % mission.time_text())
	print("outcome: %s / phase %s" % [mission.outcome_name(), mission.phase_name()])
	print("stuck events: %d" % stuck_events)
	print("times fully detected: %d" % detect_events)
	print("peak worm sign: %.1f" % peak_sign)
	var total: float = 0.0
	var low: float = 999.0
	for f in frame_samples:
		total += f
		low = minf(low, f)
	if not frame_samples.is_empty():
		print("fps mean %.1f min %.1f over %d samples" % [total / frame_samples.size(), low, frame_samples.size()])
	print("results: %s" % str(mission.results))
	print("===================================================")
