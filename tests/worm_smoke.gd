extends SceneTree
## Milestone 8: worm sign, terrain safety, and the arrival event, against the
## real arena, actors, weapons, and camera.

const Stage = WormThreatManager.Stage
const EventState = WormThreatManager.EventState

class AimedPlayer extends PlayerController:
	# Synthetic mouse events do not move the OS cursor.
	var aim_point: Vector2 = Vector2.RIGHT

	func _update_aim() -> void:
		aim_direction = global_position.direction_to(aim_point)
		aim_pivot.rotation = aim_direction.angle()

var failures: int = 0
var completed: int = 0
var mission: Node2D
var player: PlayerController
var worm: WormThreatManager
var event: WormApproachEvent
var machine: SpiceMachine
var scout: AllyCharacter
var warrior: AllyCharacter
var guard: EnemyCharacter

const SAND: Vector2 = Vector2(1000, 760)
const SAND_FAR: Vector2 = Vector2(1360, 620)
const ROCK: Vector2 = Vector2(1420, 880)
const OUTSIDE: Vector2 = Vector2(-600, 280)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _terrain_and_walking()
	await _movement_intensity()
	await _gunfire()
	await _machinery_and_target()
	await _stages_and_hysteresis()
	await _safe_rock_and_arrival()
	await _caught_on_open_sand()
	await _allies_and_reset()
	_check(completed == 8, "all worm scenarios completed")
	_check(Engine.time_scale == 1.0, "suite leaves normal game speed")
	print("WORM SMOKE: %d failure(s)" % failures)
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
	# Patrols and the other ranges stay out of the desert's way.
	for branch in ["Enemies", "ShieldRange", "PrescienceRange"]:
		for actor in mission.get_node(branch).get_children():
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			if actor is CollisionObject2D:
				actor.collision_layer = 0
	mission.get_node("Player").set_script(AimedPlayer)
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	worm = mission.get_node("WormThreat")
	event = mission.get_node("WormEvent")
	machine = mission.get_node("DesertRange/Machine")
	guard = mission.get_node("DesertRange/DesertGuard")
	scout = mission.get_node("Allies/Scout")
	warrior = mission.get_node("Allies/Warrior")
	guard.perception.stop()
	guard.weapon.disable()
	guard.ai.set_physics_process(false)
	guard.set_physics_process(false)
	for ally: AllyCharacter in [scout, warrior]:
		ally.ai.set_physics_process(false)
		ally.set_physics_process(false)
		ally.weapon.disable()
		ally.global_position = OUTSIDE + Vector2(0, 200)
	await _frames(20)


func _place(point: Vector2) -> void:
	player.global_position = point
	player.velocity = Vector2.ZERO
	player.aim_point = point + Vector2.RIGHT * 100.0
	worm.reset_threat()


## Walks Paul with real movement input for a number of frames.
func _travel(action: String, frames: int, sprint: bool = false) -> void:
	if sprint:
		Input.action_press("sprint")
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	if sprint:
		Input.action_release("sprint")
	await _frames(2)


func _terrain_of(actor: Node2D) -> TerrainSafetyComponent:
	return TerrainSafetyComponent.find_on(actor)


# --------------------------------------------------------------------------
# Scenario 1 - terrain decides whether movement carries
# --------------------------------------------------------------------------

func _terrain_and_walking() -> void:
	await _load()
	_check(worm != null and event != null, "the mission composes a worm threat manager and event")
	_check(worm.worm_sign == 0.0 and worm.stage == Stage.CALM, "the desert starts calm")
	var terrain: TerrainSafetyComponent = _terrain_of(player)
	_check(terrain != null, "Paul carries a terrain safety component")
	# Rock first: movement there must not register.
	_place(ROCK)
	await _frames(30)
	_check(terrain.is_safe() and terrain.terrain == TerrainZone.Kind.SAFE_ROCK, "the rock island reads as safe ground")
	await _travel("move_up", 60)
	_check(worm.worm_sign == 0.0, "walking on safe rock generates no worm sign")
	# Ground nobody classified is inert too, so the Arrakeen courtyard is quiet.
	_place(OUTSIDE)
	await _frames(30)
	_check(_terrain_of(player).terrain == TerrainZone.Kind.OTHER, "unclassified ground reads as OTHER")
	await _travel("move_right", 60)
	_check(worm.worm_sign == 0.0, "walking off the desert generates no worm sign")
	# Open sand does register.
	_place(SAND)
	await _frames(30)
	_check(_terrain_of(player).carries_sign(), "the desert range reads as open sand")
	await _travel("move_right", 90)
	var walked: float = worm.worm_sign
	_check(walked > 0.0, "walking on open sand raises worm sign")
	# And it decays once the rhythm stops.
	await _frames(90)
	_check(worm.worm_sign < walked, "worm sign decays when the sand goes quiet")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 2 - crouch, walk and sprint are not the same
