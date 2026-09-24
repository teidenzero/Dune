class_name PlayerController
extends CharacterBody2D
## Paul as a commanded unit. He reads no movement or aim from the keyboard or
## mouse: SquadManager turns clicks into the orders below, exactly as it does
## for the Fremen, and Paul carries them out along the navigation mesh.

signal order_changed
signal weapon_slot_changed(slot: int)

enum Order { IDLE, MOVE, ATTACK, MELEE, INTERACT }
## COMMANDED: the RTS unit of the squad scope. DIRECT: the solo scope's
## Crusader-style hero - WASD, mouse aim, dodge, shield.
enum ControlMode { COMMANDED, DIRECT }

@export_range(1.0, 1000.0, 1.0) var walk_speed: float = 180.0
## Double right-click runs. Faster, and far louder.
@export_range(1.0, 1000.0, 1.0) var sprint_speed: float = 280.0
@export_range(1.0, 1000.0, 1.0) var crouch_speed: float = 110.0
@export_range(1.0, 5000.0, 1.0) var acceleration: float = 1200.0
@export_range(1.0, 5000.0, 1.0) var deceleration: float = 1600.0
@export var arrive_distance: float = 10.0
## Weapons on Z / X. Empty uses the WeaponController's own.
@export var loadout: Array[WeaponData] = []
## An idle Paul who is shot at shoots back. Orders always take priority.
@export var retaliate: bool = true
## Drawn look; without it the placeholder shapes draw.
@export var art: CharacterArt
@export var control_mode: ControlMode = ControlMode.COMMANDED
## Which hero this body is, for growth (HeroProgress) and stats.
@export var hero_id: StringName = &"paul"

@export_group("Solo")
## The Weirding step: a short dash that outpaces a round in flight.
@export var dodge_speed: float = 620.0
@export var dodge_seconds: float = 0.22
@export var dodge_cooldown: float = 0.9
## Worm sign per second a running Holtzman shield drives into open sand.
@export var shield_worm_sign: float = 12.0
## Isometric interiors: WASD walks the grid's 8 directions and the mouse aim
## snaps to the nearest of them, as the 8-direction sprites will face.
@export var isometric: bool = false

var order: Order = Order.IDLE
var order_target: Node2D
var destination: Vector2
var waypoints: Array[Vector2] = []
var running: bool = false
## Shots still to fire on the current ATTACK order: one per click.
var shots_ordered: int = 0
var selected: bool = false:
	set(value):
		selected = value and not health.is_dead
		queue_redraw()
var is_sprinting: bool = false
var is_crouching: bool = false
var current_speed: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var equipped_slot: int = 0

var _melee_slow: bool = false
var _melee_committed: bool = false
## The player's button is still down: the blade is up and nothing is decided.
var _melee_holding: bool = false
var _interacting: InteractionPoint
var _stuck_anchor: Vector2
var _stuck_time: float = 0.0
## Solo scope state.
var dodging: bool = false
var shield: ShieldComponent
var _dodge_time: float = 0.0
var _dodge_wait: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _shield_sign_elapsed: float = 0.0
var _held_point: InteractionPoint
## Turn-based combat (the interiors) moves and acts for him; his own orders
## and real-time physics stand still while it is set. Nothing carries across
## the switch either way: back in real time he stands and waits, whatever
## happened (or was taken back) in the fight.
var turn_based: bool = false:
	set(value):
		turn_based = value
		stop()
		velocity = Vector2.ZERO
		dodging = false

@onready var aim_pivot: Node2D = $AimPivot
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var weapon_controller: WeaponController = $WeaponController
@onready var health: HealthComponent = $HealthComponent
@onready var stealth_profile: StealthProfile = $StealthProfile
@onready var recon: ReconObserverComponent = $ReconObserverComponent
@onready var melee: MeleeController = $MeleeController
@onready var prescience: PrescienceController = $PrescienceController
@onready var prescience_energy: PrescienceEnergyComponent = $PrescienceEnergy


