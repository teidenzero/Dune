class_name SoloTutorial
extends Node
## Solo training: nine rooms in the lower levels of the Arrakeen Residency,
## one lesson each, taught by Gurney Halleck. It drives the tutorial prompt
## the way TutorialManager does (same signals, current_step(), `running`,
## `hint_shown`), and every step is proven by real game state.
##
##   1 moving: click to walk, click twice to run, Space to dodge
##   2 walls fade when you are behind them; right-click a console to use it
##   3 stealth in real time: a sentry's cone, sneaking with C
##   4 prescience (Q) into a fight, a silent kill from behind, accepting
##   5 a vision taken back; firing, hit chance, evasion
##   6 being spotted: the Harkonnen act first; cover and reloading
##   7 shields: raising yours, the slow blade through his
##   8 a fuel tank
##   9 out through the hatch
##
## Each room's door is locked until its lesson is done, and each room's
## guards are dormant until their door opens. Going down restarts the room.

signal tutorial_step_started(step: TutorialStep)
signal tutorial_step_completed(step: TutorialStep)
signal tutorial_failed(reason: String)
signal tutorial_completed

const LAYOUT: String = """
#########################
#...a...#.....u.#......s#
#.......#.......#..#....#
#.P.....L...c...L..#....#
#.......#...##..#...##..#
#......b#.......#...d...#
####################L####
#.......#.......#.......#
#.g..#..#.......#.......#
#.......L.r.....L....k..#
#.h..#..#.......#.......#
#.......#.......#.......#
####L####################
#.......#.......#.......#
#.......#...m...#.......#
#.......L....T..L....X..#
#...e...#.....n.#.......#
#.......#.......#.......#
#########################
"""

## Screen angles of the four grid directions, for facing.
const GRID_EAST: float = 26.565
const GRID_WEST: float = 206.565
const GRID_SOUTH: float = 153.435
const GRID_NORTH: float = -26.565

## Room index -> the door out of it (the next room's way in).
const DOORS: Array[Vector2i] = [Vector2i(8, 3), Vector2i(16, 3), Vector2i(20, 6), Vector2i(16, 9), Vector2i(8, 9), Vector2i(4, 12), Vector2i(8, 15), Vector2i(16, 15)]
## Where a restarted room puts the hero.
const ENTRIES: Array[Vector2i] = [Vector2i(2, 3), Vector2i(9, 3), Vector2i(17, 3), Vector2i(20, 7), Vector2i(15, 9), Vector2i(7, 9), Vector2i(4, 13), Vector2i(9, 15), Vector2i(17, 15)]
## Room index -> its (column, row) on the 3 x 3 deck.
const ROOMS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]

## What there is to find, for those who look into corners.
const FINDS: Array = [
	{"lore": &"harkonnen_tally", "cell": Vector2i(1, 5)},
	{"lore": &"shield_drill", "cell": Vector2i(15, 5)},
	{"lore": &"gurney_verse", "cell": Vector2i(23, 5)},
	{"cache": &"spice_dose", "cell": Vector2i(23, 11)},
	{"cache": &"solari", "cell": Vector2i(1, 17)},
	{"lore": &"garrison_water", "cell": Vector2i(15, 17)},
]

## Guards by mark: kind, facing, name.
const GUARDS: Dictionary = {
	"s": {"kind": "guard", "facing": 180.0, "name": "SENTRY"},
	"k": {"kind": "guard", "facing": GRID_EAST, "name": "DRILL SOLDIER"},
	# Walks his round: toward the door, then away from it.
	"r": {"kind": "guard", "facing": GRID_EAST, "name": "DRILL SOLDIER", "route": [Vector2i(9, 9), Vector2i(11, 9)]},
	# Two soldiers talking, each watching the other's back.
	"g": {"kind": "guard", "facing": GRID_SOUTH, "name": "DRILL SOLDIER"},
	"h": {"kind": "guard", "facing": -60.0, "name": "DRILL SOLDIER"},
	"e": {"kind": "shielded", "facing": GRID_NORTH, "name": "SHIELDED SOLDIER"},
	"m": {"kind": "guard", "facing": GRID_EAST, "name": "DRILL SOLDIER"},
	"n": {"kind": "guard", "facing": GRID_EAST, "name": "DRILL SOLDIER"},
}

@export var player: PlayerController
@export var squad: SquadManager
@export var level: IsoLevel
@export var enemy_root: Node2D
@export var prompt: CanvasLayer
@export var hero: HeroDefinition = preload("res://resources/heroes/paul.tres")
@export var guard_scene: PackedScene = preload("res://scenes/characters/enemies/harkonnen_guard.tscn")

