extends SceneTree
## Milestone 6: crysknife melee and Holtzman personal shields.
## Runs against the real mission, player scene, hitbox physics, and input map.

const State = MeleeController.State
const Link = CommandLinkComponent.State
const FAST: MeleeAttackData = preload("res://resources/weapons/crysknife_fast.tres")
const SLOW: MeleeAttackData = preload("res://resources/weapons/crysknife_slow.tres")
const PROJECTILE: PackedScene = preload("res://scenes/combat/projectile.tscn")

class AimedPlayer extends PlayerController:
	# Synthetic mouse events do not move the OS cursor, so melee direction is
	# driven by an explicit world point. Every other player path is production
	# code; foundation_smoke covers the real mouse-aim path.
	var aim_point: Vector2 = Vector2.RIGHT

	func _update_aim() -> void:
		aim_direction = global_position.direction_to(aim_point)
		aim_pivot.rotation = aim_direction.angle()

var failures: int = 0
var completed: int = 0
var mission: Node2D
var player: PlayerController
var melee: MeleeController
var scout: AllyCharacter
var warrior: AllyCharacter
var squad: SquadManager
var guard: EnemyCharacter
var elite: EnemyCharacter


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _attack_shapes_and_timing()
	await _melee_on_unshielded()
	await _projectiles_versus_shield()
	await _melee_versus_shield()
	await _aim_and_faction_safety()
	await _elite_death_and_ally_fire()
	await _command_mode_and_hud()
	_check(completed == 7, "all melee scenarios completed")
	_check(Engine.time_scale == 1.0, "suite leaves normal game speed")
	print("MELEE SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load(live_range: bool = true) -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	root.get_node("GameManager").debug_visible = false
	mission = load("res://scenes/missions/harvester_raid_test.tscn").instantiate()
	# Patrolling guards stay out of the way; the shield range is the fixture.
	for enemy in mission.get_node("Enemies").get_children():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.collision_layer = 0
	for subject in mission.get_node("PrescienceRange").get_children():
		subject.process_mode = Node.PROCESS_MODE_DISABLED
		if subject is CharacterBody2D:
			subject.collision_layer = 0
	mission.get_node("DesertRange").process_mode = Node.PROCESS_MODE_DISABLED
	mission.get_node("Player").set_script(AimedPlayer)
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	melee = player.melee
	scout = mission.get_node("Allies/Scout")
	warrior = mission.get_node("Allies/Warrior")
	squad = mission.get_node("SquadManager")
	guard = mission.get_node("ShieldRange/TrainingGuard")
	elite = mission.get_node("ShieldRange/TrainingElite")
	if not live_range:
		for trainer in [guard, elite]:
			trainer.ai.set_physics_process(false)
			trainer.set_physics_process(false)
			trainer.perception.stop()
	# Companions would autonomously engage the range and pollute every count.
	for ally: AllyCharacter in [scout, warrior]:
		ally.ai.set_physics_process(false)
		ally.set_physics_process(false)
		ally.weapon.disable()
		ally.global_position = Vector2(-1450, -950)
	await _frames(15)


## Freezes a subject in place in front of Paul without disabling its damage path.
func _stage(subject: Node2D, offset: Vector2) -> void:
	subject.global_position = player.global_position + offset
	if subject is EnemyCharacter:
		subject.ai.set_physics_process(false)
		subject.set_physics_process(false)
		subject.perception.stop()
		subject.weapon.disable()
	_aim_at(subject.global_position)
	await _frames(2)


## Presses the melee key for `hold` seconds of physics time, then releases.
func _swing(hold: float) -> void:
	_key(KEY_E, true)
	await _frames(maxi(int(hold * 60.0), 1))
	_key(KEY_E, false)
	await _frames(2)


## Waits out wind-up, active window, and recovery.
func _settle() -> void:
	for index in range(200):
		if melee.state == MeleeController.State.IDLE:
			return
		await _frames(1)


func _attack_shapes_and_timing() -> void:
	await _load(false)
	_check(InputMap.has_action("melee_attack"), "melee_attack action is configured")
	_check(melee != null and melee.state == State.IDLE and melee.can_attack(), "Paul starts with an idle crysknife")
	_check(melee.fast_attack == FAST and melee.slow_attack == SLOW, "both crysknife attacks are configured resources")
	_check(FAST.attack_velocity > SLOW.attack_velocity, "the fast attack is the faster blade")
	_check(SLOW.damage > FAST.damage and SLOW.windup_time > FAST.windup_time * 4.0, "the slow attack trades wind-up for damage")
	_check(not melee.hitbox.monitoring, "the hitbox is inactive while idle")
	# A tap resolves as the fast attack.
	_key(KEY_E, true)
	await _frames(3)
	_check(melee.state == State.CHARGING and not melee.slow_ready, "pressing melee begins a charge")
	_check(melee.hitbox.monitoring, "the hitbox arms during the charge")
	_key(KEY_E, false)
	await _frames(2)
	_check(melee.current_attack == FAST, "a short tap swings the fast attack")
	await _frames(40)
	_check(melee.state == State.IDLE, "the fast attack recovers quickly")
	# Holding past the threshold arms the slow strike instead.
	_key(KEY_E, true)
	await _frames(12)
	_check(melee.state == State.CHARGING and not melee.slow_ready, "below the threshold the slow strike is not ready")
	await _frames(20)
	_check(melee.slow_ready and melee.charge_ratio() == 1.0, "holding past the threshold arms the penetrating strike")
	_check(melee.get_move_speed_multiplier() <= 0.5, "a charged slow strike substantially restricts movement")
	_key(KEY_E, false)
	await _frames(2)
	_check(melee.current_attack == SLOW and melee.state == State.WINDUP, "releasing a charged hold swings the slow attack")
	await _frames(30)
	_check(melee.state == State.WINDUP, "the slow wind-up is still running half a second later")
	await _frames(40)
	_check(melee.state != State.IDLE, "the slow attack is still committed after the fast attack would have finished")
	await _frames(100)
	_check(melee.state == State.IDLE, "the slow attack eventually recovers")
	completed += 1


func _melee_on_unshielded() -> void:
	await _load(false)
	player.global_position = Vector2(-700, 700)
	await _stage(guard, Vector2(46, 0))
	_check(guard.shield == null, "the ordinary guard has no personal shield")
	# Deep health pool so both swings can be compared without a death in between.
	guard.health.max_health = 300.0
	guard.health.reset_health()
	# Scenario A: fast melee damages an unshielded guard.
	var before: float = guard.health.current_health
	await _swing(0.05)
	await _settle()
	_check(guard.health.current_health == before - FAST.damage, "fast melee damages an ordinary guard")
	_check(melee.last_result == "DAMAGED" and melee.last_target == "TrainingGuard", "the controller reports the landed hit")
	# One swing may not hit the same target twice.
	var after_first: float = guard.health.current_health
	await _frames(40)
	_check(guard.health.current_health == after_first, "a single swing cannot hit the same target twice")
	# Scenario B: slow melee deals more damage to the same guard.
	await _swing(0.5)
	await _settle()
	_check(guard.health.current_health == after_first - SLOW.damage, "slow melee damages an ordinary guard harder")
	_check(SLOW.damage > FAST.damage, "the slow strike is the stronger option even without shields")
	# Out of reach stays out of reach.
	await _stage(guard, Vector2(0, 180))
	var untouched: float = guard.health.current_health
	await _swing(0.05)
	await _settle()
	_check(guard.health.current_health == untouched, "melee has a finite reach")
	# Scenario A continued: repeated attacks kill an ordinary 60 HP guard.
	await _load(false)
	player.global_position = Vector2(-700, 700)
	await _stage(guard, Vector2(46, 0))
	_check(guard.health.max_health == 60.0, "the guard keeps its authored health")
	for index in range(3):
		await _swing(0.05)
		await _settle()
	_check(guard.health.is_dead, "repeated fast melee kills an ordinary guard")
	completed += 1


func _projectiles_versus_shield() -> void:
	await _load(false)
	player.global_position = Vector2(-700, 700)
	await _stage(elite, Vector2(0, 200))
	_check(elite.shield != null and elite.shield.enabled, "the Elite carries an enabled personal shield")
	_check(elite.health.max_health == 100.0, "the Elite has Elite health")
	_check(elite.shield.velocity_threshold == 150.0, "the shield threshold is configured")
	# Scenario C: the Maula Pistol is blocked.
	var before: float = elite.health.current_health
	var blocked: Array[int] = [0]
	elite.shield.shield_blocked.connect(func(_hit: HitContext) -> void: blocked[0] += 1)
	_launch(player, elite.global_position)
	await _frames(30)
	_check(elite.health.current_health == before, "a pistol round deals the Elite no health damage")
	_check(blocked[0] == 1 and elite.shield.last_result == ShieldComponent.Result.BLOCKED, "the shield registers the blocked round")
	_check(get_nodes_in_group("projectiles").is_empty(), "the blocked projectile is destroyed rather than passing through")
	_check(elite.shield.last_attack_label == "Maula Pistol" and elite.shield.last_attack_velocity == 900.0, "the shield sees the projectile speed")
	# Energy drains cosmetically but brute force can never break the shield.
	for index in range(40):
		_launch(player, elite.global_position)
		await _frames(4)
	_check(elite.health.current_health == before, "sustained gunfire never damages a shielded enemy")
	_check(elite.shield.enabled and elite.shield.current_energy >= elite.shield.minimum_energy, "shield energy floors instead of failing")
	# Friendly fire is filtered before the shield ever sees the hit.
	var shield_hits: int = int(elite.shield.max_energy - elite.shield.current_energy)
	guard.global_position = elite.global_position + Vector2(0, 140)
	await _frames(3)
	_launch(guard, elite.global_position)
	await _frames(30)
	_check(elite.health.current_health == before, "a Harkonnen round cannot damage the Elite")
	_check(int(elite.shield.max_energy - elite.shield.current_energy) == shield_hits, "faction filtering runs before the shield, not through it")
	# The same projectile damages an unshielded guard.
	await _stage(guard, Vector2(0, -190))
	var guard_before: float = guard.health.current_health
	_launch(player, guard.global_position)
	await _frames(30)
	_check(guard.health.current_health < guard_before, "ordinary enemies remain vulnerable to ranged fire")
	completed += 1


func _melee_versus_shield() -> void:
	await _load(false)
	player.global_position = Vector2(-700, 700)
	await _stage(elite, Vector2(46, 0))
	var results: Array[String] = []
	elite.shield.shield_blocked.connect(func(hit: HitContext) -> void: results.append("BLOCKED " + hit.type_name()))
	elite.shield.shield_penetrated.connect(func(hit: HitContext) -> void: results.append("PENETRATED " + hit.type_name()))
	# Scenario E: fast melee is too fast for the shield.
	var before: float = elite.health.current_health
	await _swing(0.05)
	await _settle()
	_check(elite.health.current_health == before, "fast melee deals a shielded Elite no health damage")
	_check(results.has("BLOCKED MELEE"), "the shield reports the fast blade as blocked")
	_check(melee.last_result == "BLOCKED", "the player's melee controller reports TOO FAST feedback")
	# Scenario F: the slow blade goes through.
	_key(KEY_E, true)
	await _frames(30)
	_key(KEY_E, false)
	await _frames(58)
	await _capture("m6_shield_penetrated")
	await _settle()
	_check(elite.health.current_health == before - SLOW.damage, "slow melee penetrates the shield and damages the Elite")
	_check(results.has("PENETRATED MELEE"), "the shield reports the slow blade as penetrating")
	_check(elite.shield.enabled, "penetration does not switch the shield off")
	_check(melee.last_result == "DAMAGED", "the controller reports the penetrating hit")
	# Threshold is data, not a hardcoded flag.
	_check(FAST.penetrates(elite.shield.velocity_threshold) == false, "the fast blade fails the threshold test")
	_check(SLOW.penetrates(elite.shield.velocity_threshold), "the slow blade passes the threshold test")
	elite.shield.velocity_threshold = 500.0
	var raised: float = elite.health.current_health
	await _swing(0.05)
	await _settle()
	_check(elite.health.current_health == raised - FAST.damage, "raising the threshold lets the fast blade through")
	elite.shield.velocity_threshold = 150.0
	# Scenario G: the slow strike costs mobility while it winds up.
	await _settle()
	_key(KEY_E, true)
	await _frames(30)
	_check(melee.slow_ready, "the strike charges beside a hostile")
	var origin: Vector2 = player.global_position
	Input.action_press("move_up")
	await _frames(30)
	Input.action_release("move_up")
	var charged_travel: float = origin.distance_to(player.global_position)
	_key(KEY_E, false)
	await _settle()
	await _frames(20)
	origin = player.global_position
	Input.action_press("move_up")
	await _frames(30)
	Input.action_release("move_up")
	var free_travel: float = origin.distance_to(player.global_position)
	_check(charged_travel < free_travel * 0.6, "charging the slow strike substantially restricts movement")
	completed += 1


func _aim_and_faction_safety() -> void:
	await _load(false)
	player.global_position = Vector2(-700, 700)
	# Scenario H: melee follows the aim direction, not the nearest enemy.
	guard.global_position = player.global_position + Vector2(46, 0)
	elite.global_position = player.global_position + Vector2(-46, 0)
	for trainer in [guard, elite]:
		trainer.ai.set_physics_process(false)
		trainer.set_physics_process(false)
		trainer.perception.stop()
		trainer.weapon.disable()
	_aim_at(guard.global_position)
	await _frames(3)
	var guard_before: float = guard.health.current_health
	var elite_hits: Array[int] = [0]
	elite.shield.shield_blocked.connect(func(_hit: HitContext) -> void: elite_hits[0] += 1)
	await _swing(0.05)
	await _settle()
	_check(guard.health.current_health < guard_before, "the aimed enemy is struck")
	_check(elite_hits[0] == 0, "the enemy behind Paul is outside the hitbox")
	# Aiming the other way reverses it.
	_aim_at(elite.global_position)
	await _frames(3)
	var guard_now: float = guard.health.current_health
	await _swing(0.05)
	await _settle()
	_check(elite_hits[0] == 1, "turning to aim at the Elite strikes the Elite")
	_check(guard.health.current_health == guard_now, "the enemy now behind Paul is spared")
	# Scenario I: Fremen are never damaged by Paul's blade.
	scout.ai.set_physics_process(false)
	scout.set_physics_process(false)
	scout.global_position = player.global_position + Vector2(40, 0)
	_aim_at(scout.global_position)
	await _frames(3)
	var scout_before: float = scout.health.current_health
	await _swing(0.05)
	await _settle()
	_check(scout.health.current_health == scout_before, "Paul's blade cannot damage the Scout")
	await _swing(0.5)
	await _settle()
	_check(scout.health.current_health == scout_before, "the slow blade cannot damage the Scout either")
	completed += 1


func _elite_death_and_ally_fire() -> void:
	await _load(false)
	player.global_position = Vector2(-700, 700)
	await _stage(elite, Vector2(46, 0))
	# Scenario D: Fremen rifle fire is blocked by the same generic rule.
	var before: float = elite.health.current_health
	scout.ai.set_physics_process(false)
	scout.set_physics_process(false)
	scout.global_position = elite.global_position + Vector2(0, -180)
	await _frames(3)
	_launch(scout, elite.global_position)
	await _frames(30)
	_check(elite.health.current_health == before, "Fremen rifle fire is blocked by the Elite shield")
	_check(elite.shield.last_attack_label == "Fremen Rifle", "the shield records the ally weapon that was stopped")
	# Scenario J: slow melee eventually kills the Elite through the shield.
	var swings: int = 0
	while not elite.health.is_dead and swings < 4:
		await _swing(0.5)
		await _settle()
		swings += 1
	_check(elite.health.is_dead, "repeated penetrating strikes kill the Elite")
	_check(elite.ai.state == EnemyAIController.State.DEAD, "the Elite enters the normal DEAD state")
	_check(not elite.shield.enabled, "the shield shuts down with its owner")
	_check(not elite.weapon.enabled and elite.collision_layer == 0, "shields do not interfere with the normal death flow")
	var dead_energy: float = elite.shield.current_energy
	_launch(player, elite.global_position)
	await _frames(20)
	_check(elite.shield.current_energy == dead_energy, "a dead Elite no longer evaluates shield hits")
	completed += 1


func _command_mode_and_hud() -> void:
	await _load(false)
	player.global_position = Vector2(-700, 700)
	await _stage(guard, Vector2(46, 0))
	# Scenario K: command mode owns the controls and cancels a pending charge.
	_key(KEY_E, true)
	await _frames(30)
	_check(melee.slow_ready, "a slow strike is charged before command mode")
	squad.set_command_mode(true)
	await _frames(3)
	_check(melee.state == State.IDLE and not melee.slow_ready, "entering command mode cancels the charge")
	var untouched: float = guard.health.current_health
	_key(KEY_E, false)
	await _frames(10)
	_key(KEY_E, true)
	await _frames(10)
	_key(KEY_E, false)
	await _frames(40)
	_check(melee.state == State.IDLE and guard.health.current_health == untouched, "melee input is ignored while issuing orders")
	_check(squad.command_mode and is_equal_approx(Engine.time_scale, 0.4), "command mode is unaffected by melee input")
	squad.set_command_mode(false)
	await _frames(5)
	_check(Engine.time_scale == 1.0 and not player.squad_control_locked, "leaving command mode restores normal control")
	await _swing(0.05)
	await _settle()
	_check(guard.health.current_health < untouched, "melee works again once command mode ends")
	# Milestone 5.1 systems are untouched by melee.
	var camera: TacticalCamera = player.get_node("TacticalCamera")
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_PAUL, "the tactical camera still returns to Paul")
	_check(is_equal_approx(squad.get_effective_command_range(), 700.0), "command range value is unchanged")
	_check(squad.link_state(warrior) == Link.OUT_OF_RANGE, "the parked Warrior still reads as out of range")
	warrior.global_position = player.global_position + Vector2(80, 0)
	await _frames(4)
	_check(squad.link_state(warrior) == Link.CONNECTED and squad.can_command(warrior), "command range still functions")
	# HUD and debug surfaces.
	root.get_node("GameManager").debug_visible = true
	_key(KEY_E, true)
	await _frames(30)
	var hud: Label = mission.get_node("UI/Screen/CombatHUD/Margin/Rows/Melee")
	_check(hud.visible and hud.text.contains("PENETRATING"), "the HUD announces a ready penetrating strike")
	await _capture("m6_melee_charge")
	_key(KEY_E, false)
	await _frames(6)
	_check(mission.get_node("UI/Screen/CombatHUD/Margin/Rows/Melee").text.contains("Crysknife"), "the HUD names the committed attack")
	await _frames(120)
	var metrics: Dictionary = mission.get_node("UI").metric_labels
	for row in ["Melee state", "Melee attack", "Slow charge", "Melee velocity", "Last melee result"]:
		_check(metrics.has(row), "F1 debug overlay shows '%s'" % row)
	# The Elite's own diagnostics expose its shield.
	elite.process_mode = Node.PROCESS_MODE_INHERIT
	await _stage(elite, Vector2(0, 60))
	await _frames(12)
	var details: String = elite.get_node("DebugVisuals/Details").text
	_check(details.contains("Shield: ON") and details.contains("Threshold: 150"), "F1 enemy diagnostics expose shield state")
	await _swing(0.05)
	await _settle()
	await _capture("m6_shield_blocked")
	_check(elite.get_node("DebugVisuals/Details").text.contains("Last hit: BLOCKED"), "enemy diagnostics report the last shield result")
	root.get_node("GameManager").debug_visible = false
	completed += 1


func _launch(source: PhysicsBody2D, point: Vector2) -> void:
	var weapon: WeaponController = source.get_node("WeaponController")
	var shot: CombatProjectile = PROJECTILE.instantiate()
	var direction: Vector2 = source.global_position.direction_to(point)
	shot.configure(weapon.weapon_data, direction, source)
	mission.add_child(shot)
	shot.global_position = source.global_position + direction * 28


## Points Paul at a fixed world location for the rest of the scenario.
func _aim_at(point: Vector2) -> void:
	player.aim_point = point
	player._update_aim()


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


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
