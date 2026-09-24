class_name TurnCombat
extends Node
## Turn-based combat for the isometric interiors, Fallout-style.
##
## Real time stops when the hero is spotted (a guard reaches COMBAT) or when
## the player chooses to fight with prescience (Q). Everyone snaps to the
## grid; the hero and the Harkonnen who know he is there take turns spending
## action points. A guard who does not know is frozen in place, watching: each
## step the hero takes in his view is a chance to be seen, lower when
## sneaking. The fight ends when nobody aware of the hero is left standing.
##
## Prescience is the hero's stat: that many visions per fight. A vision plays
## the hero's turn and the enemies' answer, then offers the future to accept
## or take back. Entering a fight with Q starts one at once: rewind it and
## the fight never happened.

signal combat_started(voluntary: bool)
signal combat_ended
signal turn_changed(actor: Node2D)
signal points_changed
signal vision_changed(active: bool)
signal vision_resolved(fatal: bool)
signal round_ended(seconds: float)
signal event_logged(text: String)
signal roster_changed
signal vision_rewound

enum Phase { EXPLORE, PLAYER, ENEMY, BUSY, PROMPT }

const HERO_WALK: float = 210.0
const HERO_SNEAK: float = 130.0
const ENEMY_WALK: float = 220.0
## Guards close in and use the bayonet on a shielded hero: a slow thrust.
const BAYONET_DAMAGE: float = 14.0
const BAYONET_COST: int = 4

@export var player: PlayerController
@export var level: IsoLevel
@export var hero: HeroDefinition
## How close the camera comes in for a fight.
@export var min_zoom: float = 1.3
@export var max_zoom: float = 1.9

var phase: Phase = Phase.EXPLORE
var round_number: int = 0
var points: int = 0
var max_points: int = 10
var evasion: float = 0.0
var prescience_left: int = 0
var selected_attack: TurnRules.Attack = TurnRules.Attack.FIRE
## 4 arms a thrown stone: the next click on the floor throws it there.
var distract_armed: bool = false
var acting: Node2D
var aware: Dictionary = {}
var in_vision: bool = false
var vision_fatal: bool = false
var vision_from_explore: bool = false
var last_event: String = ""
## Off: a guard reaching COMBAT in real time does not start a fight (the
## solo tutorial's stealth lesson handles being seen itself).
var auto_engage: bool = true
## Off: Q does not start a fight from exploring.
var allow_voluntary: bool = true
## Tests: a fixed roll (0..100) instead of a random one. Negative is random.
var forced_roll: float = -1.0

var _snapshot: TurnSnapshot
## The hero as he really stands while a vision plays; the body in the vision
## is his blue shadow.
var _anchor: VisionAnchor
var _after_prompt: StringName = &""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("turn_combat")
	_rng.randomize()
	max_points = Progression.action_points(_campaign(), hero)
	if is_instance_valid(player):
		player.health.floored.connect(_on_hero_floored)
	for node: Node in get_tree().get_nodes_in_group("fuel_tanks"):
		(node as FuelTank).exploded.connect(_on_tank_exploded)
	var overlay: TurnGridOverlay = TurnGridOverlay.new()
	overlay.name = "TurnGridOverlay"
	overlay.combat = self
	overlay.level = level
	level.add_child(overlay)


func active() -> bool:
	return phase != Phase.EXPLORE


## A fight system and its interface for an interior: the TurnCombat, its
## CombatHud, and the grid overlay (which TurnCombat adds to the level).
static func install(parent: Node, hero_body: PlayerController, iso_level: IsoLevel, hero_data: HeroDefinition) -> TurnCombat:
	var combat: TurnCombat = TurnCombat.new()
	combat.name = "TurnCombat"
	combat.player = hero_body
	combat.level = iso_level
	combat.hero = hero_data
	parent.add_child(combat)
	var hud: CombatHud = CombatHud.new()
	hud.name = "CombatHud"
	hud.combat = combat
	parent.add_child(hud)
	# Q is the way into a fight in an interior, not real-time prescience.
	hero_body.prescience.input_enabled = false
	return combat


# --------------------------------------------------------------------------
# Starting and ending a fight
# --------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if phase != Phase.EXPLORE or not is_instance_valid(player) or player.health.is_dead or not auto_engage:
		return
	# A guard who has fully detected the hero starts the fight.
	var spotters: Array[EnemyCharacter] = []
	for enemy in _enemies():
		if enemy.ai.state == EnemyAIController.State.COMBAT:
			spotters.append(enemy)
	if not spotters.is_empty():
		begin(false, spotters)


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player) or player.health.is_dead:
		return
	if phase == Phase.EXPLORE:
		if event.is_action_pressed("prescience") and not event.is_echo():
			get_viewport().set_input_as_handled()
			if not allow_voluntary:
				_log("NOT HERE")
			elif _prescience() <= 0:
				_log("NO PRESCIENCE")
			else:
				begin(true)
		return
	if event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if event.is_echo():
		return
	if phase == Phase.PROMPT:
		if event.is_action_pressed("prescience") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_BACKSPACE):
			rewind_vision()
		elif event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not vision_fatal:
			accept_vision()
		return
	if phase != Phase.PLAYER:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var point: Vector2 = level.get_global_mouse_position()
		var target: Node2D = target_at(point)
		if distract_armed:
			command_distract(IsoMath.world_to_cell(point))
		elif target != null:
			command_attack(target)
		else:
			command_move(IsoMath.world_to_cell(point))
		return
	if not (event is InputEventKey and event.pressed):
		return
	if event.physical_keycode == KEY_1:
		select_attack(TurnRules.Attack.FIRE)
	elif event.physical_keycode == KEY_2:
		select_attack(TurnRules.Attack.QUICK_KNIFE)
	elif event.physical_keycode == KEY_3:
		select_attack(TurnRules.Attack.SLOW_KNIFE)
	elif event.physical_keycode == KEY_4:
		arm_distract(not distract_armed)
	elif event.is_action_pressed("use_spice"):
		command_spice()
	elif event.physical_keycode == KEY_ESCAPE and distract_armed:
		arm_distract(false)
	elif event.is_action_pressed("reload"):
		command_reload()
	elif event.is_action_pressed("shield_toggle"):
		command_shield()
	elif event.is_action_pressed("crouch"):
		command_sneak()
	elif event.is_action_pressed("prescience"):
		if in_vision:
			rewind_vision()
		else:
			command_vision()
	elif event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		end_turn()


