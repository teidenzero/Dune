extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/turn_combat_smoke.gd
##
## Turn-based combat in the harvester interior: going in by choice (Q) as a
## vision and taking it back, a silent kill from behind, being spotted and
## the Harkonnen acting first, action points and hit rules (shields stop
## bullets and quick blades), a vision in which the hero dies, the mission's
## clocks advancing by the round, and the fight ending when nobody who knows
## about the hero is left.

const INTERIOR: String = "res://scenes/missions/harvester_raid/harvester_interior.tscn"

var failures: int = 0
var completed: int = 0
var mission: Node
var player: PlayerController
var combat: TurnCombat
var controller: HarvesterInteriorController


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _prescience_entry_and_rewind()
	await _silent_kill()
	await _spotted()
	await _points_and_shields()
	await _death_in_a_vision()
	await _rounds_move_the_clocks()
	await _rewind_restores_everything()
	await _attack_opens_the_fight()
	await _leaving_is_bulletproof()
	_check(completed == 9, "all turn-combat scenarios completed")
	print("TURN COMBAT SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load() -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	root.get_node("GameManager").mission_checkpoint = &""
	mission = (load(INTERIOR) as PackedScene).instantiate()
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("World/Player")
	controller = mission.get_node("InteriorController")
	await _frames(20)
	combat = controller.combat
	# Everyone stands still until a test moves them.
	for enemy: Node in get_nodes_in_group("enemies"):
		(enemy as EnemyCharacter).set_physics_process(false)
		(enemy as EnemyCharacter).ai.set_physics_process(false)
		(enemy as EnemyCharacter).perception.set_physics_process(false)


func _enemy(id: String) -> EnemyCharacter:
	return mission.get_node("World/Enemies/" + id) as EnemyCharacter


func _place(actor: Node2D, cell: Vector2i) -> void:
	actor.global_position = IsoMath.cell_to_world(cell)
	if actor == player:
		player.teleport_to(actor.global_position)


func _prescience_entry_and_rewind() -> void:
	await _load()
	_place(player, Vector2i(3, 6))
	await _frames(2)
	var start: Vector2 = player.global_position
	_key(KEY_Q)
	await _frames(12)
	_check(combat.active() and combat.phase == TurnCombat.Phase.PLAYER, "Q starts a fight, the hero's turn first")
	_check(combat.in_vision and combat.vision_from_explore, "and the opening is a vision")
	_check(combat.opening == &"vision" and (mission.get_node("InteriorController/CombatHud") as CombatHud)._banner.text in ["PRESCIENCE", "VISION"], "and the banner is a prescience one")
	var anchor: VisionAnchor = combat._anchor
	_check(is_instance_valid(anchor) and anchor.global_position.distance_to(start) < 2.0 and player.modulate == VisionAnchor.SHADOW, "the real Paul stays where he stood; the one who acts is his blue shadow")
	_check(combat.prescience_left == 2, "one of Paul's three visions spent")
	_check(player.turn_based and _enemy("Guard_a").turn_based, "real time stops for everyone")
	_check(combat.points == 10, "ten action points")
	var hud: CombatHud = controller.get_node("CombatHud")
	_check(hud._root.visible and not (get_first_node_in_group("player_hud") as CanvasItem).visible, "the combat interface replaces the exploring HUD")
	var camera: TacticalCamera = player.get_node("TacticalCamera")
	_check(camera.combat_zoom >= combat.min_zoom, "the camera comes in close")
	combat.command_move(Vector2i(3, 9))
	await _frames(90)
	_check(IsoMath.world_to_cell(player.global_position) == Vector2i(3, 9) and combat.points == 7, "three tiles down the crawlway: three points")
	_check(anchor.global_position.distance_to(start) < 2.0, "the shadow walked; Paul did not")
	combat.command_sneak()
	var plan: Dictionary = combat.preview_move(Vector2i(3, 11))
	_check(plan.cost == 4, "sneaking costs two points a tile")
	combat.command_sneak()
	_check(not combat.preview_move(Vector2i(8, 16)).ok, "a walk beyond the points left is refused")
	combat.rewind_vision()
	await _frames(20)
	_check(not combat.active() and not player.turn_based, "taking the vision back: the fight never happened")
	_check(player.global_position.distance_to(start) < 20.0, "the hero is back where he stood")
	_check(not is_instance_valid(anchor) and player.modulate == Color.WHITE, "and the shadow is gone")
	_check(camera.combat_zoom == 0.0, "and the camera lets go")
	completed += 1


func _silent_kill() -> void:
	await _load()
	var crewman: EnemyCharacter = _enemy("Guard_a")
	_place(crewman, Vector2i(12, 2))
	crewman.face_position(IsoMath.cell_to_world(Vector2i(14, 2)))
	_place(player, Vector2i(10, 2))
	await _frames(2)
	combat.begin(true)
	await _frames(12)
	crewman.face_position(IsoMath.cell_to_world(Vector2i(14, 2)))
	combat.forced_roll = 99.0
	combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
	var preview: Dictionary = combat.preview_attack(crewman)
	_check(preview.note == "FROM BEHIND: SILENT KILL" and preview.cost == 3 + 1, "the readout promises a silent kill: one step, one cut")
	await combat.command_attack(crewman)
	await _frames(5)
	_check(crewman.health.is_dead, "the crewman dies without a sound")
	_check(not combat.aware.has(crewman) and combat.last_event == "SILENT KILL", "nobody saw it")
	combat.end_turn()
	await _frames(20)
	_check(combat.phase == TurnCombat.Phase.PROMPT and not combat.vision_fatal, "the vision ends in a choice")
	var anchor: VisionAnchor = combat._anchor
	combat.accept_vision()
	await _frames(40)
	_check(not combat.active() and crewman.health.is_dead, "accepted: back to real time, and the kill stands")
	_check(not is_instance_valid(anchor) and player.modulate.is_equal_approx(Color.WHITE), "Paul and his shadow are one again")
	completed += 1


func _spotted() -> void:
	await _load()
	var guard: EnemyCharacter = _enemy("Guard_b")
	_place(guard, Vector2i(18, 7))
	_place(player, Vector2i(21, 7))
	guard.face_position(player.global_position)
	await _frames(2)
	combat.forced_roll = 0.0
	guard.ai.target = player
	guard.ai.change_state(EnemyAIController.State.COMBAT)
	await _frames(3)
	_check(combat.active() and combat.aware.has(guard), "a guard who sees him starts the fight")
	_check(combat.phase == TurnCombat.Phase.ENEMY or combat.phase == TurnCombat.Phase.BUSY, "and the Harkonnen act first")
	await _wait_for_player_turn()
	_check(player.health.current_health < 150.0, "the guard shot first")
	_check(combat.phase == TurnCombat.Phase.PLAYER and combat.points == 10, "then it is the hero's turn")
	_check(controller.alarm_active, "being spotted raises the crawler's alarm")
	completed += 1


func _points_and_shields() -> void:
	await _load()
	var guard: EnemyCharacter = _enemy("Guard_b")
	var shielded: EnemyCharacter = _enemy("Shielded_c")
	_place(guard, Vector2i(18, 7))
	_place(player, Vector2i(21, 7))
	_place(shielded, Vector2i(22, 8))
	await _frames(2)
	combat.begin(true)
	await _frames(12)
	combat.accept_vision()
	combat.forced_roll = 0.0
	var before: float = guard.health.current_health
	combat.select_attack(TurnRules.Attack.FIRE)
	await combat.command_attack(guard)
	await _frames(3)
	_check(guard.health.current_health == before - 30.0 and combat.points == 6, "a pistol shot: four points, thirty damage")
	_check(combat.aware.has(guard), "a guard who is shot knows")
	var shielded_health: float = shielded.health.current_health
	await combat.command_attack(shielded)
	await _frames(3)
	_check(shielded.health.current_health == shielded_health and combat.points == 2, "a Holtzman shield stops the bullet")
	_check(not combat.preview_attack(shielded).ok, "two points left: no third shot")
	combat.end_turn()
	await _wait_for_player_turn()
	combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
	var quick: Dictionary = combat.preview_attack(shielded)
	_check(quick.note == "SHIELD STOPS A QUICK BLADE", "the readout warns a quick blade will not pass")
	combat.select_attack(TurnRules.Attack.SLOW_KNIFE)
	await combat.command_attack(shielded)
	await _frames(3)
	_check(shielded.health.current_health < shielded_health, "the slow blade does")
	completed += 1


func _death_in_a_vision() -> void:
	await _load()
	var guard: EnemyCharacter = _enemy("Guard_b")
	_place(guard, Vector2i(18, 7))
	_place(player, Vector2i(21, 7))
	await _frames(2)
	combat.begin(true)
	await _frames(12)
	combat.accept_vision()
	combat._make_aware(guard)
	player.health.current_health = 5.0
	combat.forced_roll = 0.0
	combat.command_vision()
	_check(combat.in_vision and combat.prescience_left == 1, "a second vision, mid-fight")
	combat.end_turn()
	await _frames(200)
	_check(combat.vision_fatal and combat.phase == TurnCombat.Phase.PROMPT, "the guard's shot would kill him: the vision shows it")
	_check(not player.health.is_dead and (mission.get_node("Mission") as MissionManager).running(), "but it is only a vision - the mission goes on")
	combat.accept_vision()
	_check(combat.in_vision, "a death cannot be accepted")
	combat.rewind_vision()
	await _frames(5)
	_check(player.health.current_health == 5.0 and combat.phase == TurnCombat.Phase.PLAYER and combat.points == 10, "taken back to the start of his turn")
	completed += 1


func _rounds_move_the_clocks() -> void:
	await _load()
	var guard: EnemyCharacter = _enemy("Guard_b")
	_place(guard, Vector2i(18, 7))
	_place(player, Vector2i(21, 7))
	for point: Node in get_nodes_in_group("sabotage_points"):
		(point as InteractionPoint).force_complete()
	await _frames(2)
	var before: float = controller.worm_remaining
	combat.begin(true)
	await _frames(12)
	combat.accept_vision()
	combat._make_aware(guard)
	await _frames(30)
	_check(is_equal_approx(controller.worm_remaining, before), "real time stops for the worm too")
	combat.forced_roll = 99.0
	combat.end_turn()
	await _wait_for_player_turn()
	_check(is_equal_approx(controller.worm_remaining, before - TurnRules.ROUND_SECONDS), "each round is five seconds of the countdown")
	# Kill the last one who knows: the fight is over.
	combat.forced_roll = 0.0
	combat.select_attack(TurnRules.Attack.FIRE)
	guard.health.current_health = 10.0
	# Everyone else is already down (a gunshot would bring them in).
	for other: EnemyCharacter in combat._living_enemies():
		if other != guard:
			other.health.die()
	await combat.command_attack(guard)
	await _frames(5)
	_check(not combat.active(), "the last Harkonnen who knew falls: back to real time")
	completed += 1


## Taking back a vision that started from exploring leaves every guard as he
## was the instant Q was pressed: where he looked, what he knew, what he was
## doing - and he goes on as if nothing happened.
func _rewind_restores_everything() -> void:
	await _load()
	var elite: EnemyCharacter = _enemy("Elite_e")
	# This one is live in real time for the test.
	elite.set_physics_process(true)
	elite.ai.set_physics_process(true)
	elite.perception.set_physics_process(true)
	_place(player, Vector2i(26, 12))
	await _frames(10)
	var rotation: float = elite.aim_pivot.rotation
	var state: EnemyAIController.State = elite.ai.state
	var detection: float = elite.perception.detection_value
	var has_memory: bool = elite.ai.has_last_known_position
	var ai_target: Node2D = elite.ai.target
	var seen_target: Node2D = elite.perception.target
	_check(not TurnRules.is_behind(player.global_position, elite) == false, "the hero starts behind the Elite, unseen")
	_key(KEY_Q)
	await _frames(12)
	combat._make_aware(elite)
	await _frames(3)
	_check(absf(angle_difference(elite.aim_pivot.rotation, rotation)) > 0.5 and elite.ai.state == EnemyAIController.State.COMBAT, "in the vision he turns on the hero")
	# He wounds the hero in the vision: the hero must not carry a grudge out.
	var ammo: int = player.weapon_controller.current_ammo
	var wound: HitContext = HitContext.ranged(10.0, 900.0, elite, &"harkonnen", "test", player.global_position, Vector2.LEFT)
	DamageResolver.resolve(player, wound)
	await _frames(2)
	combat.rewind_vision()
	await _frames(3)
	_check(player.order == PlayerController.Order.IDLE and player.order_target == null, "taken back: the hero has no order left over from the vision")
	_check(is_equal_approx(elite.aim_pivot.rotation, rotation), "taken back: he faces where he faced")
	_check(elite.ai.state == state and elite.ai.target == ai_target and elite.perception.target == seen_target, "he is doing what he was doing, after the same target as before")
	_check(is_equal_approx(elite.perception.detection_value, detection) and elite.ai.has_last_known_position == has_memory, "and remembers nothing of the vision")
	_check(not elite.turn_based and elite.ai.is_physics_processing(), "real time runs for him again")
	await _frames(90)
	_check(absf(angle_difference(elite.aim_pivot.rotation, rotation)) < 0.3 and elite.ai.state != EnemyAIController.State.COMBAT, "a second and a half later he still has not turned round")
	_check(player.weapon_controller.current_ammo == ammo and player.order == PlayerController.Order.IDLE, "and the hero has not opened fire on his own")
	completed += 1


## Whoever attacks first acts first: a knife or a shot ordered in real time
## opens the fight on the hero's turn, as his first action, with no vision.
func _attack_opens_the_fight() -> void:
	await _load()
	var squad: SquadManager = get_first_node_in_group("squad_manager") as SquadManager
	var crewman: EnemyCharacter = _enemy("Guard_a")
	_place(crewman, Vector2i(12, 2))
	crewman.face_position(IsoMath.cell_to_world(Vector2i(14, 2)))
	_place(player, Vector2i(9, 2))
	await _frames(3)
	var visions: int = combat._prescience()
	squad._begin_blade_charge(crewman)
	await _frames(3)
	_check(not combat.active() and player.order == PlayerController.Order.IDLE, "the knife held on a guard: Paul waits for the release, no real-time lunge")
	squad._release_blade_charge()
	await _frames(3)
	_check(combat.active() and combat.acting == player and not combat.in_vision, "released: the fight opens on Paul's turn, and it is not a vision")
	var hud: CombatHud = mission.get_node("InteriorController/CombatHud")
	_check(combat.opening == &"strike" and hud._banner.text == "YOU STRIKE FIRST", "the banner says he struck first - not PRESCIENCE")
	crewman.face_position(IsoMath.cell_to_world(Vector2i(14, 2)))
	for index in range(240):
		if not combat.active():
			break
		await _frames(1)
	_check(crewman.health.is_dead and not combat.active(), "a silent kill from behind, and straight back to real time")
	_check(combat.prescience_left == visions, "no vision was spent")
	# A shot from the open: Paul fires before anyone else moves.
	await _load()
	squad = get_first_node_in_group("squad_manager") as SquadManager
	var guard: EnemyCharacter = _enemy("Elite_e")
	_place(guard, Vector2i(18, 7))
	_place(player, Vector2i(21, 7))
	guard.face_position(IsoMath.cell_to_world(Vector2i(14, 7)))
	await _frames(3)
	combat.forced_roll = 0.0
	var ammo: int = player.weapon_controller.current_ammo
	var health: float = player.health.current_health
	squad.issue_context(guard.global_position)
	await _frames(3)
	_check(combat.active() and not combat.in_vision and combat.round_number == 1, "a right-click on a guard opens the fight")
	for index in range(240):
		if combat.phase == TurnCombat.Phase.PLAYER and player.weapon_controller.current_ammo < ammo:
			break
		await _frames(1)
	_check(player.weapon_controller.current_ammo == ammo - 1 and combat.phase == TurnCombat.Phase.PLAYER, "Paul's shot is the first thing that happens, and it is still his turn")
	_check(player.health.current_health == health and combat.points == combat.max_points - TurnRules.FIRE_COST, "nobody has answered yet; the shot cost its points")
	# Out of sight: the order stays a real-time one.
	await _load()
	squad = get_first_node_in_group("squad_manager") as SquadManager
	var hidden: EnemyCharacter = _enemy("Guard_b")
	_place(player, Vector2i(3, 6))
	await _frames(3)
	var reachable: bool = combat.can_open_with(hidden, TurnRules.Attack.FIRE)
	squad.issue_context(hidden.global_position)
	await _frames(3)
	_check(not reachable and not combat.active() and player.order == PlayerController.Order.ATTACK, "a guard he cannot shoot this turn: a real-time order to find a line")
	completed += 1


## However the last hunter dies, outside a vision the fight ends and real time
## returns; a dead guard never starts one; a vision still ends in its choice.
func _leaving_is_bulletproof() -> void:
	# A spotted fight; the guard dies to something that is not the hero's turn.
	await _load()
	var guard: EnemyCharacter = _enemy("Guard_b")
	_place(guard, Vector2i(18, 7))
	_place(player, Vector2i(21, 7))
	guard.face_position(player.global_position)
	await _frames(2)
	combat.forced_roll = 100.0
	guard.ai.target = player
	guard.ai.change_state(EnemyAIController.State.COMBAT)
	await _frames(3)
	await _wait_for_player_turn()
	_check(combat.phase == TurnCombat.Phase.PLAYER and combat.aware.has(guard), "a spotted fight reaches the hero's turn")
	# His shot brought the crawler; every one of them dies outside the turn.
	for hunter in combat._aware_living():
		hunter.health.take_damage(hunter.health.max_health * 3.0, null)
	await _frames(5)
	_check(not combat.active() and not player.turn_based, "the last hunters killed by a blast: real time at once")
	# A dead guard left in combat state never starts a fight.
	guard.ai.state = EnemyAIController.State.COMBAT
	await _frames(10)
	_check(not combat.active(), "a dead guard, whatever his state, never starts a fight")
	# A fight the hero opened: the wounded guard he did not alert dies too.
	await _load()
	var first: EnemyCharacter = _enemy("Guard_a")
	var second: EnemyCharacter = _enemy("Guard_b")
	_place(first, Vector2i(12, 2))
	_place(second, Vector2i(14, 5))
	first.face_position(IsoMath.cell_to_world(Vector2i(14, 2)))
	second.face_position(IsoMath.cell_to_world(Vector2i(18, 5)))
	_place(player, Vector2i(10, 2))
	await _frames(3)
	combat.begin(true, [], false)
	await _frames(5)
	combat.aware.clear()
	first.health.take_damage(first.health.max_health * 3.0, null)
	second.health.take_damage(second.health.max_health * 3.0, null)
	await _frames(5)
	_check(not combat.active() and not player.turn_based, "nobody left who knows of him: the fight he opened ends too")
	# A guard removed while the hero walks up to knife him: the action ends
	# cleanly, and with nobody left the fight does too.
	await _load()
	var victim: EnemyCharacter = _enemy("Guard_a")
	_place(victim, Vector2i(14, 2))
	victim.face_position(IsoMath.cell_to_world(Vector2i(16, 2)))
	_place(player, Vector2i(9, 2))
	await _frames(3)
	combat.begin(true, [], false)
	await _frames(5)
	combat._make_aware(victim, false)
	combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
	combat.command_attack(victim)
	await _frames(8)
	# Every guard aboard, even behind closed doors, is gone - and no more come.
	controller._pending_groups = 0
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.remove_from_group("enemies")
		enemy.queue_free()
	for index in range(480):
		if not combat.active():
			break
		await _frames(1)
	_check(not combat.active() and not player.turn_based, "a target gone mid-action: no hang, back to real time")
	# A phase that never moves on is recovered.
	await _load()
	var watcher: EnemyCharacter = _enemy("Guard_b")
	_place(player, Vector2i(3, 6))
	await _frames(3)
	combat.begin(true, [], false)
	await _frames(5)
	combat._make_aware(watcher, false)
	combat.phase = TurnCombat.Phase.BUSY
	combat._phase_since = Time.get_ticks_msec() - int((TurnCombat.STALL_SECONDS + 1.0) * 1000.0)
	await _frames(3)
	_check(combat.phase == TurnCombat.Phase.PLAYER, "a stalled phase is recovered: the hero's turn again")
	# The one who knew dies: nobody is hunting him any more.
	watcher.health.take_damage(watcher.health.max_health * 3.0, null)
	await _frames(3)
	_check(not combat.active(), "and with nobody hunting him, real time")
	# Inside a vision the vision decides: it ends in its own choice.
	await _load()
	_place(player, Vector2i(3, 6))
	await _frames(2)
	_key(KEY_Q)
	await _frames(12)
	for enemy in combat._living_enemies():
		enemy.health.take_damage(enemy.health.max_health * 3.0, null)
	await _frames(5)
	_check(combat.active() and combat.in_vision, "in a vision, everyone gone: the vision still stands until its choice")
	combat.end_turn()
	await _wait_for_player_turn()
	_check(combat.phase == TurnCombat.Phase.PROMPT, "ending the turn brings the choice")
	combat.accept_vision()
	await _frames(40)
	_check(not combat.active() and not player.turn_based, "accepted: real time")
	completed += 1


func _wait_for_player_turn() -> void:
	for index in range(2400):
		if combat.phase == TurnCombat.Phase.PLAYER or combat.phase == TurnCombat.Phase.PROMPT or not combat.active():
			return
		await _frames(1)


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
