class_name HarvesterRaidController
extends Node
## Everything that is true of *this* mission and no other: what the objectives
## mean, what disabling the beacon buys you, what sabotage sets off, and how
## the mission reacts to the desert.
##
## It drives MissionManager and subscribes to WormThreatManager. The worm
## system knows nothing about this mission, and MissionManager knows nothing
## about harvesters.

signal alarm_triggered(position: Vector2, severity: int)
signal mission_event(name: StringName)

const OBJ_APPROACH: StringName = &"approach"
const OBJ_COMMS: StringName = &"comms"
const OBJ_SABOTAGE: StringName = &"sabotage"
const OBJ_ESCAPE: StringName = &"escape"
const OBJ_SURVIVE: StringName = &"survive"
const OBJ_FREMEN: StringName = &"fremen"

@export var mission: MissionManager
@export var player: PlayerController
@export var squad: SquadManager
@export var harvester: Harvester
@export var beacon: CommunicationsBeacon
@export var worm: WormThreatManager
@export var extraction: TutorialTriggerArea
@export var approach_trigger: TutorialTriggerArea
@export var reinforcement_root: Node2D
@export var enemy_root: Node2D

@export_group("Escalation")
## Vibration the crawler throws off when it is torn open; enough to commit a worm.
@export var sabotage_worm_spike: float = 25.0
@export var alarm_radius: float = 1400.0
@export var reinforcement_delay: float = 4.0
@export var guard_scene: PackedScene = preload("res://scenes/characters/enemies/harkonnen_guard.tscn")
@export var elite_scene: PackedScene = preload("res://scenes/characters/enemies/harkonnen_elite.tscn")

var alarm_active: bool = false
var reinforcement_groups: int = 0
var reinforcements_spawned: int = 0
var escape_active: bool = false
var combat_before_sabotage: bool = false
var _reinforcement_wait: float = 0.0
var _pending_groups: int = 0
var _worm_events_before_sabotage: int = 0
## The scope the outcome is recorded in. This map is the squad scope; the
## solo scope has its own interior maps.
var scope: MissionOutcome.Scope = MissionOutcome.Scope.SQUAD


func _ready() -> void:
	add_to_group("mission_controller")
	call_deferred("_begin")


# --------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------

func _begin() -> void:
	_build_objectives()
	_connect()
	mission.begin()
	mission.record("Communications disabled", "NO")
	mission.record("Both Fremen survived", "YES")
	mission.record("Full combat before sabotage", "NO")
	mission.record("Enemies defeated", 0)
	mission.record("Prescience uses", 0)
	mission.record("Times fully detected", 0)
	mission.record("Worm events before sabotage", 0)
	mission_event.emit(&"mission_start")
	_restore_checkpoint()


func _build_objectives() -> void:
	mission.outcome_builder = build_outcome
	# The shared definition is the source of the objectives; the ids below are
	# what this controller means by each of them.
	mission.add_objectives_from_definition()
	if mission.all_objectives().is_empty():
		mission.add_objective(MissionObjective.create(OBJ_APPROACH, "Approach the spice operation", "Move down off the rocks and get eyes on the crawler."))
		mission.add_objective(MissionObjective.create(OBJ_COMMS, "Disable the communications beacon", "West of the crawler. Skipping it means a louder response."))
		mission.add_objective(MissionObjective.create(OBJ_SABOTAGE, "Sabotage the harvester", "Both control points, anywhere on the crawler."))
		mission.add_objective(MissionObjective.create(OBJ_ESCAPE, "Reach safe rock", "North of the site. Sand is where it hunts."))
		mission.add_objective(MissionObjective.create(OBJ_SURVIVE, "Survive the worm", "Stay on stone until it has taken the crawler."))
		mission.add_objective(MissionObjective.create(OBJ_FREMEN, "Keep both Fremen alive", "Optional.", true))
	mission.activate(OBJ_APPROACH)
	mission.activate(OBJ_COMMS)
	if scope == MissionOutcome.Scope.SQUAD:
		mission.activate(OBJ_FREMEN)
	mission.set_phase(&"APPROACH")