func _ready() -> void:
	health.died.connect(_on_died)
	health.damage_received.connect(_on_damage_received)
	melee.attack_finished.connect(_on_melee_finished)
	if loadout.is_empty():
		loadout.append(weapon_controller.weapon_data)
	elif weapon_controller.weapon_data != loadout[0]:
		weapon_controller.equip(loadout[0])
	aim_direction = Vector2.RIGHT.rotated(aim_pivot.rotation)
	_stuck_anchor = global_position
	if art != null and art.has_sprites():
		_use_drawn_art()
	call_deferred("_apply_growth")


## What this hero has grown into, applied to real-time play: a skilled blade
## charges the slow stroke faster; prescience ranks deepen the reserve.
func _apply_growth() -> void:
	var campaign: CampaignState = Progression.campaign_of(self)
	if campaign == null:
		return
	melee.slow_charge_threshold *= Progression.slow_charge_factor(campaign, hero_id)
	prescience_energy.max_energy += 10.0 * campaign.hero_progress(hero_id).prescience_bonus()
	prescience_energy.reset_energy()


## V outside a fight: a dose of spice refills prescience, and saturates.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_spice") and not event.is_echo() and not turn_based and not health.is_dead:
		if use_spice():
			get_viewport().set_input_as_handled()


func use_spice() -> bool:
	var campaign: CampaignState = Progression.campaign_of(self)
	if campaign == null or campaign.item_count(&"spice_dose") <= 0:
		return false
	campaign.add_item(&"spice_dose", -1)
	prescience_energy.current_energy = prescience_energy.max_energy
	prescience_energy.energy_changed.emit(prescience_energy.current_energy, prescience_energy.max_energy)
	Progression.saturate(campaign, hero_id, 2.0)
	return true


## Swap the placeholder body for the character art; the shadow stays.
func _use_drawn_art() -> void:
	var sprite: UnitSprite = art.make_sprite(self, walk_speed)
	add_child(sprite)
	# Above the shadow, under the aim marker and the blade arc.
	move_child(sprite, $Shadow.get_index() + 1)
	art.apply_to(sprite, self)
	$Body.hide()
	$Hood.hide()
	$NameLabel.raise(art.world_height * 0.75)


# --------------------------------------------------------------------------
# Orders
# --------------------------------------------------------------------------

func move_to(point: Vector2, run: bool = false) -> void:
	if health.is_dead or not point.is_finite():
		return
	_set_order(Order.MOVE)
	waypoints.clear()
	running = run
	# Running means standing up, as sprinting always did.
	if run:
		is_crouching = false
	_go(point)


## Shift + right-click: walk the queued points in order.
func queue_move(point: Vector2) -> void:
	if order != Order.MOVE:
		move_to(point, running)
		return
	waypoints.append(point)
	queue_redraw()


## One click, one shot: Paul gets a line on the target if he has none, fires,
## and waits for the next click. Clicking again at the same target queues
## another round, never more than the magazine holds.
func attack(target: Node2D) -> void:
	if health.is_dead or not _valid_target(target):
		return
	var queued: int = shots_ordered if order == Order.ATTACK and order_target == target else 0
	_set_order(Order.ATTACK, target)
	shots_ordered = mini(queued + 1, maxi(weapon_controller.current_ammo, 1))
	running = false


## Left button down on a target: the blade comes up at once and Paul closes
## while it charges. What the stroke becomes is decided on melee_let_go().
func melee_hold(target: Node2D) -> bool:
	if health.is_dead or not _valid_target(target) or not melee.enabled:
		return false
	_set_order(Order.MELEE, target)
	_melee_holding = true
	_melee_slow = false
	_melee_committed = false
	running = false
	_try_raise_blade()
	return true


