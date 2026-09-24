class_name IsoLevel
extends Node2D
## An isometric interior built from a text layout, one character per grid
## cell. This node is the y-sorted world: walls, doors, props and characters
## are all sorted by their feet, and the floor is drawn underneath.
##
##   #  wall          .  floor          D  door (slides open for anyone)
##   L  locked door   T  fuel tank      P  hero start
## Any other character is floor with a mark on it, collected in `marks` for
## the mission controller to place its own things (consoles, guards, hatches).
##
## Walls between the camera and the hero fade, so he is never lost behind one.

const FUEL_TANK: PackedScene = preload("res://scenes/environment/fuel_tank.tscn")
const FADED: float = 0.26

@export_multiline var layout: String = ""
@export var player: PlayerController
@export var navigation: NavigationRegion2D

var walls: Array[IsoWall] = []
var doors: Array[IsoDoor] = []
var tanks: Array[FuelTank] = []
var marks: Dictionary = {}
var floor_cells: Array[Vector2i] = []
var size: Vector2i = Vector2i.ZERO
var player_start: Vector2 = Vector2.ZERO

var floor_layer: IsoFloor
var cursor: IsoTileCursor
var wall_root: Node2D
var prop_root: Node2D
var _wall_cells: Dictionary = {}
var _faders: Array[Node2D] = []


var built: bool = false


## A level with its layout set in the scene builds itself; a mission
## controller that supplies the layout calls build() from its own _ready.
func _ready() -> void:
	y_sort_enabled = true
	add_to_group("iso_level")
	if layout.strip_edges() != "":
		build()


func build() -> void:
	if built:
		return
	built = true
	floor_layer = IsoFloor.new()
	floor_layer.name = "Floor"
	add_child(floor_layer)
	cursor = IsoTileCursor.new()
	cursor.name = "TileCursor"
	cursor.level = self
	add_child(cursor)
	wall_root = Node2D.new()
	wall_root.name = "Walls"
	wall_root.y_sort_enabled = true
	# Baked into the navigation mesh; doors are not, so paths run through them.
	wall_root.add_to_group("navigation_geometry")
	add_child(wall_root)
	prop_root = Node2D.new()
	prop_root.name = "Props"
	prop_root.y_sort_enabled = true
	add_child(prop_root)
	var rows: PackedStringArray = layout.strip_edges().split("\n")
	for y in rows.size():
		var row: String = rows[y].strip_edges()
		size.x = maxi(size.x, row.length())
		for x in row.length():
			if row[x] == "#":
				_wall_cells[Vector2i(x, y)] = true
	size.y = rows.size()
	for y in rows.size():
		var row: String = rows[y].strip_edges()
		for x in row.length():
			_place(row[x], Vector2i(x, y))
	floor_layer.cells = floor_cells
	floor_layer.queue_redraw()
	if navigation != null and navigation.get("walkable_rect") != null:
		navigation.set("walkable_rect", bounds().grow(-8.0))
	_frame_camera()


func _place(symbol: String, cell: Vector2i) -> void:
	var at: Vector2 = IsoMath.cell_to_world(cell)
	match symbol:
		"#":
			var wall: IsoWall = IsoWall.new()
			wall.name = "Wall_%d_%d" % [cell.x, cell.y]
			wall.position = at
			wall_root.add_child(wall)
			walls.append(wall)
			_faders.append(wall)
			# Deck under the wall too, so a faded wall is not a hole.
		"D", "L":
			var door: IsoDoor = IsoDoor.new()
			door.locked = symbol == "L"
			door.name = "Door_%d_%d" % [cell.x, cell.y]
			door.position = at
			# The wall line runs through the neighbours that are walls.
			door.along_x = _wall_cells.has(cell + Vector2i(1, 0)) or _wall_cells.has(cell - Vector2i(1, 0))
			prop_root.add_child(door)
			doors.append(door)
			_faders.append(door)
		"T":
			var tank: FuelTank = FUEL_TANK.instantiate() as FuelTank
			tank.name = "Tank_%d_%d" % [cell.x, cell.y]
			tank.position = at
			prop_root.add_child(tank)
			tanks.append(tank)
		"P":
			player_start = at
			if is_instance_valid(player):
				player.global_position = at
		".", " ":
			pass
		_:
			if not marks.has(symbol):
				marks[symbol] = []
			(marks[symbol] as Array).append(cell)
	floor_cells.append(cell)


func door_at(cell: Vector2i) -> IsoDoor:
	for door in doors:
		if IsoMath.world_to_cell(door.position) == cell:
			return door
	return null


## World position of the first cell carrying `symbol`.
func mark(symbol: String) -> Vector2:
	var cells: Array = marks.get(symbol, [])
	return IsoMath.cell_to_world(cells[0]) if not cells.is_empty() else Vector2.ZERO


func has_mark(symbol: String) -> bool:
	return not (marks.get(symbol, []) as Array).is_empty()


func is_wall(cell: Vector2i) -> bool:
	return _wall_cells.has(cell)


## A wall, or a door that is locked.
func is_blocked(cell: Vector2i) -> bool:
	if _wall_cells.has(cell):
		return true
	var door: IsoDoor = door_at(cell)
	return door != null and door.locked


## Tint a block of cells (a room) so it reads apart from its neighbours.
func stain(area: Rect2i) -> void:
	for cell in floor_cells:
		if area.has_point(cell):
			floor_layer.stained[cell] = true
	floor_layer.queue_redraw()


func add_prop(prop: Node2D, cell: Vector2i) -> void:
	prop.position = IsoMath.cell_to_world(cell)
	prop_root.add_child(prop)
	if prop is IsoProp:
		_faders.append(prop)


## Screen-space rectangle around every cell.
func bounds() -> Rect2:
	var corners: Array[Vector2] = [
		IsoMath.cell_to_world(Vector2i(0, 0)), IsoMath.cell_to_world(Vector2i(size.x - 1, 0)),
		IsoMath.cell_to_world(Vector2i(0, size.y - 1)), IsoMath.cell_to_world(size - Vector2i.ONE)]
	var rect: Rect2 = Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		rect = rect.expand(corner)
	return rect.grow_individual(IsoMath.TILE_W * 0.5, IsoMath.TILE_H * 0.5 + 90.0, IsoMath.TILE_W * 0.5, IsoMath.TILE_H * 0.5)


func _frame_camera() -> void:
	if not is_instance_valid(player):
		return
	var camera: Camera2D = player.get_node_or_null("TacticalCamera") as Camera2D
	if camera == null:
		return
	var rect: Rect2 = bounds().grow(260.0)
	camera.limit_left = floori(rect.position.x)
	camera.limit_top = floori(rect.position.y)
	camera.limit_right = ceili(rect.end.x)
	camera.limit_bottom = ceili(rect.end.y)


## Whatever stands between the camera and the hero goes see-through: anything
## drawn over him (lower on screen) whose raised block would cover him.
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var feet: Vector2 = player.global_position
	for node in _faders:
		var offset: Vector2 = node.global_position - feet
		var covers: bool = offset.y > 2.0 and offset.y < 150.0 and absf(offset.x) < IsoMath.TILE_W * 0.5 + 40.0 - offset.y * 0.25
		var target: float = FADED if covers else 1.0
		var current: float = node.get("fade")
		if not is_equal_approx(current, target):
			node.set("fade", move_toward(current, target, delta * 4.0))
