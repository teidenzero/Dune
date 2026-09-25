class_name WormThreatManager
extends Node2D
## Accumulates desert vibration into a single threat value, decides when a worm
## commits, and picks what it commits to.
##
## It owns no mission logic. The Harvester Raid will subscribe to `worm_arrived`
## rather than being called by name from in here.
##
## Accumulation and decay use world-scaled time, so a slowed world is a slowed
## desert. Warnings the player reads - camera shake, HUD - use real time.

signal worm_sign_changed(value: float, threshold: float)
signal worm_stage_changed(stage: int, previous: int)
signal worm_approach_started(target: Vector2)
signal worm_imminent
signal worm_arrived(position: Vector2, radius: float)
signal worm_event_finished
signal actor_caught(actor: Node2D)

enum Stage { CALM, DISTANT, INTERESTED, APPROACHING, IMMINENT, ARRIVAL }
enum EventState { IDLE, BUILDING, APPROACHING, ARRIVAL, COOLDOWN }

@export var event: WormApproachEvent
@export var threshold: float = 100.0
## Below the walking rate and above the crouch rate: walking slowly builds,
## crouch-walking never does.
@export var decay_per_second: float = 0.6
## Lower bounds for DISTANT, INTERESTED, APPROACHING, IMMINENT, ARRIVAL.
@export var stage_thresholds: PackedFloat32Array = PackedFloat32Array([20.0, 40.0, 60.0, 80.0, 100.0])
## Sign must fall this far below a boundary before the stage steps back down.
@export var stage_hysteresis: float = 8.0
@export var minimum_stage_seconds: float = 1.5
## Rolling window of vibration used to choose what the worm commits to.
@export var memory_seconds: float = 8.0
@export var cooldown_seconds: float = 14.0
## Sign left behind once an event resolves; the desert does not forget at once.
@export var sign_after_event: float = 15.0
@export var danger_radius: float = 260.0
## The HUD shows the meter from this much sign, so the player sees their own
## noise register long before the first stage.
@export var visible_from: float = 8.0
## A homing worm keeps turning toward the loudest place on the sand as it
## travels, instead of the point it first committed to, and surfaces only when
## it gets there. Sources close together count as one: a column of men is one
## loud thing.
@export var homing: bool = false
@export var homing_interval: float = 2.0
@export var cluster_radius: float = 220.0

var worm_sign: float = 0.0
var stage: Stage = Stage.CALM
var state: EventState = EventState.IDLE
var target: Vector2 = Vector2.INF
var cooldown_remaining: float = 0.0
## Rolling entries of {position, strength, time, label, emitter}.
var recent: Array[Dictionary] = []
var strongest_label: String = "none"
var strongest_position: Vector2 = Vector2.INF
var strongest_strength: float = 0.0

var _stage_time: float = 0.0
## The meter's fill when the worm committed; from there the bar tracks its travel.
var _commit_ratio: float = 0.0
var _homing_time: float = 0.0


func _ready() -> void:
	add_to_group("worm_threat")
	if event != null:
		event.finished.connect(_on_event_finished)
		event.erupted.connect(_on_event_erupted)


# --------------------------------------------------------------------------
# Input from emitters
# --------------------------------------------------------------------------

func report_sign(position: Vector2, amount: float, label: String, emitter: Node = null) -> void:
	if amount <= 0.0 or not is_finite(amount) or not position.is_finite():
		return
	if state == EventState.COOLDOWN:
		# The desert is still settling; activity registers but cannot re-commit.
		amount *= 0.25
	worm_sign = clampf(worm_sign + amount, 0.0, threshold)
	recent.append({
		"position": position, "strength": amount, "time": _now(),
		"label": label, "emitter": emitter,
	})
	worm_sign_changed.emit(worm_sign, threshold)


func add_debug_sign(amount: float) -> void:
	worm_sign = clampf(worm_sign + amount, 0.0, threshold)
	if amount > 0.0 and recent.is_empty() and is_instance_valid(get_tree().get_first_node_in_group("player")):
		var player: Node2D = get_tree().get_first_node_in_group("player")
		recent.append({"position": player.global_position, "strength": amount, "time": _now(), "label": "Debug", "emitter": null})
	worm_sign_changed.emit(worm_sign, threshold)


# --------------------------------------------------------------------------
# Runtime
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_prune()
	if state == EventState.COOLDOWN:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
		if cooldown_remaining <= 0.0:
			state = EventState.IDLE
	# A committed worm does not lose interest because Paul stood still.
	if state != EventState.APPROACHING and state != EventState.ARRIVAL and worm_sign > 0.0:
		worm_sign = maxf(worm_sign - decay_per_second * delta, 0.0)
		worm_sign_changed.emit(worm_sign, threshold)
	_recompute_strongest()
	_stage_time += delta
	_update_stage()
	_update_event()
	if homing and state == EventState.APPROACHING:
		_homing_time += delta
		if _homing_time >= homing_interval:
			_homing_time = 0.0
			_turn_to_loudest()


