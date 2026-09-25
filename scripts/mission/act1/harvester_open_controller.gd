class_name HarvesterOpenController
extends Node
## Act I, 1.3 The Harvester in the Open. A spice crawler stranded in open
## sand, its carryall missing; eight men on and around it; a worm already
## coming. Get them to the ornithopters on the rock.
##
## The worm homes: it keeps turning toward the loudest place on the sand and
## surfaces when it gets there. At first that is the crawler's engine - which
## makes the engine a lure: shut it down and the worm looks for the next
## loudest thing, which may be your men. Waiting men are silent; walking men
## are not, a column is one loud thing, and a panicking man is the loudest of
## all. Each of the squad can lead two men; the injured one must be carried,
## slowly. The ornithopters have seats for the squad and nine more; the spice,
## if loaded, takes three of them. If Kynes trusts the House (1.2), Paul has
## a thumper (K), louder than anything, to hold the worm somewhere harmless.
## The crawler is lost whatever the player does: the anchor. The men are what
## is in the player's hands.

const OBJ_CREW: StringName = &"crew"
const OBJ_SPICE: StringName = &"spice"
const OBJ_LIFTOFF: StringName = &"liftoff"

## Where the eight wait: name, offset from the crawler, nervous (panics),
## injured (must be carried).
const CREW: Array[Dictionary] = [
	{"name": "Keth", "at": Vector2(-300, 260), "nervous": false, "injured": false},
	{"name": "Orrin", "at": Vector2(300, 280), "nervous": true, "injured": false},
	{"name": "Dace", "at": Vector2(-440, -20), "nervous": false, "injured": true},
	{"name": "Harl", "at": Vector2(450, -40), "nervous": false, "injured": false},
	{"name": "Mirel", "at": Vector2(0, 330), "nervous": false, "injured": false},
	{"name": "Tobin", "at": Vector2(-150, -760), "nervous": true, "injured": false},
	{"name": "Sef", "at": Vector2(170, -790), "nervous": false, "injured": false},
	{"name": "Ulm", "at": Vector2(1500, 250), "nervous": false, "injured": false},
]
## How many men one of the squad can lead; a carried man counts as two.
const LEAD: int = 2
## A carrier's pace.
const CARRY_PACE: float = 0.5
## Two ornithopters: the squad's three seats, nine for the crew, and the spice
## takes three of those.
const CREW_SEATS: int = 9
const SPICE_SEATS: int = 3
## A nervous man bolts once the worm's ridge is this close to him.
const PANIC_DISTANCE: float = 1300.0
const REACH: float = 95.0
## Seconds until the first worm reaches the crawler, and how far off later
## worms rise.
const FIRST_ETA: float = 75.0
const LATER_APPROACH: float = 2600.0
## Loading spice is machinery: loud while it runs.
const LOADING_SIGN: float = 3.0

@export var mission: MissionManager
@export var player: PlayerController
@export var squad: SquadManager
@export var harvester: Harvester
@export var worm: WormThreatManager
@export var dialogue: DialogueBar
## The rock shelf where the ornithopters wait: in world units.
@export var evac_rect: Rect2 = Rect2(-520, 1150, 1040, 520)
## The mission opens stopped, once any briefing is closed: look, plan every
## man's route, then SPACE to execute. Planning never needs fast hands.
@export var open_paused: bool = true

var crew: Array[Crewman] = []
var thumpers: int = 0
var kynes: StringName = &"undecided"
var spice_saved: bool = false
var engine_off: bool = false
var lifted: bool = false
var paul_taken: bool = false
## Men on the rock, in the order they came: the first ones get the seats.
var aboard: Array[Crewman] = []
var _engine_point: InteractionPoint
var _spice_point: InteractionPoint
var _dump_point: InteractionPoint
var _liftoff_point: InteractionPoint
var _warned_panic: bool = false
var _first_worm: bool = false
var _notice_at: Dictionary = {}
var _progress_text: String = ""
var _plan_prompted: bool = false


func _ready() -> void:
	add_to_group("mission_controller")
	call_deferred("_begin")