func _connect() -> void:
	if is_instance_valid(approach_trigger):
		approach_trigger.player_entered.connect(func(_id: StringName) -> void: _on_approached())
	if is_instance_valid(extraction):
		extraction.player_entered.connect(func(_id: StringName) -> void: _on_reached_rock())
	if is_instance_valid(beacon):
		beacon.beacon_disabled.connect(_on_beacon_disabled)
	if is_instance_valid(harvester):
		harvester.sabotage_progressed.connect(_on_sabotage_progress)
		harvester.sabotaged.connect(_on_sabotaged)
	if is_instance_valid(worm):
		worm.worm_arrived.connect(_on_worm_arrived)
		worm.worm_event_finished.connect(_on_worm_finished)
		worm.actor_caught.connect(_on_actor_caught)
	if is_instance_valid(player):
		player.health.died.connect(func() -> void: mission.fail("PAUL IS DOWN"))
		player.prescience.prescience_started.connect(func() -> void: mission.bump("Prescience uses"))
	for enemy: Node in _enemies():
		_watch_enemy(enemy)
	for ally: Node in get_tree().get_nodes_in_group("allies"):
		var health: HealthComponent = HealthComponent.find_on(ally)
		if health != null:
			health.died.connect(_on_ally_died)


func _watch_enemy(enemy: Node) -> void:
	var health: HealthComponent = HealthComponent.find_on(enemy)
	if health != null and not health.died.is_connected(_on_enemy_died):
		health.died.connect(_on_enemy_died)
	var actor: EnemyCharacter = enemy as EnemyCharacter
	if actor != null and not actor.ai.state_changed.is_connected(_on_enemy_state):
		actor.ai.state_changed.connect(_on_enemy_state)


func _enemies() -> Array[Node]:
	return get_tree().get_nodes_in_group("enemies")


# --------------------------------------------------------------------------
# Objective progression
# --------------------------------------------------------------------------

func _on_approached() -> void:
	mission.complete(OBJ_APPROACH)


func _on_beacon_disabled() -> void:
	mission.complete(OBJ_COMMS)
	mission.record("Communications disabled", "YES")
	# Disabled before the site knew we were here counts for the debrief.
	mission.record("Disabled before full combat", "NO" if combat_before_sabotage else "YES")
	mission.set_checkpoint(&"comms")
	mission_event.emit(&"objective_complete")
	if mission.phase == &"APPROACH":
		mission.set_phase(&"SABOTAGE")
	mission.activate(OBJ_SABOTAGE)


func _on_sabotage_progress(done: int, total: int) -> void:
	mission.complete(OBJ_APPROACH)
	mission.activate(OBJ_SABOTAGE)
	mission.set_progress(OBJ_SABOTAGE, "%d / %d" % [done, total])
	mission.set_phase(&"SABOTAGE")
	if done == 1:
		mission.set_checkpoint(&"sabotage")
	mission_event.emit(&"objective_complete")


func _on_sabotaged() -> void:
	mission.complete(OBJ_SABOTAGE)
	mission.set_phase(&"ALARM")
	mission_event.emit(&"harvester_sabotaged")
	# The crawler tearing itself open is what wakes the desert; the worm system
	# decides what to do with that, not this controller.
	if is_instance_valid(worm) and is_instance_valid(harvester):
		worm.report_sign(harvester.global_position, sabotage_worm_spike, "Harvester sabotage", harvester.emitter)
	_raise_alarm(harvester.global_position if is_instance_valid(harvester) else Vector2.ZERO, 2)
	_begin_escape()


func _begin_escape() -> void:
	if escape_active:
		return
	escape_active = true
	mission.activate(OBJ_ESCAPE)
	mission.activate(OBJ_SURVIVE)
	mission.set_phase(&"ESCAPE")
	mission.set_checkpoint(&"escape")


func _on_reached_rock() -> void:
	if not escape_active:
		return
	mission.complete(OBJ_ESCAPE)
	_try_finish()


# --------------------------------------------------------------------------
# Alarm and reinforcements
# --------------------------------------------------------------------------

## Nearby Harkonnen learn where the noise came from. Distant ones do not become
## omniscient; they are simply out of earshot.
func _raise_alarm(position: Vector2, severity: int) -> void:
	alarm_active = true
	alarm_triggered.emit(position, severity)
	mission_event.emit(&"alarm")
	for enemy: Node in _enemies():
		var actor: EnemyCharacter = enemy as EnemyCharacter
		if actor == null or actor.health.is_dead or not actor.can_process():
			continue
		if actor.global_position.distance_to(position) > alarm_radius:
			continue
		actor.ai.suspicious_position = position
		actor.ai.disturbance_priority = 6
		actor.ai.current_disturbance = "ALARM"
		if actor.ai.state != EnemyAIController.State.COMBAT:
			actor.ai.change_state(EnemyAIController.State.INVESTIGATE)
	# Cutting the mast earlier is what makes this cheaper.
	_pending_groups = 1 if (is_instance_valid(beacon) and not beacon.active) else 2
	reinforcement_groups = _pending_groups
	_reinforcement_wait = reinforcement_delay


