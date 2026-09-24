class_name HarvesterInteriorController
extends Node
## The Harvester Raid in the Solo scope: one hero inside the crawler, on the
## same objectives as the squad raid outside, with the same ids, so the
## campaign reads the result the same way.
##
##   approach  - get into the refinery hall
##   comms     - cut the relay console, or any alarm calls the crew
##   sabotage  - both engine control points
##   escape    - out through the maintenance hatch before the worm comes
##   survive   - be off the crawler when it does
##
## Indoors there is no sand: a shield costs nothing here, which is why the
## guards wear them - and why the crysknife's slow stroke matters.

signal mission_event(name: StringName)

const OBJ_APPROACH: StringName = &"approach"
const OBJ_COMMS: StringName = &"comms"
const OBJ_SABOTAGE: StringName = &"sabotage"
const OBJ_ESCAPE: StringName = &"escape"
const OBJ_SURVIVE: StringName = &"survive"

## The crawler's deck. See IsoLevel for the common symbols; this mission adds
##   R relay console   1 2 engine control points   X maintenance hatch
##   r reinforcement entry   a b c e s guards (see GUARDS)
const LAYOUT: String = """
##############################
#r....#...........#..........#
#..P..D.....a.....D....R.....#
#.....#...........#........r.#
#.....#####.#######....T.....#
###.###...#.#.....######D#####
###.###.T.#.#................#
###.###...D.#......b.........#
###.#######.#..T.........T...#
###.........D................#
###.#######.#######.######D###
###.#.....#.#.......#........#
###.D..X..#.#...c...#...1....#
###.#.....#.#.......D....e...#
###.#.....D.#.......#...2..s.#
###.#######.#########....T...#
###.........#########........#
##############################
"""

## What there is to find aboard.
const FINDS: Array = [
	{"lore": &"crawler_log", "cell": Vector2i(28, 1)},
	{"lore": &"kynes_notes", "cell": Vector2i(13, 14)},
	{"lore": &"wormsign_bulletin", "cell": Vector2i(5, 11)},
	{"cache": &"spice_dose", "cell": Vector2i(9, 5)},
	{"cache": &"water", "cell": Vector2i(28, 16)},
]

## Guards by mark: kind, patrol cells (empty stands still) and facing.
const GUARDS: Dictionary = {
	"a": {"kind": "guard", "route": [Vector2i(8, 2), Vector2i(16, 2)], "facing": 0.0, "name": "CREWMAN"},
	"b": {"kind": "guard", "route": [Vector2i(15, 6), Vector2i(27, 6), Vector2i(27, 9), Vector2i(15, 9)], "facing": 0.0, "name": "HARKONNEN"},
	"c": {"kind": "shielded", "route": [Vector2i(14, 12), Vector2i(18, 12)], "facing": 0.0, "name": "SHIELDED GUARD"},
	"e": {"kind": "elite", "route": [], "facing": 200.0, "name": "ELITE"},
	"s": {"kind": "shielded", "route": [Vector2i(22, 12), Vector2i(27, 12), Vector2i(27, 16), Vector2i(22, 16)], "facing": 90.0, "name": "SHIELDED GUARD"},
}
const REFINERY: Rect2i = Rect2i(13, 5, 16, 5)
const ENGINE_ROOM: Rect2i = Rect2i(21, 11, 8, 6)

@export var mission: MissionManager
@export var player: PlayerController
@export var squad: SquadManager
@export var level: IsoLevel
@export var enemy_root: Node2D

@export_group("Escalation")
## From the engine giving out to the worm taking the crawler.
@export var worm_countdown: float = 75.0
@export var alarm_radius: float = 1100.0
@export var reinforcement_delay: float = 5.0
@export var hatch_radius: float = 60.0
## Closer than the squad view: one hero, tight rooms.
@export var interior_zoom: float = 1.1
## The hero sent in: his action points and prescience drive the fights.
@export var hero: HeroDefinition = preload("res://resources/heroes/paul.tres")
@export var guard_scene: PackedScene = preload("res://scenes/characters/enemies/harkonnen_guard.tscn")
@export var elite_scene: PackedScene = preload("res://scenes/characters/enemies/harkonnen_elite.tscn")