var steps: Array[TutorialStep] = []
var index: int = -1
var running: bool = false
var hint_shown: bool = false
var combat: TurnCombat
var guards: Dictionary = {}
var console_point: InteractionPoint
var hatch: IsoProp
var room: int = 0

var _step_time: float = 0.0
var _complete_wait: float = -1.0
var _events: Dictionary = {}
var _counters: Dictionary = {}
var _failing: bool = false


func _ready() -> void:
	add_to_group("solo_tutorial")
	level.layout = LAYOUT
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
		camera.gameplay_zoom = 1.1
	_build_props()
	FindPoint.place_all(level, FINDS)
	_spawn_guards()
	var campaign: CampaignState = Progression.campaign_of(self)
	if campaign != null:
		campaign.begin_mission()
	combat = TurnCombat.install(self, player, level, hero)
	combat.event_logged.connect(func(text: String) -> void: note(StringName(text.to_lower().replace(" ", "_"))))
	combat.vision_rewound.connect(func() -> void: note(&"rewound"))
	combat.combat_started.connect(func(voluntary: bool) -> void: note(&"voluntary" if voluntary else &"spotted"))
	player.health.died.connect(_on_player_died)
	_dock_prompt()
	steps = _build_steps()
	running = true
	var start: int = 0
	var saved: StringName = _gm().tutorial_checkpoint
	for i in steps.size():
		if steps[i].id == saved:
			start = i
	_skip_to_room(_room_of(start))
	_enter(start)


func _build_props() -> void:
	level.stain(Rect2i(9, 1, 7, 5))
	level.stain(Rect2i(9, 13, 7, 5))
	var console: IsoProp = IsoProp.new()
	console.name = "DoorConsole"
	console.height = 44.0
	console.footprint = 0.55
	console.light_color = Color(0.5, 0.9, 1.0)
	console.caption = "DOOR CONSOLE"
	level.add_prop(console, _cell("u"))
	console_point = InteractionPoint.new()
	console_point.name = "ConsolePoint"
	console_point.id = &"console"
	console_point.label = "OPEN THE DOOR"
	console_point.hold_seconds = 1.2
	console_point.interact_radius = 96.0
	console_point.position = level.mark("u") + Vector2(0, 40)
	level.prop_root.add_child(console_point)
	console_point.interaction_completed.connect(func(_id: StringName) -> void: note(&"console"))
	hatch = IsoProp.new()
	hatch.name = "Hatch"
	hatch.solid = false
	hatch.height = 0.0
	hatch.footprint = 0.7
	hatch.top_color = Color("2a2520")
	hatch.light_color = Color(0.5, 0.9, 1.0)
	hatch.caption = "WAY OUT"
	hatch.caption_color = Color(0.6, 0.95, 1.0)
	level.add_prop(hatch, _cell("X"))
	for symbol in ["a", "b", "c", "d"]:
		var marker: TutorialMarker = TutorialMarker.new()
		marker.name = "Marker_%s" % symbol
		marker.radius = 40.0
		marker.position = level.mark(symbol)
		level.add_child(marker)


func _spawn_guards() -> void:
	for symbol: String in GUARDS:
		var spec: Dictionary = GUARDS[symbol]
		var enemy: EnemyCharacter = guard_scene.instantiate() as EnemyCharacter
		enemy.name = "Drill_%s" % symbol
		if spec.has("route"):
			var route: PatrolRoute = PatrolRoute.new()
			route.name = "Route_%s" % symbol
			for cell: Vector2i in spec.route:
				var point: Marker2D = Marker2D.new()
				point.position = IsoMath.cell_to_world(cell)
				route.add_child(point)
			add_child(route)
			enemy.patrol_route = route
		enemy.initial_facing_degrees = spec.facing
		enemy.display_name = spec.name
		enemy.position = level.mark(symbol)
		if spec.kind == "shielded":
			var shield: ShieldComponent = ShieldComponent.new()
			shield.name = "ShieldComponent"
			enemy.add_child(shield)
			var visuals: Node2D = (load("res://scripts/ui/shield_visuals.gd") as GDScript).new()
			visuals.name = "ShieldVisuals"
			visuals.set("shield", shield)
			visuals.set("actor", enemy)
			visuals.z_index = 3
			enemy.add_child(visuals)
		enemy_root.add_child(enemy)
		(enemy.get_node("NameLabel") as Label).text = spec.name
		guards[symbol] = enemy
		_set_dormant(enemy, _room_at(_cell(symbol)) != 0)


