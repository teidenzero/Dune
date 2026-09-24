class_name MapCanvas
extends Control
## Arrakis drawn as the Fremen would draw it: ink on spice paper, north pole
## at the top. Regions are inked blobs coloured by who holds them, joined by
## dotted routes; the Coriolis storm is a band of hatching across the south.
## Marks show harvesters, worm sign and the Harkonnen grip; diamonds are
## operations (gold for the story).

signal region_selected(id: StringName)
signal operation_selected(op_id: int)

const PAPER: Color = Color("c8a46a")
const PAPER_DARK: Color = Color("a9844c")
const INK: Color = Color("3a2716")
const INK_SOFT: Color = Color(0.23, 0.15, 0.09, 0.45)
const CONTROL_COLORS: Array[Color] = [Color("8c3b2a"), Color("2f5872"), Color("9a7a2c"), Color("b89a66")]
const OP_COLORS: Dictionary = {
	&"raid": Color("d0582f"), &"water": Color("4f9fc9"), &"village": Color("c9a23a"), &"ambush": Color("b0442f"),
	&"recruit": Color("5fae78"), &"plant": Color("7fbf5a"), &"defend": Color("e04a3a"), &"story": Color("f2c14e"),
}

var state: StrategicState
var selected_region: StringName = &""
var selected_op: int = -1
var hover_region: StringName = &""

var _blobs: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	for id in ArrakisAtlas.ids():
		_blobs[id] = _blob(id)
	resized.connect(queue_redraw)


## A region's irregular outline in map space, the same every time.
func _blob(id: StringName) -> PackedVector2Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(id))
	var ground: ArrakisAtlas.Kind = ArrakisAtlas.kind(id)
	var radius: float = 30.0 if ground in [ArrakisAtlas.Kind.CITY, ArrakisAtlas.Kind.SIETCH, ArrakisAtlas.Kind.VILLAGE] else 44.0
	var points: PackedVector2Array = PackedVector2Array()
	var count: int = 14
	for index in range(count):
		var angle: float = TAU * index / count
		var r: float = radius * rng.randf_range(0.78, 1.18)
		points.append(ArrakisAtlas.position(id) + Vector2(cos(angle) * r * 1.25, sin(angle) * r * 0.85))
	return points


## Map space to this control, keeping the projection's aspect.
func _scale() -> float:
	return minf(size.x / ArrakisAtlas.SIZE.x, size.y / ArrakisAtlas.SIZE.y) * 0.96


func _origin() -> Vector2:
	return (size - ArrakisAtlas.SIZE * _scale()) * 0.5


func to_screen(point: Vector2) -> Vector2:
	return _origin() + point * _scale()


func to_map(point: Vector2) -> Vector2:
	return (point - _origin()) / _scale()


func region_at(point: Vector2) -> StringName:
	var local: Vector2 = to_map(point)
	var best: StringName = &""
	var distance: float = 55.0
	for id in ArrakisAtlas.ids():
		var gap: float = local.distance_to(ArrakisAtlas.position(id))
		if gap < distance:
			distance = gap
			best = id
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id: StringName = region_at(event.position)
		if id != hover_region:
			hover_region = id
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id: StringName = region_at(event.position)
		if id == &"":
			return
		selected_region = id
		var ops: Array[StrategicOperation] = _ops_in(id)
		selected_op = ops[0].id if not ops.is_empty() else -1
		region_selected.emit(id)
		if selected_op >= 0:
			operation_selected.emit(selected_op)
		queue_redraw()


func _ops_in(id: StringName) -> Array[StrategicOperation]:
	var result: Array[StrategicOperation] = []
	if state == null:
		return result
	for op in state.open_operations():
		if op.region == id:
			result.append(op)
	return result


