class_name IsoTileCursor
extends Node2D
## The tile under the mouse, outlined on the deck, and the tile the hero is
## walking to. It tells the player exactly where a click will send him, and
## says so in red when the tile is a wall.

var level: IsoLevel
var _hover: Vector2i = Vector2i(-999, -999)
var _hover_ok: bool = false
var _target: Vector2 = Vector2.INF


func _ready() -> void:
	# On the floor, under everything that stands on it.
	z_index = -9
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var player: PlayerController = level.player if level != null else null
	if player == null or player.control_mode != PlayerController.ControlMode.COMMANDED or player.health.is_dead or player.turn_based:
		if visible:
			hide()
		return
	show()
	var cell: Vector2i = IsoMath.world_to_cell(get_global_mouse_position())
	var ok: bool = not level.is_wall(cell) and cell.x >= 0 and cell.y >= 0 and cell.x < level.size.x and cell.y < level.size.y
	var target: Vector2 = player.destination if player.order == PlayerController.Order.MOVE else Vector2.INF
	if cell != _hover or ok != _hover_ok or target != _target:
		_hover = cell
		_hover_ok = ok
		_target = target
		queue_redraw()


func _draw() -> void:
	var diamond: PackedVector2Array = IsoMath.diamond(0.92)
	if _target.is_finite():
		var points: PackedVector2Array = PackedVector2Array()
		for point in diamond:
			points.append(_target + point)
		draw_colored_polygon(points, Color(0.5, 1.0, 0.95, 0.12))
		points.append(points[0])
		draw_polyline(points, Color(0.5, 1.0, 0.95, 0.55), 2.0, true)
	var origin: Vector2 = IsoMath.cell_to_world(_hover)
	var outline: PackedVector2Array = PackedVector2Array()
	for point in diamond:
		outline.append(origin + point)
	outline.append(outline[0])
	draw_polyline(outline, Color(0.95, 0.85, 0.55, 0.8) if _hover_ok else Color(1.0, 0.4, 0.3, 0.45), 2.0, true)
