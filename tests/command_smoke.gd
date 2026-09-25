extends SceneTree
## Free RTS camera, pause, box selection and fan-out orders, command range /
## link states, and the reconnaissance observer foundation. Runs against the
## real mission scene.

const Order = AllyAIController.Order
const Behavior = AllyAIController.Behavior
const Link = CommandLinkComponent.State
var failures: int = 0
var completed: int = 0
var mission: Node2D
var player: PlayerController
var scout: AllyCharacter
var warrior: AllyCharacter
var squad: SquadManager
var camera: TacticalCamera
var recon: ReconManager
var guard: EnemyCharacter


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _free_camera()
	await _pause()
	await _box_selection_and_fan_out()
	await _link_states_and_range()
	await _command_gating()
	await _reconnection_and_group_orders()
	await _recon_foundation()
	await _routes()
	_check(completed == 8, "all command scenarios completed")
	_check(Engine.time_scale == 1.0, "suite leaves normal game speed")
	print("COMMAND SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load(active_guard: bool = false) -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	root.get_node("GameManager").debug_visible = false
	mission = load("res://scenes/missions/harvester_raid_test.tscn").instantiate()
	for enemy in mission.get_node("Enemies").get_children():
		if not active_guard or enemy.name != "Guard_A":
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
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("Player")
	player.set_physics_process(false)
	scout = mission.get_node("Allies/Scout")
	warrior = mission.get_node("Allies/Warrior")
	squad = mission.get_node("SquadManager")
	recon = mission.get_node("ReconManager")
	guard = mission.get_node("Enemies/Guard_A")
	camera = player.get_node("TacticalCamera")
	# A real pointer resting near a window edge must not disturb these tests.
	camera.edge_scroll_enabled = false
	await _frames(15)


## Stops an ally moving so a scenario can dictate its world position.
func _freeze(ally: AllyCharacter) -> void:
	ally.ai.set_physics_process(false)
	ally.set_physics_process(false)
	ally.velocity = Vector2.ZERO


func _place(ally: AllyCharacter, point: Vector2) -> void:
	ally.global_position = point
	ally.stop_moving()


func _free_camera() -> void:
	await _load()
	_freeze(scout)
	_freeze(warrior)
	_check(camera.is_current() or (camera.iso and IsoView.active), "the tactical camera drives the view from the start")
	_check(is_equal_approx(camera.zoom.x, camera.effective_zoom()) and camera.effective_zoom() >= camera.gameplay_zoom - 0.001, "default view is at least the gameplay zoom")
	_check(camera.mode_name() == "FREE" and not camera.pan_active, "the camera starts FREE, not panning")
	# The camera keeps its own anchor: moving Paul does not drag the view.
	# Open ground, clear of the approach rock.
	player.teleport_to(Vector2(-1100, 750))
	await _frames(5)
	var parked: Vector2 = camera.anchor
	_check(camera.sees(player.global_position, 40.0), "teleport_to brings the camera to Paul")
	player.global_position = Vector2(300, -200)
	await _frames(40)
	_check(camera.anchor.distance_to(parked) < 1.0, "the free camera does not follow Paul")
	player.global_position = Vector2(-1100, 750)
	# WASD pans the view, never a unit.
	player.set_physics_process(true)
	squad.select_slot(4)
	await _frames(4)
	var before: Vector2 = camera.anchor
	Input.action_press("move_right")
	await _frames(20)
	_check(camera.pan_active and camera.mode_name() == "PANNING", "held WASD reports PANNING")
	await _frames(20)
	Input.action_release("move_right")
	await _frames(5)
	_check(camera.anchor.x > before.x + 120, "WASD pans the camera")
	_check(not camera.pan_active and camera.mode_name() == "FREE", "releasing the key ends the pan")
	_check(player.global_position.distance_to(Vector2(-1100, 750)) < 1.0 and player.order == PlayerController.Order.IDLE, "WASD does not move Paul")
	_check(squad.paul_selected and squad.selected_members.size() == 2, "panning keeps the selection")
	var free_anchor: Vector2 = camera.anchor
	await _frames(45)
	_check(camera.anchor.distance_to(free_anchor) < 1.0, "free camera stays where the player left it")
	squad.issue_context(Vector2(-1000, 750))
	_check(player.order == PlayerController.Order.MOVE, "orders still work while the camera looks elsewhere")
	player.stop()
	# Camera bounds keep the view inside the mission extents.
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _frames(240)
	Input.action_release("move_right")
	Input.action_release("move_down")
	await _frames(10)
	var half: Vector2 = Vector2.ZERO if camera.iso else camera.visible_world_size() * 0.5
	_check(camera.anchor.x <= camera.limit_right - half.x + 1.0 and camera.anchor.y <= camera.limit_bottom - half.y + 1.0, "pan is clamped to the mission bounds")
	# snap_to jumps immediately; center_on glides.
	# The headless window's aspect leaves little vertical travel, so targets are
	# compared with their in-bounds equivalent.
	camera.snap_to(Vector2(-200, 0))
	_check(camera.anchor == _clamped(Vector2(-200, 0)) and camera.mode_name() == "FREE", "snap_to jumps straight to the point")
	var glide_to: Vector2 = _clamped(Vector2(300, 0))
	camera.center_on(glide_to)
	await _frames(2)
	_check(camera.mode_name() == "CENTERING" and camera.anchor.x > -199.0 and camera.anchor.x < 299.0, "center_on glides rather than jumps")
	await _frames(90)
	_check(camera.anchor.distance_to(glide_to) < 2.0 and camera.mode_name() == "FREE", "center_on arrives and settles")
	camera.snap_to(Vector2(10000, -10000))
	_check(camera.anchor.x <= camera.limit_right - half.x + 1.0 and camera.anchor.y >= camera.limit_top + half.y - 1.0, "snap_to is clamped to the mission bounds")
	# A key press pans out of a glide.
	camera.center_on(_clamped(Vector2(-400, 0)))
	await _frames(2)
	Input.action_press("move_right")
	await _frames(3)
	Input.action_release("move_right")
	await _frames(40)
	_check(camera.mode_name() == "FREE" and camera.anchor.distance_to(_clamped(Vector2(-400, 0))) > 50.0, "panning cancels a centring glide")
	# Pressing a number twice centres on that unit; once just selects.
	_place(scout, Vector2(450, -400))
	_place(warrior, Vector2(-450, 400))
	camera.snap_to(Vector2(0, 0))
	var parked_view: Vector2 = camera.anchor
	await _frames(3)
	await _tap(KEY_3)
	await _frames(40)
	_check(warrior.selected and not squad.paul_selected, "3 selects the Warrior")
	_check(camera.anchor.distance_to(parked_view) < 1.0, "a single number press leaves the camera alone")
	await _tap(KEY_2)
	_check(scout.selected and not warrior.selected and camera.anchor.distance_to(parked_view) < 1.0, "a different number is not a double tap")
	await _tap(KEY_2)
	await _frames(90)
	_check(camera.anchor.distance_to(_clamped(scout.global_position)) < 3.0 and camera.sees(scout.global_position, 40.0), "double-tapping 2 centres the camera on the Scout")
	await _tap(KEY_1)
	await _tap(KEY_1)
	await _frames(90)
	_check(squad.paul_selected and camera.anchor.distance_to(_clamped(player.global_position)) < 3.0 and camera.sees(player.global_position, 40.0), "double-tapping 1 centres the camera on Paul")
	# Edge scrolling, driven by an explicit pointer motion near the right edge.
	camera.snap_to(Vector2(-300, 0))
	camera.edge_scroll_enabled = true
	var edge_start: Vector2 = camera.anchor
	var size: Vector2 = root.get_visible_rect().size
	_motion(Vector2(size.x - 5.0, size.y * 0.5))
	await _frames(45)
	_check(camera.pan_active and camera.anchor.x > edge_start.x + 40.0, "pointer at the viewport edge pans the camera")
	_motion(size * 0.5)
	await _frames(3)
	_check(not camera.pan_active, "pointer away from the edge stops the pan")
	camera.edge_scroll_enabled = false
	# Wheel zoom is bounded at both ends.
	for index in range(40):
		_button(MOUSE_BUTTON_WHEEL_UP, true)
	await _frames(120)
	var closest: float = camera.effective_zoom()
	_check(closest > camera.gameplay_zoom + 0.2 and closest <= camera.gameplay_zoom * camera.player_zoom_max + 0.01, "wheel up zooms in, capped at the maximum")
	for index in range(80):
		_button(MOUSE_BUTTON_WHEEL_DOWN, true)
	await _frames(120)
	var widest: Vector2 = camera.visible_world_size()
	_check(camera.effective_zoom() < camera.gameplay_zoom, "wheel down zooms out past the gameplay view")
	if camera.iso:
		# Slanted, the view is bounded by the map's isometric outline instead.
		_check(camera.effective_zoom() >= camera._scene_minimum_zoom() - 0.01, "the widest zoom is bounded by the map's outline")
	else:
		_check(widest.x <= camera.limit_right - camera.limit_left + 1.0 and widest.y <= camera.limit_bottom - camera.limit_top + 1.0, "the widest zoom never shows past the mission edges")
	_check(is_equal_approx(camera.zoom.x, camera.effective_zoom()), "the applied zoom matches the effective zoom")
	player.set_physics_process(false)
	completed += 1


func _pause() -> void:
	await _load()
	player.set_physics_process(true)
	player.retaliate = false
	player.teleport_to(Vector2(-600, 280))
	_place(scout, Vector2(-450, 280))
	_place(warrior, Vector2(-450, 360))
	_freeze(warrior)
	await _frames(20)
	var signals: Array = []
	squad.pause_changed.connect(func(value: bool): signals.append(value))
	await _tap(KEY_SPACE)
	_check(squad.paused and paused, "Space pauses the scene tree")
	_check(signals == [true], "pausing emits pause_changed")
	_check(Engine.time_scale == 1.0, "pause is a real pause, not a slowdown")
	# Orders and selection still work while paused, but nothing moves.
	var paul_at: Vector2 = player.global_position
	var scout_at: Vector2 = scout.global_position
	await _tap(KEY_1)
	_check(squad.paul_selected and not scout.selected, "number keys select while paused")
	squad.issue_context(Vector2(-900, 280))
	await _tap(KEY_2)
	_check(scout.selected and not squad.paul_selected, "and switch the selection while paused")
	squad.issue_context(Vector2(-200, 500))
	await _frames(40)
	_check(player.order == PlayerController.Order.MOVE and player.destination == Vector2(-900, 280), "Paul accepts a move order while paused")
	_check(scout.ai.current_order == Order.MOVE_TO, "the Scout accepts a move order while paused")
	_check(player.global_position == paul_at and scout.global_position == scout_at, "nobody moves while paused")
	camera.snap_to(player.global_position)
	await _frames(3)
	await _drag(player.global_position - Vector2(60, 60), player.global_position + Vector2(60, 60))
	_check(squad.paul_selected and squad.selected_members.is_empty(), "box selection works while paused")
	var anchor: Vector2 = camera.anchor
	Input.action_press("move_up")
	await _frames(20)
	Input.action_release("move_up")
	_check(camera.anchor.y < anchor.y - 50.0, "the camera still pans while paused")
	await _tap(KEY_SPACE)
	_check(not squad.paused and not paused and signals == [true, false], "Space again resumes")
	await _frames(40)
	_check(player.global_position.x < paul_at.x - 40.0, "Paul's paused order executes on resume")
	_check(scout.global_position.distance_to(scout_at) > 40.0, "the Scout's paused order executes on resume")
	# Paul's death lifts the pause and it cannot be re-applied.
	squad.set_paused(true)
	_check(paused, "pause re-applied")
	player.health.die()
	await _frames(3)
	_check(not squad.paused and not paused and signals.back() == false, "Paul's death unpauses")
	squad.set_paused(true)
	await _tap(KEY_SPACE)
	_check(not squad.paused and not paused, "a dead Paul cannot pause the game")
	completed += 1


func _box_selection_and_fan_out() -> void:
	await _load(true)
	guard.set_physics_process(false)
	guard.ai.set_physics_process(false)
	player.set_physics_process(true)
	player.retaliate = false
	player.teleport_to(Vector2(-600, 280))
	_place(scout, Vector2(-520, 240))
	_place(warrior, Vector2(-520, 330))
	_freeze(scout)
	_freeze(warrior)
	await _frames(10)
	camera.snap_to(Vector2(-560, 280))
	await _frames(3)
	# Box around the whole squad.
	await _drag(Vector2(-680, 180), Vector2(-440, 400))
	_check(squad.paul_selected and scout.selected and warrior.selected and squad.selected_units().size() == 3, "a box around the squad selects Paul and both allies")
	# Box around only the Fremen.
	await _drag(Vector2(-560, 200), Vector2(-470, 380))
	_check(not squad.paul_selected and not player.selected and squad.selected_members.size() == 2, "a box around the allies leaves Paul out")
	# Shift-box adds Paul back without dropping the others.
	await _drag(Vector2(-650, 230), Vector2(-570, 330), true)
	_check(squad.paul_selected and squad.selected_members.size() == 2, "Shift-box adds to the selection")
	# Click one unit, Shift-click another.
	await _left_click(scout.global_position)
	_check(scout.selected and not warrior.selected and not squad.paul_selected, "clicking an ally selects only him")
	await _left_click(player.global_position, true)
	_check(scout.selected and squad.paul_selected, "Shift-click adds Paul")
	await _left_click(Vector2(-560, 600))
	_check(not squad.has_selection(), "clicking empty ground clears the selection")
	# Right-click on ground fans the whole selection out.
	await _tap(KEY_4)
	var goal: Vector2 = Vector2(-900, 300)
	camera.snap_to(Vector2(-700, 300))
	await _frames(3)
	await _right_click(goal)
	_check(player.order == PlayerController.Order.MOVE and player.destination.distance_to(goal) < 2.0, "right-click sends Paul to the clicked point")
	_check(scout.ai.current_order == Order.MOVE_TO and warrior.ai.current_order == Order.MOVE_TO, "and both allies MOVE_TO beside it")
	var spots: Array[Vector2] = [player.destination, scout.ai.order_position, warrior.ai.order_position]
	var spread: bool = true
	for a in range(spots.size()):
		for b in range(a + 1, spots.size()):
			spread = spread and spots[a].distance_to(spots[b]) >= 30.0
	_check(spread, "Paul and both allies get distinct destinations %s" % str(spots))
	for spot in spots:
		_check(spot.distance_to(goal) < 130.0, "fan-out destination %s stays near the click" % str(spot))
	_check(squad.marker_position.distance_to(goal) < 1.0 and not squad.marker_attack, "a move marker shows at the click")
	# Right-click on a hostile: Paul attacks, allies ATTACK.
	guard.global_position = Vector2(-300, 200)
	camera.snap_to(Vector2(-450, 250))
	await _frames(3)
	await _right_click(guard.global_position)
	_check(player.order == PlayerController.Order.ATTACK and player.order_target == guard, "right-click on a Harkonnen orders Paul to attack")
	_check(scout.ai.current_order == Order.ATTACK and scout.ai.order_target == guard and warrior.ai.current_order == Order.ATTACK, "and the allies to ATTACK the same target")
	_check(squad.marker_attack, "an attack marker shows")
	# Paul alone: only Paul gets the order.
	player.stop()
	scout.ai.issue_order(Order.HOLD, scout.global_position)
	warrior.ai.issue_order(Order.HOLD, warrior.global_position)
	await _tap(KEY_1)
	await _right_click(Vector2(-500, 150))
	_check(player.order == PlayerController.Order.MOVE and scout.ai.current_order == Order.HOLD and warrior.ai.current_order == Order.HOLD, "1 then right-click orders only Paul")
	# The tutorial lock stops the Fremen, never Paul.
	player.stop()
	squad.commands_enabled = false
	squad.select_slot(4)
	_check(squad.paul_selected and squad.selected_members.is_empty(), "with commands locked, 4 selects Paul alone")
	squad.issue_context(Vector2(-450, 150))
	_check(player.order == PlayerController.Order.MOVE and scout.ai.current_order == Order.HOLD, "locked Fremen ignore the order Paul still takes")
	squad.commands_enabled = true
	completed += 1


## Where the camera can actually centre for a world point.
func _clamped(point: Vector2) -> Vector2:
	return camera._clamp_to_bounds(point)


func _link_states_and_range() -> void:
	await _load()
	_freeze(scout)
	_freeze(warrior)
	player.global_position = Vector2(0, 0)
	_check(is_equal_approx(squad.get_effective_command_range(), 700.0), "command range starts at the tuned 700 px")
	_place(scout, Vector2(300, 0))
	await _frames(4)
	_check(squad.link_state(scout) == Link.CONNECTED, "inside 75% of range the link is CONNECTED")
	_place(scout, Vector2(600, 0))
	await _frames(4)
	_check(squad.link_state(scout) == Link.WEAK_LINK, "past 75% of range the link is WEAK")
	_place(scout, Vector2(520, 0))
	await _frames(4)
	_check(squad.link_state(scout) == Link.CONNECTED, "back inside 75% the link reconnects")
	_place(scout, Vector2(760, 0))
	await _frames(4)
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE and not scout.command_link.can_receive_orders(), "beyond range the link is lost")
	_check(scout.command_link.quality == 0.0 and scout.command_link.distance > 700.0, "link exposes its measured distance and quality")
	# World-space only: zoom must not change the measured distance.
	var distance: float = scout.command_link.distance
	camera.zoom = Vector2(0.5, 0.5)
	await _frames(4)
	_check(is_equal_approx(scout.command_link.distance, distance), "command range uses world distance, not screen distance")
	camera.zoom = Vector2.ONE
	# Diagonal placement also uses plain world distance.
	_place(scout, Vector2(400, 400))
	await _frames(4)
	_check(squad.link_state(scout) == Link.WEAK_LINK, "diagonal separation of 566 px reads as a weak link")
	# Future modifiers go through the single accessor.
	squad.set_command_range_modifier(&"test_storm", 0.5)
	await _frames(4)
	_check(is_equal_approx(squad.get_effective_command_range(), 350.0) and squad.link_state(scout) == Link.OUT_OF_RANGE, "a range modifier narrows the effective command range")
	squad.clear_command_range_modifier(&"test_storm")
	await _frames(4)
	_check(is_equal_approx(squad.get_effective_command_range(), 700.0) and squad.link_state(scout) == Link.WEAK_LINK, "clearing the modifier restores the base range")
	completed += 1