# --------------------------------------------------------------------------

func _movement_intensity() -> void:
	await _load()
	_place(SAND)
	await _frames(30)
	await _travel("move_right", 120)
	var walked: float = worm.worm_sign
	_place(SAND)
	await _frames(30)
	await _travel("move_right", 120, true)
	var sprinted: float = worm.worm_sign
	_check(sprinted > walked * 1.5, "sprinting the same ground raises far more sign than walking")
	# Crouching is the quietest of the three.
	_place(SAND)
	await _frames(10)
	_key(KEY_CTRL)
	await _frames(4)
	_check(player.is_crouching, "Paul is crouched")
	var emitter: WormSignEmitter = player.get_node("WormSignEmitter")
	await _travel("move_right", 120)
	var crouched: float = worm.worm_sign
	var crouch_pulse: float = emitter.last_pulse
	_key(KEY_CTRL)
	await _frames(4)
	_check(crouched < walked, "crouch-walking builds far less than walking")
	_check(crouch_pulse > 0.0 and crouch_pulse < emitter.walk_sign, "crouch-walking still registers, but under the decay floor")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 3 - gunfire is a spike, and separate from enemy hearing
# --------------------------------------------------------------------------

func _gunfire() -> void:
	await _load()
	_place(SAND)
	await _frames(30)
	var heard: Array[int] = [0]
	mission.get_node("Disturbances").noise_emitted.connect(
		func(_p: Vector2, _r: float, _s: Node, type: int, _pr: int) -> void:
			if type == DisturbanceBus.Type.GUNSHOT:
				heard[0] += 1)
	var before: float = worm.worm_sign
	Input.action_press("fire_primary")
	await _frames(4)
	Input.action_release("fire_primary")
	await _frames(4)
	var spike: float = worm.worm_sign - before
	_check(spike >= player.weapon_controller.weapon_data.worm_sign_shot - 0.1, "a shot spikes worm sign by its configured amount")
	_check(heard[0] == 1, "the same shot still raises exactly one hearing disturbance")
	_check(spike > 1.0, "a single shot moves the desert more than a footstep")
	# A sustained firefight escalates the stage quickly.
	# Spaced to the weapon's actual fire rate rather than spamming the button.
	for index in range(14):
		if player.weapon_controller.current_ammo == 0:
			player.weapon_controller.current_ammo = player.weapon_controller.weapon_data.magazine_size
		Input.action_press("fire_primary")
		await _frames(3)
		Input.action_release("fire_primary")
		await _frames(21)
	_check(worm.stage >= Stage.INTERESTED, "a sustained firefight on open sand escalates the threat")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 4 - standing vibration, and what the worm commits to
# --------------------------------------------------------------------------

func _machinery_and_target() -> void:
	await _load()
	_place(ROCK)
	await _frames(30)
	_check(not machine.running, "the rig starts idle")
	machine.set_running(true)
	_check(machine.running and machine.emitter.continuous_active, "the rig can be started")
	var start: float = worm.worm_sign
	await _frames(180)
	_check(worm.worm_sign > start + 3.0, "a running rig raises worm sign while nobody moves")
	_check(worm.strongest_label.contains("Spice"), "the rig becomes the strongest vibration source")
	# It should also be what the worm commits to.
	for index in range(3000):
		if worm.state == EventState.APPROACHING:
			break
		await _frames(1)
	_check(worm.state == EventState.APPROACHING, "sustained vibration commits a worm")
	_check(worm.target.distance_to(machine.global_position) < 80.0, "the worm targets the rig, not the bystander")
	_check(event.active() and event.origin.is_finite(), "an approach event begins with a direction of arrival")
	machine.set_running(false)
	_check(not machine.emitter.continuous_active, "the rig can be stopped")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 5 - stages are readable and do not flicker