func _begin() -> void:
	_read_kynes()
	await _spawn_crew()
	_make_points()
	mission.outcome_builder = build_outcome
	mission.add_objectives_from_definition()
	for id in [OBJ_CREW, OBJ_SPICE, OBJ_LIFTOFF]:
		mission.activate(id)
	mission.begin()
	mission.set_phase(&"RESCUE")
	worm.worm_arrived.connect(_on_worm_arrived)
	worm.actor_caught.connect(_on_actor_caught)
	player.health.died.connect(func() -> void:
		paul_taken = true
		mission.fail("TAKEN BY THE WORM"))
	_send_first_worm()
	_progress()
	# The situation and the rules are in the briefing; in the field, only
	# what the player needs now.
	if kynes == &"trusts":
		thumpers = 1


## The first thing the player sees in the field: the world stopped, and the
## reminder of how this is played - pause, think, plan, execute.
func _open_on_a_plan() -> void:
	squad.set_paused(true)
	# The warning again, now that the player is looking at the field.
	var warnings: Node = get_parent().get_node_or_null("WormWarnings")
	if warnings != null and warnings.get("alert") != null:
		warnings.alert.announce("WORM SIGN!")
	dialogue.say("GURNEY", "The world waits while you think. Look over the field, give every man his route, then SPACE to execute.", 14.0)


## The worm is already on its way to the crawler when the mission opens,
## from the north-east, with its arrival time on the objectives.
func _send_first_worm() -> void:
	var event: WormApproachEvent = worm.event
	event.approach_distance = event.travel_speed * FIRST_ETA
	worm.report_sign(harvester.global_position, 1.0, "Harvester", harvester.emitter)
	worm.worm_sign = worm.stage_thresholds[2] + 5.0
	# Committed now, so its arrival time and bearing are there to plan against.
	worm.commit_now()


## What Kynes made of the House at the Banquet. Launched on its own, he is
## given the benefit of the doubt, so the thumper can be tried.
func _read_kynes() -> void:
	var campaign: CampaignState = Progression.campaign_of(self)
	var banquet: MissionOutcome = campaign.last_outcome(&"act1_banquet") if campaign != null else null
	if banquet == null or banquet.flags.has("kynes_trusts"):
		kynes = &"trusts"
	elif banquet.flags.has("kynes_doubts"):
		kynes = &"doubts"
	else:
		kynes = &"undecided"


func _spawn_crew() -> void:
	var root: Node2D = Node2D.new()
	root.name = "Crew"
	get_parent().add_child.call_deferred(root)
	await get_tree().process_frame
	for spec in CREW:
		var man: Crewman = Crewman.new()
		man.name = "Crew_" + spec.name
		man.display_name = spec.name
		man.nervous = spec.nervous
		man.injured = spec.injured
		man.position = harvester.global_position + spec.at
		root.add_child(man)
		man.post = man.global_position
		# Panic runs him out across open sand and back.
		man.panic_to = man.global_position + man.global_position.direction_to(harvester.global_position).orthogonal() * 520.0
		man.taken.connect(_on_crewman_taken)
		crew.append(man)


func _make_points() -> void:
	_engine_point = _point(&"engine", "SHUT DOWN THE ENGINE", 2.0, harvester.global_position + Vector2(-60, 200))
	_engine_point.one_shot = false
	_engine_point.interaction_completed.connect(func(_id: StringName) -> void: set_engine(engine_off))
	_spice_point = _point(&"spice", "LOAD THE SPICE", 6.0, harvester.global_position + Vector2(260, 190))
	_spice_point.interaction_completed.connect(func(_id: StringName) -> void: load_spice())
	_dump_point = _point(&"dump", "DUMP THE SPICE", 2.0, evac_rect.get_center() + Vector2(-260, 60))
	_dump_point.interaction_completed.connect(func(_id: StringName) -> void: dump_spice())
	_dump_point.enabled = false
	_liftoff_point = _point(&"liftoff", "LIFT OFF", 1.5, evac_rect.get_center() + Vector2(0, 80))
	_liftoff_point.interaction_completed.connect(func(_id: StringName) -> void: _lift_off())
	_liftoff_point.enabled = false


