extends SceneTree
## Milestone 5.1: tactical camera modes, command range / link states, and the
## reconnaissance observer foundation. Runs against the real mission scene.

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
	await _camera_modes_and_framing()
	await _tactical_free_camera()
	await _link_states_and_range()
	await _command_gating()
	await _reconnection_and_group_orders()
	await _recon_foundation()
	_check(completed == 6, "all command scenarios completed")
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
	# A real pointer resting near a window edge must not disturb framing tests.
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


func _camera_modes_and_framing() -> void:
	await _load()
	_freeze(scout)
	_freeze(warrior)
	_check(camera.is_current() and camera.position_smoothing_enabled, "tactical camera starts current and smoothed")
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_PAUL and is_equal_approx(camera.zoom.x, camera.gameplay_zoom), "default mode is FOLLOW_PAUL at gameplay zoom")
	player.global_position = Vector2(-600, 280)
	_place(scout, player.global_position + Vector2(180, 0))
	squad.set_command_mode(true)
	squad.select_slot(2)
	await _frames(40)
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_SELECTION, "command mode with a selected ally frames the selection")
	_check(camera.framing_subjects.has(player) and camera.framing_subjects.has(scout), "close separation frames Paul and the Scout together")
	_check(is_equal_approx(camera.zoom.x, camera.max_tactical_zoom), "separation inside the dead zone keeps normal zoom")
	var near_zoom: float = camera.zoom.x
	# Medium separation: both stay framed, the camera zooms out to hold them.
	_place(scout, player.global_position + Vector2(0, 780))
	await _frames(120)
	_check(camera.framing_subjects.has(player), "medium separation still includes Paul")
	_check(camera.zoom.x < near_zoom - 0.05 and camera.zoom.x >= camera.min_tactical_zoom - 0.001, "medium separation zooms out without exceeding the limit")
	var wide_zoom: float = camera.zoom.x
	await _capture("m51_shared_framing")
	# Large separation: Paul is dropped and the Scout becomes the anchor.
	_place(scout, Vector2(900, -800))
	await _frames(160)
	_check(not camera.framing_subjects.has(player) and camera.framing_subjects.has(scout), "large separation drops Paul and anchors on the Scout")
	_check(camera.zoom.x > wide_zoom, "a single distant anchor stops zooming out")
	_check(camera.anchor.distance_to(scout.global_position) < 320, "camera travels to the distant Scout")
	_check(camera.anchor.distance_to(player.global_position) > 700, "Paul is allowed to leave the framed area")
	_check(squad.link_state(scout) == Link.OUT_OF_RANGE, "camera still observes an ally that lost its command link")
	# Focusing Paul again returns the camera without leaving it stranded.
	squad.select_slot(1)
	await _frames(150)
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_PAUL, "clearing the selection restores FOLLOW_PAUL")
	_check(camera.anchor.distance_to(player.global_position) < 90, "camera returns to Paul")
	_check(absf(camera.zoom.x - camera.gameplay_zoom) < 0.02, "gameplay zoom is restored")
	squad.set_command_mode(false)
	await _frames(20)
	_check(Engine.time_scale == 1.0 and not player.squad_control_locked, "leaving command mode restores time and Paul's control")
	# Optional temporary focus: hold middle mouse to watch the selected ally.
	squad.select_slot(2)
	await _frames(4)
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_PAUL, "selecting an ally outside command mode leaves the gameplay camera alone")
	_button(MOUSE_BUTTON_MIDDLE, true)
	await _frames(60)
	_check(camera.focus_hold and camera.mode == TacticalCamera.Mode.FOLLOW_SELECTION, "held middle mouse watches the selected ally")
	_check(camera.anchor.distance_to(scout.global_position) < camera.anchor.distance_to(player.global_position), "temporary focus moves the camera toward the ally")
	_button(MOUSE_BUTTON_MIDDLE, false)
	await _frames(150)
	_check(not camera.focus_hold and camera.mode == TacticalCamera.Mode.FOLLOW_PAUL, "releasing middle mouse ends temporary focus")
	_check(camera.anchor.distance_to(player.global_position) < 90, "the camera eases back to Paul after temporary focus")
	squad.clear_selection()
	completed += 1


