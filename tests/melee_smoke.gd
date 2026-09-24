extends SceneTree
## Milestone 6: crysknife melee and Holtzman personal shields.
## Runs against the real mission, player scene, hitbox physics, and input map.
## Swing timing is driven through melee_press()/melee_release() (the scripted
## E hold); the player-facing path - E / F arm a target pick, left-click a
## hostile, Paul walks in and strikes - is covered by _crysknife_targeting.

const State = MeleeController.State
const Link = CommandLinkComponent.State
const Targeting = SquadManager.Targeting
const FAST: MeleeAttackData = preload("res://resources/weapons/crysknife_fast.tres")
const SLOW: MeleeAttackData = preload("res://resources/weapons/crysknife_slow.tres")
const PROJECTILE: PackedScene = preload("res://scenes/combat/projectile.tscn")

class AimedPlayer extends PlayerController:
	# Scripted swings aim at an explicit world point. With `scripted_aim` off,
	# Paul's own orders set his facing exactly as in production.
	var aim_point: Vector2 = Vector2.RIGHT
	var scripted_aim: bool = true

	func _update_aim() -> void:
		if not scripted_aim:
			return
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
	await _crysknife_targeting()
	await _hud_and_diagnostics()
	await _elite_duel()
	_check(completed == 9, "all melee scenarios completed")
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


## Holds the crysknife for `hold` seconds of physics time, then releases.
func _swing(hold: float) -> void:
	player.melee_press()
	await _frames(maxi(int(hold * 60.0), 1))
	player.melee_release()
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
	player.melee_press()
	await _frames(3)
	_check(melee.state == State.CHARGING and not melee.slow_ready, "pressing melee begins a charge")
	_check(melee.hitbox.monitoring, "the hitbox arms during the charge")
	player.melee_release()
	await _frames(2)
	_check(melee.current_attack == FAST, "a short tap swings the fast attack")
	await _frames(40)
	_check(melee.state == State.IDLE, "the fast attack recovers quickly")
	# Holding past the threshold arms the slow strike instead.
	player.melee_press()
	await _frames(12)
	_check(melee.state == State.CHARGING and not melee.slow_ready, "below the threshold the slow strike is not ready")
	await _frames(20)
	_check(melee.slow_ready and melee.charge_ratio() == 1.0, "holding past the threshold arms the penetrating strike")
	_check(melee.get_move_speed_multiplier() <= 0.5, "a charged slow strike substantially restricts movement")
	player.melee_release()
	await _frames(2)
	_check(melee.current_attack == SLOW and melee.state == State.WINDUP, "releasing a charged hold swings the slow attack")
	await _frames(20)
	_check(melee.state == State.WINDUP, "the slow wind-up is still running a third of a second later")
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
	player.melee_press()
	await _frames(30)
	player.melee_release()
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
	# Scenario G: the slow strike costs mobility while it is held. A new order
	# cancels a pending charge, so Paul is already walking when he draws it.
	await _settle()
	var start: Vector2 = player.global_position
	player.move_to(start + Vector2(0, -400))
	player.melee_press()
	await _frames(30)
	_check(melee.slow_ready and player.order == PlayerController.Order.MOVE, "the strike charges beside a hostile while Paul walks")
	var origin: Vector2 = player.global_position
	await _frames(30)
	var charged_travel: float = origin.distance_to(player.global_position)
	player.melee_release()
	player.stop()
	await _settle()
	await _frames(20)
	# Open ground to the west, well clear of the range.
	player.move_to(Vector2(start.x - 400.0, player.global_position.y))
	await _frames(30)
	origin = player.global_position
	await _frames(30)
	player.stop()
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