func _spawn_group() -> void:
	if _pending_groups <= 0 or not is_instance_valid(reinforcement_root):
		return
	var points: Array[Node] = reinforcement_root.get_children()
	if points.is_empty():
		_pending_groups = 0
		return
	var spawn: Node2D = points[reinforcements_spawned % points.size()] as Node2D
	var target: Vector2 = player.global_position if is_instance_valid(player) else spawn.global_position
	for index in range(2):
		_spawn_enemy(guard_scene, spawn.global_position + Vector2(index * 90 - 45, index * 70), target)
	# The heavier response brings armour with it.
	if reinforcements_spawned == 1:
		_spawn_enemy(elite_scene, spawn.global_position + Vector2(0, -90), target)
	reinforcements_spawned += 1
	_pending_groups -= 1
	mission_event.emit(&"reinforcements")
	if _pending_groups > 0:
		_reinforcement_wait = reinforcement_delay * 2.0


func _spawn_enemy(scene: PackedScene, at: Vector2, toward: Vector2) -> void:
	var enemy: EnemyCharacter = scene.instantiate() as EnemyCharacter
	enemy.global_position = at
	enemy_root.add_child(enemy)
	enemy.global_position = at
	enemy.face_position(toward)
	enemy.ai.suspicious_position = toward
	enemy.ai.change_state(EnemyAIController.State.INVESTIGATE)
	_watch_enemy(enemy)


func _process(delta: float) -> void:
	if not mission.running():
		return
	if _pending_groups > 0 and _reinforcement_wait > 0.0:
		_reinforcement_wait -= delta
		if _reinforcement_wait <= 0.0:
			_spawn_group()


# --------------------------------------------------------------------------
# Worm response
# --------------------------------------------------------------------------

func _on_worm_arrived(position: Vector2, _radius: float) -> void:
	mission.set_phase(&"WORM_EVENT")
	mission_event.emit(&"worm_arrived")
	if not harvester.is_sabotaged:
		# An early worm drawn by the player's own noise must not hand them the
		# mission: an intact crawler survives being passed by.
		_worm_events_before_sabotage += 1
		mission.record("Worm events before sabotage", _worm_events_before_sabotage)
		return
	if is_instance_valid(harvester) and harvester.global_position.distance_to(position) <= worm.danger_radius * 2.0:
		harvester.destroy()
		mission_event.emit(&"harvester_destroyed")


func _on_worm_finished() -> void:
	if harvester.destroyed:
		_try_finish()
	elif mission.running():
		mission.set_phase(&"ESCAPE" if escape_active else &"SABOTAGE")


func _on_actor_caught(actor: Node2D) -> void:
	if actor == player:
		mission.fail("TAKEN BY THE WORM")


func _try_finish() -> void:
	if not mission.running() or not escape_active:
		return
	if not mission.is_complete(OBJ_ESCAPE):
		return
	if not harvester.destroyed:
		return
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	if safety != null and not safety.is_safe():
		return
	mission.complete(OBJ_SURVIVE)
	mission.clear_checkpoint()
	mission_event.emit(&"mission_complete")
	mission.succeed()


# --------------------------------------------------------------------------
# Bookkeeping
# --------------------------------------------------------------------------

func _on_enemy_died() -> void:
	mission.bump("Enemies defeated")


func _on_enemy_state(_previous: EnemyAIController.State, current: EnemyAIController.State) -> void:
	if current != EnemyAIController.State.COMBAT:
		return
	mission.bump("Times fully detected")
	if not harvester.is_sabotaged and not combat_before_sabotage:
		combat_before_sabotage = true
		mission.record("Full combat before sabotage", "YES")


func _on_ally_died() -> void:
	mission.fail_objective(OBJ_FREMEN)
	mission.record("Both Fremen survived", "NO")


# --------------------------------------------------------------------------
# Outcome for the campaign
# --------------------------------------------------------------------------

## How this raid went, in the shape every scope reports. Clean means the
## purpose was achieved quietly: the mast cut and no firefight before the
## crawler was open. A failure after the crawler was already sabotaged still
## hurt the Harkonnen, so it counts as partial.
func build_outcome(success: bool, reason: String) -> MissionOutcome:
	var record: MissionOutcome = MissionOutcome.new()
	var definition: MissionDefinition = mission.definition
	record.mission_id = definition.id if definition != null else &"harvester_raid"
	record.scopes.append(scope)
	for item in mission.all_objectives():
		if item.state != MissionObjective.State.INACTIVE:
			record.objectives[item.id] = item.state
	var comms_cut: bool = is_instance_valid(beacon) and not beacon.active
	var sabotaged: bool = is_instance_valid(harvester) and harvester.is_sabotaged
	if success:
		record.tier = MissionOutcome.Tier.CLEAN if comms_cut and not combat_before_sabotage else MissionOutcome.Tier.NOISY
	else:
		record.tier = MissionOutcome.Tier.PARTIAL if sabotaged else MissionOutcome.Tier.FAILURE
	record.failure_reason = reason
	for ally: Node in get_tree().get_nodes_in_group("allies"):
		var health: HealthComponent = HealthComponent.find_on(ally)
		if health != null and health.is_dead:
			record.recruits_dead.append(ally.data.display_name if ally is AllyCharacter and ally.data != null else str(ally.name))
	# Heroes are never killed outright: Paul going down means Paul wounded.
	if is_instance_valid(player) and player.health.is_dead or reason == "TAKEN BY THE WORM":
		record.heroes_wounded.append("Paul")
	if not comms_cut:
		record.add_flag(&"comms_intact")
	if alarm_active:
		record.add_flag(&"alarm_raised")
	if combat_before_sabotage:
		record.add_flag(&"firefight")
	if is_instance_valid(harvester) and harvester.destroyed:
		record.add_flag(&"harvester_destroyed")
	if definition != null:
		record.apply_stakes(definition)
	return record