func _point(id: StringName, label: String, hold: float, at: Vector2) -> InteractionPoint:
	var point: InteractionPoint = InteractionPoint.new()
	point.name = "Point_" + String(id)
	point.id = id
	point.label = label
	point.hold_seconds = hold
	point.interact_radius = 120.0
	point.position = at
	get_parent().add_child.call_deferred(point)
	return point


## The engine is a lure: running, it holds the worm; off, the worm hunts.
func set_engine(running: bool) -> void:
	if harvester.destroyed:
		return
	engine_off = not running
	harvester.set_running(running)
	_engine_point.label = "SHUT DOWN THE ENGINE" if running else "RESTART THE ENGINE"
	_engine_point.used = false
	if running:
		dialogue.say("GURNEY", "Engine's running again. It'll pull the worm back to the crawler - make sure nobody's standing by it.")
	else:
		dialogue.say("GURNEY", "Engine's dead. Now it'll listen for us instead. Quiet, everyone.")


func load_spice() -> void:
	if spice_saved:
		return
	spice_saved = true
	mission.complete(OBJ_SPICE)
	_dump_point.enabled = true
	var bumped: int = _reseat()
	if bumped > 0:
		dialogue.say("DUKE LETO", "The spice is aboard, and %d of our men have no seat. Is that the trade we want?" % bumped)
	else:
		dialogue.say("GURNEY", "Spice aboard - and it takes three seats. Count them before you bring the rest.")


## The Duke's choice, on the rock: the spice out, the seats back.
func dump_spice() -> void:
	if not spice_saved:
		return
	spice_saved = false
	_dump_point.enabled = false
	mission.fail_objective(OBJ_SPICE)
	_reseat()
	dialogue.say("DUKE LETO", "Dump it. Men first. CHOAM can bill me.")


func _process(delta: float) -> void:
	if not _plan_prompted and crew.size() == CREW.size() and mission.running():
		_plan_prompted = true
		if open_paused:
			_open_on_a_plan()
		if thumpers > 0:
			dialogue.say("KYNES", "The thumper is yours. K to plant it, on open sand.")
		if open_paused:
			return
	if lifted or not mission.running() or crew.size() < CREW.size():
		return
	if not _first_worm and worm.is_worm_approaching():
		# Later worms rise nearer, once this one has been and gone.
		_first_worm = true
		worm.event.approach_distance = LATER_APPROACH
	if _spice_point.holding:
		worm.report_sign(_spice_point.global_position, LOADING_SIGN * delta, "Spice loading", _spice_point)
	var units: Array[Node2D] = [player]
	for ally in squad.members:
		if is_instance_valid(ally) and not ally.health.is_dead:
			units.append(ally)
	for man in crew:
		if not man.alive():
			continue
		if man.needs_rescue():
			_try_join(man, units)
			if man.state == Crewman.State.WAITING and man.nervous and _worm_near(man.global_position):
				man.panic()
				BarkLayer.say(man, "IT'S COMING!", BarkLayer.WARN)
				if not _warned_panic:
					_warned_panic = true
					dialogue.say("GURNEY", "One of them's running! Get to him - a running man is the loudest thing out here.")
		if man.state == Crewman.State.FOLLOWING and evac_rect.has_point(man.global_position):
			_board(man)
	for unit in units:
		unit.set("load_multiplier", CARRY_PACE if _carrying(unit) else 1.0)
	# Leaving is offered once there is someone to leave with.
	_liftoff_point.enabled = evac_rect.has_point(player.global_position) and saved() > 0
	if _everyone_home():
		_lift_off()
	_progress()


func _try_join(man: Crewman, units: Array[Node2D]) -> void:
	for unit in units:
		if unit.global_position.distance_to(man.global_position) > REACH:
			continue
		if led_by(unit) + man.burden() <= LEAD:
			man.join(unit, _followers(unit))
			BarkLayer.say(man, "WITH YOU." if not man.injured else "CAN'T WALK - THANK YOU.", BarkLayer.CALM)
			return
	# Everyone in reach is full: say so, now and then.
	for unit in units:
		if unit.global_position.distance_to(man.global_position) <= REACH:
			var now: int = Time.get_ticks_msec()
			if now - int(_notice_at.get(man, -10000)) > 3000:
				_notice_at[man] = now
				squad.flash_notice("CARRYING HIM TAKES BOTH HANDS - COME BACK FREE" if man.injured else "TWO MEN EACH - BRING THESE HOME FIRST")
			return


