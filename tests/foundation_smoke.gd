extends SceneTree
## Run: godot --headless --path . --script res://tests/foundation_smoke.gd
##
## RTS foundation: right-click orders move Paul along the navigation mesh,
## left-click and box drags select, WASD pans the free camera without moving
## anyone, and F1 still toggles the metrics panel.

const ARENA: String = "res://scenes/missions/harvester_raid_test.tscn"
const TUTORIAL: String = "res://scenes/missions/tutorial/tutorial_arrakeen.tscn"
var failures: int = 0
var player: PlayerController
var squad: SquadManager
var mission: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	# The game boots on the main menu; this suite still exercises the technical
	# test arena, which the developer launcher (MISSIONS) keeps reachable.
	_check(main_path == "res://scenes/menu/main_menu.tscn", "the main menu is the configured main scene")
	_check(load(main_path) != null, "launcher scene loads")
	_check(ResourceLoader.exists(ARENA) and ResourceLoader.exists(TUTORIAL), "both missions remain reachable")
	var packed: PackedScene = load(ARENA) as PackedScene
	mission = packed.instantiate() as Node2D
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
	squad = mission.get_node("SquadManager") as SquadManager
	await _frames(6)
	_check(root.has_node("GameManager"), "GameManager autoload present")
	_check(player.global_position == mission.get_node("Environment/SpawnMarker").global_position, "player spawns in clearing")
	for action in ["move_up", "move_down", "move_left", "move_right", "crouch", "prescience", "pause_game", "fire_primary", "squad_context", "melee_attack", "debug_toggle"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "bound input: " + action)
	_check(squad.paul_selected and player.selected, "Paul starts selected, so the first right-click already works")

	# Open ground away from all obstacles for speed and stopping measurements.
	player.teleport_to(Vector2(-1100, 750))
	await _frames(3)
	var goal: Vector2 = Vector2(-700, 750)
	await _right_click(goal)
	await _frames(2)
	_check(player.order == PlayerController.Order.MOVE and player.velocity.x > 0.0 and player.velocity.length() < player.walk_speed, "right-click ground: Paul accelerates toward it")
	await _frames(25)
	_check(absf(player.velocity.length() - player.walk_speed) < 1.0, "walking reaches configured speed")
	_check(player.aim_direction.x > 0.9, "Paul faces where he walks")
	await _frames(150)
	_check(player.global_position.distance_to(goal) <= player.arrive_distance + 4.0, "Paul arrives at the clicked point")
	await _frames(20)
	_check(player.order == PlayerController.Order.IDLE and player.velocity.is_zero_approx(), "and stops there")

	# Double right-click runs.
	await _right_click(Vector2(-1100, 750))
	await _right_click(Vector2(-1100, 750))
	await _frames(30)
	_check(player.running and player.is_sprinting and absf(player.velocity.length() - player.sprint_speed) < 1.0, "double right-click runs at sprint speed")
	await _right_click(Vector2(-1350, 750))
	await _frames(40)
	_check(not player.is_sprinting and absf(player.velocity.length() - player.walk_speed) < 1.0, "a single click walks again")
	player.stop()
	await _frames(20)

	# Order Paul to the far side of a mission rock: the path goes around it.
	player.teleport_to(Vector2(-560, 220))
	await _frames(3)
	var far_side: Vector2 = Vector2(-250, 220)
	player.move_to(far_side)
	var arrived: bool = false
	for index in range(360):
		await _frames(1)
		if player.order == PlayerController.Order.IDLE:
			arrived = player.global_position.distance_to(far_side) < 30.0
			break
	_check(arrived, "Paul paths around a rock instead of pushing into it")

	# The arena edge is not walkable; Paul stops at the nearest reachable point.
	player.teleport_to(Vector2(-1450, 750))
	await _frames(3)
	player.move_to(Vector2(-1700, 750))
	await _frames(120)
	_check(player.position.x > -1565 and player.order == PlayerController.Order.IDLE, "arena boundary holds and the order ends")

	# Queued waypoints.
	player.teleport_to(Vector2(-1100, 750))
	await _frames(3)
	player.move_to(Vector2(-1000, 750))
	player.queue_move(Vector2(-1000, 650))
	await _frames(200)
	_check(player.global_position.distance_to(Vector2(-1000, 650)) < 20.0, "Shift-queued waypoints are walked in order")

	# Selection by click and by box.
	var camera: TacticalCamera = player.get_node("TacticalCamera")
	camera.snap_to(player.global_position)
	await _frames(3)
	await _left_click(player.global_position + Vector2(300, 0))
	_check(not squad.paul_selected and not squad.has_selection(), "left-click on empty ground clears the selection")
	await _right_click(player.global_position + Vector2(100, 0))
	await _frames(3)
	_check(player.order == PlayerController.Order.IDLE, "with nothing selected a right-click orders nobody")
	await _left_click(player.global_position)
	_check(squad.paul_selected, "left-click on Paul selects him")
	await _left_click(player.global_position + Vector2(300, 0))
	await _drag(player.global_position - Vector2(80, 80), player.global_position + Vector2(80, 80))
	_check(squad.paul_selected, "a drag box around Paul selects him")

	# Free camera: WASD pans the view and never moves a unit.
	var start_anchor: Vector2 = camera.anchor
	var paul_before: Vector2 = player.global_position
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	_check(camera.anchor.x > start_anchor.x + 50.0, "WASD pans the camera")
	_check(player.global_position.distance_to(paul_before) < 1.0, "and does not move Paul")
	_check(camera.is_current(), "tactical camera is current")
	camera.snap_to(player.global_position)
	await _frames(3)
	_check(camera.sees(player.global_position, 80.0), "snap_to brings Paul back on screen")

	var ui: CanvasLayer = mission.get_node("UI")
	var panel: Control = ui.get_node("Screen/DebugPanel")
	_check(not panel.visible, "debug starts hidden")
	_key(KEY_F1, true)
	await _frames(3)
	_check(panel.visible and ui.metric_labels.has_all(["FPS", "World position", "Speed", "Sprinting", "Paul order"]), "F1 retains foundation metrics")
	_key(KEY_F1, true, true)
	await _frames(2)
	_check(panel.visible, "key repeat does not flicker debug")
	_key(KEY_F1, false)
	_key(KEY_F1, true)
	await _frames(2)
	_check(not panel.visible, "F1 hides debug")
	_key(KEY_F1, false)

	if "--capture" in OS.get_cmdline_user_args():
		_key(KEY_F1, true)
		await _frames(90)
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		_check(screenshot.save_png("res://.validation/foundation.png") == OK, "rendered screenshot saved")
	print("FOUNDATION SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


## Window coordinates for a world point. Input events arrive in window space,
## which the 1920 x 1080 canvas is stretched into.
func _screen(world: Vector2) -> Vector2:
	var viewport: Viewport = mission.get_viewport()
	return viewport.get_screen_transform() * (viewport.get_canvas_transform() * world)


func _mouse(button: MouseButton, world: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = _screen(world)
	event.global_position = event.position
	Input.parse_input_event(event)


func _right_click(world: Vector2) -> void:
	_mouse(MOUSE_BUTTON_RIGHT, world, true)
	_mouse(MOUSE_BUTTON_RIGHT, world, false)
	await _frames(1)


func _left_click(world: Vector2) -> void:
	_mouse(MOUSE_BUTTON_LEFT, world, true)
	_mouse(MOUSE_BUTTON_LEFT, world, false)
	await _frames(1)


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(MOUSE_BUTTON_LEFT, from, true)
	await _frames(1)
	_mouse(MOUSE_BUTTON_LEFT, to, false)
	await _frames(1)


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