## Start a fight. `voluntary`: the hero moves first - with Q the opening is a
## vision; an attack ordered in real time (`with_vision` off) opens it for
## real. Otherwise `spotters` saw him and move first.
func begin(voluntary: bool, spotters: Array[EnemyCharacter] = [], with_vision: bool = true) -> void:
	if phase != Phase.EXPLORE:
		return
	# Going in with prescience: the vision starts the instant Q is pressed,
	# before anyone is frozen or moved, so taking it back changes nothing.
	var before: TurnSnapshot = TurnSnapshot.capture(get_tree(), player, {}) if voluntary and with_vision else null
	round_number = 1
	evasion = 0.0
	aware.clear()
	prescience_left = _prescience()
	selected_attack = TurnRules.Attack.FIRE
	player.turn_based = true
	for enemy in _enemies():
		enemy.turn_based = true
	_settle_on_grid()
	for enemy in spotters:
		_make_aware(enemy, false)
	phase = Phase.BUSY
	_frame_fight()
	combat_started.emit(voluntary)
	roster_changed.emit()
	if voluntary and with_vision:
		prescience_left -= 1
		_start_vision(true, before)
		_start_player_turn()
	elif voluntary:
		_log("YOU STRIKE FIRST")
		_start_player_turn()
	else:
		_log("SPOTTED")
		await get_tree().create_timer(0.9).timeout
		await _enemy_phase()
		if phase == Phase.EXPLORE:
			return
		_close_round()


## Whether this attack on `target`, ordered in real time, opens a fight here:
## only one the hero could make on his first turn. A guard out of sight or out
## of reach is left to the real-time order (find a line, walk up).
func can_open_with(target: Node2D, kind: TurnRules.Attack = TurnRules.Attack.FIRE) -> bool:
	if phase != Phase.EXPLORE or not allow_voluntary or not is_instance_valid(player) or player.health.is_dead:
		return false
	if target is FuelTank:
		if (target as FuelTank).detonated:
			return false
	else:
		var enemy: EnemyCharacter = target as EnemyCharacter
		if enemy == null or not enemy.is_in_group("enemies") or enemy.health.is_dead or enemy.get_meta("dormant", false):
			return false
	if kind != TurnRules.Attack.FIRE and not player.melee.enabled:
		return false
	var kept_points: int = points
	var kept_attack: TurnRules.Attack = selected_attack
	points = Progression.action_points(_campaign(), hero)
	selected_attack = kind
	var plan: Dictionary = preview_attack(target)
	points = kept_points
	selected_attack = kept_attack
	return plan.ok


## Whoever attacks first acts first: an attack ordered in real time opens the
## fight on the hero's turn, and is his first action. No vision is spent, and
## nothing is taken back.
func open_with_attack(target: Node2D, kind: TurnRules.Attack) -> bool:
	if not can_open_with(target, kind):
		return false
	begin(true, [], false)
	select_attack(kind)
	await command_attack(target)
	# Done unseen - a silent kill, nobody the wiser: back to real time.
	if phase == Phase.PLAYER and _aware_living().is_empty():
		_finish()
	return true


func _finish() -> void:
	if phase == Phase.EXPLORE:
		return
	_clear_vision()
	phase = Phase.EXPLORE
	acting = null
	aware.clear()
	for enemy in _enemies():
		enemy.turn_based = false
	player.turn_based = false
	var camera: TacticalCamera = _camera()
	if camera != null:
		camera.set_combat_view(0.0)
	combat_ended.emit()
	roster_changed.emit()


## Visions per fight: the hero's base plus what spice and the story added,
## plus one if a dose was taken in this fight.
func _prescience() -> int:
	return Progression.visions(_campaign(), hero)


func _campaign() -> CampaignState:
	return Progression.campaign_of(self)


func _hero_id() -> StringName:
	return player.hero_id if is_instance_valid(player) else &"paul"


## What an attack costs this hero (a skilled blade is quicker).
func attack_cost(kind: TurnRules.Attack) -> int:
	if kind == TurnRules.Attack.QUICK_KNIFE:
		return Progression.quick_knife_cost(_campaign(), _hero_id())
	return TurnRules.attack_cost(kind)


func reload_cost() -> int:
	return Progression.reload_cost(_campaign(), _hero_id())


func _hero_fire_chance(target: Node2D) -> float:
	return TurnRules.fire_chance(player, target, 95.0 + Progression.fire_bonus(_campaign(), _hero_id()), 0.0)


func _hero_knife_chance(kind: TurnRules.Attack) -> float:
	return clampf(TurnRules.knife_chance(kind, 0.0) + Progression.knife_bonus(_campaign(), _hero_id()), 10.0, 98.0)