# --------------------------------------------------------------------------

func _stages_and_hysteresis() -> void:
	await _load()
	_place(ROCK)
	worm.decay_per_second = 0.0
	await _frames(20)
	var seen: Array[int] = []
	worm.worm_stage_changed.connect(func(stage: int, _prev: int) -> void: seen.append(stage))
	worm.add_debug_sign(25.0)
	await _frames(6)
	_check(worm.stage == Stage.DISTANT, "twenty-five sign reads as DISTANT")
	worm.add_debug_sign(20.0)
	await _frames(6)
	_check(worm.stage == Stage.INTERESTED, "forty-five sign reads as INTERESTED")
	# A hair below the boundary must not drop the stage back down.
	worm.worm_sign = 39.0
	await _frames(6)
	_check(worm.stage == Stage.INTERESTED, "a point below the boundary does not step the stage down")
	worm.worm_sign = 20.0
	await _frames(int(worm.minimum_stage_seconds * 60.0) + 20)
	_check(worm.stage == Stage.DISTANT, "a real drop does step the stage down")
	_check(seen.size() <= 4, "the stage did not flicker while crossing a boundary")
	_check(worm.stage_text() == "SIGN DETECTED", "each stage has player-facing wording")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 6 - rock is the answer
# --------------------------------------------------------------------------

func _safe_rock_and_arrival() -> void:
	await _load()
	_place(SAND)
	await _frames(30)
	var stages: Array[int] = []
	worm.worm_stage_changed.connect(func(stage: int, _prev: int) -> void: stages.append(stage))
	var arrivals: Array[Vector2] = []
	worm.worm_arrived.connect(func(point: Vector2, _radius: float) -> void: arrivals.append(point))
	# Commit a worm, then take shelter before it surfaces.
	machine.set_running(true)
	for index in range(3000):
		if worm.state == EventState.APPROACHING:
			break
		await _frames(1)
	_check(worm.state == EventState.APPROACHING, "the worm commits")
	_place(ROCK)
	worm.worm_sign = 95.0
	await _frames(30)
	_check(_terrain_of(player).is_safe(), "Paul reaches safe rock before arrival")
	# A committed worm keeps coming even though Paul stopped making noise.
	var held: float = worm.worm_sign
	await _frames(60)
	_check(worm.worm_sign >= held, "a committed worm does not lose interest when the sand goes quiet")
	worm.force_arrival()
	await _frames(10)
	_check(arrivals.size() == 1, "the worm arrives once")
	_check(not player.health.is_dead, "safe rock protects Paul from the eruption")
	_check(stages.has(int(Stage.APPROACHING)), "the threat passed through APPROACHING on the way")
	# The event resolves into a cooldown rather than repeating immediately.
	for index in range(900):
		if worm.state == EventState.COOLDOWN:
			break
		await _frames(1)
	_check(worm.state == EventState.COOLDOWN, "the event resolves into a cooldown")
	_check(worm.cooldown_remaining > 0.0, "the cooldown is running")
	_check(worm.worm_sign <= worm.sign_after_event + 0.1, "sign falls back after the event without resetting to nothing")
	_check(not event.active(), "the worm visual is gone once the event finishes")
	machine.set_running(false)
	completed += 1


# --------------------------------------------------------------------------
# Scenario 7 - open sand has consequences
# --------------------------------------------------------------------------

