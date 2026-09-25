class_name BriefingScreen
extends CanvasLayer
## Before a mission: where the story stands, what we know, what must be done,
## and who goes. The intel gives the rules of the place - how the worm hunts,
## how many men one soldier can bring out - never the plan: the fun is in
## deciding HOW. The world waits, paused, until BEGIN (or Enter); I reopens it
## mid-mission, where it pauses again and gives back whatever pause it found.
##
## The party column is the layout for equipment: each unit's weapon and two
## gear slots, and the quartermaster's stock with prices. Requisitions are
## shown but not yet open; they come later in the campaign.

signal closed

## The quartermaster's shelves: layout only, nothing is sold yet.
const STOCK: Array[Dictionary] = [
	{"name": "Thumper", "text": "A Fremen drum-stake. Nothing on the sand is louder.", "cost": "15 Solari"},
	{"name": "Lasgun power cells", "text": "Two spare charges for the squad's rifles.", "cost": "10 Solari"},
	{"name": "Field dressings", "text": "A wounded man walks on his own again.", "cost": "5 Water"},
	{"name": "Paracompass", "text": "True bearings where the magnetic field lies.", "cost": "8 Solari"},
	{"name": "Stillsuit", "text": "Keeps a man's water in him on the open sand.", "cost": "20 Solari"},
]
const GEAR_SLOTS: int = 2

var definition: MissionDefinition
var mission: MissionManager
var scene_path: String = ""
## The briefing before the mission: the pause it finds is its own (the
## mission holds the world for it), so BEGIN always lets the world go.
var opening: bool = false
var _was_paused: bool = false
var _held_bars: Array[CanvasLayer] = []
var _holding: bool = false
var _begin: Button


## Shows the briefing for `mission`'s definition over the current scene.
static func show_for(for_mission: MissionManager, path: String, at_start: bool = false) -> BriefingScreen:
	var screen: BriefingScreen = open(for_mission.definition, for_mission.get_parent(), path, at_start)
	screen.mission = for_mission
	return screen


## The briefing for `for_definition`, over `parent`'s scene.
static func open(for_definition: MissionDefinition, parent: Node, path: String, at_start: bool = false) -> BriefingScreen:
	var screen: BriefingScreen = BriefingScreen.new()
	screen.opening = at_start
	screen.name = "Briefing"
	screen.definition = for_definition
	screen.scene_path = path
	parent.add_child(screen)
	return screen


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("briefing_screen")
	_hold_world()
	_build()


## The world waits, and spoken lines wait with it.
func _hold_world() -> void:
	_was_paused = get_tree().paused and not opening
	get_tree().paused = true
	for node in get_tree().get_nodes_in_group("dialogue_bar"):
		var bar: CanvasLayer = node as CanvasLayer
		if bar != null and bar.process_mode != Node.PROCESS_MODE_DISABLED:
			bar.process_mode = Node.PROCESS_MODE_DISABLED
			bar.visible = false
			_held_bars.append(bar)
	_holding = true


func _release_world() -> void:
	if not _holding:
		return
	_holding = false
	for bar in _held_bars:
		if is_instance_valid(bar):
			bar.process_mode = Node.PROCESS_MODE_ALWAYS
			bar.visible = true
	_held_bars.clear()
	if is_inside_tree():
		get_tree().paused = _was_paused


func close() -> void:
	_release_world()
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	# Never leave the world paused behind a screen that is gone.
	_release_world()


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("show_briefing"):
		get_viewport().set_input_as_handled()
		close()


# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------

