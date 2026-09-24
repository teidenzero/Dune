extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/solo_smoke.gd
##
## The Solo scope's mechanics - one hero on direct control (WASD, mouse aim,
## fire, crysknife, dodge, Holtzman shield), explosive fuel tanks, the Elite
## answering a shield with the slow blade, and a SOLO outcome - exercised on
## the Harvester Raid map through SoloScope.enter(). The isometric interior
## has its own suite, interior_smoke.gd.

const RAID: String = "res://scenes/missions/harvester_raid/harvester_raid.tscn"

class AimedPlayer extends PlayerController:
	var aim_point: Vector2 = Vector2.INF

	func _update_aim() -> void:
		if aim_point.is_finite():
			aim_direction = global_position.direction_to(aim_point)

var failures: int = 0
var completed: int = 0
var mission: Node
var player: PlayerController
var worm: WormThreatManager


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _setup()
	await _movement_and_camera()
	await _fire_and_blade()
	await _dodge()
	await _shield()
	await _elite_answers_the_shield()
	await _fuel_tanks()
	await _pause_and_outcome()
	_check(completed == 8, "all solo scenarios completed")
	print("SOLO SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load() -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	var game: Node = root.get_node("GameManager")
	game.mission_checkpoint = &""
	mission = (load(RAID) as PackedScene).instantiate()
	mission.get_node("Player").set_script(AimedPlayer)
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	worm = mission.get_node("WormThreat")
	await _frames(20)
	SoloScope.enter(self, player, mission.get_node("SquadManager"))
	mission.get_node("RaidController").scope = MissionOutcome.Scope.SOLO
	await _frames(3)


## Keep the patrols out of scenarios that are not about them.
func _quiet_enemies(except: Node = null) -> void:
	for enemy: Node in mission.get_node("Enemies").get_children():
		if enemy == except:
			continue
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		(enemy as CollisionObject2D).collision_layer = 0


func _setup() -> void:
	await _load()
	var mission_manager: MissionManager = mission.get_node("Mission")
	_check(get_nodes_in_group("allies").is_empty(), "the solo scope sends one hero: no Fremen")
	_check(player.control_mode == PlayerController.ControlMode.DIRECT, "Paul is on direct control")
	_check(player.health.max_health == 150.0 and player.health.current_health == 150.0, "a lone hero is tougher")
	_check(player.get_node("TacticalCamera").follow, "the camera follows the hero")
	_check(mission.get_node("SquadManager").solo_mode, "the squad controls stand down")
	var hud: PlayerHud = mission.get_node("UI/Screen/HUD")
	_check(hud.solo and hud.hints_label.text.contains("SPACE dodge"), "the HUD shows the direct controls")
	_check(player.shield != null and not player.shield.enabled, "the hero carries a Holtzman shield, lowered")
	completed += 1


func _movement_and_camera() -> void:
	await _load()
	_quiet_enemies()
	player.teleport_to(Vector2(-200, 900))
	await _frames(3)
	var start: Vector2 = player.global_position
	Input.action_press("move_right")
	await _frames(40)
	_check(player.global_position.x > start.x + 80.0, "WASD moves the hero")
	_check(absf(player.velocity.length() - player.walk_speed) < 2.0, "at walking speed")
	Input.action_press("sprint")
	await _frames(30)
	_check(player.is_sprinting and absf(player.velocity.length() - player.sprint_speed) < 2.0, "Shift runs")
	Input.action_release("sprint")
	Input.action_release("move_right")
	await _frames(30)
	var camera: TacticalCamera = player.get_node("TacticalCamera")
	_check(camera.anchor.distance_to(player.global_position) < camera.look_ahead / camera.effective_zoom() + 20.0, "the camera stays with him")
	_key(KEY_C)
	await _frames(3)
	_check(player.is_crouching, "C crouches")
	_key(KEY_C)
	await _frames(3)
	player.aim_point = player.global_position + Vector2(0, -300)
	await _frames(2)
	_check(player.aim_direction.y < -0.99, "he aims where the mouse points")
	completed += 1


func _fire_and_blade() -> void:
	await _load()
	_quiet_enemies()
	player.teleport_to(Vector2(-200, 900))
	player.aim_point = player.global_position + Vector2(400, 0)
	await _frames(3)
	var ammo: int = player.weapon_controller.current_ammo
	Input.action_press("fire_primary")
	await _frames(2)
	Input.action_release("fire_primary")
	await _frames(2)
	_check(player.weapon_controller.current_ammo == ammo - 1, "left-click fires one round")
	Input.action_press("melee_attack")
	await _frames(2)
	_check(player.melee.state == MeleeController.State.CHARGING, "E raises the blade while held")
	Input.action_release("melee_attack")
	await _frames(2)
	_check(player.melee.current_attack == player.melee.fast_attack, "a tap is the quick strike")
	await _frames(60)
	Input.action_press("melee_attack")
	await _frames(30)
	_check(player.melee.slow_ready, "held, the slow stroke readies")
	Input.action_release("melee_attack")
	await _frames(2)
	_check(player.melee.current_attack == player.melee.slow_attack, "released, it is the slow strike")
	await _frames(100)
	completed += 1


func _dodge() -> void:
	await _load()
	_quiet_enemies()
	player.teleport_to(Vector2(-200, 900))
	await _frames(3)
	Input.action_press("move_right")
	await _frames(10)
	Input.action_press("dodge")
	await _frames(2)
	Input.action_release("dodge")
	_check(player.dodging and player.velocity.length() > player.sprint_speed * 1.5, "Space dodges, fast")
	var hit: HitContext = HitContext.ranged(20.0, 800.0, null, &"harkonnen", "Rifle", player.global_position, Vector2.RIGHT)
	_check(DamageResolver.resolve(player, hit) == DamageResolver.Outcome.MISSED, "a round arriving mid-dodge misses")
	await _frames(30)
	Input.action_release("move_right")
	_check(not player.dodging, "the dodge is short")
	_check(not player.try_dodge(Vector2.RIGHT), "and has a cooldown")
	_check(DamageResolver.resolve(player, hit) == DamageResolver.Outcome.DAMAGED, "out of the dodge he can be hit")
	await _frames(60)
	_check(player.try_dodge(Vector2.LEFT), "the dodge comes back")
	await _frames(20)
	completed += 1


func _shield() -> void:
	await _load()
	_quiet_enemies()
	# Open sand, well away from the crawler's own vibration.
	player.teleport_to(Vector2(-200, 900))
	await _frames(5)
	_key(KEY_T)
	await _frames(3)
	_check(player.shield_active(), "T raises the shield")
	var bullet: HitContext = HitContext.ranged(20.0, 800.0, null, &"harkonnen", "Rifle", player.global_position, Vector2.RIGHT)
	_check(DamageResolver.resolve(player, bullet) == DamageResolver.Outcome.BLOCKED, "the shield stops a bullet")
	var slow: HitContext = HitContext.melee(load("res://resources/weapons/harkonnen_blade_slow.tres"), null, player.global_position, Vector2.RIGHT)
	slow.source_team = &"harkonnen"
	_check(DamageResolver.resolve(player, slow) == DamageResolver.Outcome.DAMAGED, "but not a slow blade")
	worm.reset_threat()
	await _frames(120)
	var shielded: float = worm.worm_sign
	_check(shielded > 15.0, "a shield on open sand calls the worm (%.1f sign in 2 s)" % shielded)
	_key(KEY_T)
	await _frames(3)
	worm.reset_threat()
	await _frames(120)
	_check(worm.worm_sign < shielded * 0.3, "lowered, the sand goes quiet again")
	completed += 1


## The Elite knows shields: against a raised one he uses the slow blade.
func _elite_answers_the_shield() -> void:
	await _load()
	var elite: EnemyCharacter = mission.get_node("Enemies/Elite_Intake")
	_quiet_enemies(elite)
	player.teleport_to(elite.global_position + Vector2(-220, 60))
	player.set_shield(true)
	await _frames(3)
	var strokes: Array[MeleeAttackData] = []
	elite.ai.melee.attack_started.connect(func(data: MeleeAttackData) -> void: strokes.append(data))
	elite.face_position(player.global_position)
	elite.ai.target = player
	elite.ai.last_known_target_position = player.global_position
	elite.ai.has_last_known_position = true
	elite.ai.change_state(EnemyAIController.State.COMBAT)
	var hurt: bool = false
	for index in range(600):
		await _frames(1)
		if player.health.current_health < player.health.max_health:
			hurt = true
			break
	_check(not strokes.is_empty() and strokes[0] == elite.ai.melee.slow_attack, "he answers a shield with the slow stroke")
	_check(hurt, "and it gets through")
	completed += 1


func _fuel_tanks() -> void:
	await _load()
	var guard: EnemyCharacter = mission.get_node("Enemies/Guard_PerimNorth")
	_quiet_enemies(guard)
	var tank: FuelTank = mission.get_node("FuelTanks/Tank_Engine")
	guard.global_position = tank.global_position + Vector2(90, 0)
	guard.ai.set_physics_process(false)
	player.teleport_to(tank.global_position + Vector2(-60, 230))
	player.aim_point = tank.global_position
	await _frames(5)
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(player.global_position, tank.global_position, 1, [player.get_rid()])
	_check(player.global_position.distance_to(tank.global_position) > tank.blast_radius and root.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "the hero has a clear shot from outside the blast")
	worm.reset_threat()
	var guard_before: float = guard.health.current_health
	for shot in range(3):
		player.weapon_controller.cooldown_remaining = 0.0
		player.fire_weapon()
		await _frames(40)
		if tank.detonated:
			break
	_check(tank.detonated, "shooting the fuel tank sets it off")
	await _frames(4)
	_check(guard.health.current_health < guard_before, "the blast hurts the guard beside it")
	_check(worm.worm_sign > 10.0, "and the sand feels it")
	_check(player.health.current_health == player.health.max_health, "a hero at range is untouched")
	# A chain: one tank sets off another.
	var a: FuelTank = mission.get_node("FuelTanks/Tank_Deck")
	var b: FuelTank = mission.get_node("FuelTanks/Tank_South")
	b.global_position = a.global_position + Vector2(100, 0)
	a.health.take_damage(100.0)
	await _frames(30)
	_check(a.detonated and b.detonated, "tanks go up in a chain")
	completed += 1


func _pause_and_outcome() -> void:
	await _load()
	_quiet_enemies()
	var squad: SquadManager = mission.get_node("SquadManager")
	_key(KEY_P)
	await _frames(2)
	_check(squad.paused and paused, "P pauses the solo game")
	_key(KEY_P)
	await _frames(2)
	_check(not paused, "and resumes it")
	var mission_manager: MissionManager = mission.get_node("Mission")
	player.health.die()
	await _frames(5)
	var record: MissionOutcome = mission_manager.outcome_record
	_check(record != null and record.scopes == [MissionOutcome.Scope.SOLO], "the outcome is recorded in the solo scope")
	_check(record.heroes_wounded.has("Paul"), "with the hero wounded, not dead")
	root.get_node("GameManager").mission_checkpoint = &""
	completed += 1


func _key(code: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	var up: InputEventKey = InputEventKey.new()
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)


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
