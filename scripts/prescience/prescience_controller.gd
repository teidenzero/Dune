class_name PrescienceController
extends Node
## Paul's prescience: a short, expensive look at what the battlefield is already
## committed to doing.
##
## It owns activation rules, the real-time duration, and the set of projections.
## It does not decide what the future is - FuturePredictor reads existing AI
## intent - and it does not own the clock, TimeScaleManager does.

signal prescience_started
signal prescience_ended
signal prescience_denied(reason: String)
signal projections_updated

@export var player: PlayerController
@export var energy: PrescienceEnergyComponent
## Real seconds, deliberately not game seconds: the world is nearly stopped.
@export var duration: float = 3.5
@export_range(0.05, 1.0, 0.01) var world_time_scale: float = 0.2
## How far ahead, in normal-world seconds, the projection reaches.
@export var prediction_horizon: float = 3.0
@export var projection_offsets: PackedFloat32Array = PackedFloat32Array([1.0, 2.0, 3.0])
@export var updates_per_second: float = 8.0
## Short anti-double-tap guard; the energy cost is the real limiter.
@export var lockout_seconds: float = 0.5
@export_range(0.1, 1.0, 0.05) var move_speed_multiplier: float = 0.6
## A firing line passing this close to Paul is called out as dangerous.
@export var danger_radius: float = 60.0
## How far ahead a plan is rehearsed: its whole route, up to this many seconds.
@export var rehearsal_limit: float = 8.0

var active: bool = false
var remaining: float = 0.0
var lockout: float = 0.0
var projections: Array[FuturePredictor.FutureTrack] = []
var danger: bool = false
var last_denied_reason: String = ""
var last_denied_time: int = 0

var _squad: SquadManager
var _recon: ReconManager
var _update_wait: float = 0.0


func _ready() -> void:
	add_to_group("prescience")
	call_deferred("_bind")


func _bind() -> void:
	_squad = get_tree().get_first_node_in_group("squad_manager") as SquadManager
	_recon = get_tree().get_first_node_in_group("recon_manager") as ReconManager
	if is_instance_valid(player):
		player.health.died.connect(func() -> void: deactivate())


# --------------------------------------------------------------------------
# Activation
# --------------------------------------------------------------------------

func toggle() -> bool:
	if active:
		deactivate()
		return true
	return activate()


func can_activate() -> String:
	if not is_instance_valid(player) or player.health.is_dead:
		return "PAUL IS DOWN"
	if active:
		return "ALREADY ACTIVE"
	if lockout > 0.0:
		return "PRESCIENCE RECOVERING"
	if not TimeScaleManager.is_available(TimeScaleManager.Source.PRESCIENCE):
		return "TIME IS ALREADY BENT"
	if energy == null or not energy.can_spend():
		return "NOT ENOUGH PRESCIENCE"
	return ""


func activate() -> bool:
	var reason: String = can_activate()
	if reason != "":
		_deny(reason)
		return false
	if not TimeScaleManager.request(TimeScaleManager.Source.PRESCIENCE, world_time_scale):
		_deny("TIME IS ALREADY BENT")
		return false
	energy.spend()
	energy.regenerating = false
	active = true
	remaining = maxf(duration, 0.1)
	_update_wait = 0.0
	_rebuild()
	prescience_started.emit()
	return true


func deactivate() -> void:
	if not active:
		return
	active = false
	remaining = 0.0
	lockout = maxf(lockout_seconds, 0.0)
	projections.clear()
	danger = false
	if energy != null:
		energy.regenerating = true
	TimeScaleManager.release(TimeScaleManager.Source.PRESCIENCE)
	prescience_ended.emit()
	projections_updated.emit()


func _deny(reason: String) -> void:
	last_denied_reason = reason
	last_denied_time = Time.get_ticks_msec()
	prescience_denied.emit(reason)


# --------------------------------------------------------------------------
# Gameplay gates used by the player controller
# --------------------------------------------------------------------------

## Prescience is an observation state, not bullet time.
func blocks_combat() -> bool:
	return active


func blocks_sprint() -> bool:
	return active


func get_move_speed_multiplier() -> float:
	return move_speed_multiplier if active else 1.0


func remaining_ratio() -> float:
	return clampf(remaining / maxf(duration, 0.1), 0.0, 1.0)


# --------------------------------------------------------------------------
# Runtime
# --------------------------------------------------------------------------