## Everyone to the centre of a tile, no two on one.
func _settle_on_grid() -> void:
	var taken: Dictionary = {}
	for actor: Node2D in [player as Node2D] + _living_enemies():
		var cell: Vector2i = IsoMath.world_to_cell(actor.global_position)
		if taken.has(cell) or level.is_wall(cell):
			for offset in TurnRules.NEIGHBOURS:
				if not taken.has(cell + offset) and not level.is_wall(cell + offset):
					cell = cell + offset
					break
		taken[cell] = true
		actor.velocity = Vector2.ZERO
		var tween: Tween = actor.create_tween()
		tween.tween_property(actor, "global_position", IsoMath.cell_to_world(cell), 0.15)


# --------------------------------------------------------------------------
# The hero's turn
# --------------------------------------------------------------------------

func _start_player_turn() -> void:
	max_points = Progression.action_points(_campaign(), hero)
	points = max_points
	evasion = 0.0
	acting = player
	phase = Phase.PLAYER
	_frame_fight()
	turn_changed.emit(player)
	points_changed.emit()


## V: a dose of spice from the hero's own store - one more vision in this
## fight, and a little permanent saturation.
func command_spice() -> bool:
	var campaign: CampaignState = _campaign()
	if phase != Phase.PLAYER or campaign == null or campaign.item_count(&"spice_dose") <= 0:
		_log("NO SPICE")
		return false
	campaign.add_item(&"spice_dose", -1)
	prescience_left += 1
	Progression.saturate(campaign, _hero_id(), 2.0)
	CombatFx.float_text(level, player.global_position, "SPICE", Color(1.0, 0.6, 0.25))
	_log("THE SPICE: ONE MORE VISION")
	points_changed.emit()
	return true


func arm_distract(value: bool) -> void:
	distract_armed = value
	points_changed.emit()


## Where a stone thrown at `cell` would land, and who would turn to look.
func preview_distract(cell: Vector2i) -> Dictionary:
	var at: Vector2 = IsoMath.cell_to_world(cell)
	var in_range: bool = TurnRules.tiles_between(player.global_position, at) <= TurnRules.DISTRACT_RANGE_TILES and not level.is_blocked(cell)
	var listeners: Array[EnemyCharacter] = []
	for enemy in _living_enemies():
		if not aware.has(enemy) and TurnRules.tiles_between(enemy.global_position, at) <= TurnRules.DISTRACT_HEARING_TILES:
			listeners.append(enemy)
	return {"at": at, "ok": in_range and points >= TurnRules.DISTRACT_COST, "in_range": in_range, "listeners": listeners}


## A stone, thrown: every guard in earshot who does not know the hero is
## here turns to look where it landed - and so looks away from him.
func command_distract(cell: Vector2i) -> void:
	if phase != Phase.PLAYER:
		return
	var plan: Dictionary = preview_distract(cell)
	if not plan.in_range:
		_log("TOO FAR TO THROW")
		return
	if not plan.ok:
		_log("NOT ENOUGH POINTS")
		return
	distract_armed = false
	points -= TurnRules.DISTRACT_COST
	CombatFx.float_text(level, plan.at, "clack", Color(0.9, 0.85, 0.7))
	for enemy: EnemyCharacter in plan.listeners:
		enemy.face_position(plan.at)
		CombatFx.float_text(level, enemy.global_position, "?", Color(1.0, 0.8, 0.4))
	_log("A STONE CLATTERS")
	points_changed.emit()
	if points <= 0:
		end_turn()


func select_attack(kind: TurnRules.Attack) -> void:
	distract_armed = false
	if kind != TurnRules.Attack.FIRE and not player.melee.enabled:
		_log("NO CRYSKNIFE")
		return
	selected_attack = kind
	points_changed.emit()


## What a move to `cell` would take: the path, its cost, whether it is possible.
func preview_move(cell: Vector2i) -> Dictionary:
	var start: Vector2i = IsoMath.world_to_cell(player.global_position)
	var route: Array[Vector2i] = TurnRules.path(level, start, cell, _occupied(player))
	var cost: int = route.size() * _step_cost()
	return {"path": route, "cost": cost, "ok": not route.is_empty() and cost <= points}


func reachable() -> Dictionary:
	var start: Vector2i = IsoMath.world_to_cell(player.global_position)
	return TurnRules.reach(level, start, points / _step_cost(), _occupied(player))


func command_move(cell: Vector2i) -> void:
	if phase != Phase.PLAYER:
		return
	var plan: Dictionary = preview_move(cell)
	if not plan.ok:
		_log("TOO FAR" if not (plan.path as Array).is_empty() else "NO WAY THROUGH")
		return
	var had_foes: bool = not _aware_living().is_empty()
	phase = Phase.BUSY
	await _walk_hero(plan.path)
	_after_hero_action(had_foes)


func _step_cost() -> int:
	return TurnRules.SNEAK_COST if player.is_crouching else TurnRules.MOVE_COST


func _walk_hero(route: Array) -> void:
	for cell: Vector2i in route:
		if player.health.is_dead or phase == Phase.EXPLORE:
			break
		await _step(player, cell, HERO_SNEAK if player.is_crouching else HERO_WALK)
		points -= _step_cost()
		points_changed.emit()
		_watchers_look()
	player.velocity = Vector2.ZERO