func _set_dormant(enemy: EnemyCharacter, value: bool) -> void:
	if not is_instance_valid(enemy) or enemy.health.is_dead:
		return
	enemy.set_meta("dormant", value)
	enemy.turn_based = value


## The prompt moves top-right, under the combat bar and above it in layers.
func _dock_prompt() -> void:
	if prompt == null:
		return
	prompt.layer = 16
	var panel: Control = prompt.get_node("Screen/Prompt") as Control
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -600
	panel.offset_right = -24
	panel.offset_top = 150
	panel.offset_bottom = 326
	var taught: Label = prompt.get_node_or_null("Screen/Summary/Margin/Rows/Taught") as Label
	if taught != null:
		taught.text = "Moving by clicks, running, dodging\nWalls and consoles\nSneaking past a sentry\nPrescience: going in with Q, visions, taking them back\nSilent kills from behind\nTiming a patrol\nTurning heads with a thrown stone\nAction points, hit chance, evasion, cover\nHoltzman shields and the slow blade\nFuel tanks"


# --------------------------------------------------------------------------
# Steps
# --------------------------------------------------------------------------

func _build_steps() -> Array[TutorialStep]:
	var list: Array[TutorialStep] = []
	for data in _lessons():
		list.append(TutorialStep.create(data))
	return list


