class_name IsoView
extends Node
## The squad scope seen isometrically, Syndicate style. Only the *view* turns:
## the world keeps its top-down coordinates, so physics, AI, navigation, sight
## and every rule run exactly as before. TacticalCamera sets the viewport's
## canvas transform through `BASIS`; this node, made by the camera, stands the
## figures up (drawn upright against the view) and sorts them by depth.
##
## World x runs to the screen's lower right, world y to its lower left, at
## 2:1 like the interiors.

## World -> screen, before zoom and centring.
const BASIS: Transform2D = Transform2D(Vector2(0.7071, 0.35355), Vector2(-0.7071, 0.35355), Vector2.ZERO)
## Children of a unit drawn upright; everything else (shadow, aim marker,
## selection ring, cone) stays painted on the ground.
const UPRIGHT_PARTS: Array[String] = ["Sprite", "Body", "Hood", "Visuals", "NameLabel", "DetectionIndicator"]
## Groups whose members are sorted by depth each frame.
const SORTED_GROUPS: Array[String] = ["player", "allies", "enemies", "fuel_tanks", "worm_machines", "iso_sorted"]
## Actors sit in this band of z; ground art and overlays stay below it.
const DEPTH_BASE: int = 400
const DEPTH_SCALE: float = 0.04

static var active: bool = false


## Undo the view's slant for something that should stand up.
static func upright() -> Transform2D:
	return BASIS.affine_inverse()


## A world direction as it looks on screen.
static func screen_direction(world: Vector2) -> Vector2:
	return BASIS.basis_xform(world) if active else world


## A unit's part by path, wherever it lives: in place, or inside the upright
## holder once the isometric view has stood the figure up.
static func part(unit: Node, path: String) -> Node:
	var found: Node = unit.get_node_or_null(path)
	return found if found != null else unit.get_node_or_null("Upright/" + path)


## Text on the field, drawn straight on screen whatever the view: `anchor`
## is the local point it belongs to, `offset` where the text starts from
## there, in screen pixels (so "above", "centred" mean what they say).
static func draw_text(item: CanvasItem, font: Font, anchor: Vector2, offset: Vector2, text: String, size: int, color: Color, outline: int = 0, outline_color: Color = Color(0, 0, 0, 0.85)) -> void:
	var slanted: bool = active and not _stood_up(item)
	if slanted:
		item.draw_set_transform_matrix(Transform2D(0.0, anchor) * upright())
	var at: Vector2 = offset if slanted else anchor + offset
	if outline > 0:
		item.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	item.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	if slanted:
		item.draw_set_transform_matrix(Transform2D.IDENTITY)


## World units per screen pixel for `item`, in either view.
static func pixel(item: CanvasItem) -> float:
	var scale: float = item.get_canvas_transform().x.length()
	if active:
		scale /= BASIS.x.length()
	return 1.0 / maxf(scale, 0.05)


## Already inside an upright holder: its text needs no second turn.
static func _stood_up(item: Node) -> bool:
	var node: Node = item
	for step in range(4):
		if node == null:
			return false
		if String(node.name) == "Upright":
			return true
		node = node.get_parent()
	return false


static func depth(point: Vector2) -> int:
	return clampi(DEPTH_BASE + int((point.x + point.y) * DEPTH_SCALE), 110, 3000)


## Heights of the raised blocks: the yard's walls, and everything else.
const WALL_HEIGHT: float = 110.0
const COVER_HEIGHT: float = 64.0


func _ready() -> void:
	name = "IsoView"
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_raise_blocks")


## Walls and cover (a body with a Slab) stand up as blocks. Rocks already have
## their painted art; the map's boundary has no Slab and stays invisible.
func _raise_blocks() -> void:
	var scene: Node = get_parent()
	for node: Node in scene.find_children("*", "StaticBody2D", true, false):
		var body: StaticBody2D = node as StaticBody2D
		if body.has_node("RockArt") or not body.has_node("Slab"):
			continue
		var wall: bool = body.get_parent() != null and String(body.get_parent().name) == "Walls"
		IsoBlock.raise(body, WALL_HEIGHT if wall else COVER_HEIGHT)


func _exit_tree() -> void:
	active = false


func _process(delta: float) -> void:
	_fade_blocks(delta)
	for group in SORTED_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group):
			var item: Node2D = node as Node2D
			if item == null:
				continue
			if not item.has_meta("iso_upright"):
				stand_up(item)
			item.z_index = depth(item.global_position)


## A block standing in front of Paul or a Fremen turns see-through, as in the
## interiors: nobody of the squad is ever lost behind a wall.
func _fade_blocks(delta: float) -> void:
	var squad: Array[Node2D] = []
	for group in ["player", "allies"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var unit: Node2D = node as Node2D
			var health: HealthComponent = HealthComponent.find_on(unit) if unit != null else null
			if unit != null and (health == null or not health.is_dead):
				squad.append(unit)
	# Active markers too: a wall must never hide where the lesson points.
	var markers: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group("tutorial_markers"):
		if node.get("active") == true:
			markers.append(node as Node2D)
	for node: Node in get_tree().get_nodes_in_group("iso_blocks"):
		var block: IsoBlock = node as IsoBlock
		var hides: bool = false
		for unit in squad:
			if block.covers(unit.global_position):
				hides = true
				break
		if not hides:
			for marker in markers:
				if block.covers(marker.global_position) or block.covers(marker.global_position, TutorialMarker.BEACON):
					hides = true
					break
		var target: float = IsoBlock.FADED if hides else 1.0
		if not is_equal_approx(block.fade, target):
			block.fade = move_toward(block.fade, target, delta * 4.0)


## Wraps a unit's figure in an upright holder, once. A figure drawn off the
## unit's origin (a rock's art over its footprint) gets a holder of its own
## there, so its place is still read on the ground.
static func stand_up(unit: Node2D) -> void:
	unit.set_meta("iso_upright", true)
	var parts: Array[CanvasItem] = []
	for part_name in UPRIGHT_PARTS:
		var part: CanvasItem = unit.get_node_or_null(part_name) as CanvasItem
		if part != null:
			parts.append(part)
	for child in unit.get_children():
		if child is UnitSprite and not parts.has(child):
			parts.append(child)
	if not parts.is_empty():
		var holder: Node2D = Node2D.new()
		holder.name = "Upright"
		holder.transform = upright()
		unit.add_child(holder)
		unit.move_child(holder, parts[0].get_index())
		for part in parts:
			part.reparent(holder, false)
	var rock: Sprite2D = unit.get_node_or_null("RockArt") as Sprite2D
	if rock != null:
		var stand: Node2D = Node2D.new()
		stand.name = "RockUpright"
		stand.position = rock.position
		unit.add_child(stand)
		var art_scale: Vector2 = rock.scale
		rock.reparent(stand, false)
		rock.transform = upright().scaled_local(art_scale)
		rock.position = Vector2.ZERO