func _update_stage() -> void:
	var next: Stage = _stage_for(worm_sign)
	if next == stage:
		return
	# Hysteresis and a minimum dwell keep the stage readable instead of flickering.
	if next < stage:
		if _stage_time < minimum_stage_seconds:
			return
		if worm_sign > _lower_bound(stage) - stage_hysteresis:
			return
	var previous: Stage = stage
	stage = next
	_stage_time = 0.0
	worm_stage_changed.emit(stage, previous)
	if stage == Stage.IMMINENT:
		worm_imminent.emit()


func _stage_for(value: float) -> Stage:
	for index in range(stage_thresholds.size() - 1, -1, -1):
		if value >= stage_thresholds[index]:
			return (index + 1) as Stage
	return Stage.CALM


func _lower_bound(for_stage: Stage) -> float:
	var index: int = int(for_stage) - 1
	return stage_thresholds[index] if index >= 0 and index < stage_thresholds.size() else 0.0


func _update_event() -> void:
	match state:
		EventState.IDLE, EventState.BUILDING:
			state = EventState.BUILDING if worm_sign > 0.0 else EventState.IDLE
			if stage >= Stage.APPROACHING:
				_commit()
		EventState.APPROACHING:
			if not homing and worm_sign >= threshold and event != null and not event.erupting():
				event.erupt()
				state = EventState.ARRIVAL
		_:
			pass


## Commits at once to whatever is loudest now, if a worm is not already
## coming: a mission that opens with one on its way (1.3).
func commit_now() -> bool:
	if state != EventState.IDLE and state != EventState.BUILDING:
		return false
	_update_stage()
	_commit()
	return state == EventState.APPROACHING


## A worm already on its way turns toward `point` (a thumper). Returns
## whether it did: one that has surfaced, or is not coming, does not.
func retarget(point: Vector2) -> bool:
	if state != EventState.APPROACHING or event == null or event.erupting():
		return false
	target = point
	event.redirect(point)
	worm_approach_started.emit(target)
	return true


## The worm commits to whatever has been shaking the sand hardest, aggregated
## per emitter so a machine running steadily outweighs a person walking past.
func _commit() -> void:
	target = _choose_target()
	if not target.is_finite():
		return
	state = EventState.APPROACHING
	_commit_ratio = ratio()
	worm_approach_started.emit(target)
	if event != null:
		event.begin(target, danger_radius)


func _choose_target() -> Vector2:
	if homing:
		return loudest_place()
	_recompute_strongest()
	return strongest_position


## Where the sand is loudest now: each source's recent total, plus every other
## source within `cluster_radius` of it.
func loudest_place() -> Vector2:
	var totals: Dictionary = {}
	var latest: Dictionary = {}
	for entry in recent:
		var key: Variant = entry["emitter"] if entry["emitter"] != null else entry["label"]
		totals[key] = float(totals.get(key, 0.0)) + float(entry["strength"])
		latest[key] = entry
	var best_point: Vector2 = Vector2.INF
	var best: float = 0.0
	for key in totals:
		var point: Vector2 = latest[key]["position"]
		var sum: float = 0.0
		for other in totals:
			if (latest[other]["position"] as Vector2).distance_to(point) <= cluster_radius:
				sum += float(totals[other])
		if sum > best:
			best = sum
			best_point = point
	return best_point


func _turn_to_loudest() -> void:
	if event == null or event.erupting():
		return
	var point: Vector2 = loudest_place()
	if point.is_finite() and point.distance_to(target) > 40.0:
		target = point
		event.redirect(point)


## Aggregated per emitter over the memory window, so a machine running steadily
## outweighs a person walking past it.
func _recompute_strongest() -> void:
	var totals: Dictionary = {}
	var latest: Dictionary = {}
	for entry in recent:
		var key: Variant = entry["emitter"] if entry["emitter"] != null else entry["label"]
		totals[key] = float(totals.get(key, 0.0)) + float(entry["strength"])
		latest[key] = entry
	var best: Variant = null
	var best_total: float = 0.0
	for key in totals:
		if float(totals[key]) > best_total:
			best_total = float(totals[key])
			best = key
	if best == null:
		return
	var entry: Dictionary = latest[best]
	strongest_label = str(entry["label"])
	strongest_position = entry["position"]
	strongest_strength = best_total


func _prune() -> void:
	var cutoff: float = _now() - maxf(memory_seconds, 1.0)
	while not recent.is_empty() and float(recent[0]["time"]) < cutoff:
		recent.remove_at(0)
	if recent.is_empty():
		strongest_label = "none"
		strongest_strength = 0.0


# --------------------------------------------------------------------------
# Event resolution
# --------------------------------------------------------------------------

## Anyone standing on unsafe ground inside the eruption is caught. Rock is the
## whole lesson, so it is checked first and without exception.
func _on_event_erupted(position: Vector2, radius: float) -> void:
	worm_arrived.emit(position, radius)
	for group in ["player", "allies", "enemies"]:
		for actor: Node2D in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(actor) or not actor.can_process():
				continue
			var health: HealthComponent = HealthComponent.find_on(actor)
			if health != null and health.is_dead:
				continue
			var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(actor)
			if safety != null and safety.is_safe():
				continue
			if actor.global_position.distance_to(position) > radius:
				continue
			actor_caught.emit(actor)
			if health != null:
				health.die()