var relay_active: bool = true
var sabotage_done: int = 0
var sabotage_total: int = 0
var sabotaged: bool = false
var alarm_active: bool = false
var combat_before_sabotage: bool = false
var escape_active: bool = false
var escaped: bool = false
var worm_remaining: float = 0.0
var reinforcements_spawned: int = 0
var relay_point: InteractionPoint
var combat: TurnCombat
var hatch: IsoProp
var _pending_groups: int = 0
var _reinforcement_wait: float = 0.0
var _rumble: float = 0.0


func _ready() -> void:
	add_to_group("mission_controller")
	if level.layout.strip_edges() == "":
		level.layout = LAYOUT
	level.build()
	call_deferred("_begin")


# --------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------

func _begin() -> void:
	player.isometric = true
	SoloScope.enter(get_tree(), player, squad, false)
	player.teleport_to(level.player_start)
	var camera: TacticalCamera = player.get_node_or_null("TacticalCamera") as TacticalCamera
	if camera != null:
		camera.gameplay_zoom = interior_zoom
	_build_rooms()
	FindPoint.place_all(level, FINDS)
	_spawn_guards()
	_build_objectives()
	_connect()
	combat = TurnCombat.install(self, player, level, hero)
	combat.round_ended.connect(_tick)
	mission.begin()
	mission.record("Relay cut", "NO")
	mission.record("Full combat before sabotage", "NO")
	mission.record("Enemies defeated", 0)
	mission.record("Times fully detected", 0)
	mission_event.emit(&"mission_start")


func _build_rooms() -> void:
	level.stain(ENGINE_ROOM)
	level.stain(Rect2i(19, 1, 10, 4))
	# The relay: a console with a live light, cut by holding F at it.
	var relay: IsoProp = _console("COMMS RELAY", Color(1.0, 0.45, 0.35))
	level.add_prop(relay, _cell("R"))
	relay_point = _point(&"relay", "CUT THE RELAY", 2.2, level.mark("R"))
	relay_point.interaction_completed.connect(func(_id: StringName) -> void: _on_relay_cut(relay))
	for symbol in ["1", "2"]:
		var block: IsoProp = _console("ENGINE CONTROL", Color(0.95, 0.75, 0.3))
		block.height = 56.0
		level.add_prop(block, _cell(symbol))
		var point: InteractionPoint = _point(StringName("engine_%s" % symbol), "SABOTAGE ENGINE CONTROL", 2.4, level.mark(symbol))
		point.add_to_group("sabotage_points")
		point.interaction_completed.connect(func(_id: StringName) -> void: _on_sabotage_point(block))
		sabotage_total += 1
	hatch = IsoProp.new()
	hatch.name = "Hatch"
	hatch.solid = false
	hatch.height = 0.0
	hatch.footprint = 0.7
	hatch.top_color = Color("2a2520")
	hatch.light_color = Color(0.5, 0.9, 1.0)
	hatch.caption = "MAINTENANCE HATCH"
	hatch.caption_color = Color(0.6, 0.95, 1.0)
	level.add_prop(hatch, _cell("X"))


func _console(caption: String, light: Color) -> IsoProp:
	var prop: IsoProp = IsoProp.new()
	prop.name = caption.capitalize().replace(" ", "")
	prop.height = 44.0
	prop.footprint = 0.55
	prop.light_color = light
	prop.caption = caption
	return prop


func _point(id: StringName, label: String, seconds: float, at: Vector2) -> InteractionPoint:
	var point: InteractionPoint = InteractionPoint.new()
	point.name = "Point_%s" % id
	point.id = id
	point.label = label
	point.hold_seconds = seconds
	point.interact_radius = 96.0
	point.collision_layer = 0
	point.collision_mask = 0
	point.position = at + Vector2(0, 40)
	level.prop_root.add_child(point)
	return point


func _cell(symbol: String) -> Vector2i:
	return (level.marks.get(symbol, [Vector2i.ZERO]) as Array)[0]


