class_name HunterSeekerController
extends Node
## Act I, 1.1 - The Hunter-Seeker. Solo, Paul, the Residency at night.
##
##   still     A hunter-seeker drifts into Paul's chamber. It homes on motion:
##             stand still, let it come within reach, then seize it (click it).
##   search    Someone guided it from inside the house. The operator hides in
##             one of three places (a different one each play) and slips out
##             through the cellars when the household stirs. Mapes, the Fremen
##             housekeeper, can say where to look - if Paul goes to her.
##
## Clean: the needle taken and the operator found, Paul unhurt. The operator
## escaping leaves the house exposed (partial). The needle finding Paul ends
## the night (failure).

signal mission_event(name: StringName)

const OBJ_NEEDLE: StringName = &"needle"
const OBJ_OPERATOR: StringName = &"operator"

const LAYOUT: String = """
##########################
#......v.#.....#...#######
#.b......#.....D.3.#######
#..P.....D.....#...#######
#.....k..#.....###########
#........#.....###########
####D#######D#############
#........................#
#........................#
####D######D###D#####D####
#.......#.....#..#.......#
#.......#.....#..#.....2.#
#..m....#.....#..D.......#
#.......#...1.#..#.......#
#.......#.....#..#.......#
###D#######D###..#########
#................#########
#X...............#########
##########################
"""

## What there is to find in the Residency.
const FINDS: Array = [
	{"lore": &"residency_plans", "cell": Vector2i(14, 5)},
	{"lore": &"water_ring", "cell": Vector2i(1, 14)},
	{"lore": &"catholic_page", "cell": Vector2i(24, 14)},
	{"cache": &"spice_dose", "cell": Vector2i(18, 1)},
]

## Where the operator may hide, and how Mapes names each place.
const HIDEOUTS: Dictionary = {
	"1": "the west storerooms, off the gallery",
	"2": "the east stores, past the service passage",
	"3": "the little room behind the anteroom - the one with no lamp",
}

@export var mission: MissionManager
@export var player: PlayerController
@export var squad: SquadManager
@export var level: IsoLevel
@export var enemy_root: Node2D
@export var dialogue: DialogueBar
@export var hero: HeroDefinition = preload("res://resources/heroes/paul.tres")
@export var guard_scene: PackedScene = preload("res://scenes/characters/enemies/harkonnen_guard.tscn")
## Seconds from the seeker's death until the operator runs for the cellars.
@export var flee_after: float = 60.0
@export var operator_speed: float = 110.0
## Tests: a fixed hideout ("1".."3"); empty picks one at random.
@export var forced_hideout: String = ""

var phase: StringName = &"still"
var seeker: HunterSeeker
var operator: EnemyCharacter
var hideout: String = ""
var flee_timer: float = 0.0
var fleeing: bool = false
var talked_to_mapes: bool = false
var hurt: bool = false
var combat: TurnCombat
var mapes_point: InteractionPoint


func _ready() -> void:
	add_to_group("mission_controller")
	level.layout = LAYOUT
	level.kit = &"residency"
	level.build()
	call_deferred("_begin")


# --------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------

func _begin() -> void:
	player.isometric = true
	SoloScope.enter(get_tree(), player, squad, false)
	var camera: TacticalCamera = player.get_node_or_null("TacticalCamera") as TacticalCamera
	if camera != null:
		camera.gameplay_zoom = 1.2
	_furnish()
	FindPoint.place_all(level, FINDS)
	_hide_operator()
	combat = TurnCombat.install(self, player, level, hero)
	combat.allow_voluntary = false
	combat.round_ended.connect(_tick)
	player.health.damaged.connect(func(_amount: float) -> void: hurt = true)
	player.health.died.connect(_on_paul_down)
	mission.outcome_builder = build_outcome
	mission.add_objective(MissionObjective.create(OBJ_NEEDLE, "Survive the hunter-seeker", "It homes on movement. Be still; seize it when it is within reach."))
	mission.add_objective(MissionObjective.create(OBJ_OPERATOR, "Find the operator", "Someone guided it from inside the house."))
	mission.activate(OBJ_NEEDLE)
	mission.begin()
	mission.set_phase(&"STILL")
	mission.record("Hunter-seeker", "-")
	mission.record("Operator", "-")
	mission.record("Spoke with Mapes", "NO")
	_release_seeker()
	dialogue.say("", "Night, the first in the Residency. Something hums at the edge of hearing.")
	dialogue.say("PAUL", "A hunter-seeker. It goes for whatever moves. Be still. Let it come close. Then take it.")


