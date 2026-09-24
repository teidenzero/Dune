extends SceneTree
## Milestone 7: prescience against the real arena, AI, recon, and time authority.
## Command mode is gone; prescience is the only system that bends the clock,
## and its interplay with the RTS pause (Space) is covered in _pause_interplay.

const State = EnemyAIController.State
const Order = AllyAIController.Order

class AimedPlayer extends PlayerController:
	# Paul's facing is scripted so he can watch a subject without an order.
	var aim_point: Vector2 = Vector2.RIGHT

	func _update_aim() -> void:
		aim_direction = global_position.direction_to(aim_point)
		aim_pivot.rotation = aim_direction.angle()

var failures: int = 0
var completed: int = 0
var mission: Node2D
var player: PlayerController
var prescience: PrescienceController
var energy: PrescienceEnergyComponent
var squad: SquadManager
var scout: AllyCharacter
var patroller: EnemyCharacter
var combatant: EnemyCharacter


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _activation_and_energy()
	await _patrol_prediction()
	await _intent_changes()
	await _combat_and_fire()
	await _visibility_rules()
	await _ally_projection()
	await _pause_interplay()
	await _reset_safety()
	_check(completed == 8, "all prescience scenarios completed")
	_check(Engine.time_scale == 1.0, "suite leaves normal game speed")
	_check(TimeScaleManager.holder() == TimeScaleManager.Source.NONE, "suite leaves the clock unheld")
	print("PRESCIENCE SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


# --------------------------------------------------------------------------
# Harness
# --------------------------------------------------------------------------

func _load() -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	root.get_node("GameManager").debug_visible = false
	TimeScaleManager.reset()
	mission = load("res://scenes/missions/harvester_raid_test.tscn").instantiate()
	# The four patrol guards and the shield range stay out of the way; the
	# prescience range is this suite's fixture.
	for branch in ["Enemies", "ShieldRange", "DesertRange"]:
		for actor in mission.get_node(branch).get_children():
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			if actor is CollisionObject2D:
				actor.collision_layer = 0
	mission.get_node("Player").set_script(AimedPlayer)
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	prescience = player.prescience
	energy = player.prescience_energy
	squad = mission.get_node("SquadManager")
	scout = mission.get_node("Allies/Scout")
	patroller = mission.get_node("PrescienceRange/PatrolSubject")
	combatant = mission.get_node("PrescienceRange/CombatSubject")
	for subject: EnemyCharacter in [patroller, combatant]:
		subject.perception.stop()
		subject.weapon.disable()
	for ally: AllyCharacter in [scout, mission.get_node("Allies/Warrior")]:
		ally.ai.set_physics_process(false)
		ally.set_physics_process(false)
		ally.weapon.disable()
		ally.global_position = Vector2(-1500, 950)
	await _frames(20)


## Puts Paul where he can see a subject, so recon actually reports it.
func _watch(subject: Node2D, offset: Vector2) -> void:
	await _watch_from(subject.global_position + offset, subject)


## Recon sight is Paul's own observer, which does not care where he is facing -
## so he can watch a patrol from beside its route without ever entering its cone.
func _watch_from(point: Vector2, subject: Node2D) -> void:
	player.global_position = point
	player.velocity = Vector2.ZERO
	player.aim_point = subject.global_position
	player._update_aim()
	await _frames(40)


## A two-point patrol pauses at each end, so wait for a leg that is under way.
func _await_patrolling() -> bool:
	for index in range(400):
		if patroller.ai.state == State.PATROL and patroller.has_destination and patroller.move_speed > 0.0:
			return true
		await _frames(1)
	return false


## Waits out the anti-double-tap lockout.
func _ready_again() -> void:
	for index in range(200):
		if prescience.lockout <= 0.0:
			return
		await _frames(1)


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(2)


func _track_for(actor: Node2D) -> FuturePredictor.FutureTrack:
	for track: FuturePredictor.FutureTrack in prescience.projections:
		if track.actor == actor:
			return track
	return null


# --------------------------------------------------------------------------
# Scenario 1 - activation, energy, early cancel, duration
# --------------------------------------------------------------------------

func _activation_and_energy() -> void:
	await _load()
	_check(prescience != null and energy != null, "Paul composes a prescience controller and reserve")
	_check(energy.current_energy == energy.max_energy, "the reserve starts full")
	_check(not prescience.active and Engine.time_scale == 1.0, "prescience starts inactive at normal speed")
	await _watch_from(Vector2(-1420, -600), patroller)
	# Exact accounting first: regeneration is re-enabled for its own check below.
	var regen: float = energy.regen_per_second
	energy.regen_per_second = 0.0
	# Gameplay Test D: activation costs energy.
	var before: float = energy.current_energy
	await _tap(KEY_Q)
	_check(prescience.active, "Q activates prescience")
	_check(energy.current_energy == before - energy.activation_cost, "activation spends exactly the activation cost")
	_check(is_equal_approx(Engine.time_scale, prescience.world_time_scale), "the world slows to the configured scale")
	_check(not energy.regenerating, "the reserve does not refill while prescience is active")
	_check(prescience.remaining > 0.0 and prescience.remaining <= prescience.duration, "a real-time duration is running")
	# Gameplay Test E: early cancel.
	await _tap(KEY_Q)
	_check(not prescience.active, "pressing Q again ends prescience early")
	_check(Engine.time_scale == 1.0, "the world returns to normal speed")
	_check(energy.current_energy == before - energy.activation_cost, "early cancel does not refund energy")
	_check(prescience.projections.is_empty(), "no projections remain after prescience ends")
	_check(energy.regenerating, "the reserve resumes refilling")
	# The short lockout stops an accidental double tap.
	_check(prescience.can_activate() != "", "a fresh activation is briefly locked out")
	await _ready_again()
	_check(prescience.can_activate() == "", "the lockout clears on its own")
	# Duration is real time, not slowed time.
	var started: int = Time.get_ticks_msec()
	await _tap(KEY_Q)
	_check(prescience.active, "prescience activates a second time")
	for index in range(900):
		if not prescience.active:
			break
		await _frames(1)
	var elapsed: float = (Time.get_ticks_msec() - started) / 1000.0
	_check(not prescience.active, "prescience ends on its own")
	_check(elapsed < prescience.duration * 3.0, "duration is measured in real time, not slowed game time")
	_check(Engine.time_scale == 1.0, "the world is normal speed again after a natural expiry")
	# Gameplay Test D continued: the reserve eventually refuses.
	energy.current_energy = energy.activation_cost - 1.0
	await _ready_again()
	_check(not prescience.activate(), "an empty reserve refuses activation")
	_check(prescience.last_denied_reason == "NOT ENOUGH PRESCIENCE", "the refusal explains itself")
	_check(Engine.time_scale == 1.0, "a refused activation leaves the clock alone")
	energy.regen_per_second = regen
	var low: float = energy.current_energy
	await _frames(120)
	_check(energy.current_energy > low, "the reserve regenerates over time")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 2 - patrol prediction along the real navigation path
# --------------------------------------------------------------------------

func _patrol_prediction() -> void:
	await _load()
	await _watch_from(Vector2(-1420, -600), patroller)
	_check(await _await_patrolling(), "the subject is patrolling")
	_check(prescience.activate(), "prescience activates while watching a patrol")
	var track: FuturePredictor.FutureTrack = _track_for(patroller)
	_check(track != null, "the patrolling guard is projected")
	if track == null:
		prescience.deactivate()
		completed += 1
		return
	_check(track.positions.size() == 3, "three future samples are produced")
	_check(track.state_name == "PATROL" and is_equal_approx(track.certainty, 1.0), "a settled patrol reads as fully certain")
	for point in track.positions:
		_check(point.is_finite(), "predicted positions are finite")
	var first: float = patroller.global_position.distance_to(track.positions[0])
	var third: float = patroller.global_position.distance_to(track.positions[2])
	_check(third > first, "later samples are further along the path")
	var expected: float = patroller.move_speed * 1.0
	_check(absf(first - expected) < expected * 0.35, "the +1s sample is about one second of travel away")
	# Gameplay Test A: the guard actually goes roughly where it was projected.
	var predicted: Vector2 = track.positions[1]
	prescience.deactivate()
	await _frames(125)
	_check(patroller.global_position.distance_to(predicted) < 70.0, "the guard arrives near its projected +2s position")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 3 - predictions follow a change of intent
# --------------------------------------------------------------------------

func _intent_changes() -> void:
	await _load()
	await _watch_from(Vector2(-1420, -600), patroller)
	_check(await _await_patrolling(), "the subject is patrolling before the disturbance")
	_check(prescience.activate(), "prescience activates on a patrolling guard")
	var patrol_track: FuturePredictor.FutureTrack = _track_for(patroller)
	_check(patrol_track != null and patrol_track.state_name == "PATROL", "the initial projection is a patrol")
	# Gameplay Test B: a disturbance changes what the guard intends to do.
	patroller.perception.set_physics_process(true)
	var bus: DisturbanceBus = mission.get_node("Disturbances")
	bus.emit_noise(patroller.global_position + Vector2(220, 0), 600.0, null, DisturbanceBus.Type.GUNSHOT)
	for index in range(400):
		var current: FuturePredictor.FutureTrack = _track_for(patroller)
		if current != null and current.state_name != "PATROL":
			break
		await _frames(1)
	var changed: FuturePredictor.FutureTrack = _track_for(patroller)
	_check(changed != null and changed.state_name != "PATROL", "the projection follows the guard into a new state")
	_check(changed != null and changed.certainty < 1.0, "a less settled intent reads as less certain")
	prescience.deactivate()
	completed += 1


# --------------------------------------------------------------------------
# Scenario 4 - combat movement and predicted fire
# --------------------------------------------------------------------------

func _combat_and_fire() -> void:
	await _load()
	patroller.process_mode = Node.PROCESS_MODE_DISABLED
	patroller.collision_layer = 0
	await _watch(combatant, Vector2(0, 300))
	# This scenario is the one that wants a live, seeing, armed guard.
	combatant.perception.set_physics_process(true)
	combatant.weapon.enabled = true
	combatant.weapon.set_physics_process(true)
	combatant.face_position(player.global_position)
	combatant.perception._set_detection(combatant.perception.detection_max)
	for index in range(400):
		if combatant.ai.state == State.COMBAT:
			break
		await _frames(1)
	_check(combatant.ai.state == State.COMBAT, "the subject engages Paul")
	# Held in COMBAT with a live weapon: it still has an imminent shot to
	# predict, it simply never takes it while the assertions run.
	combatant.ai.set_physics_process(false)
	_check(prescience.activate(), "prescience activates during combat")
	var track: FuturePredictor.FutureTrack = null
	for index in range(200):
		track = _track_for(combatant)
		if track != null and track.fires:
			break
		await _frames(1)
	_check(track != null, "the engaging guard is projected")
	# Gameplay Test C: the shot he is about to take is drawn.
	_check(track != null and track.fires, "an imminent shot is predicted")
	_check(track != null and track.fire_delay <= prescience.prediction_horizon, "the shot falls inside the prediction horizon")
	_check(track != null and track.fire_from.is_finite() and track.fire_to.is_finite(), "the firing line has finite ends")
	_check(track != null and is_equal_approx(track.certainty, 0.55), "combat intent reads as the least certain")
	_check(prescience.danger, "a firing line through Paul raises the incoming-fire warning")
	# Combat gating: prescience is observation, not bullet time.
	var ammo: int = player.weapon_controller.current_ammo
	_check(not player.fire_weapon(), "the fire request is refused while reading the future")
	await _frames(8)
	_check(player.weapon_controller.current_ammo == ammo, "Paul cannot fire while reading the future")
	player.melee_press()
	await _frames(2)
	player.melee_release()
	await _frames(2)
	_check(player.melee.state == MeleeController.State.IDLE, "Paul cannot use the crysknife either")
	player.move_to(player.global_position + Vector2(-200, 0), true)
	await _frames(10)
	_check(not player.running and not player.is_sprinting, "a run order walks during prescience")
	_check(player.current_speed > 0.0 and player.current_speed <= player.walk_speed * prescience.move_speed_multiplier + 1.0, "Paul moves at the reduced prescience pace")
	player.stop()
	prescience.deactivate()
	await _frames(4)
	_check(player.weapon_controller.enabled and player.melee.enabled, "combat returns when prescience ends")
	# Gameplay Test: a dead actor leaves no projection behind.
	await _ready_again()
	_check(prescience.activate(), "prescience activates again")
	_check(_track_for(combatant) != null, "the living guard is projected")
	combatant.health.die()
	await _frames(40)
	_check(_track_for(combatant) == null, "a guard that dies mid-vision loses its projection")
	prescience.deactivate()
	completed += 1


# --------------------------------------------------------------------------
# Scenario 5 - prescience is not omniscience
# --------------------------------------------------------------------------

func _visibility_rules() -> void:
	await _load()
	# Gameplay Test I: an enemy nobody can see is not projected.
	patroller.global_position = Vector2(1400, -900)
	player.global_position = Vector2(-1400, 900)
	await _frames(60)
	_check(prescience.activate(), "prescience activates with no contact")
	_check(_track_for(patroller) == null, "an unseen guard is not revealed by prescience")
	prescience.deactivate()
	# Recon supplies the contact, and only then does the future appear.
	await _watch(patroller, Vector2(0, 240))
	var recon: ReconManager = mission.get_node("ReconManager")
	_check(recon.is_enemy_visible(patroller), "recon reports the guard once Paul can see him")
	await _ready_again()
	_check(prescience.activate(), "prescience activates with contact")
	_check(_track_for(patroller) != null, "a known guard is projected")
	prescience.deactivate()
	completed += 1


# --------------------------------------------------------------------------
# Scenario 6 - selected allies only
# --------------------------------------------------------------------------

func _ally_projection() -> void:
	await _load()
	patroller.process_mode = Node.PROCESS_MODE_DISABLED
	combatant.process_mode = Node.PROCESS_MODE_DISABLED
	var warrior: AllyCharacter = mission.get_node("Allies/Warrior")
	player.global_position = Vector2(-900, 500)
	for ally: AllyCharacter in [scout, warrior]:
		ally.set_physics_process(true)
		ally.ai.set_physics_process(true)
		ally.global_position = player.global_position + Vector2(60 if ally == scout else -60, 60)
	await _frames(20)
	# Gameplay Test H: only the selected companion is projected.
	squad.select_slot(2)
	squad.issue_context(Vector2(-500, 500))
	await _frames(10)
	_check(scout.ai.current_order == Order.MOVE_TO, "the Scout has a real move order")
	_check(prescience.activate(), "prescience activates with a Fremen selected")
	var scout_track: FuturePredictor.FutureTrack = _track_for(scout)
	_check(scout_track != null and scout_track.friendly, "the selected Scout is projected as friendly")
	_check(_track_for(warrior) == null, "the unselected Warrior is not projected")
	_check(scout_track != null and scout_track.state_name == "MOVE_TO", "the ally projection reports its order")
	_check(scout_track != null and scout_track.positions[2].distance_to(scout.global_position) > 20.0, "a moving ally is projected ahead of itself")
	prescience.deactivate()
	completed += 1


# --------------------------------------------------------------------------
# Scenario 7 - one owner of the clock, and the RTS pause
# --------------------------------------------------------------------------

func _pause_interplay() -> void:
	await _load()
	await _watch_from(Vector2(-1420, -600), patroller)
	# Gameplay Test F: another holder of the clock blocks prescience. Command
	# mode no longer exists, but the time authority still enforces one owner.
	_check(TimeScaleManager.request(TimeScaleManager.Source.COMMAND_MODE, 0.4), "another source can take the free clock")
	_check(not prescience.activate(), "prescience is refused while another source holds the clock")
	_check(prescience.last_denied_reason == "TIME IS ALREADY BENT", "the refusal explains itself")
	_check(is_equal_approx(Engine.time_scale, 0.4), "the refused activation did not disturb the holder")
	_check(energy.current_energy == energy.max_energy, "a refused activation costs nothing")
	TimeScaleManager.release(TimeScaleManager.Source.COMMAND_MODE)
	await _ready_again()
	_check(Engine.time_scale == 1.0, "the released clock is back to normal speed")
	_check(prescience.activate(), "prescience works once the clock is free")
	_check(TimeScaleManager.is_held_by(TimeScaleManager.Source.PRESCIENCE), "the time authority records prescience as the holder")
	_check(not TimeScaleManager.request(TimeScaleManager.Source.COMMAND_MODE, 0.4), "no other source can take the clock from prescience")
	_check(is_equal_approx(Engine.time_scale, prescience.world_time_scale), "prescience kept its own time scale")
	# Space pauses the whole world mid-vision; the vision itself is paused too.
	await _frames(10)
	var energy_held: float = energy.current_energy
	await _tap(KEY_SPACE)
	_check(squad.paused and paused, "Space pauses the game during prescience")
	var remaining_at_pause: float = prescience.remaining
	# More frames than the whole vision lasts (--fixed-fps 60 makes frames the clock).
	await _frames(int(prescience.duration * 60.0) + 60)
	_check(prescience.active, "prescience outlasts a pause longer than its own duration")
	_check(prescience.remaining == remaining_at_pause, "the real-time countdown is frozen while paused")
	_check(is_equal_approx(Engine.time_scale, prescience.world_time_scale) and TimeScaleManager.is_held_by(TimeScaleManager.Source.PRESCIENCE), "pausing leaves prescience holding the clock")
	_check(energy.current_energy == energy_held and not energy.regenerating, "the reserve neither drains nor refills while paused")
	_check(not prescience.projections.is_empty(), "the projections stay on screen while paused")
	# Q is Paul's own input, and Paul is paused: it does nothing until resume.
	await _tap(KEY_Q)
	_check(prescience.active, "Q cannot end prescience while the game is paused")
	await _tap(KEY_SPACE)
	_check(not squad.paused and not paused, "Space resumes the game")
	await _frames(10)
	_check(prescience.active and prescience.remaining < remaining_at_pause, "the countdown resumes where it stopped")
	for index in range(900):
		if not prescience.active:
			break
		await _frames(1)
	_check(not prescience.active and Engine.time_scale == 1.0, "prescience still expires on its own after the pause")
	_check(TimeScaleManager.holder() == TimeScaleManager.Source.NONE, "expiry frees the clock")
	# A pause while prescience is idle does not start it, and Q waits for resume.
	await _ready_again()
	await _tap(KEY_SPACE)
	await _tap(KEY_Q)
	_check(not prescience.active and Engine.time_scale == 1.0, "Q does not open a vision while paused")
	await _tap(KEY_SPACE)
	await _tap(KEY_Q)
	_check(prescience.active, "Q works again once play resumes")
	prescience.deactivate()
	await _frames(4)
	_check(Engine.time_scale == 1.0 and TimeScaleManager.holder() == TimeScaleManager.Source.NONE, "releasing prescience frees the clock")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 8 - reset safety
# --------------------------------------------------------------------------

func _reset_safety() -> void:
	await _load()
	await _watch_from(Vector2(-1420, -600), patroller)
	# Paul dying mid-vision must not leave the world slowed.
	_check(prescience.activate(), "prescience activates before Paul is hit")
	player.health.die()
	await _frames(6)
	_check(not prescience.active, "Paul going down ends prescience")
	_check(Engine.time_scale == 1.0, "death restores normal speed")
	_check(prescience.projections.is_empty(), "death clears every projection")
	# A scene teardown mid-vision must not leak the slowed clock either.
	await _load()
	await _watch_from(Vector2(-1420, -600), patroller)
	_check(prescience.activate(), "prescience activates before teardown")
	mission.queue_free()
	await _frames(6)
	_check(Engine.time_scale == 1.0, "scene teardown restores normal speed")
	_check(TimeScaleManager.holder() == TimeScaleManager.Source.NONE, "teardown releases the clock")
	# The arena carries its own prescience fixtures.
	await _load()
	_check(is_instance_valid(patroller) and patroller.patrol_route != null, "the arena provides a patrolling subject")
	_check(is_instance_valid(combatant), "the arena provides a second subject for combat states")
	root.get_node("GameManager").debug_visible = true
	await _watch_from(Vector2(-1420, -600), patroller)
	_check(prescience.activate(), "prescience activates for the debug capture")
	await _frames(20)
	var metrics: Dictionary = mission.get_node("UI").metric_labels
	for row in ["Prescience active", "Prescience energy", "Prescience remaining", "Prediction horizon", "Projection updates", "Tracked actors", "Time scale holder"]:
		_check(metrics.has(row), "F1 debug overlay shows '%s'" % row)
	_check(metrics.has("PatrolSubject prediction") and metrics.has("PatrolSubject future"), "F1 shows per-actor prediction data")
	await _capture("m7_prescience_debug")
	prescience.deactivate()
	root.get_node("GameManager").debug_visible = false
	await _frames(4)
	_check(Engine.time_scale == 1.0, "the suite ends at normal speed")
	completed += 1


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