func _tactical_free_camera() -> void:
	await _load()
	_freeze(scout)
	_freeze(warrior)
	player.global_position = Vector2(-600, 280)
	_place(scout, player.global_position + Vector2(220, 0))
	squad.set_command_mode(true)
	squad.select_slot(2)
	await _frames(40)
	var before: Vector2 = camera.anchor
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	await _frames(5)
	_check(camera.mode == TacticalCamera.Mode.TACTICAL_FREE and camera.pan_active, "manual panning switches to TACTICAL_FREE")
	_check(camera.anchor.x > before.x + 120, "pan moves the camera away from the framed subject")
	_check(squad.selected_members.size() == 1 and scout.selected, "panning keeps the squad selection")
	await _frames(45)
	var free_anchor: Vector2 = camera.anchor
	await _frames(45)
	_check(camera.anchor.distance_to(free_anchor) < 10, "free camera stays where the player left it")
	_check(player.global_position == Vector2(-600, 280), "command-mode WASD pans the camera instead of moving Paul")
	squad.issue_context(Vector2(-300, 320))
	_check(scout.ai.current_order == Order.MOVE_TO, "commands still work while the camera is free")
	# Recentering on a unit cancels free look.
	squad.select_slot(2)
	await _frames(60)
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_SELECTION and not camera.pan_active, "selecting a unit recenters the camera")
	# Camera bounds keep the view inside the mission extents.
	Input.action_press("move_right")
	Input.action_press("move_down")
	await _frames(240)
	Input.action_release("move_right")
	Input.action_release("move_down")
	await _frames(10)
	var half: Vector2 = root.get_visible_rect().size / camera.zoom.x * 0.5
	_check(camera.anchor.x <= camera.limit_right - half.x + 1.0 and camera.anchor.y <= camera.limit_bottom - half.y + 1.0, "tactical pan is clamped to the mission bounds")
	# Edge scrolling, driven by an explicit pointer motion near the right edge.
	squad.select_slot(2)
	await _frames(40)
	camera.edge_scroll_enabled = true
	var edge_start: Vector2 = camera.anchor
	var size: Vector2 = root.get_visible_rect().size
	_motion(Vector2(size.x - 5.0, size.y * 0.5))
	await _frames(45)
	_check(camera.pan_active and camera.anchor.x > edge_start.x + 40.0, "pointer at the viewport edge pans the tactical camera")
	_motion(size * 0.5)
	camera.edge_scroll_enabled = false
	squad.set_command_mode(false)
	await _frames(20)
	_check(camera.mode == TacticalCamera.Mode.FOLLOW_PAUL and not camera.pan_active, "exiting command mode drops free look")
	completed += 1


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
	squad.set_command_mode(true)
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
	# Out of range: HOLD is kept and FOLLOW cannot recall the ally.
	scout.ai.issue_order(Order.HOLD, scout.global_position)
	var hold: Vector2 = scout.ai.hold_position
	squad.issue_follow()
	await _frames(6)
	_check(scout.ai.current_order == Order.HOLD and scout.ai.hold_position == hold, "FOLLOW cannot recall an ally that is holding out of range")
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
	squad.set_command_mode(false)
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
	squad.set_command_mode(true)
	squad.select_slot(2)
	await _frames(10)
	var metrics: Dictionary = mission.get_node("UI").metric_labels
	for row in ["Camera mode", "Camera target", "Camera zoom", "Tactical pan active", "Shared framing distance", "Paul command range", "Scout link state", "Warrior link state", "Paul vision radius", "Scout vision radius", "Registered observers", "Enemies seen by squad"]:
		_check(metrics.has(row), "F1 debug overlay shows '%s'" % row)
	await _capture("m51_recon_debug")
	squad.set_command_mode(false)
	root.get_node("GameManager").debug_visible = false
	completed += 1


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