## Button up. A charged blade (held past the threshold) becomes the slow
## stroke; anything shorter is the quick one. In reach it lands now, otherwise
## on arrival - a slow stroke arrives with the blade still raised. `slow_hint`
## decides when the blade could not come up yet (mid-recovery).
func melee_let_go(slow_hint: bool = false) -> void:
	if order != Order.MELEE or not _melee_holding:
		return
	_melee_holding = false
	if _melee_committed and melee.state == MeleeController.State.CHARGING:
		_melee_slow = melee.slow_ready
		if not _melee_slow and not _in_reach():
			# A quick cut from out of reach: lower the blade, run in, cut.
			melee.cancel()
			_melee_committed = false
	else:
		_melee_slow = slow_hint


func _try_raise_blade() -> void:
	if melee.can_attack() and not prescience.blocks_combat():
		melee.begin_input()
		_melee_committed = melee.state == MeleeController.State.CHARGING


func _in_reach() -> bool:
	return _valid_target(order_target) and global_position.distance_to(order_target.global_position) <= melee.hitbox_base_range * 0.8


## Walk into reach and cut. `slow` commits to the shield-penetrating stroke.
func melee_strike(target: Node2D, slow: bool) -> void:
	if health.is_dead or not _valid_target(target) or not melee.enabled:
		return
	_set_order(Order.MELEE, target)
	_melee_slow = slow
	_melee_committed = false
	running = false


## Walk to a spice machine, a beacon, a sabotage point, and use it.
func interact_with(target: Node2D) -> void:
	if health.is_dead or not is_instance_valid(target):
		return
	_set_order(Order.INTERACT, target)


func stop() -> void:
	_set_order(Order.IDLE)


