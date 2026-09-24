class_name FindPoint
extends Node2D
## Something worth finding, placed in a level: lore (a page, a note, a ring)
## or a cache (spice, water, Solari). Right-click it - the hero walks over and
## picks it up. Lore opens a card and goes into the Codex, paying its small
## reward the first time only; a cache pays every time and is gone.

enum Kind { LORE, CACHE }

var kind: Kind = Kind.LORE
var id: StringName = &""
var hero: StringName = &"paul"
var point: InteractionPoint
var taken: bool = false
var _time: float = 0.0


## Put finds into an interior. Each entry is {"lore"|"cache": id, "cell": Vector2i}.
static func place_all(level: IsoLevel, finds: Array) -> Array[FindPoint]:
	var placed: Array[FindPoint] = []
	for spec: Dictionary in finds:
		var find: FindPoint = FindPoint.new()
		find.kind = Kind.LORE if spec.has("lore") else Kind.CACHE
		find.id = spec.get("lore", spec.get("cache", &""))
		find.name = "Find_%s" % find.id
		find.position = IsoMath.cell_to_world(spec.cell)
		level.prop_root.add_child(find)
		placed.append(find)
	return placed


func _ready() -> void:
	add_to_group("finds")
	z_index = 1
	point = InteractionPoint.new()
	point.name = "Take"
	point.id = id
	point.label = "READ" if kind == Kind.LORE else "TAKE"
	point.hold_seconds = 0.5
	point.interact_radius = 90.0
	point.collision_layer = 0
	point.collision_mask = 0
	add_child(point)
	point.interaction_completed.connect(func(_id: StringName) -> void: take())


func already_known() -> bool:
	var campaign: CampaignState = Progression.campaign_of(self)
	return kind == Kind.LORE and campaign != null and campaign.codex.has(id)


## Pick it up: reward, Codex, card. Tests and debug call this directly.
func take() -> PackedStringArray:
	if taken:
		return PackedStringArray()
	taken = true
	var campaign: CampaignState = Progression.campaign_of(self)
	var lines: PackedStringArray = []
	if kind == Kind.LORE:
		var entry: Dictionary = LoreLibrary.entry(id)
		var first: bool = campaign != null and not campaign.codex.has(id)
		if first:
			campaign.codex[id] = true
			lines = LoreLibrary.grant(campaign, hero, entry.get("reward", {}))
		LoreCard.open(get_tree(), entry, lines, first)
	else:
		var cache: Dictionary = LoreLibrary.CACHES.get(id, {})
		lines = LoreLibrary.grant(campaign, hero, cache.get("reward", {}))
		CombatFx.float_text(get_parent(), global_position, ", ".join(lines), Color(1.0, 0.75, 0.35))
	point.enabled = false
	if kind == Kind.CACHE:
		queue_free()
	else:
		queue_redraw()
	return lines


func _process(delta: float) -> void:
	_time = fmod(_time + delta, TAU * 10.0)
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 2.4)
	if kind == Kind.LORE:
		# A folded page, glowing faintly so it can be found in the dark.
		var read: bool = taken or already_known()
		var glow: Color = Color(0.55, 0.8, 1.0, (0.15 if read else 0.35) * (0.6 + 0.4 * pulse))
		draw_circle(Vector2(0, -6), 20.0, glow)
		var paper: Color = Color(0.86, 0.8, 0.66) if not read else Color(0.55, 0.52, 0.46)
		draw_colored_polygon(PackedVector2Array([Vector2(-11, -2), Vector2(9, -8), Vector2(12, 2), Vector2(-8, 8)]), paper)
		draw_line(Vector2(-6, 0), Vector2(6, -4), Color(0.4, 0.35, 0.28), 1.0)
		draw_line(Vector2(-4, 3), Vector2(7, -1), Color(0.4, 0.35, 0.28), 1.0)
	else:
		# A small bundle, warm orange.
		draw_circle(Vector2(0, -6), 18.0, Color(1.0, 0.6, 0.25, 0.3 * (0.6 + 0.4 * pulse)))
		draw_rect(Rect2(-9, -10, 18, 13), Color(0.55, 0.36, 0.2))
		draw_rect(Rect2(-9, -10, 18, 13), Color(0.2, 0.12, 0.06), false, 1.5)
		draw_line(Vector2(0, -10), Vector2(0, 3), Color(0.85, 0.7, 0.4), 1.5)
