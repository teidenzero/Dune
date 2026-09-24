class_name LoreCard
extends CanvasLayer
## A found piece of lore, read: its theme, title and text, and what it gave.
## The world waits while it is open; a click, Space, Enter or Escape closes it.

var entry: Dictionary = {}
var reward_lines: PackedStringArray = []
var first_time: bool = true
var _was_paused: bool = false


static func open(tree: SceneTree, data: Dictionary, lines: PackedStringArray, first: bool) -> LoreCard:
	var card: LoreCard = LoreCard.new()
	card.entry = data
	card.reward_lines = lines
	card.first_time = first
	tree.root.add_child(card)
	return card


func _ready() -> void:
	add_to_group("lore_card")
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = HudStyle.panel_box(Color(0.6, 0.8, 1.0), Color(0.06, 0.06, 0.08, 0.97), 2)
	box.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	var category: String = LoreLibrary.CATEGORY_NAMES.get(entry.get("category", &""), "")
	rows.add_child(HudStyle.label(("LORE  ·  " + category).to_upper(), 15, Color(0.6, 0.8, 1.0), HudStyle.body_font(700)))
	rows.add_child(HudStyle.label(entry.get("title", ""), 32, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	var text: Label = HudStyle.label(entry.get("text", ""), 20, HudStyle.TEXT, HudStyle.body_font(500))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(780, 0)
	rows.add_child(text)
	var footer: String = ("Added to the Codex.   " + "   ·   ".join(reward_lines)) if first_time else "Already in the Codex."
	rows.add_child(HudStyle.label(footer, 16, HudStyle.OK if first_time else HudStyle.MUTED, HudStyle.body_font(600)))
	rows.add_child(HudStyle.label("CLICK OR SPACE TO CLOSE", 13, HudStyle.MUTED))


func _unhandled_input(event: InputEvent) -> void:
	var closes: bool = (event is InputEventKey and event.pressed and not event.is_echo() and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]) \
		or (event is InputEventMouseButton and event.pressed)
	if closes:
		get_viewport().set_input_as_handled()
		close()


func _input(event: InputEvent) -> void:
	# The card sits above everything; nothing underneath gets the click.
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = _was_paused
	queue_free()
