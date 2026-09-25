class_name Crewman
extends CharacterBody2D
## A harvester hand in 1.3, to be got out before the worm comes. He waits at
## his post, silent, until one of the squad reaches him; then he walks behind
## that one, and goes low and quiet when his leader does. A nervous one panics
## when the worm comes near: he runs, and running is the loudest thing a man
## can do in the desert. The injured one cannot walk out: someone must carry
## him, slowly. At the ornithopters he is safe if there is a seat for him; on
## open sand when the worm surfaces, he is taken.
##
## Not a squad member: no weapon, no orders; the mission controller moves him.

signal reached_safety(crewman: Crewman)
signal taken(crewman: Crewman)

enum State { WAITING, PANIC, FOLLOWING, SAFE, DEAD }

const WALK: float = 160.0
const LOW: float = 105.0
const RUN: float = 250.0
## Behind his leader, a little apart from the others following him.
const TRAIL: float = 70.0

var display_name: String = "Crewman"
var nervous: bool = false
var injured: bool = false
var state: State = State.WAITING
var leader: Node2D
var slot: int = 0
## Where he waits, and where panic sends him running to and back.
var post: Vector2 = Vector2.ZERO
var panic_to: Vector2 = Vector2.ZERO
var _panic_out: bool = true
var seat: Vector2 = Vector2.INF
## Aboard with a seat; one standing on the rock without one stays behind.
var seated: bool = true
## The worm-sign emitter reads these, as it does for any walker.
var is_sprinting: bool = false
var is_crouching: bool = false
var walk_speed: float = WALK

var health: HealthComponent
var agent: NavigationAgent2D
var _bob: float = 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group("crew")
	# Sorted by depth like any figure in the isometric view.
	add_to_group("iso_sorted")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 40.0
	add_child(health)
	agent = NavigationAgent2D.new()
	agent.name = "NavigationAgent2D"
	agent.path_desired_distance = 20.0
	agent.target_desired_distance = 24.0
	add_child(agent)
	var safety: TerrainSafetyComponent = TerrainSafetyComponent.new()
	safety.name = "TerrainSafety"
	safety.actor = self
	add_child(safety)
	var emitter: WormSignEmitter = WormSignEmitter.new()
	emitter.name = "WormSignEmitter"
	emitter.actor = self
	emitter.terrain = safety
	emitter.label = "Crewman"
	emitter.movement_multiplier = 0.8
	add_child(emitter)


func _ready() -> void:
	post = global_position
	health.died.connect(func() -> void:
		state = State.DEAD
		velocity = Vector2.ZERO
		taken.emit(self))


func alive() -> bool:
	return state != State.DEAD


func needs_rescue() -> bool:
	return state == State.WAITING or state == State.PANIC


## Being carried: the injured man, once someone has him.
func carried() -> bool:
	return injured and state == State.FOLLOWING


## How much of a leader's strength he takes: a carried man takes it all.
func burden() -> int:
	return 2 if injured else 1


## One of the squad has reached him: he follows, and calms.
func join(unit: Node2D, trail_slot: int) -> void:
	if not needs_rescue():
		return
	leader = unit
	slot = trail_slot
	state = State.FOLLOWING
	is_sprinting = false


func panic() -> void:
	if state == State.WAITING and nervous and not injured:
		state = State.PANIC


## At the ornithopters: he goes where he is told, and stays.
func board(at: Vector2) -> void:
	if state == State.DEAD or state == State.SAFE:
		return
	state = State.SAFE
	seat = at
	leader = null
	is_sprinting = false
	is_crouching = false
	reached_safety.emit(self)


