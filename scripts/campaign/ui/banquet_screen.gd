class_name BanquetScreen
extends Control
## 1.2 The Banquet on screen: the guests along the table, the table's
## composure, Jessica's readings and Paul's glimpses, and below, the evening
## itself - each guest's line, the replies, how it lands. Every reply shows
## what is certain; how the guest takes it shows only once it is known.
## At the end Thufir's note, then the results, in plain words.

const MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
const SCENE: String = "res://scenes/campaign/banquet.tscn"

## Set before the screen is ready to fix the hidden agendas (tests).
var seed_value: int = -1
var banquet: Banquet
var _briefed: bool = false
var _applied: bool = false
var _composure: Label
var _stock: Label
var _cards: Dictionary = {}
var _panel: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: DuneBackdrop = DuneBackdrop.new()
	backdrop.dim = 0.55
	add_child(backdrop)
	var painting: Texture2D = ArtLibrary.story("banquet")
	if painting != null:
		var image: TextureRect = TextureRect.new()
		image.texture = painting
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.modulate = Color(0.45, 0.42, 0.4)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
	var campaign: CampaignState = Progression.campaign_of(self)
	var extra: int = campaign.hero_progress(&"paul").prescience_bonus() if campaign != null else 0
	banquet = Banquet.create(seed_value if seed_value >= 0 else int(Time.get_ticks_usec()), extra)
	_build()
	_refresh()


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	margin.add_child(rows)
	var top: HBoxContainer = HBoxContainer.new()
	rows.add_child(top)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	titles.add_child(HudStyle.label("ACT I  ·  1.2", 15, HudStyle.SAND_DIM, HudStyle.body_font(700)))
	titles.add_child(HudStyle.label("THE BANQUET", 44, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	titles.add_child(HudStyle.label("The Lady Jessica's dinner for the notables of Arrakeen", 16, HudStyle.SAND))
	var gauges: VBoxContainer = VBoxContainer.new()
	gauges.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(gauges)
	_composure = HudStyle.label("", 22, HudStyle.GOLD_LIGHT, HudStyle.body_font(700))
	_composure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gauges.add_child(_composure)
	_stock = HudStyle.label("", 16, HudStyle.SPICE_BLUE, HudStyle.body_font(600))
	_stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gauges.add_child(_stock)
	var table: HBoxContainer = HBoxContainer.new()
	table.add_theme_constant_override("separation", 14)
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(table)
	for guest in BanquetScript.GUESTS:
		var card: Dictionary = _make_card(guest)
		table.add_child(card.root)
		_cards[guest.id] = card
	var talk: PanelContainer = PanelContainer.new()
	talk.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD, Color(HudStyle.PANEL, 0.94), 2)
	box.set_content_margin_all(24)
	talk.add_theme_stylebox_override("panel", box)
	rows.add_child(talk)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	talk.add_child(scroll)
	_panel = VBoxContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_theme_constant_override("separation", 12)
	scroll.add_child(_panel)


func _make_card(guest: Dictionary) -> Dictionary:
	var root: PanelContainer = PanelContainer.new()
	root.custom_minimum_size = Vector2(330, 0)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	root.add_child(rows)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	rows.add_child(head)
	var picture: Texture2D = ArtLibrary.portrait(guest.portrait) if guest.portrait != "" else null
	if picture != null:
		var image: TextureRect = TextureRect.new()
		image.texture = picture
		image.custom_minimum_size = Vector2(72, 72)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		head.add_child(image)
	else:
		# Until the portrait arrives: initials in a ring.
		var letters: String = ""
		for word in String(guest.name).split(" ", false):
			letters += word.left(1)
		var initials: Label = HudStyle.label(letters, 26, HudStyle.GOLD_LIGHT, HudStyle.display_font())
		initials.custom_minimum_size = Vector2(72, 72)
		initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(initials)
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(HudStyle.label(guest.name.to_upper(), 18, HudStyle.TEXT, HudStyle.body_font(700)))
	var title: Label = HudStyle.label(guest.title, 13, HudStyle.SAND_DIM, HudStyle.body_font(500))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(title)
	var standing: Label = HudStyle.label("", 13, HudStyle.MUTED, HudStyle.body_font(600))
	names.add_child(standing)
	var agenda: Label = HudStyle.label("", 14, HudStyle.SPICE_BLUE, HudStyle.body_font(500))
	agenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	agenda.custom_minimum_size = Vector2(300, 58)
	rows.add_child(agenda)
	var read: Button = _button("READ HIM  ·  Jessica", func() -> void: _read(guest.id))
	rows.add_child(read)
	return {"root": root, "standing": standing, "agenda": agenda, "read": read, "faction": guest.faction}


func _refresh() -> void:
	var pips: String = ""
	for index in range(BanquetScript.MAX_COMPOSURE):
		pips += "◆ " if index < banquet.composure else "◇ "
	_composure.text = "THE TABLE   " + pips.strip_edges()
	_composure.add_theme_color_override("font_color", HudStyle.DANGER if banquet.composure <= 2 else HudStyle.GOLD_LIGHT)
	_stock.text = "Jessica's readings: %d   ·   Paul's glimpses: %d" % [banquet.readings_left, banquet.glimpses_left]
	var campaign: CampaignState = Progression.campaign_of(self)
	for guest_id: StringName in _cards:
		var card: Dictionary = _cards[guest_id]
		var current: bool = _briefed and banquet.phase == Banquet.Phase.COURSE and banquet.current_guest() == guest_id
		var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD if current else HudStyle.LINE, Color(HudStyle.PANEL, 0.92), 2 if current else 1)
		box.set_content_margin_all(14)
		card.root.add_theme_stylebox_override("panel", box)
		if campaign != null:
			card.standing.text = "%s: %s" % [CampaignState.FACTION_NAMES.get(card.faction, ""), campaign.standing_name(card.faction)]
		var known: String = banquet.agenda_text(guest_id)
		card.agenda.text = known if known != "" else "? ? ?   What does he want?"
		card.agenda.add_theme_color_override("font_color", HudStyle.DANGER if banquet.agendas.get(guest_id) == &"informant" and known != "" else (HudStyle.SPICE_BLUE if known != "" else HudStyle.SAND_DIM))
		card.read.disabled = banquet.readings_left <= 0 or banquet.revealed.has(guest_id) or banquet.phase == Banquet.Phase.DONE
		card.read.text = "READ" if not banquet.revealed.has(guest_id) else "READ ✓"
	_show_panel()


