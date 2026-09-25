class_name TutorialManager
extends Node2D
## Linear tutorial sequencer.
##
## It owns step order, prompts, hints, markers, section gates, checkpoints, and
## developer navigation. It owns no gameplay rules: every completion check reads
## existing gameplay state or an event recorded from an existing gameplay
## signal, so the tutorial doubles as an integration test of the real systems.

signal tutorial_step_started(step: TutorialStep)
signal tutorial_step_completed(step: TutorialStep)
signal tutorial_section_changed(section: StringName)
signal checkpoint_reached(step_id: StringName)
signal tutorial_failed(reason: String)
signal tutorial_completed

@export var player: PlayerController
@export var squad: SquadManager
@export var prompt: CanvasLayer
@export var restart_delay: float = 1.6

var steps: Array[TutorialStep] = []
var sections: PackedStringArray = PackedStringArray()
var index: int = -1
var running: bool = false
var finished: bool = false
var failed_reason: String = ""
var step_time: float = 0.0
var hint_shown: bool = false
## Event name -> times seen since the current step started.
var events: Dictionary = {}
## Values steps accumulate themselves (sprint seconds, crouch distance, ...).
var counters: Dictionary = {}

var _lookup: Dictionary = {}
var _completion_hold: float = 0.0
var _restart_hold: float = 0.0
## Index of the latest retry_here step in the current section, or -1.
var _retry_step: int = -1
var _section_start: Dictionary = {}


func _ready() -> void:
	add_to_group("tutorial_manager")
	# F10: jump to any lesson.
	var jump: TrainingJumpMenu = TrainingJumpMenu.new()
	jump.name = "JumpMenu"
	jump.host = self
	add_child(jump)
	steps = TutorialScript.build(self)
	for step in steps:
		if not _section_start.has(step.section):
			_section_start[step.section] = steps.find(step)
			sections.append(String(step.section))
	_bind_signals()
	_deactivate_all_markers()
	call_deferred("_begin")


# --------------------------------------------------------------------------
# Scene lookup
# --------------------------------------------------------------------------

## Cached by-name lookup so step definitions never carry brittle node paths.
func find(node_name: StringName) -> Node:
	if _lookup.has(node_name) and is_instance_valid(_lookup[node_name]):
		return _lookup[node_name]
	var found: Node = get_parent().find_child(String(node_name), true, false)
	if found != null:
		_lookup[node_name] = found
	return found


func actor(node_name: StringName) -> Node2D:
	return find(node_name) as Node2D


func worm() -> WormThreatManager:
	return get_tree().get_first_node_in_group("worm_threat") as WormThreatManager


func ally(slot: int) -> AllyCharacter:
	if not is_instance_valid(squad):
		return null
	for member in squad.members:
		if is_instance_valid(member) and member.selection_slot == slot:
			return member
	return null


# --------------------------------------------------------------------------
# Events recorded from existing gameplay signals
# --------------------------------------------------------------------------

func note_event(name: StringName) -> void:
	events[name] = int(events.get(name, 0)) + 1


func happened(name: StringName) -> bool:
	return int(events.get(name, 0)) > 0


## Standing in a volume counts as reaching it, not only crossing its edge.
func at_trigger(id: StringName) -> bool:
	for node: Node in get_tree().get_nodes_in_group("tutorial_triggers"):
		var trigger: TutorialTriggerArea = node as TutorialTriggerArea
		if trigger != null and trigger.id == id:
			return trigger.contains_player()
	return false


func count(name: StringName) -> int:
	return int(events.get(name, 0))


func add_counter(name: StringName, amount: float) -> void:
	counters[name] = float(counters.get(name, 0.0)) + amount


func counter(name: StringName) -> float:
	return float(counters.get(name, 0.0))