func _command_gating() -> void:
	await _load(true)
	guard.set_physics_process(false)
	guard.ai.set_physics_process(false)
	_freeze(warrior)
	player.global_position = Vector2(-600, 280)
	_place(warrior, player.global_position + Vector2(90, 0))
	# Connected: the normal contextual order still executes.
	_place(scout, player.global_position + Vector2(200, 0))
	await _frames(6)
	squad.select_slot(2)
	squad.issue_context(Vector2(-300, 300))
	_check(scout.ai.current_order == Order.MOVE_TO, "a connected ally accepts MOVE_TO")
	# Out of range: MOVE_TO is rejected and the existing order survives.
	_freeze(scout)
	_place(scout, Vector2(600, -700))
	await _frames(6)
	var kept: Vector2 = scout.ai.order_position
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE, "the Scout crossed beyond command range")
	squad.issue_context(Vector2(-900, 500))
	_check(scout.ai.current_order == Order.MOVE_TO and scout.ai.order_position == kept, "a rejected MOVE_TO leaves the current order untouched")
	_check(squad.rejection_active() and squad.rejection_message.contains("LINK LOST"), "command rejection reports clear feedback")
	_check(scout.command_feedback_active(), "the rejected ally shows feedback of its own")
	# Let the camera reach the disconnected Scout so the capture shows his marker.
	await _frames(60)
	_check(scout.command_feedback_active(), "ally feedback stays readable for a moment")
	await _capture("m51_link_lost")
	# Out of range, a recall still reaches. Milestone 5.1 made FOLLOW obey the
	# link like every other order; a Milestone 9 playthrough then lost the Scout
	# permanently 970 px out with no way to get him back. Tactical orders still
	# need the link - "come back" is the one instruction that always arrives.
	scout.ai.issue_order(Order.HOLD, scout.global_position)
	squad.issue_follow()
	await _frames(6)
	_check(scout.ai.current_order == Order.FOLLOW, "FOLLOW recalls an ally that is holding out of range")
	_check(scout.command_feedback_active(), "and the recalled ally says so")
	_check(not squad.can_command(scout), "while the ally is still outside the command link")
	squad.issue_context(Vector2(-900, 500))
	await _frames(6)
	_check(scout.ai.current_order == Order.FOLLOW, "a tactical order to the same ally is still refused")
	scout.ai.issue_order(Order.HOLD, scout.global_position)
	var hold: Vector2 = scout.ai.hold_position
	# Out of range: a commanded ATTACK is neither cancelled nor redirected.
	scout.ai.issue_order(Order.ATTACK, guard.global_position, guard)
	_check(scout.ai.current_order == Order.ATTACK and scout.ai.order_target == guard, "commanded attack is stored")
	squad.issue_hold()
	squad.issue_context(Vector2(-900, 500))
	await _frames(6)
	_check(scout.ai.current_order == Order.ATTACK and scout.ai.order_target == guard, "losing the link does not erase or redirect an existing attack")
	# Selection and observation of a disconnected ally must keep working.
	squad.clear_selection()
	squad.select_slot(2)
	_check(scout.selected and squad.selected_members.size() == 1, "an out-of-range ally is still selectable")
	_check(not squad.can_command(scout), "an out-of-range ally still cannot receive orders")
	completed += 1


