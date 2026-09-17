extends SceneTree
## Run: godot --headless --path . --script res://tests/foundation_smoke.gd

const ARENA: String = "res://scenes/missions/harvester_raid_test.tscn"
const TUTORIAL: String = "res://scenes/missions/tutorial/tutorial_arrakeen.tscn"
var failures: int = 0
var player: PlayerController


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	# Milestone 6.1 boots on the developer launcher; this suite still exercises
	# the technical test arena, which the launcher keeps one keypress away.
	_check(main_path == "res://scenes/missions/mission_select.tscn", "developer launcher is the configured main scene")
	_check(load(main_path) != null, "launcher scene loads")
	_check(ResourceLoader.exists(ARENA) and ResourceLoader.exists(TUTORIAL), "both missions remain reachable")
	var packed: PackedScene = load(ARENA) as PackedScene
	var mission: Node2D = packed.instantiate() as Node2D
	# Isolate foundation regression from live AI; ai_smoke exercises the guards.
	mission.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	mission.get_node("ShieldRange").process_mode = Node.PROCESS_MODE_DISABLED
	mission.get_node("PrescienceRange").process_mode = Node.PROCESS_MODE_DISABLED
	mission.get_node("DesertRange").process_mode = Node.PROCESS_MODE_DISABLED
	# Squad has its own suite; preserve isolated earlier milestone fixtures.
	mission.get_node("Allies").free()
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player") as PlayerController
	await _frames(3)
	_check(root.has_node("GameManager"), "GameManager autoload present")
	_check(player.global_position == mission.get_node("Environment/SpawnMarker").global_position, "player spawns in clearing")
	for action in ["move_up", "move_down", "move_left", "move_right", "sprint", "interact", "prescience", "squad_command", "debug_toggle"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "bound input: " + action)

	# Open space away from all obstacles for speed and stopping measurements.
	player.position = Vector2(-1100, 750)
	Input.action_press("move_right")
	await _frames(2)
	_check(player.velocity.x > 0.0 and player.velocity.length() < player.walk_speed, "accelerates gradually")
	await _frames(20)
	_check(absf(player.velocity.length() - player.walk_speed) < 0.1, "walking reaches configured speed")
	_check(player.position.x > -1100, "movement changes world position")
	Input.action_press("move_up")
	await _frames(20)
	_check(absf(player.velocity.length() - player.walk_speed) < 0.1, "diagonal speed is normalized")
	_check(player.velocity.x > 0.0 and player.velocity.y < 0.0, "diagonal direction correct")
	Input.action_press("sprint")
	await _frames(20)
	_check(player.is_sprinting and absf(player.velocity.length() - player.sprint_speed) < 0.1, "Shift action sprints")
	Input.action_release("sprint")
	await _frames(15)
	_check(not player.is_sprinting and absf(player.velocity.length() - player.walk_speed) < 0.1, "releasing sprint returns to walk")
	Input.action_release("move_right")
	Input.action_release("move_up")
	await _frames(2)
	_check(player.velocity.length() > 0.0 and player.velocity.length() < player.walk_speed, "release decelerates gradually")
	await _frames(15)
	_check(player.velocity.is_zero_approx(), "release stops movement")

	# Drive into the left face of the actual mission rock, then steer around it.
	player.position = Vector2(-500, 220)
	Input.action_press("move_right")
	await _frames(90)
	_check(player.position.x < -400 and player.get_slide_collision_count() > 0, "rock physically blocks movement")
	Input.action_release("move_right")
	Input.action_press("move_up")
	await _frames(60)
	Input.action_release("move_up")
	Input.action_press("move_right")
	await _frames(65)
	_check(player.position.x > -340, "can move around rock")
	Input.action_release("move_right")
	await _frames(15)

	player.position = Vector2(-1530, 750)
	Input.action_press("move_left")
	await _frames(40)
	_check(player.position.x > -1565 and player.get_slide_collision_count() > 0, "arena boundary blocks movement")
	Input.action_release("move_left")
	await _frames(15)

	var ui: CanvasLayer = mission.get_node("UI")
	var panel: Control = ui.get_node("Screen/DebugPanel")
	_check(not panel.visible, "debug starts hidden")
	_key(KEY_F1, true)
	await _frames(3)
	_check(panel.visible and ui.metric_labels.has_all(["FPS", "World position", "Speed", "Sprinting"]), "F1 retains foundation metrics")
	_key(KEY_F1, true, true)
	await _frames(2)
	_check(panel.visible, "key repeat does not flicker debug")
	_key(KEY_F1, false)
	_key(KEY_F1, true)
	await _frames(2)
	_check(not panel.visible, "F1 hides debug")
	_key(KEY_F1, false)

	player.position = Vector2(-600, 280)
	var camera: Camera2D = player.get_node("TacticalCamera")
	await _frames(90)
	_check(camera.is_current() and camera.position_smoothing_enabled, "smooth tactical camera active")
	# Mouse look is a constant offset on screen, so its world-space reach grows
	# as the view widens. Bounded means bounded against that, not against a
	# constant that only held while the camera sat at zoom 1.0.
	_check(camera.position.length() <= camera.look_reach() + 0.1, "mouse look remains bounded")
	_check(camera.look_reach() > camera.mouse_look_strength, "and its world reach follows the widened default view")
	# Mouse look travels further in world space now that the view is wider, so
	# the same smoothing rate needs longer to converge. Measured: it settles to
	# under half a pixel; this waits for that rather than sampling mid-glide.
	await _frames(120)
	_check(camera.get_screen_center_position().distance_to(player.position + camera.position) < 4.0, "camera settles on player with look offset")
	_check(camera.sees(player.position, 80.0), "and Paul stays comfortably on screen")
	var expected_aim: Vector2 = (player.get_global_mouse_position() - player.global_position).normalized()
	_check(player.aim_direction.dot(expected_aim) > 0.99, "aim points to world mouse position")
	Input.action_press("move_down")
	await _frames(10)
	expected_aim = (player.get_global_mouse_position() - player.global_position).normalized()
	_check(player.aim_direction.dot(expected_aim) > 0.99 and player.velocity.y > 0, "mouse aim is independent of movement")
	Input.action_release("move_down")
	await _frames(15)

	if "--capture" in OS.get_cmdline_user_args():
		player.position = Vector2(-600, 280)
		_key(KEY_F1, true)
		await _frames(90)
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		_check(screenshot.save_png("res://.validation/foundation.png") == OK, "rendered screenshot saved")
	print("FOUNDATION SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

