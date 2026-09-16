extends SceneTree
## Exercises production components with actual physics, rays, inputs and signals.

const State = EnemyAIController.State
var failures: int = 0
var completed: int = 0
var mission: Node2D
var player: PlayerController
var guard: EnemyCharacter
var events: Array[Dictionary] = []
var transitions: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _crouch_and_pulses()
	await _rates_and_geometry()
	await _suspicion_memory()
	await _hearing_and_priorities()
	await _independent_guards_and_impacts()
	await _vision_cones()
	_check(completed == 6, "all stealth scenarios completed")
	print("STEALTH SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _setup() -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	get_root().get_node("GameManager").debug_visible = false
	mission = load("res://scenes/missions/harvester_raid_test.tscn").instantiate()
	for enemy in mission.get_node("Enemies").get_children():
		if enemy.name != "Guard_D":
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			enemy.collision_layer = 0
	for trainer in mission.get_node("ShieldRange").get_children():
		trainer.process_mode = Node.PROCESS_MODE_DISABLED
		trainer.collision_layer = 0
	for subject in mission.get_node("PrescienceRange").get_children():
		subject.process_mode = Node.PROCESS_MODE_DISABLED
		if subject is CharacterBody2D:
			subject.collision_layer = 0
	mission.get_node("DesertRange").process_mode = Node.PROCESS_MODE_DISABLED
	# Squad has its own suite; preserve isolated earlier milestone fixtures.
	mission.get_node("Allies").free()
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector2(-850, -700)
	guard = mission.get_node("Enemies/Guard_D")
	guard.set_physics_process(false)
	guard.ai.set_physics_process(false)
	guard.position = Vector2(-1100, -700)
	guard.face_position(guard.position + Vector2.LEFT * 100)
	guard.weapon.disable()
	events.clear()
	transitions.clear()
	mission.get_node("Disturbances").noise_emitted.connect(func(pos: Vector2, radius: float, source: Node, type: int, priority: int): events.append({"position": pos, "radius": radius, "source": source, "type": type, "priority": priority}))
	guard.ai.state_changed.connect(func(_old: int, next: int): transitions.append(next))
	await _frames(12)


func _crouch_and_pulses() -> void:
	await _setup()
	guard.perception.set_physics_process(false)
	player.set_physics_process(true)
	_key(KEY_CTRL, true)
	await _frames(3)
	_key(KEY_CTRL, false)
	_check(player.is_crouching and player.get_node("Body").scale.y < 1.0, "physical Ctrl toggles visibly compressed crouch")
	await _frames(40)
	_check(player.is_crouching and events.is_empty(), "toggle persists and stationary crouch emits no noise")
	Input.action_press("move_right")
	await _frames(40)
	_check(absf(player.current_speed - 110.0) < 1.0 and not player.is_sprinting, "crouch movement reaches exported 110 px/s")
	_check(_footsteps(40.0, 1) >= 1 and events.size() <= 2, "crouch footsteps pulse at 40 px, not every frame")
	_check(mission.get_node("UI/Screen/CombatHUD/Margin/Rows/Stealth").text.contains("CROUCHED"), "normal HUD reports crouch")
	_key(KEY_CTRL, true)
	await _frames(2)
	_key(KEY_CTRL, false)
	events.clear()
	await _frames(65)
	_check(not player.is_crouching and absf(player.current_speed - 180.0) < 1.0, "second Ctrl press restores walking")
	_check(_footsteps(80.0, 1) >= 2 and events.size() <= 3, "walking pulses use 80 px radius about twice per second")
	_key(KEY_CTRL, true)
	await _frames(2)
	_key(KEY_CTRL, false)
	Input.action_press("sprint")
	events.clear()
	await _frames(65)
	_check(not player.is_crouching and player.is_sprinting and absf(player.current_speed - 280.0) < 1.0, "Shift exits crouch and reaches sprint speed")
	_check(_footsteps(160.0, 2) >= 3 and events.size() <= 4, "sprint pulses use 160 px and higher priority")
	Input.action_release("move_right")
	Input.action_release("sprint")
	await _frames(20)
	events.clear()
	await _frames(40)
	_check(events.is_empty() and player.stealth_profile.current_noise_radius == 0.0, "stopping silences movement noise")
	player.position = Vector2(1560, 950)
	Input.action_press("move_right")
	await _frames(30)
	events.clear()
	await _frames(45)
	_check(events.is_empty() and player.current_speed < 1.0, "pushing into boundary does not produce footsteps")
	Input.action_release("move_right")
	completed += 1


func _timed_detection(distance: float, crouched: bool, sprinting: bool) -> float:
	await _setup()
	player.position = guard.position + Vector2(distance, 0)
	player.stealth_profile.update_profile(crouched, sprinting, 180.0, 0.0)
	guard.face_position(player.position)
	var frames: int = 0
	while guard.perception.detection_value < 100.0 and frames < 600:
		await _frames(1)
		frames += 1
	return frames / 60.0


func _rates_and_geometry() -> void:
	var walk: float = await _timed_detection(250, false, false)
	var crouch: float = await _timed_detection(350, true, false)
	var sprint: float = await _timed_detection(250, false, true)
	var close: float = await _timed_detection(60, true, false)
	print("BALANCE: walk250=%.2fs crouch350=%.2fs sprint250=%.2fs close60=%.2fs" % [walk, crouch, sprint, close])
	_check(walk >= 1.5 and walk <= 2.5, "medium walking detection takes 1.5–2.5 seconds")
	_check(crouch >= 4.0 and crouch <= 6.0, "medium-long crouch detection takes 4–6 seconds")
	_check(sprint >= 0.75 and sprint <= 1.3 and sprint < walk, "sprint detection is substantially faster")
	_check(close <= 0.6, "very close crouched target is detected rapidly")
	await _setup()
	guard.face_position(player.position)
	player.stealth_profile.update_profile(false, false, 180, 0)
	await _frames(10)
	var walking_rate: float = guard.perception.detection_gain_per_second
	_check(guard.perception.detection_value > 5 and guard.perception.detection_value < 25 and guard.ai.state == State.PATROL, "first sight builds a partial meter without combat")
	_check(guard.get_node("DetectionIndicator").visible, "normal detection bar appears without F1")
	player.stealth_profile.update_profile(true, false, 110, 0)
	await _frames(10)
	_check(guard.perception.detection_gain_per_second < walking_rate * 0.5, "equivalent-distance crouching halves visual gain")
	player.stealth_profile.update_profile(false, false, 0, 0)
	await _frames(10)
	_check(guard.perception.detection_gain_per_second < walking_rate, "standing still reduces gain")
	player.position = guard.position + Vector2(470, 0)
	await _frames(10)
	_check(guard.perception.detection_gain_per_second < walking_rate * 0.5, "near-limit distance reduces detection")
	guard.perception._set_detection(0)
	player.stealth_profile.update_profile(false, false, 180, 0)
	player.position = guard.position + Vector2.RIGHT.rotated(deg_to_rad(40)) * 250
	await _frames(10)
	_check(guard.perception.can_see_target and guard.perception.detection_gain_per_second < walking_rate * 0.65, "peripheral vision gains more slowly than center")
	player.position = guard.position + Vector2(-200, 0)
	await _frames(10)
	_check(not guard.perception.can_see_target and guard.perception.detection_gain_per_second == 0, "rear approach cannot build visual detection")
	guard.position = Vector2(-140, 220)
	player.position = Vector2(-600, 220)
	guard.face_position(player.position)
	await _frames(10)
	_check(not guard.perception.can_see_target, "rock fully blocks visual gain")
	guard.position = Vector2(650, -210)
	player.position = Vector2(100, -210)
	guard.perception.vision_distance = 700
	guard.face_position(player.position)
	await _frames(10)
	_check(not guard.perception.can_see_target, "machinery blocks visual gain")
	guard.perception._set_detection(INF)
	guard.perception.update_detection(NAN)
	_check(is_finite(guard.perception.detection_value), "nonfinite input cannot poison detection meter")
	completed += 1


func _suspicion_memory() -> void:
	await _setup()
	guard.face_position(player.position)
	player.stealth_profile.update_profile(false, false, 180, 0)
	guard.ai.set_physics_process(true)
	for frame in range(120):
		await _frames(1)
		if guard.perception.detection_value >= guard.perception.suspicion_threshold:
			break
	_check(guard.ai.state == State.SUSPICIOUS, "threshold crossing is remembered immediately between AI decision ticks")
	var glimpse: Vector2 = player.position
	player.position = Vector2(-1450, 950)
	await _frames(65)
	_check(guard.ai.state == State.INVESTIGATE and guard.ai.suspicious_position == glimpse, "brief threshold-level glimpse survives disappearance")
	await _setup()
	guard.position = Vector2(-140, 220)
	player.position = Vector2(-140, 470)
	player.stealth_profile.update_profile(false, false, 180, 0)
	guard.face_position(player.position)
	guard.ai.set_physics_process(true)
	for frame in range(180):
		await _frames(1)
		if guard.perception.detection_value >= 40:
			break
	_check(guard.ai.state == State.SUSPICIOUS, "partial detection stops patrol to face Paul")
	var remembered: Vector2 = guard.ai.suspicious_position
	var partial: float = guard.perception.detection_value
	await _capture("stealth_partial")
	player.position = Vector2(-600, 220)
	await _frames(20)
	_check(not guard.perception.can_see_target and guard.perception.detection_value > 0 and guard.perception.detection_value < partial, "cover causes gradual rather than instant decay")
	await _frames(40)
	_check(guard.ai.state == State.INVESTIGATE and guard.ai.suspicious_position == remembered, "partial visual suspicion investigates original visible position")
	player.position = Vector2(-1450, 950)
	guard.set_physics_process(true)
	await _frames(1400)
	_check(guard.ai.state == State.PATROL and guard.perception.detection_value == 0, "failed investigation returns to zero-detection patrol")
	_check(transitions.count(State.SUSPICIOUS) == 1, "residual suspicion does not repeatedly restart state cycle")
	await _setup()
	guard.face_position(player.position)
	player.stealth_profile.update_profile(false, true, 280, 0)
	guard.ai.set_physics_process(true)
	await _frames(90)
	_check(guard.ai.state == State.COMBAT and guard.perception.detection_value == 100, "full detection confirms combat")
	player.position = Vector2(-1450, 950)
	await _frames(35)
	_check(guard.ai.state == State.COMBAT and guard.perception.detection_value == 100, "active combat locks detection through lost-sight grace")
	await _frames(90)
	_check(guard.ai.state == State.SEARCH and guard.perception.detection_value > 0 and guard.perception.detection_value < 100, "search retains decaying identification memory")
	var residual: float = guard.perception.detection_value
	player.position = guard.position + Vector2(250, 0)
	guard.face_position(player.position)
	await _frames(10)
	_check(guard.perception.detection_value > residual, "search reacquisition resumes from residual detection")
	completed += 1


func _hearing_and_priorities() -> void:
	for sample in [{"crouch": true, "sprint": false, "distance": 65.0, "heard": false}, {"crouch": false, "sprint": false, "distance": 65.0, "heard": true}, {"crouch": false, "sprint": true, "distance": 130.0, "heard": true}]:
		await _setup()
		guard.face_position(guard.position + Vector2.LEFT * 100)
		player.position = guard.position + Vector2(sample.distance, 0)
		player.stealth_profile.update_profile(sample.crouch, sample.sprint, 180, 0.55)
		_check((guard.ai.state == State.SUSPICIOUS) == sample.heard, "hearing scales with movement: crouch=%s sprint=%s" % [sample.crouch, sample.sprint])
		_check(not guard.perception.can_see_target, "hearing does not grant visual knowledge")
	await _setup()
	var bus: DisturbanceBus = mission.get_node("Disturbances")
	var sound: Vector2 = guard.position + Vector2(250, 100)
	bus.emit_noise(sound, 650, player, DisturbanceBus.Type.GUNSHOT)
	bus.emit_noise(guard.position + Vector2(0, 20), 160, player, DisturbanceBus.Type.FOOTSTEP, 2)
	bus.emit_noise(guard.position + Vector2(0, 10), 220, player, DisturbanceBus.Type.IMPACT)
	_check(guard.ai.suspicious_position == sound and guard.ai.disturbance_priority == 4, "gunshot memory outranks sprint and impact distractions")
	player.position = Vector2(-1450, 950)
	guard.ai.set_physics_process(true)
	await _frames(60)
	_check(guard.ai.state == State.INVESTIGATE and guard.ai.suspicious_position == sound, "audio investigation follows remembered sound, not hidden player")
	_check(guard.get_node("DetectionIndicator/State").text.contains("?"), "sound-only suspicion displays question mark")
	guard.ai.change_state(State.COMBAT)
	bus.emit_noise(guard.position, 650, player, DisturbanceBus.Type.GUNSHOT)
	_check(guard.ai.state == State.COMBAT and guard.ai.suspicious_position == sound, "combat ignores disturbances")
	completed += 1


func _independent_guards_and_impacts() -> void:
	await _setup()
	var other: EnemyCharacter = mission.get_node("Enemies/Guard_A")
	other.process_mode = Node.PROCESS_MODE_INHERIT
	other.set_physics_process(false)
	other.ai.set_physics_process(false)
	other.position = guard.position + Vector2(0, 150)
	other.face_position(other.position + Vector2.LEFT * 100)
	guard.face_position(player.position)
	player.stealth_profile.update_profile(false, false, 180, 0)
	await _frames(45)
	_check(guard.perception.detection_value > 25 and other.perception.detection_value == 0 and other.ai.state == State.PATROL, "nearby guards maintain independent visual detection")
	var bus: DisturbanceBus = mission.get_node("Disturbances")
	bus.emit_noise(guard.position, 500, guard, DisturbanceBus.Type.GUNSHOT)
	_check(guard.ai.state == State.PATROL and other.ai.state == State.SUSPICIOUS, "rifle sound alerts nearby teammate but ignores emitting guard")
	var event_count: int = events.size()
	await _frames(30)
	_check(events.size() == event_count, "hearing response does not recursively emit noises")
	guard.ai.set_physics_process(false)
	guard.position = Vector2(-140, 220)
	player.position = Vector2(-600, 220)
	player.aim_pivot.rotation = 0
	player.set_process(false)
	events.clear()
	_check(player.weapon_controller.try_fire(), "hidden player can fire a distraction")
	await _frames(25)
	var impacts: int = 0
	for event in events:
		if event.type == DisturbanceBus.Type.IMPACT:
			impacts += 1
			_check(event.radius == 220 and event.priority == 3 and event.source == player, "world impact carries smaller radius, priority and shooter identity")
	_check(impacts == 1, "one consumed projectile emits exactly one world impact")
	player.position = Vector2(-140, 470)
	player.is_crouching = true
	player.stealth_profile.update_profile(true, false, 0, 0)
	player.get_node("Body").scale.y = 0.65
	player.get_node("Hood").scale.y = 0.65
	guard.face_position(player.position)
	guard.perception._set_detection(65)
	await _frames(10)
	await _capture("stealth_alert")
	_key(KEY_F1, true)
	await _frames(3)
	_key(KEY_F1, false)
	_check(guard.get_node("DebugVisuals/Details").text.contains("Gain:") and guard.get_node("DebugVisuals/Details").text.contains("Detect:"), "F1 shows detection calculation and exact value")
	_check(mission.get_node("UI").metric_labels.has("Noise radius"), "F1 exposes player stealth profile")
	await _capture("stealth_debug")
	guard.health.die()
	await _frames(3)
	_check(not guard.get_node("DetectionIndicator").visible, "dead guard hides detection indicator")
	completed += 1


func _footsteps(radius: float, priority: int) -> int:
	var count: int = 0
	for event in events:
		if event.type == DisturbanceBus.Type.FOOTSTEP and event.radius == radius and event.priority == priority:
			count += 1
	return count


# --------------------------------------------------------------------------
# Scenario 6 - the cone the player is told to stay out of is on screen
# --------------------------------------------------------------------------

func _vision_cones() -> void:
	await _setup()
	var cone: VisionCone = guard.get_node("VisionCone")
	_check(cone != null, "every guard carries a vision cone")
	_check(not get_root().get_node("GameManager").debug_visible, "F1 diagnostics are off")
	await _frames(20)
	_check(cone.visible and cone.should_draw(), "the cone is drawn in normal play, not only under F1")
	_check(cone.z_index == VisionCone.CONE_Z and VisionCone.CONE_Z > VisionCone.GROUND_Z, "it sits above the ground and below the actors")
	_check(mission.get_node("Environment/DesertGround").z_index == VisionCone.GROUND_Z, "and the ground is behind that band")
	# It has to be the perception the guard actually uses, or it teaches a lie.
	var reach: float = 0.0
	for point: Vector2 in cone._shape:
		reach = maxf(reach, point.length())
	_check(reach <= guard.perception.vision_distance + 1.0, "the cone reaches no further than the guard can see")
	_check(reach > guard.perception.vision_distance * 0.5, "and is not a token stub")
	var span: float = cone._shape[1].angle_to(cone._shape[cone._shape.size() - 1])
	_check(absf(rad_to_deg(absf(span)) - guard.perception.field_of_view_degrees) < 2.0, "and spans the guard's real field of view")
	# Colour is the same language the detection meter over his head speaks.
	_check(cone._color == DetectionIndicator.CALM, "an unaware guard's cone is calm")
	guard.perception.priority_target = player
	player.position = guard.position + Vector2.LEFT * 150.0
	guard.face_position(player.global_position)
	var waited: int = 0
	while guard.perception.detection_value <= 0.0 and waited < 240:
		await _frames(10)
		waited += 10
	await _frames(cone.segments)
	_check(guard.perception.detection_value > 0.0, "the guard starts noticing Paul")
	_check(cone._color != DetectionIndicator.CALM, "and his cone warms to say so")
	_check(cone._color == DetectionIndicator.alert_color(guard), "cone and detection meter read from one palette")
	# Rock stops sight, so it has to stop the cone too - and only where the rock
	# actually is, which is the difference between clipping and just shrinking.
	guard.position = Vector2(-270, 150)
	guard.face_position(Vector2(400, 150))
	guard.perception.priority_target = null
	await _frames(cone.segments + 20)
	var ahead: float = cone._shape[1 + cone.segments / 2].length()
	var furthest: float = 0.0
	for point: Vector2 in cone._shape:
		furthest = maxf(furthest, point.length())
	_check(ahead < guard.perception.vision_distance * 0.8, "the rock ahead of the guard cuts his cone short")
	_check(furthest > ahead + 100.0, "while the rays either side of it still run their full length")
	# And a body has no field of view.
	guard.health.die()
	await _frames(10)
	_check(not cone.should_draw() and not cone.visible, "a dead guard's cone is gone")
	completed += 1


func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.validation/" + label + ".png")


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

