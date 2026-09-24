class_name IsoBlock
extends Node2D
## A wall or cover block standing up in the squad scope's isometric view: its
## ground footprint extruded toward the top of the screen, drawing the faces
## that look at the camera and the top. Long walls are cut into segments, each
## sorted by its own depth, so a unit at one end is not judged by the other.
## Purely visual: the body's collision, sight and navigation are untouched.
##
## `fade` lowers it to a ghost when it stands in front of one of the squad.

## Longest segment along a wall, in world units.
const SEGMENT: float = 110.0
const FADED: float = 0.32

var footprint: PackedVector2Array = PackedVector2Array()
var height: float = 64.0
var side_color: Color = Color("5a524d")
var top_color: Color = Color("857a73")
var fade: float = 1.0:
	set(value):
		if not is_equal_approx(fade, value):
			fade = value
			modulate.a = value
## Where it covers the screen (in IsoView.BASIS space, camera aside).
var screen_bounds: Rect2 = Rect2()


## Stands up a body's Slab as blocks, and hides the flat Slab and Cap.
static func raise(body: Node2D, block_height: float) -> void:
	var slab: Polygon2D = body.get_node_or_null("Slab") as Polygon2D
	if slab == null or slab.polygon.size() < 3 or body.has_meta("iso_block"):
		return
	body.set_meta("iso_block", true)
	var points: PackedVector2Array = PackedVector2Array()
	for point in slab.polygon:
		points.append(slab.position + point)
	var side: Color = slab.color
	var cap: Polygon2D = body.get_node_or_null("Cap") as Polygon2D
	var top: Color = cap.color if cap != null else slab.color.lightened(0.3)
	for piece in _pieces(points):
		var block: IsoBlock = IsoBlock.new()
		block.name = "IsoBlock"
		var centre: Vector2 = Vector2.ZERO
		for point in piece:
			centre += point
		centre /= piece.size()
		block.position = centre
		var local: PackedVector2Array = PackedVector2Array()
		for point in piece:
			local.append(point - centre)
		block.footprint = local
		block.height = block_height
		block.side_color = side
		block.top_color = top
		body.add_child(block)
	slab.visible = false
	if cap != null:
		cap.visible = false


## A rectangle is cut along its long side into segments; anything else stays whole.
static func _pieces(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if points.size() != 4:
		result.append(points)
		return result
	var box: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	var along_x: bool = box.size.x >= box.size.y
	var length: float = box.size.x if along_x else box.size.y
	var count: int = maxi(1, ceili(length / SEGMENT))
	var step: float = length / count
	for index in range(count):
		var piece: Rect2
		if along_x:
			piece = Rect2(box.position + Vector2(step * index, 0), Vector2(step, box.size.y))
		else:
			piece = Rect2(box.position + Vector2(0, step * index), Vector2(box.size.x, step))
		result.append(PackedVector2Array([piece.position, Vector2(piece.end.x, piece.position.y), piece.end, Vector2(piece.position.x, piece.end.y)]))
	return result


func _ready() -> void:
	add_to_group("iso_blocks")
	z_as_relative = false
	z_index = IsoView.depth(global_position)
	var up: Vector2 = _up()
	screen_bounds = Rect2(IsoView.BASIS * (global_position + footprint[0]), Vector2.ZERO)
	for point in footprint:
		screen_bounds = screen_bounds.expand(IsoView.BASIS * (global_position + point))
		screen_bounds = screen_bounds.expand(IsoView.BASIS * (global_position + point + up))


## Straight up on screen, as a world vector: the view's slant undone.
func _up() -> Vector2:
	return IsoView.upright().basis_xform(Vector2(0, -height))


## Whether a unit standing at `feet` is hidden behind this block.
## `lift`: how far above the feet on screen to look (the body, a beacon).
func covers(feet: Vector2, lift: float = 24.0) -> bool:
	if IsoView.depth(feet) >= z_index:
		return false
	return screen_bounds.has_point(IsoView.BASIS * feet + Vector2(0, -lift))


func _draw() -> void:
	var count: int = footprint.size()
	if count < 3:
		return
	var up: Vector2 = _up()
	var centre: Vector2 = Vector2.ZERO
	for point in footprint:
		centre += IsoView.BASIS.basis_xform(point)
	centre /= count
	var outline: Color = Color(0.1, 0.08, 0.07, 0.9)
	# The sides that face the camera: their outward normal points down-screen.
	for index in range(count):
		var a: Vector2 = footprint[index]
		var b: Vector2 = footprint[(index + 1) % count]
		var sa: Vector2 = IsoView.BASIS.basis_xform(a)
		var sb: Vector2 = IsoView.BASIS.basis_xform(b)
		var normal: Vector2 = (sb - sa).orthogonal()
		if normal.dot((sa + sb) * 0.5 - centre) < 0.0:
			normal = -normal
		if normal.y <= 0.01:
			continue
		# Light from the upper left: left-facing sides lit, right-facing in shade.
		var shade: Color = side_color.lightened(0.12) if normal.x < 0.0 else side_color.darkened(0.18)
		var face: PackedVector2Array = [a, b, b + up, a + up]
		draw_colored_polygon(face, shade)
		draw_polyline(PackedVector2Array([a, b, b + up, a + up, a]), outline, 1.5)
	var top: PackedVector2Array = PackedVector2Array()
	for point in footprint:
		top.append(point + up)
	draw_colored_polygon(top, top_color)
	top.append(top[0])
	draw_polyline(top, outline, 2.0)