func _reconnection_and_group_orders() -> void:
	await _load()
	_freeze(scout)
	_freeze(warrior)
	player.global_position = Vector2(-600, 280)
	_place(scout, Vector2(600, -700))
	_place(warrior, player.global_position + Vector2(120, 0))
	await _frames(6)
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE and squad.link_state(warrior) == Link.CONNECTED, "mixed connectivity is measured per ally")
	scout.ai.issue_order(Order.MOVE_TO, Vector2(900, -900))
	warrior.ai.issue_order(Order.FOLLOW)
	squad.select_slot(4)
	squad.issue_hold()
	await _frames(6)
	_check(warrior.ai.current_order == Order.HOLD, "the connected ally receives the group order")
	_check(scout.ai.current_order == Order.MOVE_TO, "the disconnected ally keeps its current order")
	_check(squad.rejection_active(), "the partial group order reports the ally that was missed")
	# Paul walking closer reconnects without any manual action.
	player.global_position = Vector2(120, -340)
	await _frames(6)
	_check(squad.link_state(scout) == Link.WEAK_LINK, "closing the distance restores a weak link")
	player.global_position = Vector2(450, -550)
	await _frames(6)
	_check(squad.link_state(scout) == Link.CONNECTED and squad.can_command(scout), "closing further reconnects automatically")
	squad.select_slot(2)
	squad.issue_hold()
	await _frames(6)
	_check(scout.ai.current_order == Order.HOLD, "commands become available again immediately")
	# FOLLOW beyond range is an active order and must keep running.
	scout.set_physics_process(true)
	scout.ai.set_physics_process(true)
	scout.ai.issue_order(Order.FOLLOW)
	player.global_position = Vector2(-600, 280)
	await _frames(10)
	var opening: float = scout.global_position.distance_to(player.global_position)
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE, "the following ally starts outside the link")
	await _frames(150)
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE, "the ally is still disconnected while returning")
	_check(scout.has_destination and scout.global_position.distance_to(player.global_position) < opening - 250, "a disconnected FOLLOW keeps navigating back to Paul")
	completed += 1