## Chance, hit or miss, cost, and a note for the hover readout.
func preview_attack(target: Node2D) -> Dictionary:
	var kind: TurnRules.Attack = selected_attack
	var cost: int = attack_cost(kind)
	var result: Dictionary = {"kind": kind, "cost": cost, "chance": 0.0, "note": "", "ok": false, "approach": []}
	if target is FuelTank:
		result.kind = TurnRules.Attack.FIRE
		result.cost = TurnRules.FIRE_COST
		result.chance = _hero_fire_chance(target)
		result.note = "BLAST: EVERYONE CLOSE IS HURT"
		result.ok = _can_shoot(target) and points >= TurnRules.FIRE_COST
		return result
	var enemy: EnemyCharacter = target as EnemyCharacter
	if enemy == null:
		return result
	var unaware: bool = not aware.has(enemy)
	var shield: ShieldComponent = ShieldComponent.find_on(enemy)
	var shielded: bool = shield != null and shield.enabled
	if kind == TurnRules.Attack.FIRE:
		result.chance = _hero_fire_chance(enemy)
		if shielded:
			result.note = "SHIELD STOPS BULLETS"
		elif player.weapon_controller.current_ammo <= 0:
			result.note = "EMPTY - R TO RELOAD"
		elif not _can_shoot(enemy):
			result.note = "NO LINE OF FIRE"
		result.ok = _can_shoot(enemy) and player.weapon_controller.current_ammo > 0 and points >= cost
		return result
	# The blade: walk up if needed, then cut.
	var start: Vector2i = IsoMath.world_to_cell(player.global_position)
	var goal: Vector2i = IsoMath.world_to_cell(enemy.global_position)
	var approach: Array[Vector2i] = []
	if not TurnRules.adjacent(start, goal):
		approach = _approach_path(start, goal, unaware)
		if approach.is_empty():
			result.note = "CANNOT REACH"
			return result
	result.approach = approach
	result.cost = cost + approach.size() * _step_cost()
	var standing: Vector2 = IsoMath.cell_to_world(approach[approach.size() - 1]) if not approach.is_empty() else player.global_position
	result.chance = 100.0 if unaware else _hero_knife_chance(kind)
	if shielded and kind == TurnRules.Attack.QUICK_KNIFE:
		result.note = "SHIELD STOPS A QUICK BLADE"
	elif unaware and TurnRules.is_behind(standing, enemy):
		result.note = "FROM BEHIND: SILENT KILL"
	elif unaware:
		result.note = "UNAWARE"
	result.ok = points >= result.cost
	return result


## A free tile next to the target; behind him if he has not seen us.
func _approach_path(start: Vector2i, goal: Vector2i, prefer_back: bool) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var best_score: float = INF
	var enemy: Node2D = _actor_on(goal)
	var blocked: Dictionary = _occupied(player)
	for offset in TurnRules.NEIGHBOURS:
		var cell: Vector2i = goal + offset
		if blocked.has(cell) or level.is_wall(cell) or not TurnRules.can_step(level, goal, cell):
			continue
		var route: Array[Vector2i] = TurnRules.path(level, start, cell, blocked)
		if route.is_empty() and cell != start:
			continue
		var score: float = route.size()
		if prefer_back and enemy != null and not TurnRules.is_behind(IsoMath.cell_to_world(cell), enemy):
			score += 3.5
		if score < best_score:
			best_score = score
			best = route
	return best


func command_attack(target: Node2D) -> void:
	if phase != Phase.PLAYER:
		return
	var plan: Dictionary = preview_attack(target)
	if not plan.ok:
		_log(plan.note if plan.note != "" else "NOT ENOUGH POINTS")
		return
	var had_foes: bool = not _aware_living().is_empty()
	phase = Phase.BUSY
	if not (plan.approach as Array).is_empty():
		await _walk_hero(plan.approach)
		if player.health.is_dead or phase == Phase.EXPLORE:
			return
	_face(player, target.global_position)
	points -= attack_cost(plan.kind)
	points_changed.emit()
	if plan.kind == TurnRules.Attack.FIRE:
		await _hero_fire(target, plan.chance)
	else:
		await _hero_cut(target as EnemyCharacter, plan.kind)
	_after_hero_action(had_foes)


func _hero_fire(target: Node2D, chance: float) -> void:
	var weapon: WeaponController = player.weapon_controller
	weapon.current_ammo -= 1
	weapon.ammo_changed.emit(weapon.current_ammo, weapon.weapon_data.magazine_size)
	weapon.weapon_fired.emit()
	var muzzle: Vector2 = player.global_position + Vector2(0, -34)
	var hits: bool = _roll() < chance
	var aim: Vector2 = target.global_position + Vector2(0, -30)
	if not hits:
		aim += Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-30, 10))
	CombatFx.tracer(level, muzzle, aim, Color(1.0, 0.85, 0.5))
	await get_tree().create_timer(0.12).timeout
	if not hits:
		CombatFx.float_text(level, target.global_position, "MISS", Color(0.8, 0.8, 0.8))
	elif target is FuelTank:
		(target as FuelTank).health.take_damage(weapon.weapon_data.damage, player)
	else:
		var hit: HitContext = HitContext.ranged(weapon.weapon_data.damage, weapon.weapon_data.projectile_speed, player, &"player", weapon.weapon_data.weapon_name, aim, player.global_position.direction_to(aim))
		_report(target, DamageResolver.resolve(target, hit), weapon.weapon_data.damage)
	_noise(player.global_position, weapon.weapon_data.noise_radius)
	await get_tree().create_timer(0.35).timeout