func _lessons() -> Array:
	var gurney: String = "GURNEY"
	return [
		# 1 - moving
		{"id": &"move", "section": &"r0", "speaker": gurney, "title": "Moving",
			"instruction": "Click the marked tile. You walk to the tile you click - the one under the mouse is outlined.",
			"markers": ["Marker_a"],
			"completion": func() -> bool: return _at("a")},
		{"id": &"run", "section": &"r0", "speaker": gurney, "title": "Running",
			"instruction": "Click twice, quickly, on the far marker: you run.",
			"hint": "Two clicks on the same tile. Running is fast, and loud.",
			"markers": ["Marker_b"],
			"completion": func() -> bool:
				if player.running and player.current_speed > player.walk_speed:
					_counters[&"ran"] = true
				return _counters.has(&"ran") and _at("b")},
		{"id": &"dodge", "section": &"r0", "speaker": gurney, "title": "Dodge",
			"instruction": "Press SPACE to dodge: a quick step that bullets cannot follow.",
			"note": "The door is open. Go through.",
			"completion": func() -> bool: return player.dodging,
			"on_complete": func() -> void: _open_room(1)},
		# 2 - walls and consoles
		{"id": &"walls", "section": &"r1", "speaker": gurney, "title": "Walls",
			"instruction": "Stand on the marker behind the pillar. A wall between you and the camera turns to glass.",
			"markers": ["Marker_c"], "retry_here": true,
			"completion": func() -> bool: return _at("c")},
		{"id": &"use", "section": &"r1", "speaker": gurney, "title": "Consoles",
			"instruction": "Right-click the DOOR CONSOLE. You walk to it and work it.",
			"hint": "Right-click the console itself. Hold still until the ring fills.",
			"completion": func() -> bool: return happened(&"console"),
			"on_complete": func() -> void: _open_room(2)},
		# 3 - stealth
		{"id": &"sneak", "section": &"r2", "speaker": gurney, "title": "Sneaking",
			"instruction": "A sentry watches this room - his cone is on the floor. Press C to sneak, keep behind the pillars and out of the cone, and reach the marker.",
			"hint": "Crouched you are slower, quieter and harder to see. If he sees you, you start again at the door.",
			"markers": ["Marker_d"], "retry_here": true,
			"on_start": func() -> void:
				combat.auto_engage = false
				combat.allow_voluntary = false,
			"completion": func() -> bool: return _at("d") and player.is_crouching,
			"on_complete": func() -> void:
				combat.auto_engage = true
				combat.allow_voluntary = true
				_set_dormant(guards["s"], true)
				_open_room(3)},
		# 4 - prescience and the silent kill
		{"id": &"prescience", "section": &"r3", "speaker": gurney, "title": "Prescience",
			"instruction": "This one has his back to you. Press Q: prescience takes you into a fight, and your whole turn is a vision you can take back.",
			"hint": "Q again inside the vision takes it back. Paul has three visions in each fight.",
			"retry_here": true,
			# Clicking him instead opens the fight for real: a kill still counts.
			"completion": func() -> bool: return (combat.active() and combat.in_vision) or _dead("k")},
		{"id": &"silent_kill", "section": &"r3", "speaker": gurney, "title": "A silent kill",
			"instruction": "Press 2 for the QUICK KNIFE, then click him. Hover first: from behind, unseen, it reads SILENT KILL.",
			"hint": "A knife walks you up to him first. Took the vision back? Press Q and try again.",
			"completion": func() -> bool: return _dead("k")},
		{"id": &"accept", "section": &"r3", "speaker": gurney, "title": "Accepting a future",
			"instruction": "Press SPACE to end your turn. The vision ends in a choice: ENTER accepts this future.",
			"completion": func() -> bool: return _dead("k") and not combat.active(),
			"on_complete": func() -> void: _open_room(4)},
		# 5 - taking it back; firing
		{"id": &"try_door", "section": &"r4", "speaker": gurney, "title": "A future to refuse",
			"instruction": "A soldier faces the next door. Before you go through, press Q - then walk in, inside the vision.",
			"retry_here": true,
			"completion": func() -> bool: return combat.in_vision and combat.aware.has(guards["r"])},
		{"id": &"rewind", "section": &"r4", "speaker": gurney, "title": "Take it back",
			"instruction": "He has seen you - in this future. Press Q: it never happened.",
			"completion": func() -> bool: return happened(&"rewound")},
		{"id": &"fire", "section": &"r4", "speaker": gurney, "title": "Timing",
			"instruction": "He walks his round: toward the door, then away. Crouch (C) at the door and watch him - the door opens as you step up. When his back is turned, take him with the knife: press Q to go in with a vision, or simply click him - whoever strikes first acts first, but that future cannot be taken back. Or shoot it out, the hard way.",
			"hint": "Step up to the door and it opens: you see him, and he can see you. Points you keep at the end of a turn become evasion.",
			"completion": func() -> bool: return _dead("r") and not combat.active(),
			"on_complete": func() -> void: _open_room(5)},
		# 6 - spotted
		{"id": &"spotted", "section": &"r5", "speaker": gurney, "title": "Turning heads",
			"instruction": "Two soldiers, talking, each watching the other's back: kill one and the other sees it. Go in with Q, press 4 and click the far wall between them. A thrown stone turns every head that has not seen you. Then the knife from behind - one, then the other.",
			"hint": "The ring shows who will hear the stone. If it goes wrong, the pillars are cover - and R reloads.",
			"retry_here": true,
			"completion": func() -> bool: return _dead("g") and _dead("h") and not combat.active(),
			"on_complete": func() -> void: _open_room(6)},
		# 7 - shields
		{"id": &"shield_up", "section": &"r6", "speaker": gurney, "title": "The shield",
			"instruction": "He wears a Holtzman shield. Go in, and raise yours: T. Bullets will not touch you.",
			"retry_here": true,
			"completion": func() -> bool: return combat.active() and player.shield_active()},
		{"id": &"slow_blade", "section": &"r6", "speaker": gurney, "title": "The slow blade",
			"instruction": "Nor you him - his shield stops a bullet, and a quick blade. Press 3: the SLOW KNIFE slips through. Finish him.",
			"hint": "The slow blade penetrates the shield. Five points, and he closes with the bayonet - be ready.",
			"completion": func() -> bool: return _dead("e") and not combat.active(),
			"on_complete": func() -> void: _open_room(7)},
		# 8 - fuel
		{"id": &"tank", "section": &"r7", "speaker": gurney, "title": "Fuel",
			"instruction": "Two soldiers by a fuel tank, backs to you. Shoot the tank - right-click it, or press Q and click it in a vision. The blast takes everyone close. Finish whoever stands up.",
			"hint": "Hover the tank for your chance. Keep your distance: it takes you too.",
			"retry_here": true,
			"completion": func() -> bool: return _dead("m") and _dead("n") and not combat.active(),
			"on_complete": func() -> void: _open_room(8)},
		# 9 - out
		{"id": &"exit", "section": &"r8", "speaker": gurney, "title": "Out",
			"instruction": "That is all I can teach you here. Out through the hatch.",
			"completion": func() -> bool: return player.global_position.distance_to(hatch.global_position) < 60.0},
	]


func current_step() -> TutorialStep:
	return steps[index] if index >= 0 and index < steps.size() else null


func note(name: StringName) -> void:
	_events[name] = true


func happened(name: StringName) -> bool:
	return _events.has(name)


func _enter(next: int) -> void:
	index = next
	_step_time = 0.0
	_complete_wait = -1.0
	hint_shown = false
	_events.clear()
	_counters.clear()
	var step: TutorialStep = current_step()
	if step == null:
		_finish()
		return
	if step.retry_here:
		_gm().tutorial_checkpoint = step.id
	room = _room_of(next)
	for marker: Node in get_tree().get_nodes_in_group("tutorial_markers"):
		(marker as TutorialMarker).set_active(step.markers.has(str(marker.name)))
	step.state = TutorialStep.State.ACTIVE
	if step.on_start.is_valid():
		step.on_start.call()
	tutorial_step_started.emit(step)