func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var image: Texture2D = ArtLibrary.story(definition.briefing_image)
	if image != null:
		var back: TextureRect = TextureRect.new()
		back.texture = image
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.modulate = Color(0.55, 0.55, 0.55)
		root.add_child(back)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.03, 0.02, 0.82 if image != null else 1.0)
	root.add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 72)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	root.add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	if definition.heading != "":
		page.add_child(HudStyle.label(definition.heading, 16, HudStyle.GOLD, HudStyle.body_font(700)))
	page.add_child(HudStyle.label(definition.title.to_upper(), 46, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	if definition.lore != "":
		var lore: Label = _wrapped(definition.lore, 17, HudStyle.SAND)
		lore.custom_minimum_size = Vector2(1100, 0)
		lore.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		page.add_child(lore)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 48)
	page.add_child(columns)
	var left: Control = _left_column()
	columns.add_child(left)
	if definition.show_party:
		columns.add_child(_party_column())
	else:
		# Alone on the page, the text keeps a readable line length.
		left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.custom_minimum_size = Vector2(1180, 0)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(footer)
	var hint: Label = HudStyle.label("I  reopens this briefing at any time", 14, HudStyle.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	_begin = _button("BEGIN   ·   ENTER", close, true)
	footer.add_child(_begin)


func _left_column() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.45
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 11)
	scroll.add_child(column)
	# The situation, in the briefer's voice.
	var voice: HBoxContainer = HBoxContainer.new()
	voice.add_theme_constant_override("separation", 18)
	column.add_child(voice)
	if definition.briefing_speaker != "":
		voice.add_child(_portrait(ArtLibrary.speaker_portrait(definition.briefing_speaker), definition.briefing_speaker, 112))
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voice.add_child(words)
	if definition.briefing_speaker != "":
		words.add_child(HudStyle.label(definition.briefing_speaker, 15, HudStyle.GOLD, HudStyle.body_font(700)))
	words.add_child(_wrapped(definition.briefing, 19, HudStyle.TEXT))
	column.add_child(_caption(definition.objectives_caption if definition.objectives_caption != "" else "OBJECTIVES"))
	# One line each: the objective, then what it means.
	for item in definition.objectives:
		var tag: String = "  (optional)" if item.optional else ""
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var mark: Label = HudStyle.label("◆" if item.primary else "◇", 16, HudStyle.GOLD_LIGHT if item.primary else HudStyle.TEXT)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(mark)
		var lines: VBoxContainer = VBoxContainer.new()
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.add_theme_constant_override("separation", 0)
		row.add_child(lines)
		lines.add_child(_wrapped(item.title + tag, 17, HudStyle.GOLD_LIGHT if item.primary else HudStyle.TEXT))
		if item.description != "":
			lines.add_child(_wrapped(item.description, 15, HudStyle.MUTED))
		column.add_child(row)
	column.add_child(_caption("WHAT WE KNOW"))
	for point in definition.intel_for(scene_path):
		column.add_child(_bullet(point))
	return scroll


## The party and its equipment: the layout the quartermaster will fill.
func _party_column() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.LINE, Color(0.08, 0.07, 0.05, 0.9), 1)
	box.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", box)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_caption("THE PARTY"))
	for unit in party():
		column.add_child(_unit_row(unit))
	column.add_child(_caption("QUARTERMASTER"))
	column.add_child(HudStyle.label(_stores_text(), 14, HudStyle.SAND))
	for item in STOCK:
		column.add_child(_stock_row(item))
	var note: Label = _wrapped("The quartermaster's stores open later in the campaign.", 14, HudStyle.MUTED)
	column.add_child(note)
	return panel


## Who goes: Paul, then the squad as the scene has it.
func party() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var paul: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if paul != null:
		var weapons: PackedStringArray = []
		for weapon in paul.loadout:
			if weapon != null:
				weapons.append(weapon.weapon_name)
		if weapons.is_empty() and paul.weapon_controller != null and paul.weapon_controller.weapon_data != null:
			weapons.append(paul.weapon_controller.weapon_data.weapon_name)
		result.append({"name": "Paul", "portrait": ArtLibrary.portrait("paul"), "weapon": " / ".join(weapons)})
	var squad: SquadManager = get_tree().get_first_node_in_group("squad_manager") as SquadManager
	if squad != null:
		for ally in squad.members:
			if not is_instance_valid(ally) or ally.data == null:
				continue
			var face: Texture2D = ally.data.art.portrait if ally.data.art != null else null
			if face == null:
				face = ArtLibrary.speaker_portrait(ally.data.display_name.split(" ")[0])
			var weapon_name: String = ally.data.weapon_data.weapon_name if ally.data.weapon_data != null else "-"
			result.append({"name": ally.data.display_name, "portrait": face, "weapon": weapon_name})
	return result