## How many men a unit leads (a carried man counts twice).
func led_by(unit: Node2D) -> int:
	var total: int = 0
	for man in crew:
		if man.state == Crewman.State.FOLLOWING and man.leader == unit:
			total += man.burden()
	return total


func _followers(unit: Node2D) -> int:
	return crew.filter(func(man: Crewman) -> bool: return man.state == Crewman.State.FOLLOWING and man.leader == unit).size()


func _carrying(unit: Node2D) -> bool:
	for man in crew:
		if man.carried() and man.leader == unit:
			return true
	return false


func _worm_near(point: Vector2) -> bool:
	var event: WormApproachEvent = worm.event
	return event != null and event.phase == WormApproachEvent.Phase.TRAVEL and event.position_on_path.distance_to(point) <= PANIC_DISTANCE


func _board(man: Crewman) -> void:
	aboard.append(man)
	man.board(_seat_at(aboard.size() - 1))
	_reseat()


func crew_seats() -> int:
	return CREW_SEATS - (SPICE_SEATS if spice_saved else 0)


## The first to arrive keep their seats; returns how many are left without.
func _reseat() -> int:
	var standing: int = 0
	for index in range(aboard.size()):
		var man: Crewman = aboard[index]
		man.seated = index < crew_seats()
		if not man.seated and man.alive():
			standing += 1
		man.queue_redraw()
	return standing


func _seat_at(index: int) -> Vector2:
	return evac_rect.position + Vector2(160 + (index % 5) * 150, 110 + (index / 5) * 120)


## Every living man aboard and seated, and the squad on the rock. Leaving men
## standing is a choice the player makes with LIFT OFF, never automatically.
func _everyone_home() -> bool:
	if crew.size() < CREW.size():
		return false
	for man in crew:
		if man.alive() and (man.state != Crewman.State.SAFE or not man.seated):
			return false
	if not evac_rect.has_point(player.global_position):
		return false
	for ally in squad.members:
		if is_instance_valid(ally) and not ally.health.is_dead and not evac_rect.has_point(ally.global_position):
			return false
	return true


func saved() -> int:
	return crew.filter(func(man: Crewman) -> bool: return man.state == Crewman.State.SAFE and man.seated).size()


func lost() -> int:
	return crew.filter(func(man: Crewman) -> bool: return not man.alive()).size()


func seats_free() -> int:
	return maxi(crew_seats() - aboard.size(), 0)


## Men aboard, seats, and the worm's arrival, kept on the objectives.
func worm_text() -> String:
	var event: WormApproachEvent = worm.event
	if event == null or not event.active():
		return "no worm coming"
	if event.erupting():
		return "WORM SURFACING"
	return "worm %ds" % ceili(event.eta())


func _progress() -> void:
	if mission == null:
		return
	var text: String = "%d / %d aboard  ·  %d seats free  ·  %s" % [saved(), CREW.size(), seats_free(), worm_text()]
	if text != _progress_text:
		_progress_text = text
		mission.set_progress(OBJ_CREW, text)


func _on_crewman_taken(man: Crewman) -> void:
	dialogue.say("", "%s is gone. The sand closes over the place he stood." % man.display_name)


## Whatever is on open sand where it surfaces is taken: men, the crawler,
## a thumper.
func _on_worm_arrived(at: Vector2, radius: float) -> void:
	for man in crew:
		if man.alive() and man.global_position.distance_to(at) <= radius:
			var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(man)
			if safety == null or not safety.is_safe():
				man.health.die()
	for node in get_tree().get_nodes_in_group("thumpers"):
		var thumper: Thumper = node as Thumper
		if thumper != null and thumper.global_position.distance_to(at) <= radius:
			thumper.remaining = 0.0
	if not harvester.destroyed and harvester.global_position.distance_to(at) <= radius * 1.5:
		harvester.destroy()
		_engine_point.enabled = false
		_spice_point.enabled = false
		if not spice_saved:
			mission.fail_objective(OBJ_SPICE)
		dialogue.say("DUKE LETO", "There goes the crawler. It will be hungry again soon. Keep moving.")


