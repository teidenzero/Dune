class_name MissionManager
extends Node
## Generic mission bookkeeping: objectives, phase, outcome, results, and the
## session checkpoint. It knows nothing about harvesters, beacons or worms -
## a mission controller drives it and decides what any of it means.
##
## Deliberately separate from TutorialManager. The tutorial teaches a linear
## script; a mission tracks goals that can complete out of order, be skipped,
## or fail without ending anything.

signal mission_started
signal objective_activated(objective: MissionObjective)
signal objective_completed(objective: MissionObjective)
signal objective_failed(objective: MissionObjective)
signal objectives_changed
signal phase_changed(phase: StringName, previous: StringName)
signal checkpoint_reached(id: StringName)
signal mission_completed(results: Dictionary)
signal mission_failed(reason: String)
## The shared outcome record exists; `committed` says whether the campaign has
## applied it yet.
signal outcome_recorded(outcome: MissionOutcome)

enum Outcome { RUNNING, COMPLETE, FAILED }

@export var mission_name: String = "MISSION"
@export var player: PlayerController
## The campaign's description of this mission, shared by every scope.
@export var definition: MissionDefinition

var outcome: Outcome = Outcome.RUNNING
var phase: StringName = &"INTRO"
var elapsed: float = 0.0
var failure_reason: String = ""
## Free-form factual outcomes for the results screen; no score, no grade.
var results: Dictionary = {}
## (success: bool, reason: String) -> MissionOutcome. Set by the mission
## controller, which is the only thing that knows how this mission went.
var outcome_builder: Callable = Callable()
var outcome_record: MissionOutcome
var outcome_committed: bool = false

var _objectives: Dictionary = {}
var _order: Array[StringName] = []


func _ready() -> void:
	add_to_group("mission_manager")
	# Launched on purpose (not a retry): the briefing comes first, and the
	# world waits from this very frame so no clock starts behind it.
	var game: Node = _gm()
	if game != null and game.pending_briefing:
		game.pending_briefing = false
		if has_briefing():
			get_tree().paused = true
			call_deferred("show_briefing", true)


func has_briefing() -> bool:
	return definition != null and definition.has_briefing(_scene_path())


## The briefing, at the start or again with I during the mission.
func show_briefing(at_start: bool = false) -> BriefingScreen:
	if not has_briefing() or get_tree().get_first_node_in_group("briefing_screen") != null:
		return null
	return BriefingScreen.show_for(self, _scene_path(), at_start)


## The scene this mission lives in: its own root, never whatever was current.
func _scene_path() -> String:
	if owner != null and owner.scene_file_path != "":
		return owner.scene_file_path
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	return scene.scene_file_path if scene != null else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("show_briefing") and not event.is_echo() and running() and has_briefing():
		get_viewport().set_input_as_handled()
		show_briefing()


# --------------------------------------------------------------------------
# Objectives
# --------------------------------------------------------------------------

## Objectives straight from the shared definition, in authored order.
func add_objectives_from_definition() -> void:
	if definition == null:
		return
	for item in definition.objectives:
		add_objective(item.to_objective())


func add_objective(objective: MissionObjective) -> MissionObjective:
	if objective == null or _objectives.has(objective.id):
		return objective
	_objectives[objective.id] = objective
	_order.append(objective.id)
	return objective


func objective(id: StringName) -> MissionObjective:
	return _objectives.get(id, null)


func all_objectives() -> Array[MissionObjective]:
	var list: Array[MissionObjective] = []
	for id in _order:
		list.append(_objectives[id])
	return list


func activate(id: StringName) -> void:
	var item: MissionObjective = objective(id)
	if item == null or item.state != MissionObjective.State.INACTIVE:
		return
	item.state = MissionObjective.State.ACTIVE
	objective_activated.emit(item)
	objectives_changed.emit()


## Completing an objective that was never activated is allowed on purpose: the
## player may solve something before the mission thought to ask for it.
func complete(id: StringName) -> void:
	var item: MissionObjective = objective(id)
	if item == null or item.state == MissionObjective.State.COMPLETE:
		return
	item.state = MissionObjective.State.COMPLETE
	objective_completed.emit(item)
	objectives_changed.emit()


func fail_objective(id: StringName) -> void:
	var item: MissionObjective = objective(id)
	if item == null or item.state == MissionObjective.State.COMPLETE or item.state == MissionObjective.State.FAILED:
		return
	item.state = MissionObjective.State.FAILED
	objective_failed.emit(item)
	objectives_changed.emit()