func _bind_signals() -> void:
	if is_instance_valid(player):
		player.weapon_controller.weapon_fired.connect(func() -> void: note_event(&"weapon_fired"))
		player.weapon_controller.reload_finished.connect(func() -> void: note_event(&"reload_finished"))
		player.melee.attack_landed.connect(_on_melee_landed)
		player.prescience.prescience_started.connect(func() -> void: note_event(&"prescience_started"))
		player.prescience.prescience_ended.connect(func() -> void: note_event(&"prescience_ended"))
		player.health.died.connect(_on_player_died)
	var threat: WormThreatManager = worm()
	if threat != null:
		threat.worm_arrived.connect(func(_p: Vector2, _r: float) -> void: note_event(&"worm_arrived"))
		threat.worm_event_finished.connect(func() -> void: note_event(&"worm_finished"))
	if is_instance_valid(squad):
		squad.pause_changed.connect(_on_pause_changed)
		squad.order_issued.connect(func(_order: int) -> void: note_event(&"order_issued"))
		squad.command_rejected.connect(func(_allies: Array) -> void: note_event(&"command_rejected"))
		squad.route_changed.connect(func(_ally: AllyCharacter) -> void: note_event(&"route_changed"))
	for node: Node in get_tree().get_nodes_in_group("tutorial_triggers"):
		var trigger: TutorialTriggerArea = node as TutorialTriggerArea
		if trigger != null:
			trigger.player_entered.connect(func(id: StringName) -> void: note_event(StringName("enter_" + String(id))))
	# A stray shot must never cost the player a lesson: training targets in
	# the tutorial get back up.
	for node: Node in get_tree().get_nodes_in_group("training_targets"):
		if "respawn_seconds" in node:
			node.respawn_seconds = 2.0
	for node: Node in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("training_targets"):
		var shield: ShieldComponent = ShieldComponent.find_on(node)
		if shield != null:
			shield.shield_blocked.connect(_on_shield_blocked)
			shield.shield_penetrated.connect(func(_hit: HitContext) -> void: note_event(&"shield_penetrated"))
		var health: HealthComponent = HealthComponent.find_on(node)
		if health != null:
			health.damaged.connect(_on_target_damaged.bind(node))


func _on_melee_landed(_target: Node, data: MeleeAttackData, outcome: int) -> void:
	var slow: bool = data == player.melee.slow_attack
	if outcome == DamageResolver.Outcome.BLOCKED:
		note_event(&"melee_blocked_slow" if slow else &"melee_blocked_fast")
	elif outcome == DamageResolver.Outcome.DAMAGED:
		note_event(&"melee_hit_slow" if slow else &"melee_hit_fast")


func _on_shield_blocked(hit: HitContext) -> void:
	note_event(&"shield_blocked_melee" if hit.attack_type == HitContext.Type.MELEE else &"shield_blocked_ranged")


func _on_target_damaged(_amount: float, node: Node) -> void:
	note_event(StringName("damaged_" + str(node.name)))


# --------------------------------------------------------------------------
# Sequencing
# --------------------------------------------------------------------------

func _begin() -> void:
	var resume: StringName = _gm().tutorial_checkpoint
	var start: int = 0
	if resume != &"":
		for i in range(steps.size()):
			if steps[i].id == resume:
				start = i
				break
	running = true
	var game: Node = get_node_or_null("/root/GameManager")
	if game != null and game.get("campaign") != null:
		game.campaign.begin_mission()
	_enter_step(start, true)
	# The whole squad starts selected: the first right-click moves all three.
	if is_instance_valid(squad):
		squad.call_deferred("select_slot", 4)


func current_step() -> TutorialStep:
	return steps[index] if index >= 0 and index < steps.size() else null


func current_section() -> StringName:
	var step: TutorialStep = current_step()
	return step.section if step != null else &""


