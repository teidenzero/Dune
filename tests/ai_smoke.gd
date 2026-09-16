extends SceneTree
## Run with --headless --fixed-fps 60 for deterministic fast physics validation.

const PROJECTILE: PackedScene = preload("res://scenes/combat/projectile.tscn")
const State = EnemyAIController.State

var failures: int = 0
var mission: Node2D
var player: PlayerController
var guard: EnemyCharacter
var transitions: Array[int] = []
var completed_scenarios: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _patrol_and_navigation()
	await _vision_and_combat()
	await _hearing_and_return()
	await _death_and_restart()
	_check(completed_scenarios == 4, "all AI scenarios completed without an interrupted test")
	print("AI SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load_mission(selected: String = "") -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	get_root().get_node("GameManager").debug_visible = false
	mission = load("res://scenes/missions/harvester_raid_test.tscn").instantiate()
	for enemy in mission.get_node("Enemies").get_children():
		if selected != "" and enemy.name != selected:
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
	# Squad has its own suite; preserve isolated earlier milestone fixtures.
	mission.get_node("Allies").free()
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector2(-1450, 950)
	if selected != "":
		guard = mission.get_node("Enemies/" + selected)
		transitions.clear()
		guard.ai.state_changed.connect(func(_old: int, next: int): transitions.append(next))
	await _frames(10)


func _patrol_and_navigation() -> void:
	await _load_mission()
	var region: NavigationRegion2D = mission.get_node("NavigationRegion2D")
	_check(region.navigation_polygon != null and region.navigation_polygon.get_polygon_count() > 0, "arena bakes a valid navigation mesh")
	var guards: Array[Node] = mission.get_node("Enemies").get_children()
	var indices: Dictionary = {}
	var origins: Dictionary = {}
	var moving: Dictionary = {}
	var waiting: Dictionary = {}
	for enemy: EnemyCharacter in guards:
		indices[enemy.name] = {}
		origins[enemy.name] = enemy.position
		moving[enemy.name] = false
		waiting[enemy.name] = false
	for sample in range(160):
		await _frames(15)
		for enemy: EnemyCharacter in guards:
			indices[enemy.name][enemy.ai.patrol_index] = true
			if enemy.position.distance_to(origins[enemy.name]) > 100:
				moving[enemy.name] = true
			if moving[enemy.name] and enemy.velocity.length() < 1.0:
				waiting[enemy.name] = true
	for enemy: EnemyCharacter in guards:
		_check(enemy.ai.state == State.PATROL and moving[enemy.name], "%s patrols without detecting remote Paul" % enemy.name)
		_check(indices[enemy.name].size() == enemy.patrol_route.get_points().size(), "%s visits every route waypoint" % enemy.name)
		_check(waiting[enemy.name], "%s waits at waypoints" % enemy.name)
	var map: RID = region.get_navigation_map()
	var path: PackedVector2Array = NavigationServer2D.map_get_path(map, Vector2(-700, -310), Vector2(-210, -310), true)
	_check(path.size() > 2, "route across rock is redirected around its collider")
	for index in range(1, path.size()):
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(path[index - 1], path[index], 1)
		_check(mission.get_world_2d().direct_space_state.intersect_ray(query).is_empty(), "navigation path segment clears solid geometry")
	completed_scenarios += 1


func _vision_and_combat() -> void:
	await _load_mission("Guard_D")
	guard.set_physics_process(false)
	guard.ai.set_physics_process(false)
	guard.position = Vector2(-140, 220)
	guard.face_position(Vector2(-600, 220))
	player.position = Vector2(-600, 220)
	await _frames(12)
	_check(not guard.perception.can_see_target, "rock occludes Paul inside range and FOV")
	player.position = Vector2(-140, 420)
	guard.face_position(Vector2(-140, 20))
	await _frames(12)
	_check(not guard.perception.can_see_target, "Paul behind guard is outside FOV")
	player.position = Vector2(-140, -500)
	await _frames(12)
	_check(not guard.perception.can_see_target, "vision rejects targets beyond range")
	player.position = Vector2(-140, 470)
	guard.face_position(player.position)
	await _frames(12)
	_check(guard.perception.can_see_target, "clear in-cone target is visible")
	guard.ai.set_physics_process(true)
	guard.set_physics_process(true)
	await _frames(30)
	_check(guard.ai.state != State.COMBAT, "brief visibility no longer confirms combat immediately")
	await _frames(180)
	_check(guard.ai.state == State.COMBAT, "vision confirmation enters COMBAT")
	_check(guard.weapon.current_ammo < 12, "guard fires shared Harkonnen Rifle")
	await _frames(40)
	_check(player.health.current_health < 100, "enemy projectile damages Paul")
	_check(guard.health.current_health == 60, "guard projectile ignores its owner")
	# Give this stationary test target enough HP to observe a complete magazine.
	player.health.max_health = 1000
	player.health.reset_health()
	var reloaded: Array[bool] = [false]
	guard.weapon.reload_finished.connect(func(): reloaded[0] = true)
	await _frames(520)
	_check(reloaded[0], "guard automatically reloads an empty magazine")
	var last_seen: Vector2 = guard.ai.last_known_target_position
	player.position = Vector2(-600, 220)
	await _frames(15)
	_check(not guard.perception.can_see_target and guard.ai.state == State.COMBAT, "lost sight retains COMBAT during grace period")
	_check(guard.ai.last_known_target_position.distance_to(last_seen) < 1.0, "hidden Paul does not update last-known position")
	player.position = Vector2(-1450, 950)
	await _frames(100)
	_check(guard.ai.state == State.SEARCH, "lost sight transitions to SEARCH after grace")
	_check(guard.has_destination or guard.velocity.length() < 1.0, "search navigates or pauses to look around")
	await _frames(450)
	_check(transitions.has(State.RETURN), "unsuccessful search enters RETURN")
	await _frames(350)
	_check(guard.ai.state == State.PATROL, "guard navigates back and resumes PATROL")
	completed_scenarios += 1


func _hearing_and_return() -> void:
	await _load_mission("Guard_D")
	var other: EnemyCharacter = mission.get_node("Enemies/Guard_A")
	other.process_mode = Node.PROCESS_MODE_INHERIT
	player.position = Vector2(-600, 280)
	await _frames(2)
	var bus: DisturbanceBus = mission.get_node("Disturbances")
	bus.emit_noise(Vector2(1400, 900), 100, player)
	await _frames(5)
	_check(guard.ai.state == State.PATROL, "out-of-radius noise is ignored")
	bus.emit_noise(guard.position, 650, guard, DisturbanceBus.Type.GUNSHOT)
	await _frames(2)
	_check(guard.ai.state == State.PATROL, "guard ignores its own disturbance")
	_check(player.weapon_controller.try_fire(), "player can fire to generate hearing event")
	_check(guard.ai.state == State.SUSPICIOUS, "hidden player's gunshot enters SUSPICIOUS")
	_check(guard.ai.suspicious_position.distance_to(player.position) < 1, "hearing records source position")
	player.position = Vector2(-1450, 950)
	await _frames(60)
	_check(guard.ai.state == State.INVESTIGATE, "brief suspicion leads to INVESTIGATE")
	await _frames(900)
	_check(transitions.has(State.SEARCH) and transitions.has(State.RETURN), "investigation reaches SEARCH then RETURN")
	await _frames(450)
	_check(guard.ai.state == State.PATROL, "hearing investigation eventually resumes patrol")
	_check(other.ai.state == State.PATROL, "hearing does not globally alert other guards")
	# Debug mode changes visibility without changing AI decisions.
	_key(KEY_F1, true)
	await _frames(3)
	_key(KEY_F1, false)
	_check(guard.get_node("DebugVisuals").visible, "F1 reveals guard diagnostics")
	_check(guard.get_node("DebugVisuals/Details").text.contains("PATROL"), "debug label exposes state")
	if "--capture" in OS.get_cmdline_user_args():
		player.position = guard.position + Vector2(230, 160)
		guard.face_position(player.position)
		await _frames(50)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.validation/ai_debug.png")
	_key(KEY_F1, true)
	await _frames(3)
	_key(KEY_F1, false)
	_check(not guard.get_node("DebugVisuals").visible, "AI debug drawing hidden in normal play")
	completed_scenarios += 1


func _death_and_restart() -> void:
	await _load_mission("Guard_A")
	guard.position = Vector2(250, 430)
	guard.set_physics_process(false)
	guard.ai.set_physics_process(false)
	guard.perception.stop()
	var teammate: EnemyCharacter = mission.get_node("Enemies/Guard_C")
	teammate.position = Vector2(250, 600)
	var friendly_shot: CombatProjectile = PROJECTILE.instantiate()
	friendly_shot.configure(teammate.weapon.weapon_data, Vector2.UP, teammate)
	mission.add_child(friendly_shot)
	friendly_shot.global_position = teammate.position + Vector2(0, -29)
	await _frames(20)
	_check(guard.health.current_health == 60 and not is_instance_valid(friendly_shot), "same-team body absorbs shot without friendly damage")
	player.position = Vector2(250, 650)
	await _frames(3)
	for hit in range(2):
		var shot: CombatProjectile = PROJECTILE.instantiate()
		shot.configure(player.weapon_controller.weapon_data, Vector2.UP, player)
		mission.add_child(shot)
		shot.global_position = player.position + Vector2(0, -28)
		await _frames(18)
	_check(guard.health.is_dead and guard.ai.state == State.DEAD, "two pistol projectiles kill 60-HP guard")
	_check(not guard.weapon.can_fire and not guard.weapon.enabled, "dead guard cannot fire or reload")
	_check(not guard.perception.is_physics_processing() and not guard.has_destination, "death stops perception and navigation")
	_check(guard.collision_layer == 0 and guard.velocity == Vector2.ZERO, "dead guard stops moving and blocking")
	# A fresh enemy projectile at close range completes Paul's down/restart flow.
	var shooter: EnemyCharacter = mission.get_node("Enemies/Guard_C")
	shooter.position = Vector2(250, 800)
	player.health.take_damage(90)
	var lethal: CombatProjectile = PROJECTILE.instantiate()
	lethal.configure(shooter.weapon.weapon_data, Vector2.UP, shooter)
	mission.add_child(lethal)
	lethal.global_position = shooter.position + Vector2(0, -29)
	await _frames(15)
	_check(player.health.is_dead, "rifle projectile can down Paul")
	player.set_physics_process(true)
	var down_position: Vector2 = player.position
	Input.action_press("move_right")
	Input.action_press("fire_primary")
	await _frames(10)
	Input.action_release("move_right")
	Input.action_release("fire_primary")
	_check(player.position == down_position and not player.weapon_controller.can_fire, "downed player cannot move or shoot")
	_check(mission.get_node("UI/Screen/CombatHUD/Margin/Rows/Down").visible, "PLAYER DOWN is displayed")
	_key(KEY_ENTER, true)
	await _frames(15)
	_key(KEY_ENTER, false)
	mission = current_scene as Node2D
	var restored: PlayerController = mission.get_node("Player")
	_check(restored.health.current_health == 100 and restored.weapon_controller.current_ammo == 8, "Enter reloads mission with full health and ammo")
	_check(mission.get_node("Enemies").get_children().size() == 4, "restart recreates four guards without duplicates")
	completed_scenarios += 1


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