func _show_panel() -> void:
	for child in _panel.get_children():
		child.queue_free()
	if not _briefed:
		_speech("JESSICA", "Five guests, Paul, and every one of them wants something from us - some of them more than they will say. Watch them. I can read two of them for you tonight; your own gift may show you a little of what is coming. And keep the table easy: if it turns cold, your father will end the evening, and we will have learned nothing.")
		_panel.add_child(_button("BEGIN THE DINNER", func() -> void:
			_briefed = true
			_refresh()))
		return
	match banquet.phase:
		Banquet.Phase.COURSE:
			_show_course()
		Banquet.Phase.REACTION:
			var guest: Dictionary = BanquetScript.guest(banquet.current_guest())
			_panel.add_child(HudStyle.label(guest.name.to_upper(), 15, HudStyle.SAND_DIM, HudStyle.body_font(700)))
			var line: Label = HudStyle.label(banquet.last_reaction if banquet.last_reaction != "" else "The moment passes.", 20, HudStyle.TEXT, HudStyle.body_font(500))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_panel.add_child(line)
			_panel.add_child(_button("CONTINUE", func() -> void:
				banquet.next()
				_refresh()))
		Banquet.Phase.ACCUSE:
			_speech("THUFIR (a note under the Duke's plate)", "Someone at this table was bought by the Harkonnen. If you know who, name him to me - quietly. If you are not sure, name no one: an innocent man accused is an enemy made.")
			for guest in BanquetScript.GUESTS:
				var id: StringName = guest.id
				_panel.add_child(_button("Name %s" % guest.name, func() -> void:
					banquet.accuse(id)
					_close()))
			_panel.add_child(_button("Say nothing", func() -> void:
				banquet.accuse(&"")
				_close()))
		Banquet.Phase.DONE:
			_show_results()