func set_progress(id: StringName, text: String) -> void:
	var item: MissionObjective = objective(id)
	if item == null:
		return
	item.progress = text
	objectives_changed.emit()


func is_complete(id: StringName) -> bool:
	var item: MissionObjective = objective(id)
	return item != null and item.state == MissionObjective.State.COMPLETE


func active_objective() -> MissionObjective:
	for id in _order:
		var item: MissionObjective = _objectives[id]
		if item.state == MissionObjective.State.ACTIVE and item.is_required():
			return item
	return null


func required_remaining() -> int:
	var count: int = 0
	for id in _order:
		var item: MissionObjective = _objectives[id]
		if item.is_required() and item.state != MissionObjective.State.COMPLETE:
			count += 1
	return count


# --------------------------------------------------------------------------
# Phase and outcome
# --------------------------------------------------------------------------

func begin() -> void:
	outcome = Outcome.RUNNING
	elapsed = 0.0
	var game: Node = get_node_or_null("/root/GameManager")
	if game != null and game.get("campaign") != null:
		game.campaign.begin_mission()
	mission_started.emit()


func set_phase(next: StringName) -> void:
	if next == phase:
		return
	var previous: StringName = phase
	phase = next
	phase_changed.emit(phase, previous)


func succeed() -> void:
	if outcome != Outcome.RUNNING:
		return
	outcome = Outcome.COMPLETE
	set_phase(&"COMPLETE")
	results["Mission time"] = time_text()
	_record_outcome(true, "")
	# A success stands the moment it happens.
	commit_outcome()
	mission_completed.emit(results)


func fail(reason: String) -> void:
	if outcome != Outcome.RUNNING:
		return
	outcome = Outcome.FAILED
	failure_reason = reason
	set_phase(&"FAILED")
	# A failure only counts once the player accepts it (commit_outcome);
	# retrying from a checkpoint throws it away.
	_record_outcome(false, reason)
	mission_failed.emit(reason)


func running() -> bool:
	return outcome == Outcome.RUNNING


func _record_outcome(success: bool, reason: String) -> void:
	if not outcome_builder.is_valid():
		return
	var record: MissionOutcome = outcome_builder.call(success, reason) as MissionOutcome
	if record == null:
		return
	record.time_seconds = elapsed
	record.stats = results.duplicate()
	outcome_record = record
	outcome_recorded.emit(record)


## Hands the outcome to the campaign, once.
func commit_outcome() -> void:
	if outcome_record == null or outcome_committed:
		return
	outcome_committed = true
	var game: Node = get_node_or_null("/root/GameManager")
	if game != null and game.get("campaign") != null:
		game.campaign.apply(outcome_record)


## Everything a prescient vision could change, for taking it back.
func snapshot() -> Dictionary:
	var states: Dictionary = {}
	for id in _order:
		var item: MissionObjective = _objectives[id]
		states[id] = [item.state, item.progress]
	return {"objectives": states, "phase": phase, "results": results.duplicate(true)}


func restore(data: Dictionary) -> void:
	var states: Dictionary = data.get("objectives", {})
	for id in states:
		var item: MissionObjective = objective(id)
		if item != null:
			item.state = states[id][0]
			item.progress = states[id][1]
	results = (data.get("results", {}) as Dictionary).duplicate(true)
	set_phase(data.get("phase", phase))
	objectives_changed.emit()


# --------------------------------------------------------------------------
# Results and checkpoints
# --------------------------------------------------------------------------

func record(key: String, value: Variant) -> void:
	results[key] = value


func bump(key: String, amount: int = 1) -> void:
	results[key] = int(results.get(key, 0)) + amount


func time_text() -> String:
	return "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]


## Session-scoped, like the tutorial's: it survives a scene reload and nothing
## else. There is no save game.
func set_checkpoint(id: StringName) -> void:
	_gm().mission_checkpoint = id
	checkpoint_reached.emit(id)


func checkpoint() -> StringName:
	return _gm().mission_checkpoint


func clear_checkpoint() -> void:
	_gm().mission_checkpoint = &""


## Autoload path lookup, not the global identifier: a --script test harness
## can compile this before autoloads are registered.
func _gm() -> Node:
	return get_node("/root/GameManager")


func _process(delta: float) -> void:
	# Mission time is real time: a slowed world is the player thinking, not
	# the mission taking longer.
	if outcome == Outcome.RUNNING:
		elapsed += TimeScaleManager.unscaled(delta)


func phase_name() -> String:
	return String(phase)


func outcome_name() -> String:
	return Outcome.keys()[outcome]