func _enter_step(next: int, teleport: bool = false) -> void:
	if next >= steps.size():
		_complete_tutorial()
		return
	var previous_section: StringName = current_section()
	index = next
	var step: TutorialStep = steps[index]
	step.state = TutorialStep.State.ACTIVE
	events.clear()
	counters.clear()
	step_time = 0.0
	hint_shown = false
	_completion_hold = 0.0
	# Paul moves first: the squad forms up on where he ends up, not where he was.
	if step.section != previous_section:
		_retry_step = -1
	if step.retry_here:
		_retry_step = index
	if teleport:
		_place_player_at_checkpoint(step.section)
	_apply_section(step.section, teleport or step.section != previous_section)
	_activate_markers(step)
	if step.on_start.is_valid():
		step.on_start.call()
	if step.section != previous_section:
		tutorial_section_changed.emit(step.section)
	if _section_start.get(step.section, -1) == index:
		_gm().tutorial_checkpoint = step.id
		checkpoint_reached.emit(step.id)
	tutorial_step_started.emit(step)


func _process(delta: float) -> void:
	if not running or finished:
		return
	# Prompts, hints and hand-offs run on real time. Command mode and prescience
	# slow the world, and a player waiting on a prompt should not wait five
	# times as long because the battlefield is crawling.
	delta = TimeScaleManager.unscaled(delta)
	if _restart_hold > 0.0:
		_restart_hold -= delta
		if _restart_hold <= 0.0:
			restart_section()
		return
	var step: TutorialStep = current_step()
	if step == null:
		return
	if _completion_hold > 0.0:
		_completion_hold -= delta
		if _completion_hold <= 0.0:
			_enter_step(index + 1)
		return
	step_time += delta
	if not hint_shown and step.hint != "" and step_time >= step.hint_delay:
		hint_shown = true
	if step.state == TutorialStep.State.ACTIVE and step.is_satisfied():
		_complete_step(step)


func _complete_step(step: TutorialStep) -> void:
	step.state = TutorialStep.State.COMPLETE
	_deactivate_all_markers()
	if step.on_complete.is_valid():
		step.on_complete.call()
	tutorial_step_completed.emit(step)
	_completion_hold = maxf(step.hold_after(step_time), 0.05)


func _complete_tutorial() -> void:
	finished = true
	running = false
	_gm().tutorial_checkpoint = &""
	_deactivate_all_markers()
	tutorial_completed.emit()


# --------------------------------------------------------------------------
# Sections, gates, and capability locks
# --------------------------------------------------------------------------

## Opens every gate up to the active section and unlocks the abilities that
## section has already taught. Abilities stay unlocked once introduced.
func _apply_section(section: StringName, reposition: bool) -> void:
	var reached: int = sections.find(String(section))
	for i in range(sections.size()):
		var gate: TutorialGate = find(StringName("Gate_" + sections[i])) as TutorialGate
		if gate != null:
			# Gate_<section> is the door leaving that section.
			if i < reached:
				gate.open()
			else:
				gate.close()
	if is_instance_valid(player):
		player.weapon_controller.enabled = reached >= sections.find("ranged")
		player.melee.set_enabled(reached >= sections.find("melee"))
	# The yard is a squad lesson from the first step: Paul and his two Fremen
	# guides move together, and every order reaches them.
	if is_instance_valid(squad):
		squad.commands_enabled = true
		# While Paul himself is drilled, and while a lesson is about moving
		# unseen, the Fremen watch and hold their fire whatever B says.
		var drilling: bool = reached < sections.find("squad") or section in [&"recon", &"prescience"]
		for member in squad.members:
			if is_instance_valid(member):
				member.ai.hold_fire = drilling
	if reposition:
		_prepare_section(section)