## Off where another system owns Q (the interiors' turn-based combat).
var input_enabled: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not InputMap.has_action("prescience") or event.is_echo():
		return
	if not event.is_action_pressed("prescience"):
		return
	toggle()
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _process(delta: float) -> void:
	# Duration and lockout run on real time; the world is at 20% speed.
	var real: float = TimeScaleManager.unscaled(delta)
	if lockout > 0.0:
		lockout = maxf(lockout - real, 0.0)
	if not active:
		return
	remaining -= real
	if remaining <= 0.0:
		deactivate()
		return
	_update_wait -= real
	if _update_wait <= 0.0:
		_update_wait = 1.0 / maxf(updates_per_second, 1.0)
		_rebuild()


## Rebuilt a few times a second rather than every frame; intent changes during
## an activation (a gunshot turning a patrol into an investigation) are picked up.
func _rebuild() -> void:
	projections.clear()
	danger = false
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		var actor: EnemyCharacter = enemy as EnemyCharacter
		if actor == null or not _is_known(actor):
			continue
		var projection: FuturePredictor.FutureTrack = FuturePredictor.predict_enemy(actor, projection_offsets, prediction_horizon)
		projections.append(projection)
		if projection.fires and _threatens_player(projection):
			danger = true
	var planned: Dictionary = _squad.staged if is_instance_valid(_squad) else {}
	for ally: AllyCharacter in _selected_allies():
		if not planned.has(ally):
			projections.append(FuturePredictor.predict_ally(ally, projection_offsets, prediction_horizon))
	_rehearse(planned)
	projections_updated.emit()


## The plan, rehearsed: every order waiting for the signal is walked forward
## as if it went now, beside the guards' own futures. A planned unit that one
## of them would see at the same moment is flagged SEEN.
func _rehearse(planned: Dictionary) -> void:
	if planned.is_empty():
		return
	var guards: Array[FuturePredictor.FutureTrack] = []
	for projection in projections:
		if not projection.friendly:
			guards.append(projection)
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	for unit: Node2D in planned:
		if not is_instance_valid(unit) or not unit.can_process():
			continue
		var track: FuturePredictor.FutureTrack = FuturePredictor.predict_plan(unit, planned[unit], projection_offsets, prediction_horizon, _plan_speed(unit), _plan_reach(unit, planned[unit]))
		FuturePredictor.rehearse(track, guards, rehearsal_limit, space)
		if track.seen_time >= 0.0:
			# The first ghost at or past that moment turns red.
			track.seen_at = track.positions.size()
			for index in range(projection_offsets.size()):
				if projection_offsets[index] >= track.seen_time:
					track.seen_at = index
					break
		projections.append(track)


## How fast the unit will go when the signal sends it: a planned order walks,
## and a squad that is low walks low.
func _plan_speed(unit: Node2D) -> float:
	if unit == player:
		return player.crouch_speed if player.is_crouching else player.walk_speed
	var ally: AllyCharacter = unit as AllyCharacter
	if ally == null or ally.data == null:
		return 180.0
	if ally.sneaking and is_instance_valid(player):
		return minf(ally.data.move_speed, player.crouch_speed)
	return ally.data.move_speed


## Where an attack stops: in knife reach, or where the unit would open fire.
func _plan_reach(unit: Node2D, order: Dictionary) -> float:
	if order.kind == &"melee" and unit == player:
		return player.melee.hitbox_base_range * 0.8
	if unit == player:
		return player.weapon_controller.weapon_data.effective_range
	var ally: AllyCharacter = unit as AllyCharacter
	return ally.data.preferred_combat_range if ally != null and ally.data != null else 300.0


## Prescience is not omniscience: it only looks ahead for hostiles the squad can
## currently see, through the same recon architecture a fog-of-war pass will use.
func _is_known(actor: EnemyCharacter) -> bool:
	if not is_instance_valid(actor) or not actor.can_process() or actor.health.is_dead:
		return false
	if is_instance_valid(_recon):
		return _recon.is_enemy_visible(actor)
	# No recon manager in this scene: fall back to Paul's own observer.
	return is_instance_valid(player) and player.recon != null and player.recon.can_see(actor)


## Ally futures are opt-in through selection, so the screen stays readable.
func _selected_allies() -> Array[AllyCharacter]:
	var result: Array[AllyCharacter] = []
	if not is_instance_valid(_squad):
		return result
	for ally in _squad.selected_members:
		if is_instance_valid(ally) and ally.can_process() and not ally.health.is_dead:
			result.append(ally)
	return result


func _threatens_player(projection: FuturePredictor.FutureTrack) -> bool:
	if not is_instance_valid(player):
		return false
	var point: Vector2 = Geometry2D.get_closest_point_to_segment(player.global_position, projection.fire_from, projection.fire_to)
	return point.distance_to(player.global_position) <= danger_radius


func tracked_count() -> int:
	return projections.size()


func _exit_tree() -> void:
	if active:
		active = false
		projections.clear()
		TimeScaleManager.release(TimeScaleManager.Source.PRESCIENCE)
