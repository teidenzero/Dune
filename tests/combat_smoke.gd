extends SceneTree

const PROJECTILE: PackedScene = preload("res://scenes/combat/projectile.tscn")
const DUMMY: PackedScene = preload("res://scenes/characters/test_dummy.tscn")

class AimedPlayer extends PlayerController:
	# Scripted aim through the _update_aim() hook, so fire_weapon() shots are
	# deterministic; the attack-order test below lets Paul aim for himself.
	var target: Vector2 = Vector2(-580, 40)

	func _update_aim() -> void:
		aim_direction = global_position.direction_to(target)
		aim_pivot.rotation = aim_direction.angle()

var failures: int = 0
var player: PlayerController
var weapon: WeaponController
var mission: Node2D
var counts: Dictionary = {"shots": 0, "dry": 0, "reloads": 0, "finished": 0, "deaths": 0}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_health()
	mission = load("res://scenes/missions/harvester_raid_test.tscn").instantiate()
	# Keep range regression deterministic while ai_smoke covers active enemies.
	mission.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	mission.get_node("ShieldRange").process_mode = Node.PROCESS_MODE_DISABLED
	mission.get_node("PrescienceRange").process_mode = Node.PROCESS_MODE_DISABLED
	mission.get_node("DesertRange").process_mode = Node.PROCESS_MODE_DISABLED
	mission.get_node("Player").set_script(AimedPlayer)
	# Squad has its own suite; preserve isolated earlier milestone fixtures.
	mission.get_node("Allies").free()
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	weapon = player.weapon_controller
	weapon.weapon_fired.connect(func(): counts.shots += 1)
	weapon.dry_fired.connect(func(): counts.dry += 1)
	weapon.reload_started.connect(func(): counts.reloads += 1)
	weapon.reload_finished.connect(func(): counts.finished += 1)
	var open_target: StaticBody2D = mission.get_node("TestTargets/OpenTarget")
	var health: HealthComponent = HealthComponent.find_on(open_target)
	health.died.connect(func(): counts.deaths += 1)
	await _frames(5)
	_check(weapon.current_ammo == 8 and weapon.can_fire, "pistol starts with eight rounds")
	_check(not weapon.start_reload(), "full magazine cannot reload")
	_check(HealthComponent.find_on(player).current_health == 100, "player reuses HealthComponent")
	var hud: PlayerHud = mission.get_node("UI/Screen/HUD") as PlayerHud
	await _aim_at(open_target.global_position)
	_check(player.fire_weapon(), "fire_weapon shoots along the current aim")
	await _frames(1)
	_check(counts.shots == 1 and weapon.current_ammo == 7, "one shot consumes one round")
	var shots: Array[Node] = get_nodes_in_group("projectiles")
	_check(shots.size() == 1, "visible projectile exists in flight")
	if not shots.is_empty():
		var shot: CombatProjectile = shots[0] as CombatProjectile
		_check(shot.global_position.distance_to(player.global_position) > 25, "projectile leaves muzzle away from owner")
		_check(shot.owner_actor == player and shot.visible, "projectile retains generic ownership and visuals")
	_check(not player.fire_weapon() and weapon.current_ammo == 7, "fire cooldown rejects rapid shots")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("combat_flight")
	await _frames(48)
	_check(counts.shots == 1, "an idle Paul without orders does not fire on his own")
	_check(health.current_health == 70, "traveling projectile deals thirty damage")
	for hit in range(3):
		await _aim_at(open_target.global_position)
		player.fire_weapon()
		await _frames(25)
	_check(health.current_health == 0 and health.is_dead and counts.deaths == 1, "dummy dies once on fourth hit")
	_check((IsoView.part(open_target, "Status") as Label).text.contains("DESTROYED"), "dummy has visible death state")
	_check(open_target.collision_layer == 0, "dead dummy no longer blocks shots")
	_check(weapon.current_ammo == 4, "four hits consume four rounds")
	await _frames(2)
	_check(hud.ammo_label.text == "4 / 8" and hud.status_label.text != "RELOADING", "HUD ammo readout follows the magazine")
	for shot_index in range(4):
		player.fire_weapon()
		if shot_index < 3:
			await _frames(25)
	_check(weapon.current_ammo == 0 and not weapon.can_fire, "magazine empties after eight shots")
	var fired_before: int = counts.shots
	_check(not player.fire_weapon() and counts.dry == 0, "empty weapon on cooldown refuses silently")
	weapon.cooldown_remaining = 0.0
	_check(not player.fire_weapon(), "empty weapon refuses to fire")
	_check(counts.shots == fired_before and counts.dry == 1, "empty trigger emits dry fire without spawning")
	await _frames(30)
	_check(not weapon.is_reloading and weapon.current_ammo == 0 and counts.reloads == 0, "an empty magazine waits for R: reloading is the player's call")
	_key(KEY_R, true)
	await _frames(1)
	_key(KEY_R, false)
	await _frames(1)
	_check(weapon.is_reloading and counts.reloads == 1, "R reloads the empty magazine")
	_check(not weapon.start_reload() and not weapon.try_fire(), "reload cannot restart or fire")
	_check(hud.status_label.visible and hud.status_label.text == "RELOADING", "HUD displays reload status")
	_check(hud.ammo_label.text == "0 / 8", "HUD ammo shows the empty magazine while reloading")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("combat_reload")
	await _frames(40)
	_check(weapon.is_reloading and weapon.current_ammo == 0, "reload does not refill early")
	await _frames(40)
	_check(not weapon.is_reloading and weapon.current_ammo == 8 and counts.finished == 1, "timed reload restores eight rounds")
	_check(hud.status_label.text != "RELOADING" and not hud.status_label.text.begins_with("EMPTY"), "HUD drops reload message on completion")
	_check(hud.ammo_label.text == "8 / 8", "HUD ammo follows weapon signals")
	_check(hud.weapon_name_label.text == weapon.weapon_data.weapon_name.to_upper(), "HUD names Paul's weapon")
	# R reloads a partial magazine for the selected Paul.
	_check(player.selected, "Paul is selected for keyboard orders")
	player.fire_weapon()
	await _frames(25)
	_key(KEY_R, true)
	await _frames(2)
	_key(KEY_R, false)
	_check(weapon.is_reloading and counts.reloads == 2, "R reloads the selected Paul's partial magazine")
	await _frames(3)
	_check(hud.status_label.text == "RELOADING" and hud.ammo_label.text == "7 / 8", "HUD shows the manual reload")
	await _frames(80)
	_check(weapon.current_ammo == 8 and hud.ammo_label.text == "8 / 8", "manual reload refills and HUD follows")

	var rock_target: StaticBody2D = mission.get_node("TestTargets/RockTarget")
	await _aim_at(rock_target.global_position)
	player.fire_weapon()
	await _frames(40)
	_check(HealthComponent.find_on(rock_target).current_health == 100, "rock blocks shot toward covered target")
	_check(get_nodes_in_group("projectiles").is_empty(), "rock destroys projectile")
	player.position = Vector2(-160, 360)
	await _aim_at(rock_target.global_position)
	player.fire_weapon()
	await _frames(12)
	_check(HealthComponent.find_on(rock_target).current_health == 70, "covered dummy is damageable from open angle")
	_check((IsoView.part(rock_target, "Visuals") as Node2D).modulate.r > 1.0, "impact gives visible flash")
	await _frames(15)
	await _test_projectile_safety()
	_key(KEY_F1, true)
	await _frames(2)
	_key(KEY_F1, false)
	var ui: CanvasLayer = mission.get_node("UI")
	_check(ui.metric_labels.has_all(["Current weapon", "Ammo", "Is reloading", "Fire cooldown", "Active projectiles"]), "F1 includes combat metrics")
	_check(HealthComponent.find_on(player).current_health == 100, "player remains undamaged by own shots")
	await _test_attack_order()
	if "--capture" in OS.get_cmdline_user_args():
		player.position = Vector2(-600, 280)
		await _aim_at(Vector2(-580, 40))
		await _frames(90)
		await _capture("combat_debug")
	print("COMBAT SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _test_health() -> void:
	var health: HealthComponent = HealthComponent.new()
	root.add_child(health)
	var events: Dictionary = {"death": 0, "damage": 0.0, "changes": 0}
	health.died.connect(func(): events.death += 1)
	health.damaged.connect(func(amount: float): events.damage += amount)
	health.health_changed.connect(func(_current: float, _maximum: float): events.changes += 1)
	health.take_damage(-5)
	health.heal(-5)
	_check(health.current_health == 100 and events.changes == 0, "health ignores negative damage/healing")
	health.take_damage(30)
	health.heal(500)
	_check(health.current_health == 100, "healing clamps to maximum")
	health.take_damage(500)
	health.take_damage(30)
	health.heal(30)
	health.die()
	_check(health.current_health == 0 and health.is_dead and events.death == 1, "death clamps health, ignores further damage/heal, emits once")
	_check(events.damage == 130, "damaged signal reports applied damage")
	health.reset_health()
	_check(health.current_health == 100 and not health.is_dead, "reset restores live full health")
	health.die()
	_check(events.death == 2 and health.current_health == 0, "explicit die works after reset")
	health.queue_free()


func _test_projectile_safety() -> void:
	player.position = Vector2(-1200, -700)
	await _frames(3)
	var shot: CombatProjectile = _spawn_shot(player.global_position, Vector2.RIGHT, 900, 0.1)
	await _frames(2)
	_check(is_instance_valid(shot), "projectile inside owner ignores owner collider")
	await _frames(8)
	_check(not is_instance_valid(shot), "projectile expires after lifetime")
	var wall: StaticBody2D = StaticBody2D.new()
	wall.position = Vector2(0, 950)
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(2, 100)
	collider.shape = shape
	wall.add_child(collider)
	mission.add_child(wall)
	var behind: StaticBody2D = DUMMY.instantiate()
	behind.position = Vector2(100, 950)
	mission.add_child(behind)
	player.position = Vector2(-200, 950)
	await _frames(3)
	shot = _spawn_shot(player.position + Vector2(28, 0), Vector2.RIGHT, 30000, 1.5)
	await _frames(3)
	_check(not is_instance_valid(shot) and HealthComponent.find_on(behind).current_health == 100, "swept projectile cannot tunnel through thin wall at high speed")
	player.position = Vector2(-20, 950)
	await _frames(2)
	shot = _spawn_shot(Vector2(8, 950), Vector2.RIGHT, 900, 1.5)
	await _frames(4)
	_check(not is_instance_valid(shot) and HealthComponent.find_on(behind).current_health == 100, "muzzle across wall cannot bypass cover")
	# Existing solid machinery and arena boundary must also absorb projectiles.
	player.position = Vector2(370, 20)
	await _frames(2)
	shot = _spawn_shot(player.position + Vector2(0, -28), Vector2.UP, 900, 1.5)
	await _frames(20)
	_check(not is_instance_valid(shot), "harvester absorbs projectiles")
	player.position = Vector2(-1500, -700)
	await _frames(2)
	shot = _spawn_shot(player.position + Vector2(-28, 0), Vector2.LEFT, 900, 1.5)
	await _frames(10)
	_check(not is_instance_valid(shot), "arena boundary absorbs projectiles")
	wall.queue_free()
	behind.queue_free()


## Right-click on a target out of range: Paul closes in until it is inside
## effective range with line of sight, fires until it dies, then stands down.
func _test_attack_order() -> void:
	var squad: SquadManager = mission.get_node("SquadManager") as SquadManager
	var camera: TacticalCamera = player.get_node("TacticalCamera") as TacticalCamera
	var dummy: StaticBody2D = DUMMY.instantiate()
	dummy.position = Vector2(-750, 800)
	dummy.add_to_group("training_targets")
	mission.add_child(dummy)
	var dummy_health: HealthComponent = HealthComponent.find_on(dummy)
	var fired_from: Array[float] = []
	var record: Callable = func() -> void: fired_from.append(player.global_position.distance_to(dummy.global_position))
	weapon.weapon_fired.connect(record)
	player.teleport_to(Vector2(-1350, 800))
	await _frames(3)
	if weapon.current_ammo < 8:
		weapon.start_reload()
		await _frames(90)
	var range_limit: float = weapon.weapon_data.effective_range
	var start_distance: float = player.global_position.distance_to(dummy.global_position)
	_check(start_distance > range_limit + 50.0, "attack target starts well out of range")
	squad.select_slot(1)
	camera.snap_to(dummy.global_position)
	await _frames(3)
	# Paul selected with his blade: the pointer offers both, knife on the left and fire on the right.
	_check(squad.context_kind(dummy.global_position) == ("LEFT: KNIFE · RIGHT: FIRE" if player.melee.enabled else "ATTACK"), "cursor over a hostile offers the attack")
	await _right_click(dummy.global_position)
	await _frames(2)
	_check(player.order == PlayerController.Order.ATTACK and player.order_target == dummy, "right-click on a hostile orders Paul to attack it")
	_check(player.velocity.x > 0.0 and fired_from.is_empty(), "out of range, Paul closes in instead of firing")
	# One click, one shot: after each round Paul holds fire until clicked again.
	var died_at: int = -1
	var clicks: int = 1
	var held_fire: bool = false
	for index in range(900):
		await _frames(1)
		if dummy_health.is_dead:
			died_at = index
			break
		if player.order == PlayerController.Order.IDLE and weapon.can_fire and clicks < 8:
			held_fire = held_fire or fired_from.size() == clicks
			await _right_click(dummy.global_position)
			clicks += 1
	_check(held_fire, "after a click's one shot, Paul holds fire")
	_check(died_at >= 0, "clicking again and again kills the target")
	_check(not fired_from.is_empty() and fired_from[0] <= range_limit + 1.0, "first shot is fired from inside effective range")
	_check(player.global_position.distance_to(dummy.global_position) < start_distance - 50.0, "Paul moved toward the target to engage")
	await _frames(3)
	_check(player.order == PlayerController.Order.IDLE, "attack order ends when the target dies")
	var shots_at_death: int = fired_from.size()
	_check(shots_at_death == clicks, "one round per click (%d clicks, %d shots)" % [clicks, shots_at_death])
	var resting: Vector2 = player.global_position
	await _frames(60)
	_check(fired_from.size() == shots_at_death, "Paul stops firing at the dead target")
	_check(player.global_position.distance_to(resting) < 2.0 and player.velocity.is_zero_approx(), "and stops moving")
	weapon.weapon_fired.disconnect(record)
	dummy.queue_free()


func _spawn_shot(at: Vector2, direction: Vector2, speed: float, lifetime: float) -> CombatProjectile:
	var data: WeaponData = weapon.weapon_data.duplicate() as WeaponData
	data.projectile_speed = speed
	data.projectile_lifetime = lifetime
	var shot: CombatProjectile = PROJECTILE.instantiate()
	shot.configure(data, direction, player)
	mission.add_child(shot)
	shot.global_position = at
	return shot


func _aim_at(world_position: Vector2) -> void:
	(player as AimedPlayer).target = world_position
	await _frames(2)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


## Window coordinates for a world point (the 1920 x 1080 canvas is stretched
## into the window).
func _screen(world: Vector2) -> Vector2:
	var viewport: Viewport = mission.get_viewport()
	return viewport.get_screen_transform() * (viewport.get_canvas_transform() * world)


func _mouse(button: MouseButton, world: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = _screen(world)
	event.global_position = event.position
	Input.parse_input_event(event)


func _right_click(world: Vector2) -> void:
	_mouse(MOUSE_BUTTON_RIGHT, world, true)
	_mouse(MOUSE_BUTTON_RIGHT, world, false)
	await _frames(1)


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.validation/" + filename + ".png")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