func _spawn_guards() -> void:
	for symbol: String in GUARDS:
		if not level.has_mark(symbol):
			continue
		var spec: Dictionary = GUARDS[symbol]
		var route: PatrolRoute = null
		if not (spec.route as Array).is_empty():
			route = PatrolRoute.new()
			route.name = "Route_%s" % symbol
			for cell: Vector2i in spec.route:
				var point: Marker2D = Marker2D.new()
				point.position = IsoMath.cell_to_world(cell)
				route.add_child(point)
			add_child(route)
		var enemy: EnemyCharacter = _make_enemy(String(spec.kind))
		enemy.name = "%s_%s" % [String(spec.kind).capitalize(), symbol]
		enemy.patrol_route = route
		enemy.initial_facing_degrees = spec.facing
		enemy.display_name = spec.name
		enemy.position = level.mark(symbol)
		enemy_root.add_child(enemy)
		if spec.kind != "elite":
			(enemy.get_node("NameLabel") as Label).text = spec.name


func _make_enemy(kind: String) -> EnemyCharacter:
	if kind == "elite":
		return elite_scene.instantiate() as EnemyCharacter
	var enemy: EnemyCharacter = guard_scene.instantiate() as EnemyCharacter
	if kind == "shielded":
		# Indoors a shield is free, so the crew wears them: a round will not
		# get through, a blade drawn slowly will.
		var shield: ShieldComponent = ShieldComponent.new()
		shield.name = "ShieldComponent"
		enemy.add_child(shield)
		var visuals: Node2D = (load("res://scripts/ui/shield_visuals.gd") as GDScript).new()
		visuals.name = "ShieldVisuals"
		visuals.set("shield", shield)
		visuals.set("actor", enemy)
		visuals.z_index = 3
		enemy.add_child(visuals)
	return enemy


func _build_objectives() -> void:
	mission.outcome_builder = build_outcome
	mission.add_objective(MissionObjective.create(OBJ_APPROACH, "Reach the refinery hall", "Through the crew deck, or down the crawlway."))
	mission.add_objective(MissionObjective.create(OBJ_COMMS, "Cut the comms relay", "With the relay live, any alarm brings the crew."))
	mission.add_objective(MissionObjective.create(OBJ_SABOTAGE, "Sabotage the engine", "Both control points in the engine room."))
	mission.add_objective(MissionObjective.create(OBJ_ESCAPE, "Out through the maintenance hatch", "The crippled crawler will call the worm."))
	mission.add_objective(MissionObjective.create(OBJ_SURVIVE, "Be off the crawler when the worm comes", "It takes the crawler, and everything aboard."))
	mission.activate(OBJ_APPROACH)
	mission.activate(OBJ_COMMS)
	mission.set_phase(&"APPROACH")


func _connect() -> void:
	player.health.died.connect(func() -> void: mission.fail("%s IS DOWN" % _hero_name().to_upper()))
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		_watch_enemy(enemy)


func _watch_enemy(enemy: Node) -> void:
	var health: HealthComponent = HealthComponent.find_on(enemy)
	if health != null and not health.died.is_connected(_on_enemy_died):
		health.died.connect(_on_enemy_died)
	var actor: EnemyCharacter = enemy as EnemyCharacter
	if actor != null and not actor.ai.state_changed.is_connected(_on_enemy_state):
		actor.ai.state_changed.connect(_on_enemy_state)


func _hero_name() -> String:
	return "Paul"


# --------------------------------------------------------------------------
# Objectives
# --------------------------------------------------------------------------

func _on_relay_cut(relay: IsoProp) -> void:
	relay_active = false
	relay.light_color = Color(0, 0, 0, 0)
	relay.caption = "RELAY CUT"
	relay.caption_color = Color(0.6, 0.7, 0.72)
	relay.queue_redraw()
	# Reinforcements already called stay called; nothing new comes.
	mission.complete(OBJ_COMMS)
	mission.record("Relay cut", "YES")
	mission_event.emit(&"objective_complete")


func _on_sabotage_point(block: IsoProp) -> void:
	block.light_color = Color(1.0, 0.25, 0.1)
	block.caption = "SABOTAGED"
	block.queue_redraw()
	sabotage_done += 1
	mission.complete(OBJ_APPROACH)
	mission.activate(OBJ_SABOTAGE)
	mission.set_progress(OBJ_SABOTAGE, "%d / %d" % [sabotage_done, sabotage_total])
	mission.set_phase(&"SABOTAGE")
	mission_event.emit(&"objective_complete")
	if sabotage_done >= sabotage_total and not sabotaged:
		_on_sabotaged()