func _show_course() -> void:
	var course: Dictionary = banquet.current_course()
	var guest: Dictionary = BanquetScript.guest(course.guest)
	_panel.add_child(HudStyle.label("%s   ·   %s" % [course.course.to_upper(), guest.name.to_upper()], 15, HudStyle.SAND_DIM, HudStyle.body_font(700)))
	var line: Label = HudStyle.label("\"%s\"" % course.line, 21, HudStyle.TEXT, HudStyle.body_font(500))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(line)
	for index in range(course.replies.size()):
		var reply: Dictionary = course.replies[index]
		var seen: Dictionary = banquet.preview(index)
		var text: String = "%d   %s:  %s\n        %s" % [index + 1, reply.speaker, reply.text, Banquet.describe(seen.effects)]
		if seen.known:
			text += "\n        He takes it: " + (seen.line if seen.line != "" else "without a sign.")
		else:
			text += "\n        How he takes it: unknown"
		var choice: int = index
		_panel.add_child(_button(text, func() -> void:
			banquet.choose(choice)
			_refresh(), true))
	if not banquet.knows_reactions():
		var glimpse: Button = _button("GLIMPSE HOW HE WILL TAKE IT  ·  Paul's prescience", func() -> void:
			if banquet.glimpse():
				_refresh())
		glimpse.disabled = banquet.glimpses_left <= 0
		_panel.add_child(glimpse)


func _read(guest_id: StringName) -> void:
	if banquet.read(guest_id):
		_refresh()


func _close() -> void:
	if not _applied:
		_applied = true
		var campaign: CampaignState = Progression.campaign_of(self)
		if campaign != null:
			campaign.apply(banquet.outcome())
	_refresh()


func _show_results() -> void:
	var outcome: MissionOutcome = banquet.outcome()
	_panel.add_child(HudStyle.label("THE EVENING, AFTERWARDS   ·   %s" % outcome.tier_title(), 18, HudStyle.GOLD_LIGHT, HudStyle.body_font(700)))
	var lines: PackedStringArray = []
	var changes: String = Banquet.describe({"standings": outcome.standings, "resources": outcome.resources})
	lines.append("Standing and stores: " + changes)
	if outcome.heat > 0:
		lines.append("The Baron heard more than he should have.")
	elif outcome.heat < 0:
		lines.append("The Baron's ears in Arrakeen are closed.")
	if outcome.flags.has("kynes_trusts"):
		lines.append("Kynes leaves convinced: this House may be different. He will remember it.")
	elif outcome.flags.has("kynes_doubts"):
		lines.append("Kynes leaves unconvinced. To him the Atreides are one more House come for the spice.")
	else:
		lines.append("Kynes leaves undecided. He will be watching.")
	if outcome.flags.has("smugglers_channel"):
		lines.append("The smugglers have a way to reach Gurney.")
	for entry in banquet.record:
		if entry.begins_with("Jessica read") or entry.contains("named") or entry.contains("accused") or entry.contains("early"):
			lines.append(entry)
	var text: Label = HudStyle.label("\n".join(lines), 18, HudStyle.TEXT, HudStyle.body_font(500))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(text)
	_panel.add_child(_button("CONTINUE", _leave))


func _leave() -> void:
	var game: Node = get_node_or_null("/root/GameManager")
	if game != null and game.get("flow") != null and game.flow.playing(SCENE):
		game.flow.advance(get_tree())
		return
	get_tree().change_scene_to_file(MAIN_MENU)


func _speech(speaker: String, text: String) -> void:
	_panel.add_child(HudStyle.label(speaker, 15, HudStyle.SPICE_BLUE, HudStyle.body_font(700)))
	var line: Label = HudStyle.label(text, 20, HudStyle.TEXT, HudStyle.body_font(500))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(line)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()) or banquet.phase != Banquet.Phase.COURSE or not _briefed:
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if index >= 0 and index < banquet.current_course().replies.size():
		banquet.choose(index)
		_refresh()
		get_viewport().set_input_as_handled()


func _button(text: String, action: Callable, reply: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_override("font", HudStyle.body_font(600 if reply else 700))
	button.add_theme_font_size_override("font_size", 17 if reply else 16)
	button.add_theme_color_override("font_color", HudStyle.TEXT)
	button.add_theme_color_override("font_hover_color", HudStyle.GOLD_LIGHT)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD if key == "hover" else HudStyle.LINE, HudStyle.PANEL_2, 1)
		box.set_content_margin_all(12)
		box.shadow_size = 0
		button.add_theme_stylebox_override(key, box)
	button.pressed.connect(action)
	return button
