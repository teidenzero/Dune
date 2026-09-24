class_name TurnGridOverlay
extends Node2D
## The deck in a fight: the tiles the hero can still reach this turn, the
## path to the one under the mouse with its cost, and a ring of colour under
## everyone in the fight - gold for whoever is acting, red for Harkonnen who
## know he is there, amber for those who do not yet.

var combat: TurnCombat
var level: IsoLevel


func _ready() -> void:
	z_index = -8


func _process(_delta: float) -> void:
	visible = combat != null and combat.active()
	if visible:
		queue_redraw()


func _draw() -> void:
	var player: PlayerController = combat.player
	var diamond: PackedVector2Array = IsoMath.diamond(0.9)
	if combat.phase == TurnCombat.Phase.PLAYER:
		var reach: Dictionary = combat.reachable()
		var tint: Color = Color(0.45, 0.85, 1.0, 0.10) if not combat.in_vision else Color(0.55, 0.7, 1.0, 0.16)
		for cell: Vector2i in reach:
			_diamond(IsoMath.cell_to_world(cell), diamond, tint, Color(0.45, 0.85, 1.0, 0.22), 1.0)
		var mouse: Vector2 = get_global_mouse_position()
		if combat.distract_armed:
			_draw_throw(mouse)
		elif combat.target_at(mouse) == null:
			var plan: Dictionary = combat.preview_move(IsoMath.world_to_cell(mouse))
			var route: Array = plan.path
			var color: Color = Color(0.95, 0.85, 0.5) if plan.ok else Color(1.0, 0.45, 0.35)
			var previous: Vector2 = player.global_position
			for cell: Vector2i in route:
				var point: Vector2 = IsoMath.cell_to_world(cell)
				draw_line(previous, point, Color(color, 0.7), 3.0, true)
				draw_circle(point, 5.0, color)
				previous = point
			if not route.is_empty():
				_diamond(previous, diamond, Color(color, 0.18), color, 2.0)
				_label(previous + Vector2(0, -16), "%d AP" % plan.cost, color)
	for enemy in combat._living_enemies():
		var ring: Color = Color(1.0, 0.4, 0.3) if combat.aware.has(enemy) else Color(1.0, 0.75, 0.3, 0.6)
		if combat.acting == enemy:
			ring = Color(1.0, 0.85, 0.4)
		_diamond(enemy.global_position, IsoMath.diamond(0.6), Color(ring, 0.18), ring, 2.0)
	var hero_ring: Color = Color(1.0, 0.85, 0.4) if combat.acting == player else Color(0.55, 0.95, 0.75)
	_diamond(player.global_position, IsoMath.diamond(0.6), Color(hero_ring, 0.2), hero_ring, 2.0)


## Where the stone would land, how far it carries, and who would turn.
func _draw_throw(mouse: Vector2) -> void:
	var plan: Dictionary = combat.preview_distract(IsoMath.world_to_cell(mouse))
	var color: Color = Color(1.0, 0.85, 0.45) if plan.ok else Color(1.0, 0.45, 0.35)
	var at: Vector2 = plan.at
	draw_line(combat.player.global_position, at, Color(color, 0.5), 2.0, true)
	var hearing: float = TurnRules.DISTRACT_HEARING_TILES * TurnRules.TILE_DISTANCE
	draw_arc(at, hearing, 0, TAU, 48, Color(color, 0.45), 2.0, true)
	_diamond(at, IsoMath.diamond(0.7), Color(color, 0.25), color, 2.0)
	for enemy: EnemyCharacter in plan.listeners:
		draw_line(enemy.global_position, at, Color(color, 0.35), 1.5, true)
		_label(enemy.global_position + Vector2(0, -62), "TURNS", color)
	_label(at + Vector2(0, -16), "%d AP" % TurnRules.DISTRACT_COST if plan.in_range else "TOO FAR", color)


func _diamond(at: Vector2, shape: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point in shape:
		points.append(at + point)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, edge, width, true)


func _label(at: Vector2, text: String, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var size: int = WorldLabel.font_size(self, 15)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.05, 0.04, 0.03))
	draw_string(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
