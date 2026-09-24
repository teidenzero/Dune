extends SceneTree

const Order = AllyAIController.Order
const Behavior = AllyAIController.Behavior
const State = EnemyAIController.State
const PROJECTILE: PackedScene = preload("res://scenes/combat/projectile.tscn")
var failures: int = 0
var completed: int = 0
var mission: Node2D
var player: PlayerController
var scout: AllyCharacter
var warrior: AllyCharacter
var squad: SquadManager
var guard: EnemyCharacter
var camera: TacticalCamera


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _selection_and_controls()
	await _navigation_and_orders()
	await _attack_and_enemy_response()
	await _defense_and_factions()
	await _target_and_order_edges()
	await _death_and_time_restore()
	_check(completed == 6, "all squad scenarios completed")
	_check(Engine.time_scale == 1.0, "suite leaves normal game speed")
	print("SQUAD SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load(active_guard: bool = false) -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	root.get_node("GameManager").debug_visible = false
	mission = load("res://scenes/missions/harvester_raid_test.tscn").instantiate()
	for enemy in mission.get_node("Enemies").get_children():
		if not active_guard or enemy.name != "Guard_A":
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.collision_layer = 0
	for trainer in mission.get_node("ShieldRange").get_children():
		trainer.process_mode = Node.PROCESS_MODE_DISABLED
		trainer.collision_layer = 0
	for subject in mission.get_node("PrescienceRange").get_children():
		subject.process_mode = Node.PROCESS_MODE_DISABLED
		if subject is CharacterBody2D:
			subject.collision_layer = 0
	mission.get_node("DesertRange").process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	player.set_physics_process(false)
	scout = mission.get_node("Allies/Scout")
	warrior = mission.get_node("Allies/Warrior")
	squad = mission.get_node("SquadManager")
	guard = mission.get_node("Enemies/Guard_A")
	camera = player.get_node("TacticalCamera")
	# A real pointer resting near a window edge must not pan the view mid-click.
	camera.edge_scroll_enabled = false
	await _frames(15)


func _selection_and_controls() -> void:
	await _load()
	_check(squad.members.size() == 2 and scout.health.current_health == 80 and warrior.health.current_health == 120, "two data-configured Fremen register with correct health")
	_check(scout.ai.current_order == Order.FOLLOW and warrior.ai.current_order == Order.FOLLOW, "both allies start following")
	_check(squad.paul_selected and player.selected and squad.selected_members.is_empty(), "Paul starts selected on his own")
	await _tap(KEY_2)
	_check(scout.selected and not warrior.selected and not squad.paul_selected, "2 selects only Scout")
	await _tap(KEY_3)
	_check(warrior.selected and not scout.selected and not player.selected, "3 selects only Warrior")
	await _tap(KEY_4)
	_check(squad.selected_members.size() == 2 and squad.paul_selected and squad.selected_units().size() == 3, "4 selects Paul and both allies")
	await _tap(KEY_1)
	_check(squad.paul_selected and player.selected and squad.selected_members.is_empty(), "1 selects Paul alone")
	await _tap(KEY_TAB)
	_check(squad.paul_selected and squad.selected_units().size() == 1 and Engine.time_scale == 1.0 and not squad.paused, "Tab no longer toggles a command mode or slows time")
	# Clicks select units; WASD pans the camera and never moves or fires Paul.
	player.set_physics_process(true)
	player.retaliate = false
	player.teleport_to(Vector2(-1100, 750))
	_place_ally(scout, Vector2(-1000, 700))
	_place_ally(warrior, Vector2(-1000, 800))
	camera.snap_to(Vector2(-1050, 750))
	await _frames(5)
	var initial: Vector2 = player.position
	var ammo: int = player.weapon_controller.current_ammo
	Input.action_press("move_right")
	await _left_click(scout.global_position)
	await _frames(10)
	Input.action_release("move_right")
	camera.snap_to(Vector2(-1050, 750))
	await _frames(3)
	_check(scout.selected and not warrior.selected and not squad.paul_selected, "left-click selects an ally")
	_check(player.position == initial and player.weapon_controller.current_ammo == ammo, "clicks and WASD cannot move or fire Paul")
	await _left_click(warrior.global_position, true)
	_check(squad.selected_members.size() == 2 and not squad.paul_selected, "Shift-click adds a second ally")
	await _left_click(scout.global_position, true)
	_check(not scout.selected and warrior.selected, "Shift-click toggles an ally out")
	await _left_click(player.global_position, true)
	_check(squad.paul_selected and warrior.selected and squad.selected_units().size() == 2, "Shift-click adds Paul")
	await _left_click(player.global_position)
	_check(squad.paul_selected and squad.selected_members.is_empty(), "plain click on Paul selects him alone")
	await _left_click(Vector2(-1100, 950))
	_check(not squad.has_selection() and not player.selected, "click on empty ground clears everything")
	await _tap(KEY_3)
	await _tap(KEY_H)
	_check(warrior.ai.current_order == Order.HOLD and scout.ai.current_order == Order.FOLLOW, "H affects selected unit only")
	await _tap(KEY_G)
	_check(warrior.ai.current_order == Order.FOLLOW, "G restores FOLLOW")
	# C: the whole squad goes low together, whoever is selected, and stands
	# together; a holding Fremen keeps the squad's stance.
	await _tap(KEY_3)
	await _tap(KEY_H)
	await _tap(KEY_1)
	await _tap(KEY_C)
	await _frames(20)
	_check(player.is_crouching and scout.is_crouching and warrior.is_crouching, "C crouches the whole squad, whoever is selected")
	await _tap(KEY_C)
	await _frames(20)
	_check(not player.is_crouching and not scout.is_crouching and not warrior.is_crouching, "C again stands everyone up, holding or not")
	await _tap(KEY_C)
	await _frames(5)
	player.move_to(player.global_position + Vector2(200, 0), true)
	await _frames(20)
	_check(not player.is_crouching and not scout.sneaking and not warrior.sneaking, "a run order stands the whole squad")
	player.stop()
	player.teleport_to(initial)
	await _tap(KEY_3)
	await _tap(KEY_G)
	await _tap(KEY_4)
	await _capture("squad_command")
	await _tap(KEY_F1)
	await _frames(3)
	var metrics: Dictionary = mission.get_node("UI").metric_labels
	_check(metrics.has("Selected units") and metrics["Selected units"].text.contains("Paul") and scout.get_node("SelectionIndicator/Details").visible, "F1 exposes squad and ally diagnostics")
	await _capture("squad_debug")
	await _tap(KEY_F1)
	# Right-click with only Paul selected moves Paul and nobody else.
	await _tap(KEY_1)
	var order: Order = scout.ai.current_order
	await _right_click(Vector2(-1250, 750))
	_check(player.order == PlayerController.Order.MOVE and scout.ai.current_order == order and warrior.ai.current_order == order, "right-click with Paul selected orders only Paul")
	await _frames(30)
	_check(player.position.x < initial.x - 5, "Paul walks to the right-clicked point")
	await _tap(KEY_H)
	_check(player.order == PlayerController.Order.IDLE, "H stops Paul")
	player.set_physics_process(false)
	completed += 1


func _navigation_and_orders() -> void:
	await _load()
	squad.select_slot(3)
	squad.issue_hold()
	var anchor: Vector2 = warrior.ai.hold_position
	scout.position = Vector2(-600, 220)
	squad.select_slot(2)
	camera.snap_to(Vector2(-350, 220))
	await _frames(3)
	await _right_click(Vector2(-100, 220))
	_check(scout.ai.current_order == Order.MOVE_TO and warrior.ai.current_order == Order.HOLD, "terrain right click gives independent MOVE_TO")
	_check(player.order == PlayerController.Order.IDLE, "an order to the Scout alone leaves Paul idle")
	await _frames(25)
	var path: PackedVector2Array = scout.agent.get_current_navigation_path()
	_check(path.size() > 2, "Scout path routes around approach rock")
	await _frames(340)
	_check(scout.ai.current_order == Order.HOLD and scout.position.distance_to(Vector2(-100, 220)) < 25, "MOVE_TO reaches destination and persists as HOLD")
	_check(warrior.position.distance_to(anchor) < 10, "Warrior's independent HOLD stays put")
	squad.select_slot(3)
	squad.select_ally(scout, true)
	squad.issue_context(Vector2(-850, -80))
	_check(scout.ai.order_position.distance_to(warrior.ai.order_position) >= 55, "group destinations use distinct formation offsets")
	await _frames(600)
	_check(scout.ai.current_order == Order.HOLD and warrior.ai.current_order == Order.HOLD, "both group moves complete as HOLD")
	_check(scout.position.distance_to(warrior.position) > 40, "group placement maintains spacing")
	var scout_hold: Vector2 = scout.position
	# Far from the holding pair but still inside Paul's 700 px command range.
	player.position = Vector2(-1200, -500)
	await _frames(100)
	_check(scout.position.distance_to(scout_hold) < 5, "moving Paul does not pull positioned units out of HOLD")
	squad.issue_follow()
	await _frames(900)
	_check(scout.position.distance_to(player.position + scout.follow_offset) < 65 and warrior.position.distance_to(player.position + warrior.follow_offset) < 65, "FOLLOW brings both companions around obstacles to Paul")
	var settled: Vector2 = scout.position
	await _frames(90)
	_check(scout.position.distance_to(settled) < 3, "settled follower does not continually jitter")
	player.is_crouching = true
	player.position += Vector2(180, 0)
	await _frames(30)
	_check(scout.velocity.length() <= 112 and warrior.velocity.length() <= 112, "crouched Paul limits companion follow speed")
	_check(scout.get_collision_exceptions().has(player) and player.get_collision_exceptions().has(scout), "friendly bodies cannot hard-block Paul")
	completed += 1


func _combat_fixture() -> void:
	await _load(true)
	# Within command range of the Scout, but outside the guard's 500 px sight.
	player.position = Vector2(-1300, -1000)
	warrior.ai.issue_order(Order.HOLD, Vector2(-1300, 950))
	warrior.position = Vector2(-1300, 950)
	guard.position = Vector2(-800, -700)
	guard.set_physics_process(false)
	guard.ai.set_physics_process(false)
	guard.face_position(Vector2(-1200, -700))
	scout.position = Vector2(-1200, -700)
	scout.ai.issue_order(Order.HOLD, scout.position)
	await _frames(3)


func _attack_and_enemy_response() -> void:
	await _combat_fixture()
	# 180 px: close enough that a standing Fremen is identified on sight, and
	# still outside the guard's 500 px view of Paul at (-1300, -1000).
	scout.position = Vector2(-980, -700)
	scout.ai.issue_order(Order.HOLD, scout.position)
	await _frames(4)
	var hold: Vector2 = scout.ai.hold_position
	squad.select_slot(2)
	squad.issue_context(guard.position)
	_check(scout.ai.current_order == Order.ATTACK and scout.ai.order_target == guard, "context on guard stores commanded hostile target")
	guard.ai.set_physics_process(true)
	await _frames(22)
	_check(guard.ai.state == State.COMBAT and guard.ai.target == scout, "guard identifies visible Scout and engages him")
	_check(not guard.perception.player_visible and guard.perception.detection_value == 0, "engaging Fremen does not reveal hidden Paul")
	await _frames(210)
	_check(guard.health.is_dead, "Fremen Rifle projectiles kill commanded enemy")
	_check(scout.health.current_health < 80 and not scout.health.is_dead, "enemy rifle damages surviving Fremen")
	await _frames(200)
	_check(scout.ai.current_order == Order.HOLD and scout.position.distance_to(hold) < 25, "attack completion restores prior HOLD position")
	# A Fremen who is holding still and low is not identified from across the
	# bowl; the guard comes to look instead of opening fire.
	await _combat_fixture()
	scout.position = Vector2(-1250, -700)
	squad.set_stance(true)
	scout.ai.issue_order(Order.HOLD, scout.position)
	await _frames(20)
	guard.ai.set_physics_process(true)
	await _frames(30)
	_check(scout.is_crouching, "a Fremen holding with the squad low stays low")
	_check(guard.ai.state != State.COMBAT, "a crouched Fremen at 450 px is not instantly identified")
	_check(guard.ai.state == State.SUSPICIOUS or guard.ai.state == State.INVESTIGATE, "the guard investigates the movement instead")
	await _combat_fixture()
	guard.weapon.disable()
	guard.health.max_health = 1000
	guard.health.reset_health()
	scout.ai.issue_order(Order.ATTACK, guard.position, guard)
	var reloaded: Array[bool] = [false]
	scout.weapon.reload_finished.connect(func(): reloaded[0] = true)
	await _frames(430)
	_check(reloaded[0] and guard.health.current_health < 1000, "ally uses shared automatic reload and continues firing")
	guard.position = Vector2(1400, -800)
	await _frames(30)
	_check(scout.ai.current_order == Order.HOLD, "commanded attack leash restores previous order")
	completed += 1


func _defense_and_factions() -> void:
	await _combat_fixture()
	guard.weapon.disable()
	warrior.position = Vector2(-1150, -850)
	warrior.ai.issue_order(Order.HOLD, warrior.position)
	var anchor: Vector2 = warrior.position
	guard.position = Vector2(-900, -850)
	await _frames(250)
	_check(guard.health.is_dead and warrior.ai.current_order == Order.HOLD, "HOLD defends against nearby visible hostiles without replacing order")
	await _frames(150)
	_check(warrior.position.distance_to(anchor) < 25, "temporary combat returns Warrior to hold anchor")
	await _combat_fixture()
	guard.weapon.disable()
	guard.position = Vector2(-1200, -300)
	var scout_order: Order = scout.ai.current_order
	scout.health.take_damage(1, guard)
	await _frames(15)
	_check(scout.ai.combat_target == guard and scout.ai.current_order == scout_order, "damage source triggers self-defense beyond passive radius")
	guard.health.die()
	await _frames(50)
	_check(scout.ai.behavior == Behavior.HOLD and scout.ai.current_order == scout_order, "self-defense resumes the persistent order")
	# Actual swept projectiles exercise generic team immunity in both directions.
	warrior.ai.set_physics_process(false)
	scout.ai.set_physics_process(false)
	warrior.set_physics_process(false)
	scout.set_physics_process(false)
	player.position = Vector2(-800, -700)
	scout.position = Vector2(-1100, -700)
	warrior.position = Vector2(-950, -700)
	var hp: float = warrior.health.current_health
	_launch(scout, warrior.position)
	await _frames(20)
	_check(warrior.health.current_health == hp, "ally projectile cannot damage another Fremen")
	warrior.position = Vector2(-950, -950)
	_launch(scout, player.position)
	await _frames(30)
	_check(player.health.current_health == 100, "ally projectile cannot damage Paul")
	_launch(player, scout.position)
	var scout_hp: float = scout.health.current_health
	await _frames(30)
	_check(scout.health.current_health == scout_hp, "Paul projectile cannot damage Fremen")
	completed += 1


func _target_and_order_edges() -> void:
	await _combat_fixture()
	scout.ai.issue_order(Order.FOLLOW)
	scout.ai.issue_order(Order.ATTACK, guard.position, guard)
	guard.health.die()
	await _frames(20)
	_check(scout.ai.current_order == Order.FOLLOW, "attack from FOLLOW restores FOLLOW on target death")
	await _combat_fixture()
	var destination: Vector2 = Vector2(-1100, -950)
	scout.ai.issue_order(Order.MOVE_TO, destination)
	scout.ai.issue_order(Order.ATTACK, guard.position, guard)
	guard.queue_free()
	await _frames(20)
	_check(scout.ai.current_order == Order.MOVE_TO and scout.ai.order_position == destination, "freed attack target safely restores interrupted MOVE destination")
	await _combat_fixture()
	guard.weapon.disable()
	scout.weapon.disable()
	scout.set_physics_process(false)
	# This scenario needs the target genuinely out of reach, so it sets its own
	# distance rather than inheriting the fixture's identification range.
	scout.position = Vector2(-1200, -700)
	scout.ai.issue_order(Order.HOLD, scout.position)
	await _frames(4)
	guard.position = Vector2(-650, -700)
	scout.ai.issue_order(Order.ATTACK, guard.position, guard)
	await _frames(560)
	_check(scout.ai.current_order == Order.HOLD, "visible but unreachable attack times out and restores prior order")
	await _combat_fixture()
	guard.weapon.disable()
	scout.weapon.disable()
	var anchor: Vector2 = scout.ai.hold_position
	guard.position = anchor + Vector2(250, 0)
	await _frames(20)
	_check(scout.ai.behavior == Behavior.COMBAT, "nearby hostile starts autonomous defense")
	scout.position = anchor + Vector2(300, 0)
	guard.position = anchor + Vector2(500, 0)
	await _frames(25)
	_check(not is_instance_valid(scout.ai.combat_target) and scout.ai.current_order == Order.HOLD, "leash prevents reacquisition from ratcheting HOLD across the map")
	await _combat_fixture()
	guard.health.max_health = 1000
	guard.health.reset_health()
	player.position = Vector2(-1000, -700)
	scout.position = Vector2(-800, -1000)
	scout.ai.issue_order(Order.HOLD, scout.position)
	scout.weapon.disable()
	guard.ai.set_physics_process(true)
	guard.face_position(player.position)
	await _frames(15)
	guard.perception._set_detection(100)
	await _frames(20)
	_check(guard.ai.target == player, "guard can initially engage identified Paul")
	guard.health.take_damage(1, scout)
	_check(guard.ai.target == scout, "hit-source observation resolves before old combat aim can override it")
	await _frames(20)
	_check(guard.ai.target == scout and guard.perception.priority_target == scout, "guard turns toward and prioritizes a Fremen attacker")
	player.position = Vector2(-1450, 950)
	await _frames(140)
	_check(guard.perception.detection_value < 100 and guard.ai.target == scout, "Fremen combat does not freeze hidden Paul's identification meter")
	completed += 1


func _death_and_time_restore() -> void:
	await _load()
	squad.select_slot(4)
	scout.health.die()
	await _frames(3)
	_check(not scout.selected and squad.selected_members.size() == 1 and scout.ai.behavior == Behavior.DEAD, "death clears selected ally and stops AI")
	_check(not scout.weapon.enabled and scout.collision_layer == 0, "dead ally stops combat and blocking")
	await _tap(KEY_2)
	_check(squad.selected_units().is_empty(), "dead-unit number selection is safe")
	await _tap(KEY_4)
	_check(squad.selected_members.size() == 1 and warrior.selected and squad.paul_selected, "surviving ally remains commandable alongside Paul")
	await _tap(KEY_SPACE)
	_check(squad.paused and paused, "Space pauses before Paul falls")
	player.health.die()
	await _frames(2)
	_check(not squad.paused and not paused and Engine.time_scale == 1.0, "player death immediately lifts the pause")
	_check(not squad.paul_selected and not player.selected, "a dead Paul drops out of the selection")
	await _tap(KEY_1)
	_check(not squad.paul_selected, "a dead Paul cannot be reselected")
	player.set_physics_process(true)
	await _tap(KEY_ENTER)
	await _frames(12)
	mission = current_scene as Node2D
	squad = mission.get_node("SquadManager")
	_check(Engine.time_scale == 1.0 and not paused and squad.members.size() == 2 and squad.members[0].health.current_health > 0, "Enter restart restores both allies at normal speed")
	_check(squad.paul_selected and squad.player.selected, "the restarted mission selects Paul again")
	squad.set_paused(true)
	mission.queue_free()
	await _frames(3)
	_check(Engine.time_scale == 1.0 and not paused, "scene teardown while paused restores the running game")
	completed += 1


func _launch(source: PhysicsBody2D, point: Vector2) -> void:
	var weapon: WeaponController = source.get_node("WeaponController")
	var shot: CombatProjectile = PROJECTILE.instantiate()
	var direction: Vector2 = source.global_position.direction_to(point)
	shot.configure(weapon.weapon_data, direction, source)
	mission.add_child(shot)
	shot.global_position = source.global_position + direction * 28


func _place_ally(ally: AllyCharacter, point: Vector2) -> void:
	ally.ai.set_physics_process(false)
	ally.set_physics_process(false)
	ally.velocity = Vector2.ZERO
	ally.global_position = point
	ally.stop_moving()


## Window coordinates for a world point. Input events arrive in window space,
## which the 1920 x 1080 canvas is stretched into.
func _screen(world: Vector2) -> Vector2:
	var viewport: Viewport = mission.get_viewport()
	return viewport.get_screen_transform() * (viewport.get_canvas_transform() * world)


func _mouse(button: MouseButton, world: Vector2, pressed: bool, shift: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.position = _screen(world)
	event.global_position = event.position
	Input.parse_input_event(event)


func _right_click(world: Vector2) -> void:
	_mouse(MOUSE_BUTTON_RIGHT, world, true)
	_mouse(MOUSE_BUTTON_RIGHT, world, false)
	await _frames(1)


func _left_click(world: Vector2, shift: bool = false) -> void:
	_mouse(MOUSE_BUTTON_LEFT, world, true, shift)
	_mouse(MOUSE_BUTTON_LEFT, world, false, shift)
	await _frames(1)


func _tap(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


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