func _caught_on_open_sand() -> void:
	await _load()
	_place(SAND)
	await _frames(30)
	var caught: Array[String] = []
	worm.actor_caught.connect(func(actor: Node2D) -> void: caught.append(str(actor.name)))
	worm.report_sign(SAND, 40.0, "Test")
	worm.force_arrival()
	await _frames(10)
	_check(caught.has("Player"), "Paul standing on open sand inside the eruption is caught")
	_check(player.health.is_dead, "being caught routes through the existing death flow")
	_check(_terrain_of(player).carries_sign(), "he was on open sand, not rock")
	# The existing restart clears every trace of the event.
	await _tap(KEY_ENTER)
	await _frames(40)
	mission = current_scene as Node2D
	worm = mission.get_node("WormThreat")
	event = mission.get_node("WormEvent")
	player = mission.get_node("Player")
	await _frames(20)
	_check(worm.worm_sign == 0.0 and worm.stage == Stage.CALM, "a restart resets worm sign")
	_check(worm.state == EventState.IDLE and not worm.target.is_finite(), "a restart clears the committed target")
	_check(not event.active(), "no worm visual survives a restart")
	_check(not player.health.is_dead, "Paul is back")
	var camera: TacticalCamera = player.get_node("TacticalCamera")
	_check(camera.shake_amount() <= 0.01, "camera shake does not survive a restart")
	completed += 1


# --------------------------------------------------------------------------
# Scenario 8 - companions, camera, and reset safety
# --------------------------------------------------------------------------

func _allies_and_reset() -> void:
	await _load()
	# Fremen move quieter on sand than Paul does.
	var paul_emitter: WormSignEmitter = player.get_node("WormSignEmitter")
	var scout_emitter: WormSignEmitter = scout.get_node("WormSignEmitter")
	_check(scout_emitter.movement_multiplier < paul_emitter.movement_multiplier, "Fremen movement carries less than Paul's")
	_place(OUTSIDE)
	scout.global_position = SAND
	scout.set_physics_process(true)
	await _frames(30)
	_check(_terrain_of(scout).carries_sign(), "the Scout is on open sand")
	worm.reset_threat()
	# Drive the ally directly: its own emitter reads its velocity.
	for index in range(120):
		scout.velocity = Vector2(190, 0)
		scout.move_and_slide()
		await _frames(1)
	scout.velocity = Vector2.ZERO
	_check(worm.strongest_strength > 0.0, "a companion crossing open sand contributes worm sign")
	_check(worm.strongest_label.contains("Fremen"), "the companion is credited as the source")
	# Camera shake is driven by stage and clears on reset.
	var camera: TacticalCamera = player.get_node("TacticalCamera")
	camera.add_shake(0.8)
	await _frames(2)
	_check(camera.shake_amount() > 0.0, "the camera can be shaken")
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_PAUL, "shake does not disturb the camera mode")
	await _frames(120)
	_check(camera.shake_amount() <= 0.01, "shake decays on its own")
	# A reset leaves nothing behind.
	worm.report_sign(SAND, 70.0, "Test")
	await _frames(10)
	worm.reset_threat()
	await _frames(6)
	_check(worm.worm_sign == 0.0 and worm.state == EventState.IDLE, "reset_threat clears sign and state")
	_check(worm.recent.is_empty() and not event.active(), "reset_threat clears memory and the visual")
	# Debug surfaces.
	root.get_node("GameManager").debug_visible = true
	_place(SAND)
	worm.report_sign(SAND, 45.0, "Test")
	await _frames(20)
	var metrics: Dictionary = mission.get_node("UI").metric_labels
	for row in ["Worm sign", "Worm threat stage", "Worm event state", "Worm strongest source", "Worm target", "Worm cooldown", "Player terrain", "Player on safe ground"]:
		_check(metrics.has(row), "F1 debug overlay shows '%s'" % row)
	var hud: Label = mission.get_node("UI/Screen/CombatHUD/Margin/Rows/Worm")
	_check(hud.visible and hud.text.contains("WORM"), "the HUD reports the threat once it is real")
	await _capture("m8_worm_threat")
	worm.force_arrival()
	await _frames(20)
	await _capture("m8_worm_arrival")
	worm.reset_threat()
	root.get_node("GameManager").debug_visible = false
	await _frames(4)
	_check(not hud.visible, "the HUD hides itself again once the desert is calm")
	completed += 1


func _key(code: Key) -> void:
	var event_down: InputEventKey = InputEventKey.new()
	event_down.physical_keycode = code
	event_down.pressed = true
	Input.parse_input_event(event_down)
	var event_up: InputEventKey = InputEventKey.new()
	event_up.physical_keycode = code
	event_up.pressed = false
	Input.parse_input_event(event_up)


func _tap(code: Key) -> void:
	_key(code)
	await _frames(4)


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