func _hero_cut(enemy: EnemyCharacter, kind: TurnRules.Attack) -> void:
	var data: MeleeAttackData = player.melee.slow_attack if kind == TurnRules.Attack.SLOW_KNIFE else player.melee.fast_attack
	var unaware: bool = not aware.has(enemy)
	var silent: bool = unaware and TurnRules.is_behind(player.global_position, enemy)
	await _lunge(player, enemy.global_position)
	CombatFx.slash(level, player.global_position, player.global_position.direction_to(enemy.global_position), Color(0.95, 0.9, 0.7))
	var chance: float = 100.0 if unaware else _hero_knife_chance(kind)
	if _roll() >= chance:
		CombatFx.float_text(level, enemy.global_position, "MISS", Color(0.8, 0.8, 0.8))
	else:
		var hit: HitContext = HitContext.melee(data, player, enemy.global_position, player.global_position.direction_to(enemy.global_position))
		# From behind, unseen: the blade finds the spine.
		if silent:
			hit.damage = enemy.health.max_health * 2.0
		var outcome: DamageResolver.Outcome = DamageResolver.resolve(enemy, hit)
		if silent and outcome == DamageResolver.Outcome.DAMAGED:
			Progression.award(_campaign(), _hero_id(), &"silent_kill")
			CombatFx.float_text(level, enemy.global_position, "SILENT KILL", Color(1.0, 0.85, 0.4))
			_log("SILENT KILL")
		else:
			_report(enemy, outcome, hit.damage)
	# A guard who lives through a cut knows exactly where the hero is.
	if is_instance_valid(enemy) and not enemy.health.is_dead and not aware.has(enemy):
		_make_aware(enemy)
	# A cut is quiet, but not to a guard who is looking at it.
	_witnesses(enemy.global_position)
	await get_tree().create_timer(0.3).timeout


func command_reload() -> void:
	var weapon: WeaponController = player.weapon_controller
	if phase != Phase.PLAYER or points < reload_cost() or weapon.current_ammo >= weapon.weapon_data.magazine_size:
		return
	phase = Phase.BUSY
	points -= reload_cost()
	points_changed.emit()
	weapon.start_reload()
	await weapon.reload_finished
	_after_hero_action(not _aware_living().is_empty())


func command_shield() -> void:
	if phase != Phase.PLAYER or player.shield == null or points < TurnRules.SHIELD_COST:
		return
	points -= TurnRules.SHIELD_COST
	player.set_shield(not player.shield_active())
	_log("SHIELD UP" if player.shield_active() else "SHIELD DOWN")
	points_changed.emit()


func command_sneak() -> void:
	if phase != Phase.PLAYER:
		return
	player.set_crouching(not player.is_crouching)
	points_changed.emit()


func end_turn() -> void:
	if phase != Phase.PLAYER:
		return
	evasion = points * TurnRules.EVASION_PER_POINT
	points = 0
	points_changed.emit()
	phase = Phase.BUSY
	# Unseen, with nobody hunting him: the fight simply ends.
	if _aware_living().is_empty() and not in_vision:
		_finish()
		return
	await _enemy_phase()
	if phase == Phase.EXPLORE:
		return
	_close_round()


## `had_foes`: somebody was hunting him before the action. If the action
## left nobody, the fight is won; a hero nobody knows about keeps his turn
## until he ends it.
func _after_hero_action(had_foes: bool) -> void:
	if phase == Phase.EXPLORE:
		return
	if vision_fatal:
		_prompt(&"")
		return
	if had_foes and _aware_living().is_empty():
		if in_vision:
			_prompt(&"finish")
		else:
			_finish()
		return
	phase = Phase.PLAYER
	points_changed.emit()
	roster_changed.emit()
	if points <= 0:
		end_turn()


func _close_round() -> void:
	if player.health.is_dead and not in_vision:
		return
	round_number += 1
	round_ended.emit(TurnRules.ROUND_SECONDS)
	_absorb_newcomers()
	if vision_fatal:
		_prompt(&"")
	elif in_vision:
		_prompt(&"finish" if _aware_living().is_empty() else &"player")
	else:
		_start_player_turn()


# --------------------------------------------------------------------------
# The Harkonnen turn
# --------------------------------------------------------------------------

func _enemy_phase() -> void:
	phase = Phase.ENEMY
	for enemy in _aware_living():
		if phase == Phase.EXPLORE or vision_fatal or (player.health.is_dead and not in_vision):
			break
		acting = enemy
		turn_changed.emit(enemy)
		var camera: TacticalCamera = _camera()
		if camera != null:
			camera.center_on((enemy.global_position + player.global_position) * 0.5)
		await get_tree().create_timer(0.35).timeout
		await _enemy_turn(enemy)
		await get_tree().create_timer(0.25).timeout
	acting = null


func _enemy_turn(enemy: EnemyCharacter) -> void:
	var budget: int = TurnRules.ELITE_POINTS if enemy.ai.melee_only else TurnRules.GUARD_POINTS
	_face(enemy, player.global_position)
	var guard_rounds: int = 0
	while budget > 0 and not enemy.health.is_dead and not vision_fatal and phase != Phase.EXPLORE:
		if player.health.is_dead and not in_vision:
			return
		guard_rounds += 1
		if guard_rounds > 20:
			return
		var here: Vector2i = IsoMath.world_to_cell(enemy.global_position)
		var hero_cell: Vector2i = IsoMath.world_to_cell(player.global_position)
		var close: bool = TurnRules.adjacent(here, hero_cell)
		# A shield turns bullets: close in and use the blade (or bayonet).
		var wants_blade: bool = enemy.ai.melee_only or player.shield_active()
		if wants_blade:
			var cost: int = _enemy_blade_cost(enemy)
			if close:
				if budget < cost:
					return
				budget -= cost
				await _enemy_cut(enemy)
				continue
			var route: Array[Vector2i] = _enemy_route(enemy, hero_cell)
			var steps: int = mini(route.size(), budget)
			if steps <= 0:
				return
			await _walk_enemy(enemy, route.slice(0, steps))
			budget -= steps
			continue
		if enemy.weapon.current_ammo <= 0:
			if budget < TurnRules.RELOAD_COST:
				return
			budget -= TurnRules.RELOAD_COST
			enemy.weapon.current_ammo = enemy.weapon.weapon_data.magazine_size
			CombatFx.float_text(level, enemy.global_position, "RELOAD", Color(0.8, 0.8, 0.8))
			await get_tree().create_timer(0.4).timeout
			continue
		if _enemy_can_shoot(enemy):
			if budget < TurnRules.FIRE_COST:
				return
			budget -= TurnRules.FIRE_COST
			await _enemy_fire(enemy)
			continue
		# No line of fire: advance, keeping enough to shoot on arrival.
		var path_in: Array[Vector2i] = _enemy_route(enemy, hero_cell)
		var spend: int = mini(path_in.size(), maxi(budget - TurnRules.FIRE_COST, 1))
		if spend <= 0:
			return
		for cell in path_in.slice(0, spend):
			await _step(enemy, cell, ENEMY_WALK)
			budget -= 1
			if _enemy_can_shoot(enemy):
				break
		enemy.velocity = Vector2.ZERO