func _furnish() -> void:
	var bed: IsoProp = IsoProp.new()
	bed.name = "Bed"
	bed.height = 18.0
	bed.footprint = 0.85
	bed.top_color = Color("6b5a44")
	bed.side_color = Color("3b3026")
	level.add_prop(bed, _cell("b"))
	var desk: IsoProp = IsoProp.new()
	desk.name = "Desk"
	desk.height = 30.0
	desk.footprint = 0.6
	desk.light_color = Color(1.0, 0.8, 0.45)
	level.add_prop(desk, _cell("k"))
	var vent: IsoProp = IsoProp.new()
	vent.name = "Vent"
	vent.solid = false
	vent.height = 0.0
	vent.footprint = 0.4
	vent.top_color = Color("22201c")
	vent.texture = IsoKit.texture(level.kit, "floor_grate")
	vent.anchor = IsoKit.FLOOR_ANCHOR
	level.add_prop(vent, _cell("v"))
	var hatch: IsoProp = IsoProp.new()
	hatch.name = "CellarHatch"
	hatch.solid = false
	hatch.height = 0.0
	hatch.footprint = 0.7
	hatch.top_color = Color("2a2520")
	hatch.caption = "CELLAR DOOR"
	hatch.texture = IsoKit.texture(level.kit, "hatch")
	hatch.anchor = IsoKit.FLOOR_ANCHOR
	level.add_prop(hatch, _cell("X"))
	# Mapes, the housekeeper, in the kitchen.
	var mapes: IsoProp = IsoProp.new()
	mapes.name = "Mapes"
	mapes.height = 54.0
	mapes.footprint = 0.3
	mapes.top_color = Color("4a3a5a")
	mapes.side_color = Color("2e2438")
	mapes.caption = "MAPES"
	mapes.caption_color = Color(0.8, 0.75, 1.0)
	level.add_prop(mapes, _cell("m"))
	mapes_point = InteractionPoint.new()
	mapes_point.name = "TalkToMapes"
	mapes_point.id = &"mapes"
	mapes_point.label = "TALK TO MAPES"
	mapes_point.hold_seconds = 0.4
	mapes_point.interact_radius = 110.0
	mapes_point.enabled = false
	mapes_point.position = level.mark("m") + Vector2(0, 40)
	level.prop_root.add_child(mapes_point)
	mapes_point.interaction_completed.connect(func(_id: StringName) -> void: _talk_to_mapes())


func _hide_operator() -> void:
	hideout = forced_hideout if forced_hideout != "" else str(randi_range(1, 3))
	operator = guard_scene.instantiate() as EnemyCharacter
	operator.name = "Operator"
	operator.display_name = "HARKONNEN OPERATOR"
	operator.position = level.mark(hideout)
	operator.initial_facing_degrees = 90.0
	enemy_root.add_child(operator)
	(operator.get_node("NameLabel") as Label).text = operator.display_name
	operator.health.max_health = 40.0
	operator.health.reset_health()
	operator.health.died.connect(_on_operator_down)
	# Crouched in the dark until the needle is gone.
	operator.set_meta("dormant", true)
	operator.turn_based = true


func _release_seeker() -> void:
	seeker = HunterSeeker.new()
	seeker.name = "HunterSeeker"
	seeker.position = level.mark("v") + Vector2(0, -40)
	level.add_child(seeker)
	seeker.begin(player)
	seeker.seized.connect(_on_seized)


func _cell(symbol: String) -> Vector2i:
	return (level.marks.get(symbol, [Vector2i.ZERO]) as Array)[0]


# --------------------------------------------------------------------------
# Phase one: be still
# --------------------------------------------------------------------------

## A click on the seeker, when it can be caught, catches it. Any other click
## is a move - and moving is what it is waiting for.
func _unhandled_input(event: InputEvent) -> void:
	if phase != &"still" or not is_instance_valid(seeker):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var point: Vector2 = level.get_global_mouse_position()
		if point.distance_to(seeker.global_position) <= 50.0:
			get_viewport().set_input_as_handled()
			if not seeker.seize():
				dialogue.say("PAUL", "Not yet. Too far - and it would feel the reach.", 2.0)


func _on_seized() -> void:
	phase = &"search"
	mission.complete(OBJ_NEEDLE)
	mission.record("Hunter-seeker", "SEIZED")
	mission.activate(OBJ_OPERATOR)
	mission.set_phase(&"SEARCH")
	mission_event.emit(&"seeker_seized")
	CombatFx.float_text(level, player.global_position, "SEIZED", Color(1.0, 0.85, 0.4))
	flee_timer = flee_after
	combat.allow_voluntary = true
	mapes_point.enabled = true
	operator.set_meta("dormant", false)
	operator.turn_based = false
	# He waits, listening; the AI stands guard over his hole.
	dialogue.say("PAUL", "It was guided. Someone close, watching through its eye - inside these walls.")
	dialogue.say("MAPES", "(from below) Young master? There are ways through this house the Atreides have not found. Come down to me.")