func _crysknife_targeting() -> void:
	await _load(false)
	# Paul's own orders set his facing in this scenario, as in production.
	player.scripted_aim = false
	player.retaliate = false
	player.global_position = Vector2(-700, 700)
	await _stage(guard, Vector2(150, 0))
	guard.health.max_health = 300.0
	guard.health.reset_health()
	var camera: TacticalCamera = player.get_node("TacticalCamera")
	camera.snap_to(player.global_position + Vector2(75, 0))
	await _frames(4)
	var hud: PlayerHud = mission.get_node("UI/Screen/HUD")
	var started: Array[MeleeAttackData] = []
	var finished: Array[MeleeAttackData] = []
	melee.attack_started.connect(func(data: MeleeAttackData) -> void: started.append(data))
	melee.attack_finished.connect(func(data: MeleeAttackData, _hits: int) -> void: finished.append(data))
	_check(squad.paul_selected and squad.targeting == Targeting.NONE, "Paul starts selected with no strike armed")
	# Scenario K: with Paul selected, a quick left-click on a hostile is a
	# quick strike. No key needs pressing first.
	var anchor: Vector2 = camera.anchor
	var before: float = guard.health.current_health
	await _left_click(guard.global_position)
	_check(player.order == PlayerController.Order.MELEE and player.order_target == guard, "a quick left-click on a hostile issues a melee strike order")
	_check(not squad.blade_charging and squad.targeting == Targeting.NONE, "releasing the button ends the charge")
	await _frames(6)
	_check(player.velocity.x > 0.0 and melee.state == State.IDLE, "Paul walks toward a target out of reach")
	await _frames(2)
	_check(hud.melee_label.text == "CLOSING IN", "the HUD reports Paul closing in")
	await _await_strike()
	_check(started == [FAST] and finished == [FAST], "a quick click delivers exactly one quick strike")
	_check(guard.health.current_health == before - FAST.damage, "the quick strike damages the guard")
	_check(player.global_position.distance_to(guard.global_position) <= melee.hitbox_base_range, "Paul struck from inside his reach")
	_check(player.order == PlayerController.Order.IDLE, "the melee order ends after the stroke")
	_check(camera.anchor.distance_to(anchor) < 1.0, "the free camera does not chase Paul into melee")
	# Holding the button charges: the HUD ring fills and the prompt changes.
	_mouse(MOUSE_BUTTON_LEFT, guard.global_position, true)
	await _frames(2)
	_check(squad.blade_charging and player.order == PlayerController.Order.MELEE and melee.state == State.CHARGING, "pressing on a hostile raises the blade at once")
	_check(hud.notice_label.text.contains("QUICK STRIKE"), "while short of the threshold the HUD offers the quick strike")
	await _real_wait(squad.slow_hold_seconds() + 0.1)
	await _frames(2)
	_check(squad.blade_charge_ratio() >= 1.0 and hud.notice_label.text.contains("SLOW STRIKE READY"), "holding past the threshold readies the slow strike")
	# Right-click while holding abandons the charge; nothing is ordered.
	var standing: Vector2 = player.global_position
	await _right_click(player.global_position + Vector2(0, -200))
	_mouse(MOUSE_BUTTON_LEFT, guard.global_position, false)
	await _frames(10)
	_check(not squad.blade_charging and player.order == PlayerController.Order.IDLE and melee.state == State.IDLE, "right-click lowers the blade and cancels the strike")
	_check(player.global_position.distance_to(standing) < 20.0, "and is not also a move order")
	# E arms the blade; a click on open ground keeps it armed and explains.
	await _tap(KEY_E)
	_check(squad.targeting == Targeting.STRIKE, "E arms the crysknife")
	_check(melee.state == State.IDLE and player.order == PlayerController.Order.IDLE, "arming does not swing or move Paul")
	await _frames(2)
	_check(hud.notice_label.visible and hud.notice_label.text.contains("CRYSKNIFE"), "the HUD prompts for a target")
	await _left_click(player.global_position + Vector2(0, -220))
	_check(squad.targeting == Targeting.STRIKE and player.order == PlayerController.Order.IDLE, "clicking open ground does not spend the armed blade")
	_check(squad.notice.contains("LEFT-CLICK A TARGET"), "a missed pick tells the player what to click")
	await _tap(KEY_E)
	_check(squad.targeting == Targeting.NONE, "pressing E again disarms the blade")
	await _tap(KEY_E)
	await _tap(KEY_ESCAPE)
	_check(squad.targeting == Targeting.NONE, "Esc cancels an armed blade")
	# The blade belongs to Paul.
	squad.select_slot(1)
	await _tap(KEY_E)
	squad.select_slot(2)
	_check(squad.targeting == Targeting.NONE, "selecting away from Paul drops an armed blade")
	await _tap(KEY_E)
	_check(squad.targeting == Targeting.NONE and squad.notice.contains("SELECT PAUL"), "arming is refused when Paul is not selected")
	await _left_click(guard.global_position)
	_check(player.order == PlayerController.Order.IDLE and not squad.blade_charging, "without Paul selected a click on a hostile is no strike")
	squad.select_slot(1)
	melee.set_enabled(false)
	await _tap(KEY_E)
	_check(squad.targeting == Targeting.NONE and squad.notice.contains("NOT YOURS YET"), "arming is refused while the blade is withheld")
	await _left_click(guard.global_position)
	_check(player.order == PlayerController.Order.IDLE and squad.notice.contains("NOT YOURS YET"), "clicking a hostile with the blade withheld explains itself")
	player.melee_strike(guard, false)
	_check(player.order == PlayerController.Order.IDLE, "a withheld blade refuses a direct strike order too")
	melee.set_enabled(true)
	# Orders still work while paused; the strike happens on resume.
	started.clear()
	finished.clear()
	await _stage(guard, Vector2(-150, 0))
	camera.snap_to(player.global_position)
	await _frames(4)
	squad.set_paused(true)
	await _frames(2)
	await _left_click(guard.global_position)
	var frozen: Vector2 = player.global_position
	await _frames(20)
	_check(player.order == PlayerController.Order.MELEE and player.global_position == frozen, "a strike ordered while paused waits for the world")
	squad.set_paused(false)
	var paused_before: float = guard.health.current_health
	await _await_strike()
	_check(finished == [FAST] and guard.health.current_health == paused_before - FAST.damage, "the paused order lands once play resumes")
	# Shields: a quick click is too fast for the Elite, a held one goes through.
	await _load(false)
	player.scripted_aim = false
	player.retaliate = false
	player.global_position = Vector2(-700, 700)
	await _stage(elite, Vector2(150, 0))
	camera = player.get_node("TacticalCamera")
	camera.snap_to(player.global_position + Vector2(75, 0))
	await _frames(4)
	hud = mission.get_node("UI/Screen/HUD")
	var results: Array[String] = []
	elite.shield.shield_blocked.connect(func(hit: HitContext) -> void: results.append("BLOCKED " + hit.type_name()))
	elite.shield.shield_penetrated.connect(func(hit: HitContext) -> void: results.append("PENETRATED " + hit.type_name()))
	var shielded: Array[MeleeAttackData] = []
	player.melee.attack_started.connect(func(data: MeleeAttackData) -> void: shielded.append(data))
	var elite_before: float = elite.health.current_health
	await _left_click(elite.global_position)
	_check(player.order == PlayerController.Order.MELEE and player.order_target == elite, "a quick strike can be ordered on the Elite")
	await _await_strike()
	_check(shielded == [FAST] and results == ["BLOCKED MELEE"], "the quick strike reaches the Elite and is blocked")
	_check(elite.health.current_health == elite_before and melee.last_result == "BLOCKED", "the shield stops the quick strike")
	await _frames(2)
	_check(hud.melee_label.text.contains("TOO FAST - BLOCKED"), "the HUD reports the blocked strike")
	# Step back so the slow strike has to walk in as well.
	player.teleport_to(elite.global_position + Vector2(-150, 0))
	camera.snap_to(player.global_position + Vector2(75, 0))
	await _frames(4)
	# The blade comes up while the button is held, not after it is released.
	_mouse(MOUSE_BUTTON_LEFT, elite.global_position, true)
	await _frames(2)
	var saw_charge: bool = melee.state == State.CHARGING and hud.melee_label.text.begins_with("Slow Attack")
	await _real_wait(squad.slow_hold_seconds() + 0.1)
	await _frames(2)
	_check(saw_charge, "the blade is charging while the button is held, and the HUD shows it")
	_check(melee.slow_ready and player.order == PlayerController.Order.MELEE, "held past the threshold, the slow stroke is ready before release")
	_mouse(MOUSE_BUTTON_LEFT, elite.global_position, false)
	await _frames(1)
	for index in range(400):
		await _frames(1)
		if player.order == PlayerController.Order.IDLE and melee.state == State.IDLE:
			break
	_check(shielded == [FAST, SLOW], "a held click delivers exactly one slow strike")
	_check(results.has("PENETRATED MELEE"), "the slow strike penetrates the shield")
	_check(elite.health.current_health == elite_before - SLOW.damage, "the slow strike damages the Elite")
	_check(elite.shield.enabled, "the shield stays up after penetration")
	completed += 1