func _enemy_blade_cost(enemy: EnemyCharacter) -> int:
	if enemy.ai.melee_only:
		return TurnRules.SLOW_KNIFE_COST if player.shield_active() else TurnRules.QUICK_KNIFE_COST
	return BAYONET_COST


func _enemy_route(enemy: EnemyCharacter, hero_cell: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = TurnRules.path(level, IsoMath.world_to_cell(enemy.global_position), hero_cell, _occupied(enemy))
	if not route.is_empty() and route[route.size() - 1] == hero_cell:
		route.pop_back()
	return route


func _walk_enemy(enemy: EnemyCharacter, route: Array) -> void:
	for cell: Vector2i in route:
		if enemy.health.is_dead or phase == Phase.EXPLORE:
			break
		await _step(enemy, cell, ENEMY_WALK)
	enemy.velocity = Vector2.ZERO


func _enemy_can_shoot(enemy: EnemyCharacter) -> bool:
	return enemy.weapon.enabled and enemy.global_position.distance_to(player.global_position) <= enemy.ai.maximum_combat_range \
		and TurnRules.has_sight(level.get_world_2d().direct_space_state, enemy.global_position + Vector2(0, -20), player.global_position + Vector2(0, -20))


func _enemy_fire(enemy: EnemyCharacter) -> void:
	_face(enemy, player.global_position)
	var data: WeaponData = enemy.weapon.weapon_data
	enemy.weapon.current_ammo -= 1
	enemy.weapon.weapon_fired.emit()
	var chance: float = TurnRules.fire_chance(enemy, player, 75.0, evasion)
	var hits: bool = _roll() < chance
	var aim: Vector2 = player.global_position + Vector2(0, -30)
	if not hits:
		aim += Vector2(_rng.randf_range(-45, 45), _rng.randf_range(-30, 10))
	CombatFx.tracer(level, enemy.global_position + Vector2(0, -30), aim, Color(1.0, 0.45, 0.35))
	await get_tree().create_timer(0.12).timeout
	if hits:
		var hit: HitContext = HitContext.ranged(data.damage, data.projectile_speed, enemy, &"enemy", data.weapon_name, aim, enemy.global_position.direction_to(aim))
		_report(player, DamageResolver.resolve(player, hit), data.damage)
	else:
		CombatFx.float_text(level, player.global_position, "MISS", Color(0.8, 0.8, 0.8))
	_noise(enemy.global_position, data.noise_radius)
	await get_tree().create_timer(0.35).timeout


func _enemy_cut(enemy: EnemyCharacter) -> void:
	_face(enemy, player.global_position)
	await _lunge(enemy, player.global_position)
	CombatFx.slash(level, enemy.global_position, enemy.global_position.direction_to(player.global_position), Color(1.0, 0.5, 0.4))
	var hit: HitContext
	var blade: MeleeController = enemy.get_node_or_null("MeleeController") as MeleeController
	if enemy.ai.melee_only and blade != null:
		var slow: bool = player.shield_active() and blade.slow_attack != null
		var data: MeleeAttackData = blade.slow_attack if slow else blade.fast_attack
		hit = HitContext.melee(data, enemy, player.global_position, enemy.global_position.direction_to(player.global_position))
	else:
		hit = HitContext.new()
		hit.damage = BAYONET_DAMAGE
		hit.attack_velocity = 90.0
		hit.attack_type = HitContext.Type.MELEE
		hit.source = enemy
		hit.source_team = &"enemy"
		hit.label = "Bayonet"
	if _roll() < clampf(80.0 - evasion, 10.0, 95.0):
		_report(player, DamageResolver.resolve(player, hit), hit.damage)
	else:
		CombatFx.float_text(level, player.global_position, "MISS", Color(0.8, 0.8, 0.8))
	await get_tree().create_timer(0.3).timeout


# --------------------------------------------------------------------------
# Awareness
# --------------------------------------------------------------------------

## After each of the hero's steps, every guard who does not know he is there
## gets a look: in his cone and in sight, he may notice.
func _watchers_look() -> void:
	for enemy in _living_enemies():
		if aware.has(enemy) or not _sees(enemy, player.global_position):
			continue
		var tiles: float = TurnRules.tiles_between(enemy.global_position, player.global_position)
		var chance: float = 20.0 if player.is_crouching else 60.0
		if tiles <= 2.0:
			chance = 60.0 if player.is_crouching else 100.0
		if player.shield_active():
			chance += 20.0
		chance *= Progression.detection_factor(_campaign(), _hero_id())
		if _roll() < chance:
			_make_aware(enemy)
		else:
			# Moving in a guard's eye and not being noticed is the craft.
			Progression.award(_campaign(), _hero_id(), &"unseen")


func _sees(enemy: EnemyCharacter, point: Vector2) -> bool:
	var offset: Vector2 = point - enemy.global_position
	if offset.length() > enemy.perception.vision_distance:
		return false
	var forward: Vector2 = Vector2.RIGHT.rotated(enemy.aim_pivot.global_rotation)
	if offset.length() > 1.0 and forward.dot(offset.normalized()) < cos(deg_to_rad(enemy.perception.field_of_view_degrees * 0.5)):
		return false
	return TurnRules.has_sight(level.get_world_2d().direct_space_state, enemy.global_position + Vector2(0, -20), point + Vector2(0, -20))


func _make_aware(enemy: EnemyCharacter, announce: bool = true) -> void:
	if aware.has(enemy) or enemy.health.is_dead:
		return
	aware[enemy] = true
	enemy.ai.target = player
	# The mission hears it the way it hears a real-time detection.
	enemy.ai.change_state(EnemyAIController.State.COMBAT)
	_face(enemy, player.global_position)
	if announce:
		CombatFx.float_text(level, enemy.global_position, "!", Color(1.0, 0.4, 0.3))
		_log("%s SEES YOU" % enemy.display_name)
	roster_changed.emit()


## A loud noise brings everyone in earshot into the fight.
func _noise(at: Vector2, radius: float) -> void:
	for enemy in _living_enemies():
		if not aware.has(enemy) and enemy.global_position.distance_to(at) <= radius:
			_make_aware(enemy)


## A quiet kill is only seen by a guard looking at it.
func _witnesses(at: Vector2) -> void:
	for enemy in _living_enemies():
		if not aware.has(enemy) and enemy.global_position.distance_to(at) <= 420.0 and _sees(enemy, at):
			_make_aware(enemy)


func _on_tank_exploded(tank: FuelTank) -> void:
	if phase != Phase.EXPLORE:
		_noise(tank.global_position, tank.noise_radius)


## Reinforcements that came aboard mid-fight join it, knowing where he is.
func _absorb_newcomers() -> void:
	for enemy in _enemies():
		if not enemy.turn_based:
			enemy.turn_based = true
			_make_aware(enemy)


# --------------------------------------------------------------------------
# Prescience: visions
# --------------------------------------------------------------------------

## Q during the hero's turn: this turn and the enemies' answer become a vision.
func command_vision() -> void:
	if phase != Phase.PLAYER or in_vision:
		return
	if prescience_left <= 0:
		_log("NO PRESCIENCE LEFT")
		return
	prescience_left -= 1
	_start_vision(false)
	points_changed.emit()


func _start_vision(from_explore: bool, taken: TurnSnapshot = null) -> void:
	_snapshot = taken if taken != null else TurnSnapshot.capture(get_tree(), player, _combat_state())
	in_vision = true
	vision_fatal = false
	vision_from_explore = from_explore
	_anchor = VisionAnchor.leave(player, level)
	player.health.survive_at = 1.0
	_log("VISION")
	vision_changed.emit(true)


func _prompt(after: StringName) -> void:
	_after_prompt = after
	phase = Phase.PROMPT
	acting = null
	vision_resolved.emit(vision_fatal)


## This future stands.
func accept_vision() -> void:
	if not in_vision or vision_fatal:
		return
	_clear_vision()
	match _after_prompt:
		&"finish":
			_finish()
		&"player":
			_start_player_turn()
		_:
			phase = Phase.PLAYER
			points_changed.emit()


## Take it back: everything returns to where the vision began.
func rewind_vision() -> void:
	if not in_vision or _snapshot == null:
		return
	var shot: TurnSnapshot = _snapshot
	var from_explore: bool = vision_from_explore
	_snapshot.restore(get_tree(), player)
	_clear_vision(false)
	_log("REWOUND")
	vision_rewound.emit()
	if from_explore:
		_finish()
		return
	_restore_combat_state(shot.combat)
	phase = Phase.PLAYER
	acting = player
	turn_changed.emit(player)
	points_changed.emit()
	roster_changed.emit()


## `accepted`: the shadow's future stands and the hero steps into it;
## otherwise the shadow is simply gone.
func _clear_vision(accepted: bool = true) -> void:
	if not in_vision:
		return
	in_vision = false
	vision_fatal = false
	_snapshot = null
	if is_instance_valid(_anchor):
		if accepted:
			_anchor.reunite()
		else:
			_anchor.dissolve()
	_anchor = null
	if is_instance_valid(player):
		player.health.survive_at = 0.0
	vision_changed.emit(false)


func _on_hero_floored() -> void:
	if in_vision:
		vision_fatal = true
		CombatFx.float_text(level, player.global_position, "YOU DIE HERE", Color(0.6, 0.8, 1.0))


func _combat_state() -> Dictionary:
	var aware_list: Array = []
	for enemy in aware:
		aware_list.append(enemy)
	return {"points": points, "evasion": evasion, "round": round_number, "aware": aware_list}


func _restore_combat_state(state: Dictionary) -> void:
	points = state.get("points", max_points)
	evasion = state.get("evasion", 0.0)
	round_number = state.get("round", round_number)
	aware.clear()
	for enemy in state.get("aware", []):
		if is_instance_valid(enemy):
			aware[enemy] = true
			(enemy as EnemyCharacter).ai.state = EnemyAIController.State.COMBAT
	for enemy in _enemies():
		enemy.turn_based = true


# --------------------------------------------------------------------------
# Shared
# --------------------------------------------------------------------------

## One tile, walked: velocity drives the walk cycle while the body glides.
func _step(actor: Node2D, cell: Vector2i, speed: float) -> void:
	var goal: Vector2 = IsoMath.cell_to_world(cell)
	_face(actor, goal)
	while actor.global_position.distance_to(goal) > 1.0:
		if phase == Phase.EXPLORE or not is_instance_valid(actor):
			return
		var delta: float = get_physics_process_delta_time()
		var direction: Vector2 = actor.global_position.direction_to(goal)
		actor.velocity = direction * speed
		actor.global_position = actor.global_position.move_toward(goal, speed * delta)
		await get_tree().physics_frame
	actor.global_position = goal


func _lunge(actor: Node2D, toward: Vector2) -> void:
	var home: Vector2 = actor.global_position
	var reach: Vector2 = home + home.direction_to(toward) * 18.0
	var tween: Tween = actor.create_tween()
	tween.tween_property(actor, "global_position", reach, 0.08)
	tween.tween_property(actor, "global_position", home, 0.14)
	await tween.finished


func _face(actor: Node2D, point: Vector2) -> void:
	if actor == player:
		if player.global_position.distance_squared_to(point) > 1.0:
			player.aim_direction = player.global_position.direction_to(point)
			player.aim_pivot.rotation = player.aim_direction.angle()
	elif actor is EnemyCharacter:
		(actor as EnemyCharacter).face_position(point)


func _report(target: Node2D, outcome: DamageResolver.Outcome, damage: float) -> void:
	match outcome:
		DamageResolver.Outcome.BLOCKED:
			CombatFx.float_text(level, target.global_position, "SHIELD", Color(0.55, 0.8, 1.0))
			_log("BLOCKED BY THE SHIELD")
		DamageResolver.Outcome.DAMAGED:
			CombatFx.float_text(level, target.global_position, "-%d" % roundi(damage), Color(1.0, 0.55, 0.4) if target == player else Color(1.0, 0.9, 0.6))
			var health: HealthComponent = HealthComponent.find_on(target)
			if target != player and health != null and health.is_dead:
				_log("%s DOWN" % (target as EnemyCharacter).display_name)
				roster_changed.emit()
			elif target != player and target is EnemyCharacter:
				_make_aware(target as EnemyCharacter)
		_:
			CombatFx.float_text(level, target.global_position, "MISS", Color(0.8, 0.8, 0.8))


func _roll() -> float:
	return forced_roll if forced_roll >= 0.0 else _rng.randf_range(0.0, 100.0)


func _can_shoot(target: Node2D) -> bool:
	return target.global_position.distance_to(player.global_position) <= 900.0 \
		and TurnRules.has_sight(level.get_world_2d().direct_space_state, player.global_position + Vector2(0, -20), target.global_position + Vector2(0, -12))


## What a click at `point` would target: a Harkonnen (body or feet) or a tank.
## The nearest wins, and a click right on a tank beats a guard caught only by
## the lenient probe below his body.
func target_at(point: Vector2) -> Node2D:
	var best: Node2D
	var distance: float = 44.0
	for enemy in _living_enemies():
		var direct: float = point.distance_to(enemy.global_position)
		var body: float = (point + Vector2(0, 40)).distance_to(enemy.global_position) + 12.0
		var gap: float = minf(direct, body)
		if gap < distance:
			distance = gap
			best = enemy
	for node: Node in get_tree().get_nodes_in_group("fuel_tanks"):
		var tank: FuelTank = node as FuelTank
		if tank == null or tank.detonated:
			continue
		var gap: float = point.distance_to(tank.global_position)
		if gap < 34.0 and gap < distance:
			distance = gap
			best = tank
	return best


func _log(text: String) -> void:
	last_event = text
	event_logged.emit(text)


func _camera() -> TacticalCamera:
	return player.get_node_or_null("TacticalCamera") as TacticalCamera if is_instance_valid(player) else null


## Frame the hero and everyone who knows he is there, as close as fits.
func _frame_fight() -> void:
	var camera: TacticalCamera = _camera()
	if camera == null:
		return
	var box: Rect2 = Rect2(player.global_position, Vector2.ZERO)
	var framed: Array[EnemyCharacter] = _aware_living()
	if framed.is_empty():
		# Going in unseen: frame whoever is close enough to matter.
		for enemy in _living_enemies():
			if enemy.global_position.distance_to(player.global_position) <= 620.0:
				framed.append(enemy)
	for enemy in framed:
		box = box.expand(enemy.global_position)
	box = box.grow(220.0)
	var view: Vector2 = camera.get_viewport_rect().size
	var fit: float = minf(view.x / maxf(box.size.x, 1.0), (view.y - 260.0) / maxf(box.size.y, 1.0))
	camera.set_combat_view(clampf(fit, min_zoom, max_zoom))
	camera.center_on(box.get_center() + Vector2(0, 30))


func _enemies() -> Array[EnemyCharacter]:
	var result: Array[EnemyCharacter] = []
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		# Dormant: behind a door the level has not opened yet; not in play.
		if node is EnemyCharacter and not node.is_queued_for_deletion() and not node.get_meta("dormant", false):
			result.append(node)
	return result


func _living_enemies() -> Array[EnemyCharacter]:
	return _enemies().filter(func(e: EnemyCharacter) -> bool: return not e.health.is_dead)


func _aware_living() -> Array[EnemyCharacter]:
	return _living_enemies().filter(func(e: EnemyCharacter) -> bool: return aware.has(e))


## The turn order for the HUD: the hero, then those who hunt him.
func turn_order() -> Array[Node2D]:
	var order: Array[Node2D] = [player]
	for enemy in _aware_living():
		order.append(enemy)
	return order


func _occupied(except: Node2D) -> Dictionary:
	var cells: Dictionary = {}
	if player != except and not player.health.is_dead:
		cells[IsoMath.world_to_cell(player.global_position)] = true
	for enemy in _living_enemies():
		if enemy != except:
			cells[IsoMath.world_to_cell(enemy.global_position)] = true
	return cells


func _actor_on(cell: Vector2i) -> Node2D:
	for enemy in _living_enemies():
		if IsoMath.world_to_cell(enemy.global_position) == cell:
			return enemy
	return null