func _process(delta: float) -> void:
	if not running or _failing:
		return
	var step: TutorialStep = current_step()
	if step == null:
		return
	_step_time += delta
	if not hint_shown and step.hint != "" and _step_time >= step.hint_delay:
		hint_shown = true
	if step.id == &"sneak" and _sentry_saw():
		_fail_room("HE SAW YOU")
		return
	if _complete_wait >= 0.0:
		_complete_wait -= delta
		if _complete_wait < 0.0:
			_enter(index + 1)
		return
	if step.is_satisfied():
		step.state = TutorialStep.State.COMPLETE
		if step.on_complete.is_valid():
			step.on_complete.call()
		tutorial_step_completed.emit(step)
		_complete_wait = step.delay_after


func _finish() -> void:
	running = false
	_gm().tutorial_checkpoint = &""
	tutorial_completed.emit()


# --------------------------------------------------------------------------
# Rooms
# --------------------------------------------------------------------------

## Unlock the door into `next` and wake its guards.
func _open_room(next: int) -> void:
	var door: IsoDoor = level.door_at(DOORS[next - 1])
	if door != null:
		door.locked = false
	for symbol: String in guards:
		if _room_at(_cell(symbol)) == next:
			_set_dormant(guards[symbol], false)


## A restart part-way: earlier rooms are done - their doors open, their
## guards gone - and the hero stands at this room's door.
func _skip_to_room(target: int) -> void:
	if target <= 0:
		return
	for done in range(target):
		var door: IsoDoor = level.door_at(DOORS[done])
		if door != null:
			door.locked = false
	for symbol: String in guards:
		var enemy: EnemyCharacter = guards[symbol]
		var where: int = _room_at(_cell(symbol))
		if where < target:
			enemy.remove_from_group("enemies")
			enemy.queue_free()
		else:
			_set_dormant(enemy, where != target)
	if target > 1:
		console_point.force_complete()
	player.teleport_to(IsoMath.cell_to_world(ENTRIES[target]))


func _room_of(step_index: int) -> int:
	var section: String = String(steps[step_index].section)
	return int(section.substr(1))


func _room_at(cell: Vector2i) -> int:
	var slot: Vector2i = Vector2i(cell.x / 8, cell.y / 6)
	return ROOMS.find(slot)


func _cell(symbol: String) -> Vector2i:
	return (level.marks.get(symbol, [Vector2i.ZERO]) as Array)[0]


func _at(symbol: String) -> bool:
	return IsoMath.world_to_cell(player.global_position) == _cell(symbol)


func _dead(symbol: String) -> bool:
	var enemy: EnemyCharacter = guards.get(symbol)
	return not is_instance_valid(enemy) or enemy.health.is_dead


func _sentry_saw() -> bool:
	var sentry: EnemyCharacter = guards.get("s")
	if not is_instance_valid(sentry):
		return false
	return sentry.ai.state == EnemyAIController.State.COMBAT or sentry.perception.perception_state >= PerceptionComponent.Awareness.ALERT


## Back to the room's door, the room as it was.
func _fail_room(reason: String) -> void:
	_failing = true
	tutorial_failed.emit(reason)
	await get_tree().create_timer(1.4).timeout
	var sentry: EnemyCharacter = guards.get("s")
	if is_instance_valid(sentry):
		sentry.global_position = level.mark("s")
		sentry.perception.detection_value = 0.0
		sentry.perception.perception_state = PerceptionComponent.Awareness.UNAWARE
		sentry.ai.target = null
		sentry.ai.state = EnemyAIController.State.PATROL
		sentry.stop_moving()
		sentry.aim_pivot.rotation = deg_to_rad(GUARDS["s"].facing)
	player.set_crouching(false)
	player.teleport_to(IsoMath.cell_to_world(ENTRIES[room]))
	_failing = false
	_enter(index)


func _on_player_died() -> void:
	tutorial_failed.emit("PAUL IS DOWN")
	await get_tree().create_timer(1.6).timeout
	get_tree().reload_current_scene()


func debug_rows() -> Dictionary:
	var step: TutorialStep = current_step()
	return {
		"Tutorial step": String(step.id) if step != null else "-",
		"Room": room,
		"Hero cell": str(IsoMath.world_to_cell(player.global_position)),
	}


func _gm() -> Node:
	return get_node("/root/GameManager")