## Checkpoints and mission phases place Paul directly; the camera goes with him.
func teleport_to(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	stop()
	var camera: TacticalCamera = get_node_or_null("TacticalCamera") as TacticalCamera
	if camera != null:
		camera.snap_to(point)


## One shot along the current aim, unless prescience holds Paul's hands.
func fire_weapon() -> bool:
	if health.is_dead or prescience.blocks_combat():
		return false
	return weapon_controller.try_fire()


## Direct crysknife control, for scripted sequences and tests; players use
## melee_strike() through E / F targeting.
func melee_press() -> void:
	if not health.is_dead and not prescience.blocks_combat():
		melee.begin_input()


func melee_release() -> void:
	melee.release_input()


## Hook for scripted control (tests, cutscenes): runs every physics tick just
## before the aim pivot is turned to `aim_direction`. Orders set the aim.
func _update_aim() -> void:
	pass


func set_crouching(value: bool) -> void:
	is_crouching = value
	if value:
		running = false


## Returns false for an empty slot or the weapon already in hand.
func equip_slot(slot: int) -> bool:
	if slot < 0 or slot >= loadout.size() or loadout[slot] == null or slot == equipped_slot:
		return false
	if not weapon_controller.equip(loadout[slot]):
		return false
	equipped_slot = slot
	weapon_slot_changed.emit(slot)
	return true


func order_name() -> String:
	return Order.keys()[order]


func _set_order(value: Order, target: Node2D = null) -> void:
	if is_instance_valid(_interacting):
		_interacting.command_hold = false
	_interacting = null
	if melee.state == MeleeController.State.CHARGING:
		melee.cancel()
	_melee_holding = false
	order = value
	order_target = target
	_stuck_time = 0.0
	_stuck_anchor = global_position
	shots_ordered = 0
	if value == Order.IDLE:
		waypoints.clear()
		running = false
	order_changed.emit()
	queue_redraw()


func _go(point: Vector2) -> void:
	destination = point
	if _navigation_ready():
		agent.target_position = point


# --------------------------------------------------------------------------
# Runtime
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if health.is_dead:
		if Input.is_action_just_pressed("restart_mission"):
			get_tree().reload_current_scene()
		return
	if turn_based:
		return
	if control_mode == ControlMode.DIRECT:
		_direct_control(delta)
		return
	var desired: Vector2 = Vector2.ZERO
	match order:
		Order.MOVE:
			desired = _run_move()
		Order.ATTACK:
			desired = _run_attack()
		Order.MELEE:
			desired = _run_melee()
		Order.INTERACT:
			desired = _run_interact()
	if prescience.blocks_sprint():
		running = false
	_dodge_wait = maxf(_dodge_wait - delta, 0.0)
	if dodging:
		# The step overrides the order for its fifth of a second; the order
		# picks up again from wherever it lands.
		_dodge_time -= delta
		velocity = _dodge_direction * dodge_speed
		dodging = _dodge_time > 0.0
	else:
		var rate: float = deceleration if desired.is_zero_approx() else acceleration
		velocity = velocity.move_toward(desired, rate * delta)
	move_and_slide()
	current_speed = get_real_velocity().length()
	is_sprinting = (running and not is_crouching and not desired.is_zero_approx()) or dodging
	_shield_worm_sign(delta)
	_check_stuck(delta, desired)
	stealth_profile.update_profile(is_crouching, is_sprinting, current_speed, delta)
	$Body.scale = Vector2(1.0, 0.65) if is_crouching else Vector2.ONE
	$Hood.scale = $Body.scale
	if order == Order.MOVE and current_speed > 8.0:
		aim_direction = velocity.normalized()
	if prescience.blocks_combat() and melee.state == MeleeController.State.CHARGING:
		melee.cancel()
	_update_aim()
	aim_pivot.rotation = aim_direction.angle()
	if selected and (order == Order.MOVE or not waypoints.is_empty()):
		queue_redraw()


# --------------------------------------------------------------------------
# Solo scope: direct control
# --------------------------------------------------------------------------

## Switch Paul to the solo scope's direct control. `with_shield` fits a
## personal Holtzman shield, off until the player raises it.
func enable_direct_control(with_shield: bool = true) -> void:
	control_mode = ControlMode.DIRECT
	stop()
	selected = false
	if with_shield:
		fit_shield()


## A personal Holtzman shield, lowered. Solo heroes carry one in either
## control scheme; the isometric interiors keep Paul on click orders.
func fit_shield() -> void:
	if shield == null:
		shield = ShieldComponent.new()
		shield.name = "ShieldComponent"
		shield.enabled = false
		add_child(shield)
		var visuals: Node2D = (load("res://scripts/ui/shield_visuals.gd") as GDScript).new()
		visuals.name = "ShieldVisuals"
		visuals.set("shield", shield)
		visuals.set("actor", self)
		visuals.set("shimmer_radius", 28.0)
		visuals.z_index = 3
		add_child(visuals)


func set_shield(active: bool) -> void:
	if shield != null:
		shield.enabled = active and not health.is_dead
		_shield_sign_elapsed = 0.0


func shield_active() -> bool:
	return shield != null and shield.enabled


## A dodge in progress outpaces rounds in flight; blades still find him.
func evades(hit: HitContext) -> bool:
	return dodging and hit.attack_type == HitContext.Type.RANGED


func dodge_ready_ratio() -> float:
	return 1.0 - clampf(_dodge_wait / maxf(dodge_cooldown, 0.01), 0.0, 1.0)


func _direct_control(delta: float) -> void:
	_dodge_wait = maxf(_dodge_wait - delta, 0.0)
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if isometric:
		direction = IsoMath.keys_to_move(direction)
	if Input.is_action_just_pressed("crouch"):
		set_crouching(not is_crouching)
	if Input.is_action_pressed("sprint"):
		is_crouching = false
	if Input.is_action_just_pressed("dodge"):
		try_dodge(direction)
	var running: bool = Input.is_action_pressed("sprint") and not direction.is_zero_approx() and not prescience.blocks_sprint()
	if dodging:
		_dodge_time -= delta
		velocity = _dodge_direction * dodge_speed
		if _dodge_time <= 0.0:
			dodging = false
	else:
		var speed: float = crouch_speed if is_crouching else (sprint_speed if running else walk_speed)
		speed *= melee.get_move_speed_multiplier() * prescience.get_move_speed_multiplier()
		var rate: float = deceleration if direction.is_zero_approx() else acceleration
		velocity = velocity.move_toward(direction * speed, rate * delta)
	move_and_slide()
	current_speed = get_real_velocity().length()
	is_sprinting = (running or dodging) and current_speed > 8.0
	stealth_profile.update_profile(is_crouching, is_sprinting, current_speed, delta)
	$Body.scale = Vector2(1.0, 0.65) if is_crouching else Vector2.ONE
	$Hood.scale = $Body.scale
	_aim_at_mouse()
	_update_aim()
	aim_pivot.rotation = aim_direction.angle()
	_direct_combat()
	_direct_interact()
	_shield_worm_sign(delta)


## Space. Toward where you are moving, or a step back from where you aim.
func try_dodge(direction: Vector2 = Vector2.ZERO) -> bool:
	if _dodge_wait > 0.0 or dodging or health.is_dead:
		return false
	if melee.state != MeleeController.State.IDLE and melee.state != MeleeController.State.CHARGING:
		return false
	melee.cancel()
	if direction.is_zero_approx() and control_mode == ControlMode.COMMANDED and velocity.length() > 20.0:
		direction = velocity
	_dodge_direction = direction.normalized() if not direction.is_zero_approx() else -aim_direction
	dodging = true
	is_crouching = false
	_dodge_time = dodge_seconds
	_dodge_wait = dodge_cooldown
	return true


func _aim_at_mouse() -> void:
	var mouse_delta: Vector2 = get_global_mouse_position() - global_position
	if mouse_delta.length_squared() > 1.0:
		aim_direction = IsoMath.snap8(mouse_delta) if isometric else mouse_delta.normalized()


## 0..7 clockwise from screen-up: the sprite direction to show.
func facing_index() -> int:
	return IsoMath.facing_index(aim_direction)


func _direct_combat() -> void:
	if prescience.blocks_combat():
		melee.cancel()
	elif Input.is_action_just_pressed("melee_attack"):
		melee.begin_input()
	elif Input.is_action_just_released("melee_attack"):
		melee.release_input()
	if Input.is_action_just_pressed("reload"):
		weapon_controller.start_reload()
	if Input.is_action_just_pressed("weapon_1"):
		equip_slot(0)
	elif Input.is_action_just_pressed("weapon_2"):
		equip_slot(1)
	if Input.is_action_just_pressed("shield_toggle"):
		set_shield(not shield_active())
	if weapon_controller.enabled and weapon_controller.current_ammo == 0 and not weapon_controller.is_reloading:
		weapon_controller.start_reload()
	if dodging:
		return
	var automatic: bool = weapon_controller.weapon_data.automatic
	var firing: bool = Input.is_action_pressed("fire_primary") if automatic else Input.is_action_just_pressed("fire_primary")
	if firing:
		fire_weapon()


## F: hold at a beacon or sabotage point, tap at a machine.
func _direct_interact() -> void:
	var holding: bool = Input.is_action_pressed("interact")
	var point: InteractionPoint = null
	for node: Node in get_tree().get_nodes_in_group("interaction_points"):
		var candidate: InteractionPoint = node as InteractionPoint
		if candidate != null and candidate.available() and candidate.player_in_range():
			point = candidate
			break
	if _held_point != null and (_held_point != point or not holding):
		if is_instance_valid(_held_point):
			_held_point.command_hold = false
		_held_point = null
	if point != null and holding:
		point.command_hold = true
		_held_point = point
	if Input.is_action_just_pressed("interact"):
		for node: Node in get_tree().get_nodes_in_group("worm_machines"):
			if node is SpiceMachine and node.player_in_range():
				node.toggle()
				break


## Dune's oldest rule: a shield on open sand calls the worm into a frenzy.
## Interiors (the isometric maps) have steel underfoot: no sand, no worm.
func _shield_worm_sign(delta: float) -> void:
	if not shield_active() or isometric:
		return
	var terrain: TerrainSafetyComponent = TerrainSafetyComponent.find_on(self)
	if terrain != null and terrain.is_safe():
		return
	_shield_sign_elapsed += delta
	if _shield_sign_elapsed >= 0.5:
		var emitter: WormSignEmitter = get_node_or_null("WormSignEmitter") as WormSignEmitter
		if emitter != null:
			emitter.impulse(shield_worm_sign * _shield_sign_elapsed, "Holtzman shield")
		_shield_sign_elapsed = 0.0


func _move_speed() -> float:
	var speed: float = crouch_speed if is_crouching else (sprint_speed if running else walk_speed)
	return speed * melee.get_move_speed_multiplier() * prescience.get_move_speed_multiplier()


## Velocity toward `destination` along the navigation path.
func _steer() -> Vector2:
	var next: Vector2 = destination
	if _navigation_ready():
		if agent.is_navigation_finished():
			return Vector2.ZERO
		next = agent.get_next_path_position()
	elif global_position.distance_to(destination) <= arrive_distance:
		return Vector2.ZERO
	return global_position.direction_to(next) * _move_speed()


func _run_move() -> Vector2:
	if global_position.distance_to(destination) <= arrive_distance or (_navigation_ready() and agent.is_navigation_finished()):
		if waypoints.is_empty():
			_set_order(Order.IDLE)
			return Vector2.ZERO
		_go(waypoints.pop_front())
	return _steer()


func _run_attack() -> Vector2:
	if not _valid_target(order_target):
		_set_order(Order.IDLE)
		return Vector2.ZERO
	var target_position: Vector2 = order_target.global_position
	var in_range: bool = global_position.distance_to(target_position) <= weapon_controller.weapon_data.effective_range
	if in_range and has_line_of_sight(order_target):
		aim_direction = global_position.direction_to(target_position)
		aim_pivot.rotation = aim_direction.angle()
		if weapon_controller.current_ammo <= 0 and not weapon_controller.is_reloading:
			# The trigger clicks on nothing: reloading is the player's call.
			weapon_controller.try_fire()
			_set_order(Order.IDLE)
		elif weapon_controller.can_fire and fire_weapon():
			shots_ordered -= 1
			if shots_ordered <= 0:
				_set_order(Order.IDLE)
		return Vector2.ZERO
	if destination.distance_to(target_position) > 24.0:
		_go(target_position)
	return _steer()


func _run_melee() -> Vector2:
	var target_alive: bool = _valid_target(order_target)
	if target_alive:
		aim_direction = global_position.direction_to(order_target.global_position)
	var reach: float = melee.hitbox_base_range * 0.8
	var distance: float = global_position.distance_to(order_target.global_position) if target_alive else INF
	if _melee_holding and not _melee_committed:
		# The button went down mid-recovery: raise the blade the moment it can.
		_try_raise_blade()
	if _melee_committed:
		if melee.state != MeleeController.State.CHARGING:
			# The stroke is in the air; Paul finishes it before anything else.
			return Vector2.ZERO
		if not target_alive:
			melee.cancel()
			_set_order(Order.IDLE)
			return Vector2.ZERO
		if _melee_holding:
			# Still deciding: blade up, closing, never cutting on his own.
			return _approach(order_target.global_position) if distance > reach else Vector2.ZERO
		if distance <= reach and (not _melee_slow or melee.slow_ready):
			melee.release_input()
			return Vector2.ZERO
		# Blade raised: keep after him, slowly, until he is in reach.
		return _approach(order_target.global_position) if distance > reach else Vector2.ZERO
	if not target_alive:
		_set_order(Order.IDLE)
		return Vector2.ZERO
	if melee.can_attack() and not prescience.blocks_combat():
		# The slow stroke is raised on the way in, so it lands on arrival
		# instead of giving a moving target a second to step away.
		var raise_at: float = reach + (walk_speed * melee.slow_charge_threshold if _melee_slow else 0.0)
		if distance <= raise_at:
			melee.begin_input()
			_melee_committed = melee.state == MeleeController.State.CHARGING
			if _melee_committed and not _melee_slow and distance <= reach:
				melee.release_input()
			if distance <= reach:
				return Vector2.ZERO
	return _approach(order_target.global_position)


func _approach(point: Vector2) -> Vector2:
	if destination.distance_to(point) > 12.0:
		_go(point)
	return _steer()


func _run_interact() -> Vector2:
	var target: Node2D = order_target
	if not is_instance_valid(target):
		_set_order(Order.IDLE)
		return Vector2.ZERO
	if target is InteractionPoint:
		var point: InteractionPoint = target
		if not point.available():
			_set_order(Order.IDLE)
			return Vector2.ZERO
		if point.player_in_range():
			_interacting = point
			point.command_hold = true
			return Vector2.ZERO
	elif target.has_method("player_in_range") and target.player_in_range():
		if target.has_method("toggle"):
			target.toggle()
		_set_order(Order.IDLE)
		return Vector2.ZERO
	if destination.distance_to(target.global_position) > 12.0:
		_go(target.global_position)
	return _steer()


func _on_melee_finished(_data: MeleeAttackData, _hits: int) -> void:
	if order == Order.MELEE and _melee_committed:
		_set_order(Order.IDLE)


## A body that stops making progress asks the navigation server for a fresh path.
func _check_stuck(delta: float, desired: Vector2) -> void:
	if desired.is_zero_approx() or global_position.distance_to(_stuck_anchor) > 12.0:
		_stuck_anchor = global_position
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time > 0.8:
		_stuck_time = 0.0
		_go(destination)


func _navigation_ready() -> bool:
	return agent != null and NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) > 0


