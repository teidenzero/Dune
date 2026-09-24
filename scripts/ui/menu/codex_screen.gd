class_name CodexScreen
extends Control
## The Codex: every piece of lore found so far, by theme. Found entries can be
## read again; unfound ones show only where they wait. Also the hero's growth
## at a glance.

const MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"

var _list: VBoxContainer
var _reader: VBoxContainer
var _title: Label
var _text: Label
var _where: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: DuneBackdrop = DuneBackdrop.new()
	backdrop.dim = 0.7
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60 if side in ["left", "right"] else 40)
	add_child(margin)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	margin.add_child(rows)
	var campaign: CampaignState = Progression.campaign_of(self)
	var found: int = campaign.codex.size() if campaign != null else 0
	rows.add_child(HudStyle.label("THE CODEX", 44, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	rows.add_child(HudStyle.label("%d of %d pieces of lore found   ·   %s" % [found, LoreLibrary.ENTRIES.size(), _growth_line(campaign)], 16, HudStyle.SAND))
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 40)
	rows.add_child(columns)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_reader = VBoxContainer.new()
	_reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader.add_theme_constant_override("separation", 14)
	columns.add_child(_reader)
	_title = HudStyle.label("", 32, HudStyle.GOLD_LIGHT, HudStyle.display_font())
	_reader.add_child(_title)
	_where = HudStyle.label("", 15, Color(0.6, 0.8, 1.0), HudStyle.body_font(600))
	_reader.add_child(_where)
	_text = HudStyle.label("Choose an entry.", 20, HudStyle.TEXT, HudStyle.body_font(500))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(700, 0)
	_reader.add_child(_text)
	for category in LoreLibrary.CATEGORIES:
		var ids: Array[StringName] = LoreLibrary.in_category(category)
		if ids.is_empty():
			continue
		_list.add_child(HudStyle.caption(LoreLibrary.CATEGORY_NAMES[category].to_upper()))
		for id in ids:
			var known: bool = campaign != null and campaign.codex.has(id)
			var entry: Dictionary = LoreLibrary.entry(id)
			var button: Button = _button(entry.title if known else "? ? ?", show_entry.bind(id))
			button.disabled = false
			if not known:
				button.add_theme_color_override("font_color", HudStyle.SAND_DIM)
			_list.add_child(button)
	var back: Button = _button("BACK", func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	rows.add_child(back)


func show_entry(id: StringName) -> void:
	var campaign: CampaignState = Progression.campaign_of(self)
	var entry: Dictionary = LoreLibrary.entry(id)
	var known: bool = campaign != null and campaign.codex.has(id)
	_title.text = entry.title if known else "Not yet found"
	_where.text = LoreLibrary.CATEGORY_NAMES.get(entry.category, "").to_upper() + "   ·   " + entry.get("where", "")
	_text.text = entry.text if known else "Somewhere in %s, for those who look into corners." % String(entry.get("where", "the world")).to_lower()


func _growth_line(campaign: CampaignState) -> String:
	if campaign == null:
		return ""
	var paul: HeroProgress = campaign.hero_progress(&"paul")
	return "Paul: Blade %d  ·  Firearms %d  ·  Desert craft %d  ·  Prescience +%d  ·  Spice doses %d" % [
		paul.rank(&"blade"), paul.rank(&"firearms"), paul.rank(&"desert_craft"), paul.prescience_bonus(), campaign.item_count(&"spice_dose")]


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", HudStyle.body_font(600))
	button.add_theme_font_size_override("font_size", 17)
	for key in ["normal", "hover", "pressed"]:
		var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD if key != "normal" else HudStyle.LINE, HudStyle.PANEL_2, 1)
		box.set_content_margin_all(10)
		box.shadow_size = 0
		button.add_theme_stylebox_override(key, box)
	button.pressed.connect(action)
	return button