## Shift + right-click builds a route; a waypoint can be dragged while he is
## in range; a plain order replaces the route; a route is walked through to
## the last waypoint, beyond command range too, where it can't be changed.
func _routes() -> void:
	await _load()
	_freeze(warrior)
	player.global_position = Vector2(-600, 280)
	_place(scout, Vector2(-480, 280))
	await _frames(6)
	squad.select_slot(2)
	squad.issue_context(Vector2(-400, 280))
	squad.issue_context(Vector2(-400, 400), true)
	squad.issue_context(Vector2(-300, 400), true)
	var points: Array[Vector2] = scout.ai.waypoints()
	_check(points.size() == 3, "Shift + right-click adds waypoints: three in the route")
	var found: Dictionary = squad.waypoint_at(points[1])
	_check(not found.is_empty() and found.ally == scout and int(found.index) == 1, "a waypoint can be picked under the cursor")
	_check(squad.grab_waypoint(points[1]) and not squad.waypoint_drag.is_empty(), "and taken hold of")
	_check(squad.drop_waypoint(Vector2(-470, 430)) and scout.ai.waypoints()[1].distance_to(Vector2(-470, 430)) < 40.0, "dragged, it moves")
	squad.issue_context(Vector2(-420, 300))
	_check(scout.ai.waypoints().size() == 1, "a plain right-click replaces the route")
	squad.issue_context(Vector2(-420, 420), true)
	await _frames(200)
	_check(scout.ai.current_order == Order.HOLD and scout.global_position.distance_to(Vector2(-420, 420)) < 40.0, "the route is walked to its last waypoint, and held")
	# Given in range, carried out of it.
	squad.issue_context(Vector2(-420, 200))
	squad.issue_context(Vector2(-300, 200), true)
	_freeze(scout)
	_place(scout, Vector2(600, -700))
	await _frames(6)
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE, "the Scout is out of range")
	var far: Array[Vector2] = scout.ai.waypoints()
	_check(squad.grab_waypoint(far[1]) and squad.waypoint_drag.is_empty() and squad.rejection_active(), "out of range, his route can't be changed - and it says so")
	_check(scout.ai.waypoints() == far and scout.ai.current_order == Order.MOVE_TO, "but it stands, and he keeps to it")
	completed += 1