func _physics_process(delta: float) -> void:
	_bob = fmod(_bob + delta * 6.0, TAU)
	var goal: Vector2 = global_position
	var speed: float = WALK
	is_sprinting = false
	is_crouching = false
	match state:
		State.WAITING, State.DEAD:
			velocity = Vector2.ZERO
			queue_redraw()
			return
		State.PANIC:
			# Back and forth across the sand, as fast as he can.
			goal = panic_to if _panic_out else post
			if global_position.distance_to(goal) < 30.0:
				_panic_out = not _panic_out
			speed = RUN
			is_sprinting = true
		State.FOLLOWING:
			if not is_instance_valid(leader):
				state = State.WAITING
				return
			var back: Vector2 = -(leader.velocity as Vector2).normalized() if leader.get("velocity") is Vector2 and (leader.velocity as Vector2).length() > 10.0 else Vector2(0, 1)
			if carried():
				# On his carrier's back: wherever the carrier is, and silent.
				global_position = leader.global_position + back * 10.0
				velocity = Vector2.ZERO
				queue_redraw()
				return
			goal = leader.global_position + back * TRAIL * (slot + 1) + back.orthogonal() * (18.0 if slot % 2 == 0 else -18.0)
			# A leader keeping low keeps his men low: slower, and quiet.
			if bool(leader.get("is_crouching")):
				is_crouching = true
				speed = LOW
			if global_position.distance_to(goal) < 26.0:
				velocity = Vector2.ZERO
				queue_redraw()
				return
		State.SAFE:
			goal = seat
			if global_position.distance_to(goal) < 10.0:
				velocity = Vector2.ZERO
				queue_redraw()
				return
	agent.target_position = goal
	var next: Vector2 = agent.get_next_path_position() if NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) > 0 else goal
	if next.distance_to(global_position) < 2.0:
		next = goal
	velocity = global_position.direction_to(next) * speed
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	var dead: bool = state == State.DEAD
	if IsoView.active:
		draw_set_transform_matrix(IsoView.upright())
	# A figure: legs, a work coverall, a hood, and a shadow at the feet.
	draw_circle(Vector2(0, 2), 13.0, Color(0, 0, 0, 0.28))
	if dead:
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var lift: float = 2.0 * sin(_bob) if velocity.length() > 5.0 else 0.0
	# Carried: drawn up on his carrier's shoulders.
	var up: float = -34.0 if carried() else (8.0 if is_crouching else 0.0)
	var coverall: Color = Color(0.72, 0.52, 0.28) if not injured else Color(0.62, 0.42, 0.3)
	draw_rect(Rect2(Vector2(-9, -20 + lift + up), Vector2(18, 20 - maxf(up, 0.0))), coverall.darkened(0.25))
	draw_rect(Rect2(Vector2(-11, -44 + lift + up), Vector2(22, 26)), coverall)
	draw_circle(Vector2(0, -52 + lift + up), 9.0, Color(0.85, 0.72, 0.58))
	draw_arc(Vector2(0, -52 + lift + up), 10.0, PI, TAU, 12, Color(0.45, 0.35, 0.22), 4.0, true)
	if injured:
		draw_rect(Rect2(Vector2(-11, -34 + lift + up), Vector2(22, 5)), Color(0.85, 0.85, 0.8))
	if state == State.PANIC:
		draw_string(HudStyle.body_font(800), Vector2(-4, -70 + lift), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, HudStyle.DANGER)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var status: String = {State.WAITING: "WAITING", State.PANIC: "PANICKING", State.FOLLOWING: "WITH YOU", State.SAFE: "ABOARD"}.get(state, "")
	if injured and state == State.WAITING:
		status = "INJURED - CARRY HIM"
	elif carried():
		status = "CARRIED"
	elif state == State.SAFE and not seated:
		status = "NO SEAT"
	var color: Color = HudStyle.DANGER if state == State.PANIC or (state == State.SAFE and not seated) else (HudStyle.OK if state == State.SAFE else HudStyle.SAND)
	var font: Font = HudStyle.body_font(600)
	var text: String = "%s  ·  %s" % [display_name.to_upper(), status]
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	IsoView.draw_text(self, font, Vector2.ZERO, Vector2(-width * 0.5, -84 + (-34.0 if carried() else 0.0)), text, 12, color, 3)
