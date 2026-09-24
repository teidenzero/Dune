extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/interior_smoke.gd
##
## The Solo scope's first isometric interior, the inside of the harvester:
## the isometric grid and its 8 directions, the level built from its layout,
## click-to-move onto tiles with the squad's click orders, doors, walls
## fading in front of the hero, and the mission run end to end - relay,
## engine, hatch - reporting the raid's objectives in the SOLO scope.

const INTERIOR: String = "res://scenes/missions/harvester_raid/harvester_interior.tscn"

var failures: int = 0
var completed: int = 0
var mission: Node
var player: PlayerController
var controller: HarvesterInteriorController
var level: IsoLevel


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_grid_math()
	await _level_builds()
	await _movement_and_aim()
	await _doors_and_fading()
	await _run_the_mission()
	await _worm_takes_the_crawler()
	_check(completed == 6, "all interior scenarios completed")
	print("INTERIOR SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load() -> void:
	if is_instance_valid(mission):
		mission.queue_free()
		await _frames(2)
	root.get_node("GameManager").mission_checkpoint = &""
	mission = (load(INTERIOR) as PackedScene).instantiate()
	root.add_child(mission)
	current_scene = mission
	player = mission.get_node("World/Player")
	controller = mission.get_node("InteriorController")
	level = mission.get_node("World")
	await _frames(20)


func _quiet_enemies() -> void:
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		(enemy as CollisionObject2D).collision_layer = 0


func _grid_math() -> void:
	var round_trip: bool = true
	for cell in [Vector2i(0, 0), Vector2i(5, 2), Vector2i(17, 13), Vector2i(3, 9)]:
		round_trip = round_trip and IsoMath.world_to_cell(IsoMath.cell_to_world(cell)) == cell
	_check(round_trip, "grid cells and world positions convert both ways")
	_check(IsoMath.snap8(Vector2(1, 0.1)) == Vector2.RIGHT, "a nearly-level aim snaps to east")
	_check(IsoMath.snap8(Vector2(1, 0.4)).is_equal_approx(Vector2(2, 1).normalized()), "a shallow diagonal snaps to the grid's 2:1 diagonal")
	_check(IsoMath.snap8(Vector2(-0.1, -1)) == Vector2.UP, "a nearly-vertical aim snaps to north")
	_check(IsoMath.keys_to_move(Vector2(1, 1).normalized()).is_equal_approx(Vector2(2, 1).normalized()), "a diagonal key pair walks along the grid line")
	_check(IsoMath.facing_index(Vector2.UP) == 0 and IsoMath.facing_index(Vector2.LEFT) == 6, "facings are numbered clockwise from north")
	completed += 1


func _level_builds() -> void:
	await _load()
	_check(level.walls.size() > 150 and level.doors.size() == 9, "the crawler's walls and doors are built from the layout")
	_check(level.tanks.size() == 5, "fuel tanks stand where the layout puts them")
	_check(get_nodes_in_group("enemies").size() == 5, "five Harkonnen aboard")
	var shielded: int = 0
	for enemy: Node in get_nodes_in_group("enemies"):
		if ShieldComponent.find_on(enemy) != null:
			shielded += 1
	_check(shielded == 3, "two shielded guards and the Elite: indoors, shields are free")
	_check(player.isometric and player.shield != null, "the hero is isometric, and carries a shield")
	_check(get_nodes_in_group("allies").is_empty(), "alone")
	_check(IsoMath.world_to_cell(player.global_position) == Vector2i(3, 2), "he starts in the boarding bay")
	var map: RID = player.get_world_2d().navigation_map
	var path: PackedVector2Array = NavigationServer2D.map_get_path(map, player.global_position, level.mark("1"), true)
	_check(path.size() > 2 and path[path.size() - 1].distance_to(level.mark("1")) < 60.0, "the navigation mesh reaches the engine room")
	var mission_manager: MissionManager = mission.get_node("Mission")
	_check(mission_manager.objective(&"approach").state == MissionObjective.State.ACTIVE and mission_manager.objective(&"comms").state == MissionObjective.State.ACTIVE, "the raid's objectives, in interior terms")
	completed += 1


func _movement_and_aim() -> void:
	await _load()
	_quiet_enemies()
	var squad: SquadManager = mission.get_node("SquadManager")
	_check(squad.hero_mode and squad.paul_selected and player.control_mode == PlayerController.ControlMode.COMMANDED, "the hero is on click orders, always selected")
	var hud: PlayerHud = mission.get_node("UI/Screen/HUD")
	_check(hud.solo_clicks and hud.hints_label.text.contains("CLICK a tile"), "the HUD explains the click controls")
	# A click off-centre on a floor tile in the crew corridor.
	player.teleport_to(IsoMath.cell_to_world(Vector2i(9, 2)))
	await _frames(3)
	var tile: Vector2i = Vector2i(14, 2)
	_click(IsoMath.cell_to_world(tile) + Vector2(20, 8), MOUSE_BUTTON_LEFT)
	await _frames(2)
	_check(player.order == PlayerController.Order.MOVE and player.destination == IsoMath.cell_to_world(tile), "a left click walks him to the centre of that tile")
	_check(level.cursor.visible and level.cursor._target == IsoMath.cell_to_world(tile), "the destination tile is marked on the deck")
	await _frames(20)
	_check(player.facing_index() == 3, "he faces the way he walks, in one of 8 directions")
	await _frames(160)
	_check(player.global_position.distance_to(IsoMath.cell_to_world(tile)) < 14.0, "and gets there")
	_click(IsoMath.cell_to_world(Vector2i(10, 2)), MOUSE_BUTTON_RIGHT)
	await _frames(2)
	_check(player.order == PlayerController.Order.MOVE and player.destination == IsoMath.cell_to_world(Vector2i(10, 2)), "right-click moves too")
	player.stop()
	# The crewman in the corridor: right-click fires on him.
	var crewman: EnemyCharacter = mission.get_node("World/Enemies/Guard_a")
	crewman.global_position = player.global_position + Vector2(260, 0)
	crewman.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(2)
	# On his body, above his feet.
	_click(crewman.global_position + Vector2(0, -38), MOUSE_BUTTON_RIGHT)
	await _frames(2)
	_check(player.order == PlayerController.Order.ATTACK and player.order_target == crewman, "right-click on an enemy attacks him")
	player.stop()
	crewman.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	_key(KEY_SPACE)
	await _frames(2)
	_check(player.dodging or player.dodge_ready_ratio() < 1.0, "Space dodges")
	_check(not squad.paused, "and does not pause")
	_key(KEY_T)
	await _frames(2)
	_check(player.shield_active(), "T raises the shield")
	_key(KEY_P)
	await _frames(2)
	_check(squad.paused, "P pauses")
	_key(KEY_P)
	await _frames(2)
	completed += 1


func _doors_and_fading() -> void:
	await _load()
	_quiet_enemies()
	var door: IsoDoor = null
	for candidate in level.doors:
		if IsoMath.world_to_cell(candidate.global_position) == Vector2i(6, 2):
			door = candidate
	_check(door != null and not door.is_open, "the boarding bay door starts shut")
	player.teleport_to(door.global_position + Vector2(-70, -10))
	await _frames(6)
	_check(door.is_open, "it slides open as the hero walks up")
	player.teleport_to(level.player_start)
	await _frames(6)
	_check(not door.is_open, "and shuts behind him")
	# Just north of the refinery's south wall: that wall stands between him
	# and the camera, and fades.
	var wall_cell: Vector2i = Vector2i(15, 10)
	var wall: IsoWall = level.wall_root.get_node("Wall_%d_%d" % [wall_cell.x, wall_cell.y])
	player.teleport_to(IsoMath.cell_to_world(Vector2i(14, 9)))
	await _frames(40)
	_check(wall.fade < 0.5, "a wall in front of the hero goes see-through")
	player.teleport_to(level.player_start)
	await _frames(40)
	_check(wall.fade > 0.95, "and solid again when he leaves")
	completed += 1


func _run_the_mission() -> void:
	await _load()
	_quiet_enemies()
	var mission_manager: MissionManager = mission.get_node("Mission")
	var campaign: CampaignState = root.get_node("GameManager").campaign
	var history: int = campaign.history.size()
	player.teleport_to(IsoMath.cell_to_world(Vector2i(20, 7)))
	await _frames(3)
	_check(mission_manager.is_complete(&"approach"), "walking into the refinery completes the approach")
	controller.relay_point.force_complete()
	await _frames(2)
	_check(mission_manager.is_complete(&"comms") and not controller.relay_active, "cutting the relay completes comms")
	var points: Array[Node] = get_nodes_in_group("sabotage_points")
	_check(points.size() == 2, "two engine control points")
	(points[0] as InteractionPoint).force_complete()
	await _frames(2)
	_check(mission_manager.objective(&"sabotage").progress == "1 / 2" and not controller.escape_active, "one of two")
	(points[1] as InteractionPoint).force_complete()
	await _frames(2)
	_check(mission_manager.is_complete(&"sabotage") and controller.escape_active, "both: the engine is crippled and the worm is coming")
	_check(controller.alarm_active and controller._pending_groups == 0, "the crew is alarmed, but with the relay cut nobody is called in")
	var before: float = controller.worm_remaining
	await _frames(30)
	_check(controller.worm_remaining < before, "the worm countdown runs")
	player.teleport_to(controller.hatch.global_position)
	await _frames(3)
	var record: MissionOutcome = mission_manager.outcome_record
	_check(mission_manager.outcome == MissionManager.Outcome.COMPLETE, "out through the hatch: mission complete")
	_check(record != null and record.scopes == [MissionOutcome.Scope.SOLO] and record.mission_id == &"harvester_raid", "recorded as the Harvester Raid, in the solo scope")
	_check(record.tier == MissionOutcome.Tier.CLEAN, "relay cut and no firefight: a clean result")
	_check(record.objectives.get(&"sabotage") == MissionObjective.State.COMPLETE and record.objectives.get(&"escape") == MissionObjective.State.COMPLETE, "with the same objective ids as the squad raid")
	_check(record.flags.has("harvester_destroyed") and record.heroes_wounded.is_empty(), "the crawler is lost and the hero walks away")
	_check(campaign.history.size() == history + 1, "the campaign takes the result")
	completed += 1


func _worm_takes_the_crawler() -> void:
	await _load()
	_quiet_enemies()
	var mission_manager: MissionManager = mission.get_node("Mission")
	for point: Node in get_nodes_in_group("sabotage_points"):
		(point as InteractionPoint).force_complete()
	await _frames(2)
	_check(controller._pending_groups == 2, "with the relay live, the alarm calls two groups of crew")
	await _frames(int(controller.reinforcement_delay * 60.0) + 10)
	_check(controller.reinforcements_spawned >= 1 and get_nodes_in_group("enemies").size() >= 7, "and they come aboard")
	controller.worm_remaining = 0.05
	await _frames(10)
	var record: MissionOutcome = mission_manager.outcome_record
	_check(mission_manager.outcome == MissionManager.Outcome.FAILED and mission_manager.failure_reason == "TAKEN BY THE WORM", "still aboard when the worm comes: failed")
	_check(record != null and record.tier == MissionOutcome.Tier.PARTIAL, "partial: the crawler is lost all the same")
	_check(record.heroes_wounded.has("Paul") and record.flags.has("comms_intact"), "the hero is wounded, not killed, and the relay was left live")
	_check(not mission_manager.outcome_committed, "a failure waits for the player to accept it")
	root.get_node("GameManager").mission_checkpoint = &""
	completed += 1


## A click at a world point, as the viewport would receive it.
func _click(world: Vector2, button: MouseButton) -> void:
	var viewport: Viewport = mission.get_viewport()
	var screen: Vector2 = viewport.get_screen_transform() * (viewport.get_canvas_transform() * world)
	for pressed in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		Input.parse_input_event(event)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