func _recon_foundation() -> void:
	await _load(true)
	_freeze(scout)
	_freeze(warrior)
	guard.set_physics_process(false)
	guard.ai.set_physics_process(false)
	guard.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = Vector2(-1400, 900)
	_place(warrior, Vector2(-1250, 900))
	guard.global_position = Vector2(500, -700)
	await _frames(10)
	recon.refresh_observers()
	_check(recon.observers.size() >= 3, "Paul, Scout, and Warrior register as recon observers")
	_check(player.recon.vision_radius == 450.0 and scout.recon.vision_radius == 650.0 and warrior.recon.vision_radius == 400.0, "the Scout carries the largest recon radius")
	_check(scout.recon.vision_radius > warrior.recon.vision_radius and scout.recon.vision_radius > player.recon.vision_radius, "Scout recon exceeds both other friendlies")
	_place(scout, Vector2(200, -700))
	await _frames(40)
	_check(recon.is_enemy_visible(guard), "a scouting Fremen supplies contact on a distant enemy")
	var contact: Dictionary = recon.get_contact(guard)
	_check(contact.get("observer", "") == "Fremen Scout", "the contact records which observer saw it")
	_check(player.global_position.distance_to(guard.global_position) > player.recon.vision_radius, "Paul personally cannot see that enemy")
	_check(recon.visible_count() == 1 and recon.known_count() == 1, "only the observed enemy is counted")
	# Withdrawing keeps last-known intelligence instead of erasing it.
	var seen_at: Vector2 = recon.get_last_seen_position(guard)
	_place(scout, Vector2(-1300, 800))
	await _frames(45)
	_check(not recon.is_enemy_visible(guard), "losing every observer clears current visibility")
	_check(recon.get_last_seen_position(guard) == seen_at and recon.get_last_seen_age(guard) > 0.0, "last-seen position and age survive the loss of contact")
	# A dead enemy is dropped from the contact list.
	_place(scout, Vector2(200, -700))
	await _frames(40)
	_check(recon.is_enemy_visible(guard), "returning restores the contact")
	guard.health.die()
	await _frames(40)
	_check(recon.known_count() == 0, "dead hostiles leave the contact list")
	# Debug overlay exposes the camera, link, and recon sections.
	root.get_node("GameManager").debug_visible = true
	squad.select_slot(4)
	await _frames(10)
	var metrics: Dictionary = mission.get_node("UI").metric_labels
	for row in ["Camera mode", "Camera zoom", "Camera panning", "Paused", "Targeting", "Paul order", "Selected units", "Paul command range", "Scout link state", "Warrior link state", "Paul vision radius", "Scout vision radius", "Registered observers", "Enemies seen by squad"]:
		_check(metrics.has(row), "F1 debug overlay shows '%s'" % row)
	_check(metrics.has("Selected units") and metrics["Selected units"].text.contains("Paul") and metrics["Selected units"].text.contains("Warrior"), "F1 selected units lists Paul with the allies")
	_check(metrics.has("Camera mode") and metrics["Camera mode"].text.contains(camera.mode_name()), "F1 camera mode reads the free camera state")
	await _capture("m51_recon_debug")
	root.get_node("GameManager").debug_visible = false
	completed += 1