## The Elite is a blade duelist: no rifle, he closes and cuts. Quick strikes
## bounce off his shield; slow strikes, ordered the normal way, win.
func _elite_duel() -> void:
	await _load(true)
	player.scripted_aim = false
	player.retaliate = false
	guard.process_mode = Node.PROCESS_MODE_DISABLED
	guard.collision_layer = 0
	player.teleport_to(elite.global_position + Vector2(-280, 0))
	await _frames(3)
	var shots: Array[int] = [0]
	elite.weapon.weapon_fired.connect(func() -> void: shots[0] += 1)
	var blocked: Array[int] = [0]
	elite.shield.shield_blocked.connect(func(_hit: HitContext) -> void: blocked[0] += 1)
	_check(not elite.weapon.enabled, "the Elite has put his rifle away")
	elite.face_position(player.global_position)
	elite.ai.target = player
	elite.ai.last_known_target_position = player.global_position
	elite.ai.has_last_known_position = true
	elite.ai.change_state(EnemyAIController.State.COMBAT)
	var closed: bool = false
	for index in range(300):
		await _frames(1)
		if elite.global_position.distance_to(player.global_position) <= elite.ai.melee_engage_range + 4.0:
			closed = true
			break
	_check(closed, "he charges to blade range")
	var hurt: bool = false
	for index in range(240):
		await _frames(1)
		if player.health.current_health < player.health.max_health:
			hurt = true
			break
	_check(hurt, "his blade hurts Paul")
	_check(shots[0] == 0 and get_nodes_in_group("projectiles").is_empty(), "and he never fires a shot")
	var elite_health: float = elite.health.current_health
	player.melee_strike(elite, false)
	await _await_strike()
	_check(blocked[0] >= 1 and elite.health.current_health == elite_health, "a quick strike bounces off his shield")
	for attempt in range(4):
		if elite.health.is_dead or player.health.is_dead:
			break
		player.melee_strike(elite, true)
		await _await_strike()
	_check(elite.health.is_dead, "slow strikes, ordered the normal way, cut him down")
	_check(not player.health.is_dead, "and Paul survives a straight duel (%.0f HP left)" % player.health.current_health)
	_check(not elite.get_node("MeleeController").enabled, "a dead duelist's blade goes still")
	completed += 1


