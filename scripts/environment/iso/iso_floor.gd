class_name IsoFloor
extends Node2D
## Draws every floor cell of an interior in one pass, under everything that
## is y-sorted. Deck plating with a grating pattern; `stained` cells carry a
## spice-rust tint so rooms read differently.

var cells: Array[Vector2i] = []
var stained: Dictionary = {}
var base_color: Color = Color("4a4038")
var alt_color: Color = Color("433a33")
var stain_color: Color = Color("6b4a2a")
var line_color: Color = Color("2a241f")


func _ready() -> void:
	z_index = -10


func _draw() -> void:
	var diamond: PackedVector2Array = IsoMath.diamond()
	var inner: PackedVector2Array = IsoMath.diamond(0.72)
	for cell in cells:
		var origin: Vector2 = IsoMath.cell_to_world(cell)
		var color: Color = base_color if (cell.x + cell.y) % 2 == 0 else alt_color
		if stained.has(cell):
			color = color.lerp(stain_color, 0.55)
		var points: PackedVector2Array = PackedVector2Array()
		for point in diamond:
			points.append(origin + point)
		draw_colored_polygon(points, color)
		points.append(points[0])
		draw_polyline(points, line_color, 1.5, true)
		var grate: PackedVector2Array = PackedVector2Array()
		for point in inner:
			grate.append(origin + point)
		grate.append(grate[0])
		draw_polyline(grate, Color(line_color, 0.45), 1.0, true)
