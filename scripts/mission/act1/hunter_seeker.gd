class_name HunterSeeker
extends Node2D
## A hunter-seeker: a sliver of metal on a suspensor, with a poisoned tip and
## an operator somewhere near, watching through its eye. It homes on motion.
## Still, the hero is hard to find: it drifts and searches, closer each pass.
## Move, and it locks and strikes. Hang still while it comes within reach,
## and it can be seized.

signal struck
signal seized

enum State { DRIFT, HUNT, DEAD }

## Motion it can feel, and how far.
@export var sense_radius: float = 520.0
@export var sense_speed: float = 14.0
@export var drift_speed: float = 42.0
@export var hunt_speed: float = 300.0
## Close enough to seize it.
@export var reach: float = 95.0
## Still this long, and a locked seeker loses him again.
@export var lose_after: float = 0.5
@export var strike_damage: float = 999.0

var state: State = State.DRIFT
var target: PlayerController
var search_point: Vector2
var _still: float = 0.0
var _search_error: float = 150.0
var _bob: float = 0.0
var _hover: float = 0.0


func _ready() -> void:
	z_index = 12
	search_point = global_position


func begin(hero: PlayerController) -> void:
	target = hero
	_pick_search_point()


## Whether a click here, now, would catch it.
func can_seize() -> bool:
	return state != State.DEAD and is_instance_valid(target) and target.current_speed < sense_speed \
		and global_position.distance_to(target.global_position + Vector2(0, -30)) <= reach


func seize() -> bool:
	if not can_seize():
		return false
	state = State.DEAD
	seized.emit()
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
	return true


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not is_instance_valid(target) or target.health.is_dead:
		return
	_bob = fmod(_bob + delta * 3.0, TAU)
	var body: Vector2 = target.global_position + Vector2(0, -30)
	var moving: bool = target.current_speed > sense_speed
	var near: bool = global_position.distance_to(body) <= sense_radius
	match state:
		State.DRIFT:
			if moving and near:
				state = State.HUNT
				_still = 0.0
			else:
				global_position = global_position.move_toward(search_point, drift_speed * delta)
				if global_position.distance_to(search_point) < 6.0:
					# The operator guesses again, and guesses better.
					_search_error = maxf(_search_error * 0.7, 20.0)
					_pick_search_point()
		State.HUNT:
			_still = 0.0 if moving else _still + delta
			if _still >= lose_after:
				state = State.DRIFT
				search_point = body
				return
			global_position = global_position.move_toward(body, hunt_speed * delta)
			if global_position.distance_to(body) < 16.0:
				_strike()
	_hover = 1.0 if can_seize() else move_toward(_hover, 0.0, delta * 3.0)
	queue_redraw()


func _pick_search_point() -> void:
	var body: Vector2 = target.global_position + Vector2(0, -30)
	var angle: float = randf() * TAU
	search_point = body + Vector2(cos(angle), sin(angle) * 0.6) * randf_range(_search_error * 0.5, _search_error)


func _strike() -> void:
	state = State.DEAD
	struck.emit()
	target.health.take_damage(strike_damage, self)
	queue_free()


func _draw() -> void:
	var lift: Vector2 = Vector2(0, sin(_bob) * 3.0)
	# Suspensor shimmer under it.
	draw_circle(Vector2(0, 34), 10.0, Color(0.5, 0.8, 1.0, 0.12))
	var hunting: bool = state == State.HUNT
	var tip: Color = Color(1.0, 0.35, 0.3) if hunting else Color(0.8, 0.9, 1.0)
	var angle: float = 0.0
	if is_instance_valid(target):
		angle = (target.global_position + Vector2(0, -30) - global_position).angle()
	var forward: Vector2 = Vector2.RIGHT.rotated(angle)
	draw_line(lift - forward * 12.0, lift + forward * 12.0, Color(0.75, 0.78, 0.82), 3.0, true)
	draw_circle(lift + forward * 12.0, 2.2, tip)
	draw_circle(lift - forward * 12.0, 3.0, Color(0.35, 0.38, 0.42))
	if _hover > 0.0:
		draw_arc(lift, 20.0, 0, TAU, 24, Color(1.0, 0.85, 0.4, 0.8 * _hover), 2.0, true)