func _on_sabotaged() -> void:
	sabotaged = true
	mission.complete(OBJ_SABOTAGE)
	mission_event.emit(&"harvester_sabotaged")
	_raise_alarm(level.mark("1"))
	escape_active = true
	worm_remaining = worm_countdown
	mission.activate(OBJ_ESCAPE)
	mission.activate(OBJ_SURVIVE)
	mission.set_phase(&"ESCAPE")
	_shake(0.5)


func _on_escaped() -> void:
	escaped = true
	mission.complete(OBJ_ESCAPE)
	mission.complete(OBJ_SURVIVE)
	mission_event.emit(&"mission_complete")
	mission.succeed()


func _process(delta: float) -> void:
	if not mission.running() or not is_instance_valid(player) or player.health.is_dead:
		return
	var cell: Vector2i = IsoMath.world_to_cell(player.global_position)
	if REFINERY.has_point(cell) and not mission.is_complete(OBJ_APPROACH):
		mission.complete(OBJ_APPROACH)
		mission.activate(OBJ_SABOTAGE)
		mission.set_phase(&"SABOTAGE")
	if escape_active and player.global_position.distance_to(hatch.global_position) <= hatch_radius:
		_on_escaped()
		return
	# In a turn-based fight time passes by the round (see _tick).
	if combat == null or not combat.active():
		_tick(delta)


## Mission clocks: reinforcements and the worm. Real time while exploring,
## TurnRules.ROUND_SECONDS per round in a fight.
func _tick(delta: float) -> void:
	if not mission.running():
		return
	if _pending_groups > 0:
		_reinforcement_wait -= delta
		if _reinforcement_wait <= 0.0:
			_spawn_group()
	if not escape_active:
		return
	worm_remaining = maxf(worm_remaining - delta, 0.0)
	mission.set_progress(OBJ_ESCAPE, "%ds" % ceili(worm_remaining))
	# The deck shakes harder as it comes.
	_rumble -= delta
	if _rumble <= 0.0:
		_rumble = lerpf(4.0, 0.8, 1.0 - worm_remaining / maxf(worm_countdown, 1.0))
		_shake(lerpf(0.12, 0.45, 1.0 - worm_remaining / maxf(worm_countdown, 1.0)))
	if worm_remaining <= 0.0:
		_shake(1.0)
		mission.fail_objective(OBJ_SURVIVE)
		mission.fail("TAKEN BY THE WORM")


## What a prescient vision may change here, for taking it back.
func vision_snapshot() -> Dictionary:
	return {
		"alarm_active": alarm_active, "combat_before_sabotage": combat_before_sabotage,
		"pending": _pending_groups, "wait": _reinforcement_wait, "spawned": reinforcements_spawned,
		"worm": worm_remaining,
	}


func vision_restore(data: Dictionary) -> void:
	alarm_active = data.alarm_active
	combat_before_sabotage = data.combat_before_sabotage
	_pending_groups = data.pending
	_reinforcement_wait = data.wait
	reinforcements_spawned = data.spawned
	worm_remaining = data.worm


func _shake(amount: float) -> void:
	var camera: TacticalCamera = player.get_node_or_null("TacticalCamera") as TacticalCamera
	if camera != null:
		camera.add_shake(amount)


# --------------------------------------------------------------------------
# Alarm and reinforcements
# --------------------------------------------------------------------------

## Everyone in earshot comes to look. With the relay live, the crew from the
## boarding bay and the relay room come too.
func _raise_alarm(position: Vector2) -> void:
	var first: bool = not alarm_active
	alarm_active = true
	mission_event.emit(&"alarm")
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var actor: EnemyCharacter = node as EnemyCharacter
		if actor == null or actor.health.is_dead or actor.global_position.distance_to(position) > alarm_radius:
			continue
		actor.ai.suspicious_position = position
		actor.ai.disturbance_priority = 6
		actor.ai.current_disturbance = "ALARM"
		if actor.ai.state != EnemyAIController.State.COMBAT:
			actor.ai.change_state(EnemyAIController.State.INVESTIGATE)
	if first and relay_active:
		_pending_groups = 2
		_reinforcement_wait = reinforcement_delay


