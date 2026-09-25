extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/harvester_open_smoke.gd
##
## Act I, 1.3 The Harvester in the Open: the worm is already coming for the
## crawler, with its arrival time shown; it homes on the loudest place on the
## sand, so shutting the engine down hands it to the next loudest thing and a
## thumper takes it away; each of the squad leads two men and the injured one
## is carried, slowly; a nervous man panics when the ridge comes near; the
## ornithopters seat nine and the spice takes three, and can be dumped; the
## worm takes men on sand where it surfaces. All saved and the spice left is a
## clean day Kynes respects; the spice kept at the cost of men pleases CHOAM;
## Paul taken, or nobody aboard, is a failure. Kynes doubting: no thumper.

const SCENE: String = "res://scenes/missions/act1/harvester_open.tscn"

var failures: int = 0
var scene: Node
var controller: HarvesterOpenController
var player: PlayerController
var mission: MissionManager
var worm: WormThreatManager


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _opening()
	await _groups_and_carrying()
	await _homing_and_thumper()
	await _seats_and_spice()
	await _spice_kept()
	await _failures()
	await _kynes_doubts()
	print("HARVESTER OPEN SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await _frames(2)
	scene = (load(SCENE) as PackedScene).instantiate()
	# These checks need the world running; the opening pause is briefing_smoke's.
	(scene.get_node("Controller") as HarvesterOpenController).open_paused = false
	root.add_child(scene)
	current_scene = scene
	await _frames(20)
	controller = scene.get_node("Controller")
	player = scene.get_node("Player")
	mission = scene.get_node("Mission")
	worm = scene.get_node("WormThreat")


func _man(name: String) -> Crewman:
	for man in controller.crew:
		if man.display_name == name:
			return man
	return null


func _ally(index: int) -> AllyCharacter:
	return controller.squad.members[index]


func _opening() -> void:
	await _load()
	_check(controller.crew.size() == 8, "eight men wait")
	_check(controller.kynes == &"trusts" and controller.thumpers == 1, "on its own, Kynes trusts the House: a thumper")
	_check(worm.is_worm_approaching() and worm.target.distance_to(controller.harvester.global_position) < 5.0, "the worm is already coming for the crawler")
	var alert: WormSignAlert = scene.get_node("WormWarnings").alert
	_check(alert != null and alert.banner_visible() and alert.headline == "WORM SIGN!", "WORM SIGN! across the screen")
	_check(alert.ridge().is_finite(), "and an arrow to the ridge")
	var eta: float = worm.event.eta()
	_check(eta > 60.0 and eta < 80.0, "about seventy-five seconds out (%.0f)" % eta)
	_check("worm" in mission.objective(HarvesterOpenController.OBJ_CREW).progress, "its arrival time is on the objectives")
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	_check(safety != null and safety.is_safe(), "Paul starts on the ornithopters' rock")
	_check(not controller._liftoff_point.enabled, "nobody aboard: lift-off is not offered")


func _groups_and_carrying() -> void:
	await _load()
	for name in ["Keth", "Mirel"]:
		player.global_position = _man(name).global_position + Vector2(40, 0)
		await _frames(3)
	_check(_man("Keth").leader == player and _man("Mirel").leader == player, "Paul leads two")
	player.global_position = _man("Harl").global_position + Vector2(40, 0)
	await _frames(3)
	_check(_man("Harl").state == Crewman.State.WAITING, "and no third")
	# The injured man takes a whole carrier.
	var gurney: AllyCharacter = _ally(0)
	gurney.global_position = _man("Dace").global_position + Vector2(40, 0)
	await _frames(3)
	_check(_man("Dace").carried() and _man("Dace").leader == gurney, "Gurney carries Dace")
	_check(is_equal_approx(gurney.load_multiplier, HarvesterOpenController.CARRY_PACE), "and slows to a carrier's pace")
	_check(is_equal_approx(player.load_multiplier, 1.0), "Paul, leading walkers, does not")
	gurney.global_position = _man("Orrin").global_position + Vector2(40, 0)
	await _frames(3)
	_check(_man("Orrin").leader != gurney, "a carrier leads nobody else")
	# A nervous man bolts when the ridge comes near.
	var tobin: Crewman = _man("Tobin")
	worm.event.position_on_path = tobin.global_position + Vector2(600, 0)
	await _frames(20)
	_check(tobin.state == Crewman.State.PANIC and tobin.is_sprinting, "Tobin panics as the ridge nears, and runs")
	_check(_man("Sef").state == Crewman.State.WAITING, "Sef, steady, waits in silence")


func _homing_and_thumper() -> void:
	await _load()
	controller.set_engine(false)
	_check(controller.engine_off and not controller.harvester.running, "the engine shut down")
	# The loudest place on the sand now is somewhere else: it turns.
	var loud: Vector2 = Vector2(-1400, 200)
	worm.report_sign(loud, 20.0, "Test column")
	await _frames(45)
	_check(worm.target.distance_to(loud) < 5.0, "with the engine off, the worm homes on the loudest place")
	# A thumper outdrums it.
	player.global_position = Vector2(-1300, 900)
	await _frames(20)
	_check(controller.place_thumper() and controller.thumpers == 0, "the thumper planted on open sand")
	var thumper: Thumper = scene.get_node("Thumper")
	await _frames(3)
	_check(scene.get_node("WormWarnings").alert.headline == "THE WORM TURNS", "a thumper turning the worm is announced")
	# A few beats and the drum is the loudest thing on the sand.
	await _frames(360)
	_check(worm.target.distance_to(thumper.global_position) < 5.0, "and the worm turns to it")
	player.global_position = Vector2(0, 1420)
	await _frames(20)
	_check(not controller.place_thumper(), "only one")
	# Restarting the engine is possible while the crawler stands.
	controller.set_engine(true)
	_check(controller.harvester.running and not controller.engine_off, "the engine restarted, a lure again")
	# It surfaces on a man in the open: he is taken.
	var harl: Crewman = _man("Harl")
	worm._on_event_erupted(harl.global_position, 420.0)
	await _frames(2)
	_check(not harl.alive() and controller.lost() >= 1, "Harl, on sand where it surfaced, is taken")


func _seats_and_spice() -> void:
	await _load()
	for man in controller.crew:
		controller._board(man)
	_check(controller.saved() == 8 and controller.seats_free() == 1, "eight aboard, one seat spare")
	controller.load_spice()
	_check(controller.saved() == 6, "the spice takes three seats: two men are left standing")
	_check(not _man("Sef").seated and not _man("Ulm").seated, "the last to arrive")
	_home_squad()
	await _frames(10)
	_check(mission.running(), "men standing: no automatic lift-off")
	controller.dump_spice()
	_check(controller.saved() == 8, "the spice dumped, everyone seated")
	await _frames(10)
	var record: MissionOutcome = mission.outcome_record
	_check(record != null and record.tier == MissionOutcome.Tier.CLEAN, "all eight home: a clean day")
	_check(record != null and record.flags.has("kynes_respect") and int(record.standings.get(&"fremen", 0)) >= 1, "men before spice: Kynes respects it")
	_check(record != null and record.flags.has("carryall_sabotaged") and not record.flags.has("spice_saved"), "the carryall remembered; the spice gone")
	_check(controller.harvester.destroyed, "the crawler lost either way")


func _spice_kept() -> void:
	await _load()
	controller._spice_point.force_complete()
	await _frames(2)
	for man in controller.crew:
		controller._board(man)
	_home_squad()
	await _frames(5)
	controller._lift_off()
	await _frames(3)
	var record: MissionOutcome = mission.outcome_record
	_check(record != null and record.tier == MissionOutcome.Tier.NOISY and controller.lost() == 2, "the spice kept, two men left on the rock")
	_check(record != null and record.flags.has("spice_saved") and int(record.standings.get(&"choam", 0)) >= 1, "CHOAM is pleased")
	_check(record != null and not record.flags.has("kynes_respect"), "Kynes notes what the House valued")


func _failures() -> void:
	await _load()
	controller._lift_off()
	await _frames(2)
	_check(mission.outcome == MissionManager.Outcome.FAILED and not mission.outcome_record.heroes_wounded.has("Paul"), "leaving with nobody aboard is a failure")
	await _load()
	player.global_position = Vector2(-1400, 200)
	await _frames(20)
	worm._on_event_erupted(player.global_position, 420.0)
	await _frames(5)
	var record: MissionOutcome = mission.outcome_record
	_check(mission.outcome == MissionManager.Outcome.FAILED and record.tier == MissionOutcome.Tier.FAILURE, "Paul taken: a failure")
	_check(record.heroes_wounded.has("Paul"), "and Paul is wounded")


func _kynes_doubts() -> void:
	var campaign: CampaignState = root.get_node("GameManager").campaign
	var banquet: MissionOutcome = MissionOutcome.new()
	banquet.mission_id = &"act1_banquet"
	banquet.tier = MissionOutcome.Tier.PARTIAL
	banquet.add_flag(&"kynes_doubts")
	campaign.history.append(banquet)
	await _load()
	_check(controller.kynes == &"doubts" and controller.thumpers == 0, "Kynes doubts the House: no thumper")
	player.global_position = Vector2(-1400, 200)
	await _frames(20)
	_check(not controller.place_thumper(), "K does nothing without one")
	campaign.history.erase(banquet)


func _home_squad() -> void:
	player.global_position = Vector2(0, 1420)
	for ally in controller.squad.members:
		ally.global_position = Vector2(80, 1400)


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