func _prepare_section(section: StringName) -> void:
	var threat: WormThreatManager = worm()
	if threat != null:
		threat.reset_threat()
		for machine: Node in get_tree().get_nodes_in_group("worm_machines"):
			machine.set_running(false)
	# Stealth guards teach, they do not execute: their weapons stay cold.
	for group_name in [&"StealthGuards", &"PrescienceGuards"]:
		var post: Node = find(group_name)
		if post == null:
			continue
		for guard: Node in post.get_children():
			if guard is EnemyCharacter:
				guard.weapon.enabled = false
				if not guard.perception.perception_state_changed.is_connected(_on_stealth_detection):
					guard.perception.perception_state_changed.connect(_on_stealth_detection)
	if not is_instance_valid(squad):
		return
	if section == &"squad":
		set_actor_armed(&"Target_SquadEnemy", false)
	regroup_allies()


## Holds a training opponent inert until its lesson begins, then gives it its
## normal perception and weapon back so the exercise is a real fight.
func set_actor_armed(node_name: StringName, armed: bool) -> void:
	var foe: EnemyCharacter = find(node_name) as EnemyCharacter
	if foe == null or foe.health.is_dead:
		return
	foe.weapon.enabled = armed
	foe.perception.set_physics_process(armed)
	if not armed:
		foe.perception.stop()


## Parks every living Fremen where they stand, so a lesson about Paul is not
## given away by companions wandering after him.
func hold_allies() -> void:
	if not is_instance_valid(squad):
		return
	for member in squad.members:
		if is_instance_valid(member) and not member.health.is_dead:
			member.ai.issue_order(AllyAIController.Order.HOLD, member.global_position)


## Sends the living Fremen to the given points with ordinary MOVE_TO orders;
## each holds there on arrival.
func station_allies(points: Array) -> void:
	if not is_instance_valid(squad):
		return
	var slot: int = 0
	for member in squad.members:
		if not is_instance_valid(member) or member.health.is_dead or slot >= points.size():
			continue
		var point: Vector2 = _on_navmesh(member, points[slot])
		member.ai.issue_order(AllyAIController.Order.MOVE_TO, point)
		slot += 1


## Forms the squad up beside Paul at the start of a section, each holding
## there until the player moves him (or calls him to follow with G).
func regroup_allies() -> void:
	if not is_instance_valid(squad) or not is_instance_valid(player):
		return
	var index_offset: int = 0
	# At the very start the squad may not have registered its Fremen yet.
	var fremen: Array = squad.members if not squad.members.is_empty() else get_tree().get_nodes_in_group("allies")
	for member: AllyCharacter in fremen:
		if not is_instance_valid(member) or member.health.is_dead:
			continue
		var offset: Vector2 = Vector2(-70.0 if index_offset == 0 else 70.0, 90.0)
		var point: Vector2 = _on_navmesh(member, player.global_position + offset)
		member.global_position = point
		member.velocity = Vector2.ZERO
		member.stop_moving()
		# Beside Paul, holding: they move when the player moves them.
		member.ai.issue_order(AllyAIController.Order.HOLD, point)
		index_offset += 1


## The nearest walkable point to `point`. Right after a scene change the
## navigation map can report itself ready before this scene's mesh is in it,
## and answer (0, 0) - across the yard. A snap that far is not trusted.
func _on_navmesh(member: AllyCharacter, point: Vector2) -> Vector2:
	if not member.navigation_ready():
		return point
	var snapped: Vector2 = NavigationServer2D.map_get_closest_point(member.agent.get_navigation_map(), point)
	return snapped if snapped.distance_to(point) <= 120.0 else point


func _on_pause_changed(active: bool) -> void:
	note_event(&"paused" if active else &"unpaused")
	# This manager is paused along with the world, so a step cannot poll the
	# pause itself; pausing inside a vision is recorded as it happens.
	if active and is_instance_valid(player) and player.prescience != null and player.prescience.active:
		note_event(&"paused_in_vision")


func _on_stealth_detection(state: PerceptionComponent.Awareness) -> void:
	if _restart_hold > 0.0 or not running:
		return
	if current_section() != &"stealth" and current_section() != &"prescience":
		return
	if state == PerceptionComponent.Awareness.DETECTED:
		fail_section("SPOTTED")