# --------------------------------------------------------------------------
# Checkpoints and developer controls
# --------------------------------------------------------------------------

## Reload plus reconstruction, as with the tutorial: reliability over elegance.
func _restore_checkpoint() -> void:
	var point: StringName = mission.checkpoint()
	if point == &"":
		return
	match point:
		&"comms":
			beacon.disable()
			_move_player(&"Checkpoint_comms")
		&"sabotage":
			beacon.disable()
			_move_player(&"Checkpoint_sabotage")
		&"escape":
			beacon.disable()
			for node: Node in get_tree().get_nodes_in_group("sabotage_points"):
				(node as InteractionPoint).force_complete()
			_move_player(&"Checkpoint_escape")


func _move_player(marker_name: StringName) -> void:
	var marker: Node2D = get_parent().find_child(String(marker_name), true, false) as Node2D
	if marker == null or not is_instance_valid(player):
		return
	player.teleport_to(marker.global_position)
	player.health.reset_health()
	var offset: int = 0
	for ally: AllyCharacter in get_tree().get_nodes_in_group("allies"):
		if ally.health.is_dead:
			continue
		ally.global_position = marker.global_position + Vector2(-80 + offset * 160, 90)
		ally.velocity = Vector2.ZERO
		ally.stop_moving()
		ally.ai.issue_order(AllyAIController.Order.HOLD, ally.global_position)
		offset += 1


func restart_from_checkpoint() -> void:
	get_tree().reload_current_scene()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _gm().debug_visible or event.is_echo() or not event.is_pressed():
		return
	if not InputMap.has_action("mission_debug_advance") or not InputMap.has_action("mission_debug_alarm"):
		return
	if event.is_action_pressed("mission_debug_advance"):
		_debug_advance()
	elif event.is_action_pressed("mission_debug_alarm"):
		_raise_alarm(player.global_position, 2)
	elif event.is_action_pressed("mission_debug_restart"):
		restart_from_checkpoint()
	else:
		return
	get_viewport().set_input_as_handled()


## Completes whatever the mission is currently waiting on.
func _debug_advance() -> void:
	if is_instance_valid(beacon) and beacon.active:
		beacon.disable()
		return
	if not harvester.is_sabotaged:
		for node: Node in get_tree().get_nodes_in_group("sabotage_points"):
			var point: InteractionPoint = node as InteractionPoint
			if point.available():
				point.force_complete()
				return
		return
	if not harvester.destroyed and is_instance_valid(worm):
		worm.force_arrival()


## Autoload path lookup, not the global identifier: a --script test harness
## can compile this before autoloads are registered.
func _gm() -> Node:
	return get_node("/root/GameManager")


func debug_rows() -> Dictionary:
	var objective: MissionObjective = mission.active_objective()
	return {
		"Mission state": "%s / %s" % [mission.phase_name(), mission.outcome_name()],
		"Current objective": objective.display_title() if objective != null else "-",
		"Beacon active": "YES" if is_instance_valid(beacon) and beacon.active else "NO",
		"Sabotage progress": "%d / %d" % [harvester.sabotage_done, harvester.sabotage_total] if is_instance_valid(harvester) else "-",
		"Alarm active": "YES" if alarm_active else "NO",
		"Reinforcements": "%d of %d groups" % [reinforcements_spawned, reinforcement_groups],
		"Harvester state": "DESTROYED" if harvester.destroyed else ("SABOTAGED" if harvester.is_sabotaged else "RUNNING"),
		"Escape active": "YES" if escape_active else "NO",
		"Paul safe": "YES" if _player_safe() else "NO",
		"Mission checkpoint": String(mission.checkpoint()),
		"Mission time": mission.time_text(),
	}


func _player_safe() -> bool:
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	return safety != null and safety.is_safe()