func _unit_row(unit: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_portrait(unit.portrait, unit.name, 56))
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(HudStyle.label(String(unit.name).to_upper(), 15, HudStyle.TEXT, HudStyle.body_font(700)))
	var slots: HBoxContainer = HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	right.add_child(slots)
	slots.add_child(_slot(unit.weapon, true))
	for index in range(GEAR_SLOTS):
		slots.add_child(_slot("empty", false))
	return row


func _slot(text: String, filled: bool) -> Control:
	var slot: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD if filled else HudStyle.LINE, HudStyle.PANEL_2 if filled else Color(0, 0, 0, 0.25), 1)
	box.set_content_margin_all(6)
	slot.add_theme_stylebox_override("panel", box)
	slot.custom_minimum_size = Vector2(0 if filled else 70, 28)
	slot.add_child(HudStyle.label(text.to_upper() if filled else "-  GEAR  -", 12, HudStyle.SAND if filled else HudStyle.MUTED))
	return slot


func _stock_row(item: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	words.add_child(HudStyle.label(item.name, 15, HudStyle.TEXT, HudStyle.body_font(700)))
	words.add_child(_wrapped(item.text, 13, HudStyle.MUTED))
	var cost: Label = HudStyle.label(item.cost, 14, HudStyle.GOLD_LIGHT)
	cost.custom_minimum_size = Vector2(84, 0)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost)
	var buy: Button = _button("REQUISITION", func() -> void: pass)
	buy.disabled = true
	buy.tooltip_text = "Not open yet"
	row.add_child(buy)
	return row


func _stores_text() -> String:
	var campaign: CampaignState = Progression.campaign_of(self)
	if campaign == null:
		return ""
	var parts: PackedStringArray = []
	for key in [&"solari", &"water", &"spice"]:
		parts.append("%s %d" % [CampaignState.resource_name(key), int(campaign.resources.get(key, 0))])
	return "HOUSE STORES   " + "   ·   ".join(parts)


# --------------------------------------------------------------------------
# Pieces
# --------------------------------------------------------------------------

func _caption(text: String) -> Label:
	var label: Label = HudStyle.label(text, 14, HudStyle.GOLD, HudStyle.body_font(800))
	label.add_theme_constant_override("outline_size", 0)
	return label


func _wrapped(text: String, size: int, color: Color) -> Label:
	var label: Label = HudStyle.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _bullet(text: String) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var mark: Label = HudStyle.label("·", 20, HudStyle.GOLD)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mark)
	row.add_child(_wrapped(text, 17, HudStyle.TEXT))
	return row


func _indented(control: Control, pixels: int) -> Control:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", pixels)
	margin.add_child(control)
	return margin


func _portrait(texture: Texture2D, who: String, size: int) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = Vector2(size, size)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.LINE, HudStyle.PANEL_2, 1)
	frame.add_theme_stylebox_override("panel", box)
	if texture != null:
		var image: TextureRect = TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(image)
	else:
		var letters: String = ""
		for word in who.split(" ", false):
			letters += word.substr(0, 1)
		var initials: Label = HudStyle.label(letters.substr(0, 2), int(size * 0.34), HudStyle.GOLD_LIGHT, HudStyle.display_font())
		initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(initials)
	return frame


func _button(text: String, action: Callable, main: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", HudStyle.body_font(700))
	button.add_theme_font_size_override("font_size", 18 if main else 12)
	button.add_theme_color_override("font_color", HudStyle.GOLD_LIGHT if main else HudStyle.TEXT)
	button.add_theme_color_override("font_hover_color", HudStyle.GOLD_LIGHT)
	button.add_theme_color_override("font_disabled_color", HudStyle.MUTED)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD if key == "hover" or (main and key == "normal") else HudStyle.LINE, HudStyle.PANEL_2, 1)
		box.set_content_margin_all(14 if main else 8)
		button.add_theme_stylebox_override(key, box)
	button.pressed.connect(action)
	return button
