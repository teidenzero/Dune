class_name IsoWall
extends StaticBody2D
## One isometric wall block: a diamond footprint that collides and stops
## sight, drawn as a raised box. Its origin is the footprint's centre, so the
## World's y-sort puts characters behind or in front of it correctly. `fade`
## lowers it to a ghost when the hero walks behind it.

## Low enough that a corridor behind a wall still reads.
@export var height: float = 52.0
@export var top_color: Color = Color("5b5146")
@export var left_color: Color = Color("3a332c")
@export var right_color: Color = Color("2c2621")
@export var edge_color: Color = Color("1a1612")
## Painted block (IsoKit), drawn with its footprint centre on the origin.
var texture: Texture2D
## 1 = solid, lower = see-through.
var fade: float = 1.0:
	set(value):
		if not is_equal_approx(fade, value):
			fade = value
			modulate.a = value


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape: CollisionPolygon2D = CollisionPolygon2D.new()
	shape.polygon = IsoMath.diamond()
	add_child(shape)


func _draw() -> void:
	if texture != null:
		draw_texture(texture, -IsoKit.BLOCK_ANCHOR)
		return
	var hw: float = IsoMath.TILE_W * 0.5
	var hh: float = IsoMath.TILE_H * 0.5
	var up: Vector2 = Vector2(0, -height)
	var n: Vector2 = Vector2(0, -hh)
	var e: Vector2 = Vector2(hw, 0)
	var s: Vector2 = Vector2(0, hh)
	var w: Vector2 = Vector2(-hw, 0)
	# Two visible faces, then the lit top.
	draw_colored_polygon(PackedVector2Array([w + up, s + up, s, w]), left_color)
	draw_colored_polygon(PackedVector2Array([s + up, e + up, e, s]), right_color)
	draw_colored_polygon(PackedVector2Array([n + up, e + up, s + up, w + up]), top_color)
	# Panel seams and outline, so blocks read as machinery rather than clay.
	draw_line(w + up * 0.5, s + up * 0.5, Color(edge_color, 0.5), 1.5)
	draw_line(s + up * 0.5, e + up * 0.5, Color(edge_color, 0.5), 1.5)
	draw_polyline(PackedVector2Array([n + up, e + up, s + up, w + up, n + up]), edge_color, 2.0, true)
	draw_line(w + up, w, edge_color, 2.0)
	draw_line(s + up, s, edge_color, 2.0)
	draw_line(e + up, e, edge_color, 2.0)