## Window coordinates for a world point. Input events arrive in window space,
## which the 1920 x 1080 canvas is stretched into.
func _screen(world: Vector2) -> Vector2:
	var viewport: Viewport = mission.get_viewport()
	return viewport.get_screen_transform() * (viewport.get_canvas_transform() * world)


func _mouse(button: MouseButton, world: Vector2, pressed: bool, shift: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	event.position = _screen(world)
	event.global_position = event.position
	Input.parse_input_event(event)


func _right_click(world: Vector2) -> void:
	_mouse(MOUSE_BUTTON_RIGHT, world, true)
	_mouse(MOUSE_BUTTON_RIGHT, world, false)
	await _frames(1)


func _left_click(world: Vector2, shift: bool = false) -> void:
	_mouse(MOUSE_BUTTON_LEFT, world, true, shift)
	_mouse(MOUSE_BUTTON_LEFT, world, false, shift)
	await _frames(1)


func _drag(from: Vector2, to: Vector2, shift: bool = false) -> void:
	_mouse(MOUSE_BUTTON_LEFT, from, true, shift)
	await _frames(1)
	_mouse(MOUSE_BUTTON_LEFT, to, false, shift)
	await _frames(1)


func _tap(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _button(button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = root.get_visible_rect().size * 0.5
	event.global_position = event.position
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)


func _motion(point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)


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