func _draw() -> void:
	var scale: float = _scale()
	var top_left: Vector2 = _origin()
	var paper: Rect2 = Rect2(top_left, ArrakisAtlas.SIZE * scale)
	draw_rect(paper.grow(10.0), Color("1a130c"))
	draw_rect(paper, PAPER)
	# Latitude lines, the way a Fremen cartographer would rule them.
	for index in range(1, 6):
		var y: float = paper.position.y + paper.size.y * index / 6.0
		draw_line(Vector2(paper.position.x, y), Vector2(paper.end.x, y), Color(INK, 0.08), 1.0)
	_draw_storm(paper)
	if state == null:
		return
	for route in ArrakisAtlas.ROUTES:
		_dotted(to_screen(ArrakisAtlas.position(route[0])), to_screen(ArrakisAtlas.position(route[1])), INK_SOFT)
	for id in ArrakisAtlas.ids():
		_draw_region(id, scale)
	for op in state.open_operations():
		_draw_operation(op, scale)
	var font: Font = HudStyle.display_font()
	draw_string(font, paper.position + Vector2(16, 30), "ARRAKIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(INK, 0.7))
	draw_string(font, paper.position + Vector2(16, paper.size.y - 14), "SOUTHERN LATITUDES", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.5))


func _draw_storm(paper: Rect2) -> void:
	if state == null:
		return
	var center: float = state.storm_center()
	var top: float = paper.position.y + paper.size.y * maxf(center - 0.1, 0.6)
	var bottom: float = paper.position.y + paper.size.y * minf(center + 0.1, 1.0)
	if bottom <= top:
		return
	draw_rect(Rect2(paper.position.x, top, paper.size.x, bottom - top), Color(0.45, 0.3, 0.16, 0.28))
	var step: float = 14.0
	var x: float = paper.position.x - (bottom - top)
	while x < paper.end.x:
		var a: Vector2 = Vector2(x, bottom)
		var b: Vector2 = Vector2(x + (bottom - top), top)
		draw_line(a.clamp(Vector2(paper.position.x, top), Vector2(paper.end.x, bottom)), b.clamp(Vector2(paper.position.x, top), Vector2(paper.end.x, bottom)), Color(0.35, 0.22, 0.1, 0.22), 1.5)
		x += step
	draw_string(HudStyle.display_font(), Vector2(paper.end.x - 230, top + 20), "CORIOLIS STORM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.18, 0.08, 0.7))


func _draw_region(id: StringName, scale: float) -> void:
	var region: RegionState = state.region(id)
	var points: PackedVector2Array = PackedVector2Array()
	for point in _blobs[id]:
		points.append(to_screen(point))
	var fill: Color = CONTROL_COLORS[region.control]
	fill.a = 0.55 if ArrakisAtlas.kind(id) != ArrakisAtlas.Kind.HIDDEN else 0.3
	draw_colored_polygon(points, fill)
	points.append(points[0])
	var edge_width: float = 3.0 if id == selected_region else (2.0 if id == hover_region else 1.2)
	var edge: Color = Color("f6e2a8") if id == selected_region else INK
	draw_polyline(points, edge, edge_width, true)
	var center: Vector2 = to_screen(ArrakisAtlas.position(id))
	_draw_kind(id, center, scale)
	var font: Font = HudStyle.body_font(700)
	var label: String = ArrakisAtlas.title(id).to_upper()
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(font, center + Vector2(-width * 0.5, 30 * scale + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(PAPER, 0.8))
	draw_string(font, center + Vector2(-width * 0.5, 30 * scale + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	# The Harkonnen grip, as red pips.
	for index in range(region.grip):
		draw_circle(center + Vector2(-16 + index * 8, -20 * scale - 6), 3.0, Color("b0301f"))
	# Harvesters, as little crawlers.
	for index in range(region.harvesters):
		var at: Vector2 = center + Vector2(-18 + index * 12, 14 * scale)
		draw_rect(Rect2(at, Vector2(9, 5)), Color("2a1c10"))
	if region.worm_sign >= 50.0:
		_draw_worm(center + Vector2(22 * scale + 10, -4), region.worm_sign / RegionState.WORM_MAX)


func _draw_kind(id: StringName, center: Vector2, scale: float) -> void:
	var size_px: float = 7.0 * maxf(scale, 0.8)
	match ArrakisAtlas.kind(id):
		ArrakisAtlas.Kind.CITY:
			draw_rect(Rect2(center - Vector2(size_px, size_px), Vector2(size_px, size_px) * 2.0), INK, false, 2.0)
			draw_rect(Rect2(center - Vector2(size_px, size_px) * 0.4, Vector2(size_px, size_px) * 0.8), INK)
		ArrakisAtlas.Kind.SIETCH:
			draw_arc(center + Vector2(0, size_px * 0.5), size_px, PI, TAU, 12, INK, 2.0)
			draw_line(center + Vector2(-size_px, size_px * 0.5), center + Vector2(size_px, size_px * 0.5), INK, 2.0)
		ArrakisAtlas.Kind.VILLAGE:
			for dx in [-size_px, 0.0, size_px]:
				draw_rect(Rect2(center + Vector2(dx - 3, -3), Vector2(6, 6)), INK)
		ArrakisAtlas.Kind.SAND:
			for row in range(2):
				var y: float = center.y - 3 + row * 6
				draw_polyline(PackedVector2Array([Vector2(center.x - size_px * 1.4, y), Vector2(center.x - size_px * 0.5, y - 3), Vector2(center.x + size_px * 0.4, y), Vector2(center.x + size_px * 1.3, y - 3)]), INK, 1.5, true)
		ArrakisAtlas.Kind.POLAR:
			draw_circle(center, size_px, Color(0.9, 0.95, 1.0, 0.8))
			draw_arc(center, size_px, 0, TAU, 20, INK, 1.5)
		ArrakisAtlas.Kind.HIDDEN:
			draw_arc(center, size_px, 0, TAU, 20, Color(INK, 0.5), 1.5)
			draw_circle(center, 2.5, Color("5c8a3a"))
		_:
			draw_colored_polygon(PackedVector2Array([center + Vector2(-size_px, size_px * 0.6), center + Vector2(0, -size_px), center + Vector2(size_px, size_px * 0.6)]), Color(INK, 0.8))


func _draw_worm(at: Vector2, strength: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(9):
		points.append(at + Vector2(index * 3.0, sin(index * 1.1) * 4.0))
	draw_polyline(points, Color(0.55, 0.2, 0.1, 0.4 + strength * 0.5), 3.0, true)


func _draw_operation(op: StrategicOperation, scale: float) -> void:
	var center: Vector2 = to_screen(ArrakisAtlas.position(op.region)) + Vector2(0, -34 * scale - 14)
	center.y = maxf(center.y, _origin().y + 14.0)
	var color: Color = OP_COLORS.get(op.kind, Color.WHITE)
	var r: float = 11.0 if op.story else 9.0
	var diamond: PackedVector2Array = PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
	draw_colored_polygon(diamond, color)
	diamond.append(diamond[0])
	draw_polyline(diamond, Color("f6e2a8") if op.id == selected_op else INK, 3.0 if op.id == selected_op else 1.5, true)
	if op.status == StrategicOperation.Status.ORDERED:
		var hero: HeroDefinition = state.hero(op.leader)
		var initial: String = hero.display_name.substr(0, 1) if hero != null else "?"
		draw_string(HudStyle.body_font(700), center + Vector2(-4, 5), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)


func _dotted(from: Vector2, to: Vector2, color: Color) -> void:
	var length: float = from.distance_to(to)
	var step: Vector2 = (to - from) / maxf(length, 1.0)
	var travelled: float = 0.0
	while travelled < length:
		draw_line(from + step * travelled, from + step * minf(travelled + 5.0, length), color, 1.5)
		travelled += 11.0
