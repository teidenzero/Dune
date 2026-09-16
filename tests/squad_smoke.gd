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
	await _frames(15)


func _selection_and_controls() -> void:
	await _load()
	_check(squad.members.size() == 2 and scout.health.current_health == 80 and warrior.health.current_health == 120, "two data-configured Fremen register with correct health")
	_check(scout.ai.current_order == Order.FOLLOW and warrior.ai.current_order == Order.FOLLOW, "both allies start following")
	await _tap(KEY_2)
	_check(scout.selected and not warrior.selected, "2 selects only Scout")
	await _tap(KEY_3)
	_check(warrior.selected and not scout.selected, "3 selects only Warrior")
	await _tap(KEY_4)
	_check(squad.selected_members.size() == 2, "4 selects both allies")
	await _tap(KEY_1)
	_check(squad.selected_members.is_empty(), "1 clears squad selection without changing Paul control")
	await _tap(KEY_TAB)
	_check(squad.command_mode and is_equal_approx(Engine.time_scale, 0.4), "Tab enables non-paused command slowdown")
	player.set_physics_process(true)
	var initial: Vector2 = player.position
	var ammo: int = player.weapon_controller.current_ammo
	Input.action_press("move_right")
	_mouse(scout.global_position, MOUSE_BUTTON_LEFT, true)
	await _frames(10)
	_mouse(scout.global_position, MOUSE_BUTTON_LEFT, false)
	Input.action_release("move_right")
	_check(scout.selected and not warrior.selected, "command left-click selects an ally")
	_check(player.position == initial and player.weapon_controller.current_ammo == ammo, "command clicks and WASD cannot move/fire Paul")
	Input.action_press("fire_primary")
	await _frames(2)
	squad.set_command_mode(false)
	await _frames(5)
	_check(player.weapon_controller.current_ammo == ammo, "held selection click cannot become a shot when command mode exits")
	Input.action_release("fire_primary")
	squad.set_command_mode(true)
	_mouse(warrior.global_position, MOUSE_BUTTON_LEFT, true, true)
	await _frames(2)
	_mouse(warrior.global_position, MOUSE_BUTTON_LEFT, false, true)
	_check(squad.selected_members.size() == 2, "Shift-click adds a second ally")
	_mouse(scout.global_position, MOUSE_BUTTON_LEFT, true, true)
	await _frames(2)
	_mouse(scout.global_position, MOUSE_BUTTON_LEFT, false, true)
	_check(not scout.selected and warrior.selected, "Shift-click toggles an ally out")
	await _tap(KEY_H)
	_check(warrior.ai.current_order == Order.HOLD and scout.ai.current_order == Order.FOLLOW, "H affects selected unit only")
	await _tap(KEY_G)
	_check(warrior.ai.current_order == Order.FOLLOW, "G restores FOLLOW")
	await _tap(KEY_4)
	await _capture("squad_command")
	await _tap(KEY_F1)
	_check(mission.get_node("UI").metric_labels.has("Command mode") and scout.get_node("SelectionIndicator/Details").visible, "F1 exposes squad and ally diagnostics")
	await _capture("squad_debug")
	await _tap(KEY_TAB)
	_check(not squad.command_mode and Engine.time_scale == 1.0 and not player.squad_control_locked, "Tab reliably restores normal control and speed")
	Input.action_press("move_right")
	await _frames(12)
	Input.action_release("move_right")
	_check(player.position.x > initial.x + 5, "Paul movement resumes outside command mode")
	var order: Order = scout.ai.current_order
	_mouse(Vector2(-500, 500), MOUSE_BUTTON_RIGHT, true)
	await _frames(2)
	_mouse(Vector2(-500, 500), MOUSE_BUTTON_RIGHT, false)
	_check(scout.ai.current_order == order, "normal-mode right click does not issue orders")
	completed += 1


func _navigation_and_orders() -> void:
	await _load()
	squad.select_slot(3)
	squad.issue_hold()
	var anchor: Vector2 = warrior.ai.hold_position
	scout.position = Vector2(-600, 220)
	squad.select_slot(2)
	squad.set_command_mode(true)
	_mouse(Vector2(-100, 220), MOUSE_BUTTON_RIGHT, true)
	await _frames(2)
	_mouse(Vector2(-100, 220), MOUSE_BUTTON_RIGHT, false)
	_check(scout.ai.current_order == Order.MOVE_TO and warrior.ai.current_order == Order.HOLD, "terrain right click gives independent MOVE_TO")
	squad.set_command_mode(false)
	await _frames(25)
	var path: PackedVector2Array = scout.agent.get_current_navigation_path()
	_check(path.size() > 2, "Scout path routes around approach rock")
	await _frames(340)
	_check(scout.ai.current_order == Order.HOLD and scout.position.distance_to(Vector2(-100, 220)) < 25, "MOVE_TO reaches destination and persists as HOLD")
	_check(warrior.position.distance_to(anchor) < 10, "Warrior's independent HOLD stays put")
	squad.select_slot(4)
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
	_check(squad.selected_members.is_empty(), "dead-unit number selection is safe")
	await _tap(KEY_4)
	_check(squad.selected_members.size() == 1 and warrior.selected, "surviving ally remains commandable")
	await _tap(KEY_TAB)
	player.health.die()
	await _frames(2)
	_check(not squad.command_mode and Engine.time_scale == 1.0, "player death immediately exits command slowdown")
	player.set_physics_process(true)
	await _tap(KEY_ENTER)
	await _frames(12)
	mission = current_scene as Node2D
	squad = mission.get_node("SquadManager")
	_check(Engine.time_scale == 1.0 and squad.members.size() == 2 and squad.members[0].health.current_health > 0, "Enter restart restores both allies at normal speed")
	squad.set_command_mode(true)
	mission.queue_free()
	await _frames(3)
	_check(Engine.time_scale == 1.0, "scene teardown during command mode restores speed")
	completed += 1


func _launch(source: PhysicsBody2D, point: Vector2) -> void:
	var weapon: WeaponController = source.get_node("WeaponController")
	var shot: CombatProjectile = PROJECTILE.instantiate()
	var direction: Vector2 = source.global_position.direction_to(point)
	shot.configure(weapon.weapon_data, direction, source)
	mission.add_child(shot)
	shot.global_position = source.global_position + direction * 28


func _mouse(point: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = squad.get_canvas_transform() * point
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	# Coordinates are already in the viewport, not the headless window's pixels.
	root.push_input(event, true)


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