## Waits for Paul's melee order to finish its stroke.
func _await_strike() -> void:
	for index in range(400):
		await _frames(1)
		if player.order == PlayerController.Order.IDLE and melee.state == State.IDLE:
			return


func _hud_and_diagnostics() -> void:
	await _load(false)
	player.global_position = Vector2(-700, 700)
	await _stage(guard, Vector2(46, 0))
	# Milestone 5.1 command range is untouched by melee.
	_check(is_equal_approx(squad.get_effective_command_range(), 700.0), "command range value is unchanged")
	_check(squad.link_state(warrior) == Link.OUT_OF_RANGE, "the parked Warrior still reads as out of range")
	warrior.global_position = player.global_position + Vector2(80, 0)
	await _frames(4)
	_check(squad.link_state(warrior) == Link.CONNECTED and squad.can_command(warrior), "command range still functions")
	# A new order abandons a charging stroke.
	player.melee_press()
	await _frames(30)
	_check(melee.slow_ready, "a slow strike is charged")
	player.move_to(player.global_position + Vector2(0, -100))
	await _frames(2)
	_check(melee.state == State.IDLE and not melee.slow_ready, "a new order cancels the charge")
	player.melee_release()
	player.stop()
	await _frames(20)
	# HUD and debug surfaces.
	await _stage(guard, Vector2(46, 0))
	root.get_node("GameManager").debug_visible = true
	var hud: PlayerHud = mission.get_node("UI/Screen/HUD")
	player.melee_press()
	await _frames(30)
	_check(hud.melee_label.visible and hud.melee_label.text.contains("PENETRATING"), "the HUD announces a ready penetrating strike")
	await _capture("m6_melee_charge")
	player.melee_release()
	await _frames(6)
	_check(hud.melee_label.text.contains("Crysknife"), "the HUD names the committed attack")
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
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(1)
	_key(code, false)
	await _frames(1)


## Window coordinates for a world point (the 1920 x 1080 canvas is stretched).
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


func _left_click(world: Vector2) -> void:
	_mouse(MOUSE_BUTTON_LEFT, world, true)
	_mouse(MOUSE_BUTTON_LEFT, world, false)
	await _frames(1)


func _right_click(world: Vector2) -> void:
	_mouse(MOUSE_BUTTON_RIGHT, world, true)
	_mouse(MOUSE_BUTTON_RIGHT, world, false)
	await _frames(1)


func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.validation/" + label + ".png")


## Wall-clock wait: the blade charge is timed in real milliseconds, and a
## fixed-fps headless run spins frames far faster than real time.
func _real_wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _hold_click(world: Vector2, seconds: float) -> void:
	_mouse(MOUSE_BUTTON_LEFT, world, true)
	await _frames(1)
	await _real_wait(seconds)
	_mouse(MOUSE_BUTTON_LEFT, world, false)
	await _frames(1)


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