func _spawn_group() -> void:
	var entries: Array = level.marks.get("r", [])
	if entries.is_empty() or not is_instance_valid(player):
		_pending_groups = 0
		return
	var at: Vector2 = IsoMath.cell_to_world(entries[reinforcements_spawned % entries.size()])
	for index in range(2):
		var enemy: EnemyCharacter = _make_enemy("guard")
		enemy.display_name = "CREWMAN"
		enemy.position = at + Vector2(index * 50 - 25, index * 20)
		enemy_root.add_child(enemy)
		(enemy.get_node("NameLabel") as Label).text = enemy.display_name
		enemy.face_position(player.global_position)
		enemy.ai.suspicious_position = player.global_position
		enemy.ai.change_state(EnemyAIController.State.INVESTIGATE)
		_watch_enemy(enemy)
	reinforcements_spawned += 1
	_pending_groups -= 1
	_reinforcement_wait = reinforcement_delay * 2.0
	mission_event.emit(&"reinforcements")


# --------------------------------------------------------------------------
# Bookkeeping
# --------------------------------------------------------------------------

func _on_enemy_died() -> void:
	mission.bump("Enemies defeated")


func _on_enemy_state(_previous: EnemyAIController.State, current: EnemyAIController.State) -> void:
	if current != EnemyAIController.State.COMBAT:
		return
	mission.bump("Times fully detected")
	if not sabotaged and not combat_before_sabotage:
		combat_before_sabotage = true
		mission.record("Full combat before sabotage", "YES")
	# A guard who sees you shouts; with the relay live, that is heard aboard.
	_raise_alarm(player.global_position)


## The same shape the squad raid reports, in the Solo scope.
func build_outcome(success: bool, reason: String) -> MissionOutcome:
	var record: MissionOutcome = MissionOutcome.new()
	var definition: MissionDefinition = mission.definition
	record.mission_id = definition.id if definition != null else &"harvester_raid"
	record.scopes.append(MissionOutcome.Scope.SOLO)
	for item in mission.all_objectives():
		if item.state != MissionObjective.State.INACTIVE:
			record.objectives[item.id] = item.state
	if success:
		record.tier = MissionOutcome.Tier.CLEAN if not relay_active and not combat_before_sabotage else MissionOutcome.Tier.NOISY
	else:
		record.tier = MissionOutcome.Tier.PARTIAL if sabotaged else MissionOutcome.Tier.FAILURE
	record.failure_reason = reason
	# Heroes are never killed outright: down, or caught aboard, means wounded.
	if player.health.is_dead or reason == "TAKEN BY THE WORM":
		record.heroes_wounded.append(_hero_name())
	if relay_active:
		record.add_flag(&"comms_intact")
	if alarm_active:
		record.add_flag(&"alarm_raised")
	if combat_before_sabotage:
		record.add_flag(&"firefight")
	if sabotaged and (success or reason == "TAKEN BY THE WORM"):
		record.add_flag(&"harvester_destroyed")
	if definition != null:
		record.apply_stakes(definition)
	return record


func restart_from_checkpoint() -> void:
	get_tree().reload_current_scene()


func debug_rows() -> Dictionary:
	var objective: MissionObjective = mission.active_objective()
	return {
		"Mission state": "%s / %s" % [mission.phase_name(), mission.outcome_name()],
		"Current objective": objective.display_title() if objective != null else "-",
		"Relay": "LIVE" if relay_active else "CUT",
		"Sabotage progress": "%d / %d" % [sabotage_done, sabotage_total],
		"Alarm active": "YES" if alarm_active else "NO",
		"Reinforcements": "%d spawned, %d pending" % [reinforcements_spawned, _pending_groups],
		"Worm in": "%ds" % ceili(worm_remaining) if escape_active else "-",
		"Hero cell": str(IsoMath.world_to_cell(player.global_position)) if is_instance_valid(player) else "-",
		"Mission time": mission.time_text(),
	}