func _on_event_finished() -> void:
	state = EventState.COOLDOWN
	cooldown_remaining = maxf(cooldown_seconds, 0.0)
	worm_sign = clampf(sign_after_event, 0.0, threshold)
	recent.clear()
	target = Vector2.INF
	_stage_time = 0.0
	stage = _stage_for(worm_sign)
	worm_sign_changed.emit(worm_sign, threshold)
	worm_event_finished.emit()


## Used by death, checkpoint reloads, and section restarts: no stale event may
## survive a reset.
func reset_threat() -> void:
	_homing_time = 0.0
	worm_sign = 0.0
	stage = Stage.CALM
	state = EventState.IDLE
	cooldown_remaining = 0.0
	target = Vector2.INF
	recent.clear()
	strongest_label = "none"
	strongest_strength = 0.0
	_stage_time = 0.0
	if event != null:
		event.cancel()
	worm_sign_changed.emit(worm_sign, threshold)


## Developer control, so it must always do what it says. In a desert that has
## sensed nothing there is no target to travel to, and _commit would silently
## refuse; the worm then comes for the intruder, who is the only thing there.
func force_arrival() -> void:
	if state == EventState.ARRIVAL or state == EventState.COOLDOWN:
		return
	worm_sign = threshold
	if state != EventState.APPROACHING:
		if not _choose_target().is_finite():
			var intruder: Node2D = get_tree().get_first_node_in_group("player") as Node2D
			if is_instance_valid(intruder):
				report_sign(intruder.global_position, 1.0, "Forced arrival")
		_commit()
	if event != null and not event.erupting():
		event.erupt()
		state = EventState.ARRIVAL


func is_worm_approaching() -> bool:
	return state == EventState.APPROACHING or state == EventState.ARRIVAL


func stage_name() -> String:
	return Stage.keys()[stage]


func state_name() -> String:
	return EventState.keys()[state]


## Player-facing wording; the exact number stays in F1.
func stage_text() -> String:
	match stage:
		Stage.DISTANT:
			return "SIGN DETECTED"
		Stage.INTERESTED:
			return "WORM SIGN RISING"
		Stage.APPROACHING:
			return "WORM APPROACHING"
		Stage.IMMINENT:
			return "WORM IMMINENT"
		Stage.ARRIVAL:
			return "WORM"
		_:
			return "CALM"


func ratio() -> float:
	return clampf(worm_sign / maxf(threshold, 1.0), 0.0, 1.0)


## What the meter shows. Building up, it is the sign. Once the worm has
## committed it becomes the approach: it fills with the worm's travel and is
## full exactly when the worm surfaces, whichever comes first - the travel
## ending or the sign reaching the threshold.
func display_ratio() -> float:
	if state == EventState.ARRIVAL or (event != null and event.erupting()):
		return 1.0
	if state == EventState.APPROACHING and event != null and event.active():
		return maxf(ratio(), lerpf(_commit_ratio, 1.0, event.travel_ratio()))
	return ratio()


## Seconds until the committed worm surfaces; 0 when none is coming.
func arrival_eta() -> float:
	if state != EventState.APPROACHING or event == null:
		return 0.0
	return event.eta()


func meter_visible() -> bool:
	return worm_sign >= visible_from or stage > Stage.CALM or is_worm_approaching()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Debug-only shortcuts: iterating on threat escalation by actually walking
## around the desert each time is unworkable.
func _unhandled_key_input(event: InputEvent) -> void:
	var debug: Node = get_node_or_null("/root/GameManager")
	if debug == null or not debug.debug_visible or event.is_echo() or not event.is_pressed():
		return
	if InputMap.has_action("worm_debug_boost") and event.is_action_pressed("worm_debug_boost"):
		add_debug_sign(15.0)
	elif InputMap.has_action("worm_debug_calm") and event.is_action_pressed("worm_debug_calm"):
		if state == EventState.IDLE or state == EventState.BUILDING:
			add_debug_sign(-15.0)
		else:
			reset_threat()
	elif InputMap.has_action("worm_debug_arrival") and event.is_action_pressed("worm_debug_arrival"):
		force_arrival()
	else:
		return
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null or not manager.debug_visible:
		return
	var font: Font = ThemeDB.fallback_font
	for entry in recent:
		var point: Vector2 = to_local(entry["position"])
		var strength: float = float(entry["strength"])
		draw_circle(point, 4.0 + strength * 1.5, Color(1.0, 0.72, 0.35, 0.35))
	if target.is_finite():
		var centre: Vector2 = to_local(target)
		draw_arc(centre, danger_radius, 0, TAU, 48, Color(1.0, 0.45, 0.3, 0.6), 2.0, true)
		IsoView.draw_text(self, font, centre, Vector2(6, -danger_radius - 8), "WORM TARGET %s" % strongest_label, 12, Color(1.0, 0.6, 0.4))
