class_name IsoDoor
extends StaticBody2D
## A crawler bulkhead hatch. It slides open for anyone who walks up to it,
## Harkonnen included, and shuts behind them. Closed, it blocks movement and
## sight like a wall - so a closed door is cover, and an opening one is warning.

@export var open_distance: float = 96.0
@export var height: float = 70.0
@export var frame_color: Color = Color("3a332c")
@export var panel_color: Color = Color("7a5a32")
@export var edge_color: Color = Color("1a1612")

## The wall line runs along grid x (screen down-right) rather than grid y.
var along_x: bool = true
var is_open: bool = false
## A locked door stays shut for everyone; a tutorial or a mission opens it.
var locked: bool = false:
	set(value):
		locked = value
		queue_redraw()
## 0 closed .. 1 open, for the slide.
var _slide: float = 0.0
var _shape: CollisionPolygon2D
var fade: float = 1.0:
	set(value):
		if not is_equal_approx(fade, value):
			fade = value
			modulate.a = value


func _ready() -> void:
	add_to_group("iso_doors")
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionPolygon2D.new()
	_shape.polygon = IsoMath.diamond(0.9)
	add_child(_shape)


func _physics_process(delta: float) -> void:
	var wants: bool = false
	for group in ["player", "enemies", "allies"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body: Node2D = node as Node2D
			if body == null:
				continue
			var health: HealthComponent = HealthComponent.find_on(body)
			if health != null and health.is_dead:
				continue
			if body.global_position.distance_to(global_position) <= open_distance:
				wants = true
				break
		if wants:
			break
	if locked:
		wants = false
	if wants != is_open:
		is_open = wants
		_shape.set_deferred("disabled", is_open)
	var target: float = 1.0 if is_open else 0.0
	if not is_equal_approx(_slide, target):
		_slide = move_toward(_slide, target, delta * 5.0)
		queue_redraw()


func _draw() -> void:
	var hw: float = IsoMath.TILE_W * 0.5
	var hh: float = IsoMath.TILE_H * 0.5
	var n: Vector2 = Vector2(0, -hh)
	var e: Vector2 = Vector2(hw, 0)
	var s: Vector2 = Vector2(0, hh)
	var w: Vector2 = Vector2(-hw, 0)
	# The threshold plate stays; the panel sinks into the deck as it opens.
	draw_colored_polygon(PackedVector2Array([n, e, s, w]), frame_color.darkened(0.2))
	draw_polyline(PackedVector2Array([n, e, s, w, n]), edge_color, 2.0, true)
	var up: Vector2 = Vector2(0, -height * (1.0 - _slide))
	if up.y > -2.0:
		return
	# The panel runs along the wall line the door sits in.
	var half: Vector2 = Vector2(hw, hh) * 0.5 if along_x else Vector2(-hw, hh) * 0.5
	var left: Vector2 = -half
	var right: Vector2 = half
	if left.x > right.x:
		var swap: Vector2 = left
		left = right
		right = swap
	draw_colored_polygon(PackedVector2Array([left + up, right + up, right, left]), panel_color)
	draw_polyline(PackedVector2Array([left, left + up, right + up, right]), edge_color, 2.0, true)
	var stripe_color: Color = Color(1.0, 0.35, 0.25, 0.6) if locked else Color(0.95, 0.72, 0.25, 0.35)
	for index in range(1, 4):
		var stripe: Vector2 = up * (index / 4.0)
		draw_line(left + stripe, right + stripe, stripe_color, 2.0)
