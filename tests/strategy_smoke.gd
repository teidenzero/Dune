extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/strategy_smoke.gd
##
## The strategic map, first pass (Act II, the raid campaign): the atlas of
## Arrakis, operations and leaders, orders and their effects on the map, the
## storm, worms and the Harkonnen answer, a story mission played and read
## back, and the map room screen with its trip through the Council.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_atlas()
	_new_campaign()
	_orders()
	_the_week()
	_harkonnen_answer()
	_story_round_trip()
	await _map_room()
	print("STRATEGY SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _fresh() -> StrategicState:
	return StrategicState.new_act_two(CampaignState.new(), 7)


func _atlas() -> void:
	var ids: Array[StringName] = ArrakisAtlas.ids()
	_check(ids.size() == 21, "twenty-one regions of Arrakis")
	var routes_ok: bool = true
	for route in ArrakisAtlas.ROUTES:
		routes_ok = routes_ok and ids.has(route[0]) and ids.has(route[1])
	_check(routes_ok, "every route joins two real regions")
	# Every region can be reached from Sietch Tabr.
	var seen: Dictionary = {&"sietch_tabr": true}
	var frontier: Array[StringName] = [&"sietch_tabr"]
	while not frontier.is_empty():
		for next in ArrakisAtlas.neighbours(frontier.pop_front()):
			if not seen.has(next):
				seen[next] = true
				frontier.append(next)
	_check(seen.size() == ids.size(), "the map is one connected whole")
	_check(ArrakisAtlas.latitude(&"polar_sink") < 0.1 and ArrakisAtlas.latitude(&"southern_gardens") > 0.9, "north pole at the top, the southern gardens at the bottom")


func _new_campaign() -> void:
	var state: StrategicState = _fresh()
	_check(state.regions.size() == 21 and state.week == 1 and state.act == 2, "Act II begins in week one")
	_check(state.region(&"carthag").control == RegionState.Holder.HARKONNEN and state.region(&"sietch_tabr").control == RegionState.Holder.FREMEN, "Carthag is Harkonnen, Sietch Tabr is Fremen")
	_check(state.production >= StrategicState.QUOTA - 20 and state.production == state._count_production(), "Rabban's harvesters are working near his quota (less whatever the storm covers)")
	var story: StrategicOperation = null
	var raids: int = 0
	for op in state.open_operations():
		if op.story:
			story = op
		elif op.kind == OperationTemplates.RAID:
			raids += 1
	_check(story != null and story.story_code == "2.5" and story.playable(), "the story's first raid waits on the Funeral Plain, playable")
	_check(state._side_count() == StrategicState.OPEN_SIDE_OPERATIONS, "four side operations on offer")
	_check(raids == 0, "side raids wait until the first raid has been struck")


func _orders() -> void:
	var state: StrategicState = _fresh()
	var op: StrategicOperation = null
	for candidate in state.open_operations():
		if not candidate.story and not state.region(candidate.region).storm and candidate.water_cost <= 10:
			op = candidate
			break
	_check(op != null, "an operation to order")
	_check(state.blocked(op, &"") != "", "nothing goes without a leader")
	var fighters_before: int = state.free_fighters()
	_check(state.order(op, &"stilgar") and op.status == StrategicOperation.Status.ORDERED, "Stilgar leads it")
	_check(not state.available_heroes().has(&"stilgar"), "and cannot lead anything else this week")
	_check(state.free_fighters() == fighters_before - op.fighters, "its fighters are committed")
	state.cancel(op)
	_check(op.status == StrategicOperation.Status.OPEN and state.available_heroes().has(&"stilgar"), "cancelling frees him")
	# What a successful raid does, whether ordered or played.
	var raid: StrategicOperation = OperationTemplates.build(OperationTemplates.RAID, state.region(&"great_flat"))
	state._add(raid)
	raid.leader = &"paul"
	var harvesters: int = state.region(&"great_flat").harvesters
	var history: int = state.campaign.history.size()
	state._settle(raid, true, true, true)
	_check(state.region(&"great_flat").harvesters == harvesters - 2 and raid.status == StrategicOperation.Status.SUCCEEDED, "a clean raid cripples two harvesters")
	_check(state.campaign.history.size() == history + 1 and state.campaign.standing(&"fremen") == 1, "the order reports to the campaign like a mission: the Fremen take note")
	var village: StrategicOperation = OperationTemplates.build(OperationTemplates.VILLAGE, state.region(&"tuono_basin"))
	state._add(village)
	state.region(&"tuono_basin").grip = 2
	state._settle(village, true, false, true)
	_check(state.region(&"tuono_basin").control == RegionState.Holder.FREMEN, "a village freed of its garrison turns Fremen")


func _the_week() -> void:
	var state: StrategicState = _fresh()
	var stormed_north: bool = false
	var stormed_south: bool = false
	for week in range(12):
		state.end_week()
		for id: StringName in state.regions:
			if state.regions[id].storm:
				if ArrakisAtlas.latitude(id) < 0.55:
					stormed_north = true
				else:
					stormed_south = true
	_check(stormed_south and not stormed_north, "the Coriolis storm roams the south and never the northern fields")
	_check(state.week == 13, "twelve weeks pass")
	_check(state._side_count() == StrategicState.OPEN_SIDE_OPERATIONS, "the board is restocked every week")
	_check(state.campaign.resources[&"water"] > CampaignState.STARTING_RESOURCES[&"water"], "the sietches' water mounts week by week")


func _harkonnen_answer() -> void:
	var state: StrategicState = _fresh()
	var flat: RegionState = state.region(&"great_flat")
	flat.harvesters = 0
	flat.rebuild_wait = 1
	state.end_week()
	_check(state.attention > 0.0, "short of the quota, the Emperor starts to look")
	_check(flat.harvesters == 1, "Rabban sends a new harvester where one was lost")
	# High heat: the Harkonnen sweep for a sietch.
	state.campaign.heat = 10
	var sweeps: int = 0
	for index in range(6):
		state.end_week()
		for op in state.open_operations():
			if op.kind == OperationTemplates.DEFEND:
				sweeps += 1
	_check(sweeps > 0, "with the heat high, Harkonnen troops sweep toward a sietch")
	var defend: StrategicOperation = null
	for op in state.open_operations():
		if op.kind == OperationTemplates.DEFEND:
			defend = op
	if defend != null:
		var fighters: int = state.fighters
		state.end_week()
		_check(defend.status == StrategicOperation.Status.FAILED and state.fighters <= maxi(fighters - 4, 0), "left unanswered, the sweep finds the sietch")
	state.attention = StrategicState.ATTENTION_MAX - 1.0
	for region: RegionState in state.regions.values():
		region.harvesters = 0
	state.end_week()
	_check(state.act_complete, "when the Emperor's attention is full, Act III begins")


func _story_round_trip() -> void:
	var campaign: CampaignState = CampaignState.new()
	var state: StrategicState = StrategicState.new_act_two(campaign, 3)
	var story: StrategicOperation = null
	for op in state.open_operations():
		if op.story:
			story = op
	_check(state.launch(story, &"paul") and state.pending_op == story.id, "the first raid is launched as a mission, Paul leading")
	# Abandoned: nothing recorded.
	state.absorb_mission_result()
	_check(story.status == StrategicOperation.Status.OPEN and story.leader == &"", "a mission left without a result leaves the operation open")
	state.launch(story, &"paul")
	var harvesters: int = state.region(&"funeral_plain").harvesters
	var outcome: MissionOutcome = MissionOutcome.new()
	outcome.mission_id = &"harvester_raid"
	outcome.tier = MissionOutcome.Tier.NOISY
	outcome.scopes.append(MissionOutcome.Scope.SQUAD)
	outcome.heroes_wounded.append("Paul")
	campaign.apply(outcome)
	state.absorb_mission_result()
	_check(story.status == StrategicOperation.Status.SUCCEEDED and state.story_done.has("2.5"), "the raid played and won: story 2.5 is done")
	_check(state.region(&"funeral_plain").harvesters == harvesters - 1, "and a harvester is gone from the Funeral Plain")
	_check(int(state.wounded.get(&"paul", 0)) == StrategicState.WOUNDED_WEEKS and not state.available_heroes().has(&"paul"), "Paul came back wounded: out for two weeks")
	var raids: bool = false
	for index in range(8):
		state.end_week()
		for op in state.open_operations():
			raids = raids or op.kind == OperationTemplates.RAID
	_check(raids, "the raid campaign is open: side raids appear on the map")


func _map_room() -> void:
	var game: Node = root.get_node("GameManager")
	game.campaign = CampaignState.new()
	game.strategy = null
	change_scene_to_file("res://scenes/campaign/map_room.tscn")
	await _frames(10)
	var room: MapRoom = current_scene as MapRoom
	_check(room != null and game.strategy != null, "the map room opens and starts the Act II campaign")
	var side: StrategicOperation = null
	var story: StrategicOperation = null
	for op in room.state.open_operations():
		if op.story:
			story = op
		elif side == null and not room.state.region(op.region).storm:
			side = op
	room.select_operation(side.id)
	await _frames(2)
	_check(room.leader != &"", "choosing an operation proposes its best leader")
	room.send_order()
	await _frames(2)
	_check(side.status == StrategicOperation.Status.ORDERED, "SEND AS AN ORDER orders it")
	room.select_operation(story.id)
	room.select_leader(room.state.available_heroes()[0])
	room.play(MissionOutcome.Scope.POLITICAL)
	await _frames(10)
	var council: CouncilScreen = current_scene as CouncilScreen
	_check(council != null and council.home_scene == MapRoom.SCENE_PATH and council.definition != null, "COUNCIL opens the political operation for this raid")
	council.go_home()
	await _frames(10)
	room = current_scene as MapRoom
	_check(room != null and story.status == StrategicOperation.Status.OPEN, "back without resolving it: the map room, the raid still open")
	var week: int = room.state.week
	room.end_week()
	await _frames(2)
	_check(room.state.week == week + 1 and side.status != StrategicOperation.Status.ORDERED, "END WEEK resolves the orders")


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
