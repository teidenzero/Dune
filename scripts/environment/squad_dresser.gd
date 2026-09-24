class_name SquadDresser
extends RefCounted
## Dresses a squad map in the painted yard kit (`assets/environment/yard/`),
## once it has loaded: ground textures on the floors and slabs, painted rocks
## over the rock obstacles. Only looks change - every collision shape, terrain
## zone and navigation polygon stays exactly as the map built it. Anything the
## kit has no art for keeps its drawn look.

const ROOT: String = "res://assets/environment/yard/"
## Rock art is drawn this much wider than the footprint it stands on.
const ROCK_SPREAD: float = 1.2


static func texture(name: String) -> Texture2D:
	var path: String = ROOT + name + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func dress(root: Node) -> void:
	if root == null:
		return
	for node: Node in root.find_children("*", "Polygon2D", true, false):
		var polygon: Polygon2D = node as Polygon2D
		var name: String = String(polygon.name)
		var parent: String = String(polygon.get_parent().name)
		if parent == "Floor" and name.begins_with("Floor_"):
			_ground(polygon, "ground_sand" if name == "Floor_desert" else "ground_courtyard")
		elif name == "SandBed" or name == "CombinedSlab" or name.begins_with("SandPatch"):
			_ground(polygon, "ground_sand")
		elif name.begins_with("Slab_") or (parent == "Desert" and name.ends_with("Slab")):
			# The worm-safe rock the player stands on.
			_ground(polygon, "ground_rock_shelf")
	for node: Node in root.find_children("*", "StaticBody2D", true, false):
		var body: StaticBody2D = node as StaticBody2D
		if body.has_node("Base") and body.has_node("TopFace"):
			_rock(body, body.get_node("Base") as Polygon2D, ["Base", "TopFace", "LightFace"])
		elif String(body.name).begins_with("Ridge") and body.has_node("Slab"):
			_rock(body, body.get_node("Slab") as Polygon2D, ["Slab", "Cap"])


## A floor or slab polygon takes a tiled ground texture, keeping a trace of
## its own colour so sections still read apart.
static func _ground(polygon: Polygon2D, art: String) -> void:
	var ground: Texture2D = texture(art)
	if ground == null:
		return
	polygon.texture = ground
	polygon.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	polygon.color = Color.WHITE.lerp(polygon.color, 0.18)


## A rock obstacle's drawn faces give way to painted rock sized to its
## footprint; its shadow and its collision stay.
static func _rock(body: StaticBody2D, footprint: Polygon2D, faces: Array) -> void:
	if footprint == null or footprint.polygon.is_empty() or body.has_node("RockArt"):
		return
	var bounds: Rect2 = Rect2(footprint.position + footprint.polygon[0], Vector2.ZERO)
	for point in footprint.polygon:
		bounds = bounds.expand(footprint.position + point)
	var span: float = maxf(bounds.size.x, bounds.size.y)
	var art: Texture2D = texture("rock_small" if span < 150.0 else ("rock_medium" if span < 280.0 else "rock_large"))
	if art == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "RockArt"
	sprite.texture = art
	var scale: float = bounds.size.x * ROCK_SPREAD / art.get_width()
	sprite.scale = Vector2(scale, scale)
	# Seated on the footprint: the art's lower edge near the footprint's.
	sprite.position = bounds.get_center() - Vector2(0, bounds.size.y * 0.18)
	sprite.z_index = footprint.z_index
	body.add_child(sprite)
	for face: String in faces:
		var drawn: CanvasItem = body.get_node_or_null(face) as CanvasItem
		if drawn != null:
			drawn.visible = false
