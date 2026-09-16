class_name TerrainZone
extends Area2D
## Coarse ground classification for worm sign. Deliberately not a terrain
## material system: a zone says only whether the ground under it carries
## vibration or breaks it.

enum Kind { OTHER, OPEN_SAND, SAFE_ROCK }

@export var kind: Kind = Kind.OPEN_SAND
## Scales how much rhythm this ground transmits; rock is silent regardless.
@export_range(0.0, 3.0, 0.05) var sign_multiplier: float = 1.0
@export var debug_color: Color = Color(0.92, 0.78, 0.45, 0.10)


func _ready() -> void:
	add_to_group("terrain_zones")
	monitoring = false
	monitorable = true
	z_index = -5


func is_safe() -> bool:
	return kind == Kind.SAFE_ROCK


func kind_name() -> String:
	return Kind.keys()[kind]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var manager: Node = get_node_or_null("/root/GameManager")
	if manager == null or not manager.debug_visible:
		return
	for child in get_children():
		var shape: CollisionShape2D = child as CollisionShape2D
		if shape == null or shape.shape == null:
			continue
		var color: Color = Color(0.55, 0.9, 0.7, 0.16) if is_safe() else debug_color
		if shape.shape is RectangleShape2D:
			var size: Vector2 = (shape.shape as RectangleShape2D).size
			draw_rect(Rect2(shape.position - size * 0.5, size), color)
			draw_rect(Rect2(shape.position - size * 0.5, size), Color(color, 0.55), false, 2.0)
		elif shape.shape is CircleShape2D:
			var radius: float = (shape.shape as CircleShape2D).radius
			draw_circle(shape.position, radius, color)
			draw_arc(shape.position, radius, 0, TAU, 40, Color(color, 0.55), 2.0, true)
