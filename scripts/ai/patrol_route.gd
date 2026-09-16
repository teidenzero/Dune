class_name PatrolRoute
extends Node2D
## Ordered Marker2D children define a loop in world coordinates.


func _ready() -> void:
	get_node("/root/GameManager").debug_visibility_changed.connect(func(_value: bool): queue_redraw())
	queue_redraw()


func _draw() -> void:
	if not get_node("/root/GameManager").debug_visible:
		return
	var points: PackedVector2Array = get_points()
	for index in range(points.size()):
		var point: Vector2 = to_local(points[index])
		draw_circle(point, 6.0, Color(0.8, 0.85, 1.0), false, 2.0)
		if points.size() > 1:
			draw_line(point, to_local(points[(index + 1) % points.size()]), Color(0.8, 0.85, 1.0, 0.3), 1.0)


func get_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for child in get_children():
		if child is Marker2D:
			points.append(child.global_position)
	return points