func _place_player_at_checkpoint(section: StringName) -> void:
	var spawn: Node2D = actor(StringName("Checkpoint_" + String(section)))
	if spawn != null and is_instance_valid(player):
		player.teleport_to(spawn.global_position)


func _activate_markers(step: TutorialStep) -> void:
	_deactivate_all_markers()
	for name in step.markers:
		var marker: TutorialMarker = find(StringName(name)) as TutorialMarker
		if marker != null:
			marker.set_active(true)


func _deactivate_all_markers() -> void:
	for node: Node in get_tree().get_nodes_in_group("tutorial_markers"):
		(node as TutorialMarker).set_active(false)


# --------------------------------------------------------------------------
# Failure, checkpoints, and developer navigation
# --------------------------------------------------------------------------

func fail_section(reason: String) -> void:
	if not running or _restart_hold > 0.0:
		return
	if is_instance_valid(player) and player.prescience != null:
		player.prescience.deactivate()
	var threat: WormThreatManager = worm()
	if threat != null:
		threat.reset_threat()
	failed_reason = reason
	var step: TutorialStep = current_step()
	if step != null:
		step.state = TutorialStep.State.FAILED
	tutorial_failed.emit(reason)
	_restart_hold = restart_delay


func _on_player_died() -> void:
	# Paul's existing Enter restart reloads the scene; the checkpoint survives
	# on GameManager, so the tutorial resumes at the current section.
	failed_reason = "PAUL IS DOWN"
	tutorial_failed.emit(failed_reason)
	running = false


## Reloads the mission and resumes at the current section's first step.
func restart_section(target: StringName = &"") -> void:
	var section: StringName = target if target != &"" else current_section()
	var start: int = int(_section_start.get(section, 0))
	if target == &"" and _retry_step >= 0 and steps[_retry_step].section == section:
		start = _retry_step
	_gm().tutorial_checkpoint = steps[start].id if start < steps.size() else &""
	get_tree().reload_current_scene()


func jump_to_section(offset: int) -> void:
	var here: int = sections.find(String(current_section()))
	var target: int = clampi(here + offset, 0, sections.size() - 1)
	if target == here and offset != 0:
		return
	var start: int = int(_section_start.get(StringName(sections[target]), 0))
	for i in range(steps.size()):
		steps[i].state = TutorialStep.State.COMPLETE if i < start else TutorialStep.State.INACTIVE
	finished = false
	running = true
	_restart_hold = 0.0
	_enter_step(start, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _gm().debug_visible or event.is_echo() or not event.is_pressed():
		return
	if InputMap.has_action("tutorial_restart_section") and event.is_action_pressed("tutorial_restart_section"):
		restart_section()
	elif InputMap.has_action("tutorial_next_section") and event.is_action_pressed("tutorial_next_section"):
		jump_to_section(1)
	elif InputMap.has_action("tutorial_prev_section") and event.is_action_pressed("tutorial_prev_section"):
		jump_to_section(-1)
	else:
		return
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


# --------------------------------------------------------------------------
# Diagnostics
# --------------------------------------------------------------------------

func debug_rows() -> Dictionary:
	var step: TutorialStep = current_step()
	return {
		"Tutorial active": str(running and not finished),
		"Tutorial section": String(current_section()) if step != null else "-",
		"Tutorial step": "%d/%d %s" % [index + 1, steps.size(), String(step.id) if step != null else "-"],
		"Tutorial step state": step.state_name() if step != null else "-",
		"Tutorial checkpoint": String(_gm().tutorial_checkpoint),
		"Tutorial hint timer": "%.1f s (%s)" % [step_time, "shown" if hint_shown else "waiting"],
		"Tutorial condition": str(step.is_satisfied()) if step != null else "-",
	}

## Autoload path lookup, not the global identifier: a --script test harness
## can compile these before autoloads are registered.
func _gm() -> Node:
	return get_node("/root/GameManager")