func _valid_target(candidate: Variant) -> bool:
	# While the game is paused every actor reports can_process() false, yet
	# orders given during the pause must still be accepted.
	if not is_instance_valid(candidate) or candidate == self or not (candidate.can_process() or get_tree().paused):
		return false
	if candidate.get_meta("team_id", &"") == &"player":
		return false
	var target_health: HealthComponent = HealthComponent.find_on(candidate)
	return target_health != null and not target_health.is_dead


func has_line_of_sight(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate):
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, candidate.global_position, 3, [get_rid()])
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == candidate


## Hit while standing idle, he turns on whoever fired. Shooting back is the
## player's click: every round Paul fires is one the player chose.
func _on_damage_received(_amount: float, source: Node) -> void:
	if retaliate and not turn_based and order == Order.IDLE and not health.is_dead and source is Node2D and source.get_meta("team_id", &"") == &"harkonnen":
		aim_direction = global_position.direction_to((source as Node2D).global_position)
		aim_pivot.rotation = aim_direction.angle()


func _on_died() -> void:
	set_shield(false)
	dodging = false
	_set_order(Order.IDLE)
	velocity = Vector2.ZERO
	is_sprinting = false
	current_speed = 0.0
	selected = false
	stealth_profile.update_profile(is_crouching, false, 0.0, 0.0, false)
	weapon_controller.disable()
	melee.disable()
	prescience.deactivate()
	$Body.modulate = Color(0.4, 0.4, 0.4)
	$NameLabel.text = "DOWN"


# --------------------------------------------------------------------------
# Selection feedback
# --------------------------------------------------------------------------

func _draw() -> void:
	if not selected:
		return
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color(0.55, 0.95, 0.75, 0.9), 2.5, true)
	# The route ahead, so an order visibly took.
	var points: PackedVector2Array = [Vector2.ZERO]
	if order == Order.MOVE:
		if _navigation_ready():
			var path: PackedVector2Array = agent.get_current_navigation_path()
			for index in range(agent.get_current_navigation_path_index(), path.size()):
				points.append(to_local(path[index]))
		else:
			points.append(to_local(destination))
		for point in waypoints:
			points.append(to_local(point))
	if points.size() > 1:
		draw_polyline(points, Color(0.55, 0.95, 0.75, 0.45), 2.0, true)
		draw_circle(points[points.size() - 1], 5.0, Color(0.55, 0.95, 0.75, 0.7))