# --------------------------------------------------------------------------
# Phase two: the operator
# --------------------------------------------------------------------------

func _talk_to_mapes() -> void:
	if talked_to_mapes:
		return
	talked_to_mapes = true
	mission.record("Spoke with Mapes", "YES")
	mapes_point.enabled = false
	dialogue.say("MAPES", "The Harkonnen dug their holes before you came. If one of them still breathes in this house, he is in %s." % HIDEOUTS[hideout])
	dialogue.say("MAPES", "Go quietly. And remember who told you.")


func _process(delta: float) -> void:
	if not mission.running() or not is_instance_valid(player) or player.health.is_dead:
		return
	if combat != null and combat.active():
		return
	_tick(delta)
	if fleeing:
		_flee()


## Mission time: real time while exploring, five seconds a round in a fight.
func _tick(delta: float) -> void:
	if phase != &"search" or fleeing or not is_instance_valid(operator) or operator.health.is_dead:
		return
	flee_timer = maxf(flee_timer - delta, 0.0)
	mission.set_progress(OBJ_OPERATOR, "%ds" % ceili(flee_timer))
	if flee_timer <= 0.0:
		fleeing = true
		mission.set_progress(OBJ_OPERATOR, "HE RUNS")
		dialogue.say("", "Somewhere below, a door that should not open, opens.")
		# From here he is making for the cellar door, not standing guard.
		operator.ai.set_physics_process(false)


func _flee() -> void:
	if not is_instance_valid(operator) or operator.health.is_dead or operator.turn_based:
		return
	var exit: Vector2 = level.mark("X")
	# Seen on his way out, he turns and fights.
	if operator.perception.perception_state >= PerceptionComponent.Awareness.ALERT or operator.ai.state == EnemyAIController.State.COMBAT:
		operator.ai.set_physics_process(true)
		operator.ai.target = player
		operator.ai.change_state(EnemyAIController.State.COMBAT)
		fleeing = false
		return
	operator.navigate_to(exit, operator_speed)
	if operator.global_position.distance_to(exit) < 50.0:
		_operator_escaped()


func _operator_escaped() -> void:
	fleeing = false
	mission.record("Operator", "ESCAPED")
	mission.fail_objective(OBJ_OPERATOR)
	dialogue.say("PAUL", "Gone. Thufir will not sleep tonight.")
	operator.remove_from_group("enemies")
	operator.queue_free()
	mission.fail("THE OPERATOR GOT AWAY")


func _on_operator_down() -> void:
	if phase != &"search":
		return
	phase = &"done"
	fleeing = false
	mission.record("Operator", "FOUND")
	mission.complete(OBJ_OPERATOR)
	dialogue.say("PAUL", "The one who held the leash. Thufir will want to know how he got into our walls.")
	mission_event.emit(&"operator_found")
	await get_tree().create_timer(1.2).timeout
	if mission.running():
		mission.succeed()


func _on_paul_down() -> void:
	mission.fail("THE NEEDLE FOUND PAUL" if phase == &"still" else "PAUL IS DOWN")


# --------------------------------------------------------------------------
# Outcome
# --------------------------------------------------------------------------

func build_outcome(success: bool, reason: String) -> MissionOutcome:
	var record: MissionOutcome = MissionOutcome.new()
	var definition: MissionDefinition = mission.definition
	record.mission_id = definition.id if definition != null else &"act1_hunter_seeker"
	record.scopes.append(MissionOutcome.Scope.SOLO)
	for item in mission.all_objectives():
		if item.state != MissionObjective.State.INACTIVE:
			record.objectives[item.id] = item.state
	if success:
		record.tier = MissionOutcome.Tier.CLEAN if not hurt else MissionOutcome.Tier.NOISY
	else:
		record.tier = MissionOutcome.Tier.PARTIAL if mission.is_complete(OBJ_NEEDLE) else MissionOutcome.Tier.FAILURE
	record.failure_reason = reason
	if player.health.is_dead:
		record.heroes_wounded.append("Paul")
	if talked_to_mapes:
		# Mapes tells her people the young master listened to a Fremen.
		record.add_flag(&"mapes_trust")
		record.standings[&"fremen"] = 1
	if record.tier == MissionOutcome.Tier.PARTIAL:
		record.add_flag(&"operator_loose")
	if definition != null:
		record.apply_stakes(definition)
	return record


func restart_from_checkpoint() -> void:
	get_tree().reload_current_scene()


func debug_rows() -> Dictionary:
	return {
		"Phase": String(phase),
		"Hideout": hideout,
		"Seeker": HunterSeeker.State.keys()[seeker.state] if is_instance_valid(seeker) else "gone",
		"Flee in": "%ds" % ceili(flee_timer) if phase == &"search" else "-",
		"Mapes": "YES" if talked_to_mapes else "NO",
	}