func _on_actor_caught(actor: Node) -> void:
	if actor == player:
		paul_taken = true
		mission.fail("TAKEN BY THE WORM")


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("place_thumper") or event.is_echo() or lifted:
		return
	get_viewport().set_input_as_handled()
	place_thumper()


## K: Paul plants Kynes's thumper at his feet - on open sand only.
func place_thumper() -> bool:
	if thumpers <= 0:
		squad.flash_notice("NO THUMPER" if kynes != &"trusts" else "THE THUMPER IS PLANTED")
		return false
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
	if safety != null and safety.is_safe():
		squad.flash_notice("A THUMPER NEEDS OPEN SAND")
		return false
	thumpers -= 1
	var thumper: Thumper = Thumper.new()
	thumper.name = "Thumper"
	thumper.position = player.global_position
	get_parent().add_child(thumper)
	dialogue.say("PAUL", "Drumming. Now get clear of it.")
	return true


func _lift_off() -> void:
	if lifted or not mission.running():
		return
	lifted = true
	# Whoever is still out there, or has no seat, is left to the desert.
	for man in crew:
		if man.alive() and (man.state != Crewman.State.SAFE or not man.seated):
			man.health.die()
	if saved() == 0:
		mission.fail_objective(OBJ_CREW)
		mission.fail("THE CREW LEFT TO THE DESERT")
		return
	mission.complete(OBJ_CREW)
	mission.complete(OBJ_LIFTOFF)
	if not harvester.destroyed:
		# The anchor: the worm takes the crawler behind them.
		harvester.destroy()
	if not spice_saved:
		mission.fail_objective(OBJ_SPICE)
	mission.succeed()


func build_outcome(success: bool, reason: String) -> MissionOutcome:
	var record: MissionOutcome = MissionOutcome.new()
	var definition: MissionDefinition = mission.definition
	record.mission_id = definition.id if definition != null else &"act1_harvester_open"
	record.scopes.append(MissionOutcome.Scope.SQUAD)
	for item in mission.all_objectives():
		if item.state != MissionObjective.State.INACTIVE:
			record.objectives[item.id] = item.state
	var home: int = saved()
	var gone: int = CREW.size() - home
	if not success:
		record.tier = MissionOutcome.Tier.FAILURE
		if paul_taken or player.health.is_dead:
			# Taken by the worm, and dragged out of the sand alive.
			record.heroes_wounded.append("Paul")
	elif gone == 0:
		record.tier = MissionOutcome.Tier.CLEAN
	elif gone <= 2:
		record.tier = MissionOutcome.Tier.NOISY
	else:
		record.tier = MissionOutcome.Tier.PARTIAL
	record.failure_reason = reason
	for ally in squad.members:
		if is_instance_valid(ally) and ally.health.is_dead:
			record.heroes_wounded.append(ally.data.display_name if ally.data != null else String(ally.name))
	record.add_flag(&"carryall_sabotaged")
	if success and gone == 0 and not spice_saved:
		# The Duke chose the men over the spice, and Kynes saw it.
		record.add_flag(&"kynes_respect")
		record.standings[&"fremen"] = 1
	if gone > 0:
		record.add_flag(&"crew_lost")
	if spice_saved and success:
		record.add_flag(&"spice_saved")
		record.standings[&"choam"] = int(record.standings.get(&"choam", 0)) + 1
		record.resources[&"spice"] = 12
	# The manager copies its results into the record once this returns.
	mission.record("Crew saved", "%d / %d" % [home, CREW.size()])
	mission.record("Spice", "loaded" if spice_saved else "left to the worm")
	if definition != null:
		record.apply_stakes(definition)
	return record


func restart_from_checkpoint() -> void:
	get_tree().reload_current_scene()


func debug_rows() -> Dictionary:
	return {"Crew aboard": "%d / %d" % [saved(), CREW.size()], "Crew lost": str(lost()), "Seats free": str(seats_free()), "Kynes": String(kynes), "Thumpers": str(thumpers), "Engine": "off" if engine_off else "running", "Worm": worm_text()}
