class_name CouncilScreen
extends Control
## The campaign's home: where House Atreides weighs the factions of Arrakis and
## chooses how to act. Built in code in the HUD's style.
##
##   COUNCIL    faction standings, Harkonnen heat, resources, missions
##   BRIEFING   a mission's stakes and its scopes (squad / political / solo)
##   OPERATION  a political approach, an agent, Intel to spend, the odds
##   DILEMMA    the approach's trade-off
##   RESULT     the outcome and what it changed
##
## Everything it changes goes through CampaignState.apply(MissionOutcome), the
## same door the squad scope uses.

const MISSIONS: Array[String] = ["res://resources/missions/harvester_raid.tres"]
const SCENE_PATH: String = "res://scenes/campaign/council.tscn"
const LAUNCHER: String = "res://scenes/missions/mission_select.tscn"
const FACTION_NOTES: Dictionary = {
	&"fremen": ["Recruits, desert shelter, worm lore", "Water, respect, war on the Harkonnen"],
	&"guild": ["Transport, extraction, off-world goods", "Spice; hates surprises in the spice flow"],
	&"choam": ["Income, prices, trade contracts", "The spice flowing, whoever controls it"],
	&"bene_gesserit": ["Intelligence, secrets, prescience", "Hidden agendas; favours come due"],
	&"emperor": ["Legitimacy, protection", "Fears whoever grows too strong"],
	&"smugglers": ["Black-market gear, informants", "Solari; a blind eye to their trade"],
}
const TIER_COLORS: Array[Color] = [Color("8fd18a"), Color("eaa53a"), Color("dcc08a"), Color("e0583c")]

var campaign: CampaignState
var definition: MissionDefinition
var approach: PoliticalApproach
var agent: HeroDefinition
var intel_spent: int = 0
var last_outcome: MissionOutcome
## Opened from the map room for a single operation: straight to it, and back
## to the map afterwards.
var home_scene: String = ""
## The prologue's lesson: one matter, the Duke talking Paul through it, and
## the campaign carrying on afterwards.
var lesson_mission: MissionDefinition
var _return_button: Button

signal view_shown(key: String)
## Tests set this to decide the roll; negative means random.
var forced_roll: float = -1.0

var _views: Dictionary = {}
var _resource_row: HBoxContainer
var _approach_buttons: Array[Button] = []
var _agent_buttons: Array[Button] = []
var _odds_label: Label
var _agent_trait: Label
var _intel_label: Label
var _commit_button: Button
var _dilemma_text: Label
var _choice_box: VBoxContainer
var _result_title: Label
var _result_body: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var game: Node = get_node_or_null("/root/GameManager")
	campaign = game.campaign if game != null else CampaignState.new()
	var background: ColorRect = ColorRect.new()
	background.color = HudStyle.GROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 56 if side in ["left", "right"] else 40)
	add_child(margin)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 22)
	margin.add_child(rows)
	rows.add_child(_header())
	_resource_row = HBoxContainer.new()
	_resource_row.add_theme_constant_override("separation", 14)
	rows.add_child(_resource_row)
	var stack: Control = Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(stack)
	_views["council"] = _council_view()
	_views["briefing"] = _briefing_view()
	_views["operation"] = _operation_view()
	_views["dilemma"] = _dilemma_view()
	_views["result"] = _result_view()
	for key in _views:
		var view: Control = _views[key]
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(view)
	show_view("council")
	if game != null and game.get("flow") != null and game.flow.is_lesson():
		lesson_mission = load(game.flow.current().mission) as MissionDefinition
		# The briefing first, before the Duke walks Paul through the table.
		var briefing: MissionBriefing = MissionBriefing.new()
		briefing.name = "BriefingHost"
		briefing.definition = lesson_mission
		briefing.scene_path = SCENE_PATH
		add_child(briefing)
		var lesson: CouncilLesson = CouncilLesson.new()
		lesson.name = "Lesson"
		lesson.council = self
		add_child(lesson)
		_rebuild_council()
	if game != null and game.get("council_focus") != null and game.council_focus != "":
		home_scene = game.council_home
		definition = load(game.council_focus) as MissionDefinition
		game.council_focus = ""
		if definition != null:
			open_operation()


func go_home() -> void:
	get_tree().change_scene_to_file(home_scene)


# --------------------------------------------------------------------------
# Views
# --------------------------------------------------------------------------

func show_view(key: String) -> void:
	for name in _views:
		_views[name].visible = name == key
	_refresh_resources()
	match key:
		"council":
			_rebuild_council()
		"briefing":
			_rebuild_briefing()
		"operation":
			_refresh_operation()
	view_shown.emit(key)


func _header() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_child(HudStyle.label("THE COUNCIL", 40, HudStyle.SAND, HudStyle.display_font()))
	box.add_child(HudStyle.label("Arrakeen  ·  House Atreides weighs the powers of Arrakis", 18, HudStyle.MUTED))
	return box


func _refresh_resources() -> void:
	for child in _resource_row.get_children():
		child.queue_free()
	for key in CampaignState.RESOURCES:
		_resource_row.add_child(_chip("%s  %d" % [CampaignState.resource_name(key).to_upper(), int(campaign.resources[key])], HudStyle.SAND))
	var heat_color: Color = HudStyle.DANGER if campaign.heat >= 6 else HudStyle.GOLD
	_resource_row.add_child(_chip("HARKONNEN HEAT  %d / %d" % [campaign.heat, CampaignState.HEAT_MAX], heat_color))


func _chip(text: String, color: Color) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.LINE, HudStyle.PANEL, 1)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(HudStyle.label(text, 16, color, HudStyle.mono_font()))
	return panel


# --- Council ---------------------------------------------------------------

func _council_view() -> Control:
	var columns: HBoxContainer = HBoxContainer.new()
	columns.name = "Council"
	columns.add_theme_constant_override("separation", 40)
	var left: VBoxContainer = VBoxContainer.new()
	left.name = "Factions"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	var right: VBoxContainer = VBoxContainer.new()
	right.name = "Missions"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	columns.add_child(right)
	return columns


func _rebuild_council() -> void:
	var left: VBoxContainer = _views["council"].get_node("Factions")
	var right: VBoxContainer = _views["council"].get_node("Missions")
	for child in left.get_children() + right.get_children():
		child.queue_free()
	left.add_child(HudStyle.caption("FACTIONS OF ARRAKIS"))
	for faction in CampaignState.FACTIONS:
		left.add_child(_faction_row(faction))
	right.add_child(HudStyle.caption("OPERATIONS"))
	var paths: Array = [lesson_mission.resource_path] if lesson_mission != null else MISSIONS
	for path in paths:
		var mission: MissionDefinition = load(path) as MissionDefinition
		if mission != null:
			right.add_child(_mission_card(mission))
	if not campaign.history.is_empty():
		right.add_child(HudStyle.caption("CHRONICLE"))
		for index in range(campaign.history.size() - 1, maxi(campaign.history.size() - 6, -1), -1):
			var record: MissionOutcome = campaign.history[index]
			var scope: String = MissionOutcome.Scope.keys()[record.scopes[0]] if not record.scopes.is_empty() else "?"
			right.add_child(HudStyle.label("%s  ·  %s  ·  %s" % [String(record.mission_id).capitalize(), record.tier_title(), scope.to_lower()], 16, TIER_COLORS[record.tier]))
	if lesson_mission == null:
		var back: Button = _button("BACK TO LAUNCHER", _on_back_to_launcher)
		right.add_child(back)


func _faction_row(faction: StringName) -> Control:
	var panel: PanelContainer = _panel()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var standing_now: int = campaign.standing(faction)
	var emblem: TextureRect = TextureRect.new()
	emblem.texture = ArtLibrary.emblem(String(faction))
	emblem.custom_minimum_size = Vector2(48, 48)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.self_modulate = HudStyle.OK if standing_now > 0 else (HudStyle.DANGER if standing_now < 0 else HudStyle.SAND)
	row.add_child(emblem)
	var names: VBoxContainer = VBoxContainer.new()
	names.custom_minimum_size = Vector2(250, 0)
	names.add_child(HudStyle.label(CampaignState.faction_name(faction).to_upper(), 20, HudStyle.TEXT, HudStyle.body_font(700)))
	var standing: int = campaign.standing(faction)
	var standing_color: Color = HudStyle.OK if standing > 0 else (HudStyle.DANGER if standing < 0 else HudStyle.MUTED)
	names.add_child(HudStyle.label(campaign.standing_name(faction).to_upper(), 15, standing_color))
	row.add_child(names)
	row.add_child(_standing_pips(standing))
	var notes: VBoxContainer = VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var note: Array = FACTION_NOTES.get(faction, ["", ""])
	notes.add_child(HudStyle.label("Gives: " + note[0], 14, HudStyle.SAND))
	notes.add_child(HudStyle.label("Wants: " + note[1], 14, HudStyle.MUTED))
	row.add_child(notes)
	return panel


## -2..+3 as six cells; neutral sits between the red and the green.
func _standing_pips(standing: int) -> Control:
	var pips: HBoxContainer = HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for value in range(CampaignState.STANDING_MIN, CampaignState.STANDING_MAX + 1):
		var cell: ColorRect = ColorRect.new()
		cell.custom_minimum_size = Vector2(22, 14)
		var lit: bool = (value < 0 and standing <= value) or (value > 0 and standing >= value) or (value == 0 and standing == 0)
		var color: Color = HudStyle.DANGER if value < 0 else (HudStyle.OK if value > 0 else HudStyle.SAND_DIM)
		cell.color = color if lit else Color(color, 0.18)
		pips.add_child(cell)
	return pips


func _mission_card(mission: MissionDefinition) -> Control:
	var panel: PanelContainer = _panel(HudStyle.GOLD)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	rows.add_child(HudStyle.label(mission.title.to_upper(), 24, HudStyle.GOLD_LIGHT, HudStyle.body_font(700)))
	var briefing: Label = HudStyle.label(mission.briefing, 16, HudStyle.TEXT, HudStyle.body_font(500))
	briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing.custom_minimum_size = Vector2(700, 0)
	rows.add_child(briefing)
	rows.add_child(HudStyle.label("At stake: " + CampaignState.faction_name(mission.faction_at_stake), 15, HudStyle.MUTED))
	var last: MissionOutcome = campaign.last_outcome(mission.id)
	if last != null:
		rows.add_child(HudStyle.label("Last time: " + last.tier_title(), 15, TIER_COLORS[last.tier]))
	rows.add_child(_button("BRIEFING", func() -> void: open_briefing(mission)))
	return panel


# --- Briefing ----------------------------------------------------------------

func open_briefing(mission: MissionDefinition) -> void:
	definition = mission
	show_view("briefing")


func _briefing_view() -> Control:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Briefing"
	rows.add_theme_constant_override("separation", 14)
	return rows


func _rebuild_briefing() -> void:
	var rows: VBoxContainer = _views["briefing"]
	for child in rows.get_children():
		child.queue_free()
	if definition == null:
		return
	rows.add_child(HudStyle.label(definition.title.to_upper(), 30, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	var text: Label = HudStyle.label(definition.briefing, 18, HudStyle.TEXT, HudStyle.body_font(500))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(1100, 0)
	rows.add_child(text)
	rows.add_child(HudStyle.caption("WHAT IT MEANS FOR US"))
	for tier in [MissionOutcome.Tier.CLEAN, MissionOutcome.Tier.NOISY, MissionOutcome.Tier.PARTIAL, MissionOutcome.Tier.FAILURE]:
		var line: String = "%s:  %s" % [MissionOutcome.TIER_TITLES[tier], OperationResolver.describe(definition.stakes_for(tier))]
		rows.add_child(HudStyle.label(line, 16, TIER_COLORS[tier]))
	rows.add_child(HudStyle.caption("HOW DO WE ACT?"))
	var scopes: Array[MissionOutcome.Scope] = definition.available_scopes()
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	rows.add_child(buttons)
	var squad: Button = _button("SQUAD  ·  lead the raid yourself", start_squad)
	squad.disabled = not scopes.has(MissionOutcome.Scope.SQUAD)
	buttons.add_child(squad)
	var political: Button = _button("POLITICAL  ·  work the Council", open_operation)
	political.disabled = not scopes.has(MissionOutcome.Scope.POLITICAL)
	buttons.add_child(political)
	var solo: Button = _button("SOLO  ·  one hero, alone" if scopes.has(MissionOutcome.Scope.SOLO) else "SOLO  ·  one hero, alone  (interior coming)", start_solo)
	solo.disabled = not scopes.has(MissionOutcome.Scope.SOLO)
	buttons.add_child(solo)
	rows.add_child(_button("BACK", func() -> void: show_view("council")))


func start_squad() -> void:
	_launch(definition.squad_scene)


func start_solo() -> void:
	_launch(definition.solo_scene)


func _launch(scene: String) -> void:
	if scene == "":
		return
	var game: Node = get_node_or_null("/root/GameManager")
	if game != null:
		game.return_scene = SCENE_PATH
		game.mission_checkpoint = &""
	get_tree().change_scene_to_file(scene)


# --- Operation ---------------------------------------------------------------

func open_operation() -> void:
	approach = null
	agent = null
	intel_spent = 0
	_rebuild_operation()
	show_view("operation")


func _operation_view() -> Control:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Operation"
	rows.add_theme_constant_override("separation", 14)
	return rows


func _rebuild_operation() -> void:
	var rows: VBoxContainer = _views["operation"]
	for child in rows.get_children():
		child.queue_free()
	_approach_buttons.clear()
	_agent_buttons.clear()
	rows.add_child(HudStyle.label("%s  ·  THE COUNCIL'S WAY" % definition.title.to_upper(), 26, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	rows.add_child(HudStyle.caption("APPROACH  ·  WHOSE HELP DO WE BUY?"))
	var approaches: HBoxContainer = HBoxContainer.new()
	approaches.add_theme_constant_override("separation", 14)
	rows.add_child(approaches)
	for item in definition.political_approaches:
		approaches.add_child(_approach_card(item))
	rows.add_child(HudStyle.caption("AGENT  ·  WHO CARRIES IT OUT?"))
	var agents: HBoxContainer = HBoxContainer.new()
	agents.add_theme_constant_override("separation", 10)
	rows.add_child(agents)
	for hero in HeroRoster.all():
		var button: Button = _button(hero.display_name, func() -> void: select_agent(hero))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 52)
		button.set_meta(&"hero", hero)
		agents.add_child(button)
		_agent_buttons.append(button)
	_agent_trait = HudStyle.label("", 15, HudStyle.MUTED)
	rows.add_child(_agent_trait)
	var intel_row: HBoxContainer = HBoxContainer.new()
	intel_row.add_theme_constant_override("separation", 10)
	rows.add_child(intel_row)
	intel_row.add_child(HudStyle.label("SPEND INTEL", 16, HudStyle.SAND))
	intel_row.add_child(_button("-", func() -> void: set_intel(intel_spent - 1)))
	_intel_label = HudStyle.label("0", 20, HudStyle.TEXT, HudStyle.mono_font())
	intel_row.add_child(_intel_label)
	intel_row.add_child(_button("+", func() -> void: set_intel(intel_spent + 1)))
	intel_row.add_child(HudStyle.label("(+%d%% each)" % roundi(OperationResolver.INTEL_STEP * 100.0), 15, HudStyle.MUTED))
	_odds_label = HudStyle.label("", 28, HudStyle.GOLD_LIGHT, HudStyle.body_font(700))
	rows.add_child(_odds_label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	rows.add_child(buttons)
	_commit_button = _button("COMMIT THE OPERATION", commit_operation)
	buttons.add_child(_commit_button)
	buttons.add_child(_button("BACK", func() -> void:
		if home_scene != "":
			go_home()
		else:
			show_view("briefing")))
	_refresh_operation()


func _approach_card(item: PoliticalApproach) -> Button:
	var reason: String = OperationResolver.blocked_reason(item, campaign)
	var costs: PackedStringArray = []
	for key in item.costs:
		costs.append("%s %d" % [CampaignState.resource_name(key), int(item.costs[key])])
	var text: String = "%s\n\n%s\n\nThrough: %s (%s)\nCost: %s\nBase odds: %d%%" % [
		item.title.to_upper(), item.description, CampaignState.faction_name(item.faction),
		campaign.standing_name(item.faction), ", ".join(costs), roundi(item.base_chance * 100.0)]
	if reason != "":
		text += "\n\nBLOCKED: " + reason
	var button: Button = _button(text, func() -> void: select_approach(item))
	button.toggle_mode = true
	button.disabled = reason != ""
	button.custom_minimum_size = Vector2(560, 290)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta(&"approach", item)
	_approach_buttons.append(button)
	return button


func select_approach(item: PoliticalApproach) -> void:
	approach = item
	set_intel(intel_spent)
	_refresh_operation()


func select_agent(hero: HeroDefinition) -> void:
	agent = hero
	_refresh_operation()


## Intel is capped by what the campaign holds, minus what the approach costs.
func set_intel(value: int) -> void:
	var available: int = int(campaign.resources.get(&"intel", 0))
	if approach != null:
		available -= int(approach.costs.get(&"intel", 0))
	intel_spent = clampi(value, 0, maxi(available, 0))
	_refresh_operation()


func _refresh_operation() -> void:
	if _odds_label == null or not is_instance_valid(_odds_label):
		return
	for button in _approach_buttons:
		button.set_pressed_no_signal(button.get_meta(&"approach") == approach)
	for button in _agent_buttons:
		button.set_pressed_no_signal(button.get_meta(&"hero") == agent)
	_intel_label.text = str(intel_spent)
	_agent_trait.text = "%s, %s. %s" % [agent.display_name, agent.title, agent.political_trait] if agent != null else "Choose who carries it out."
	if approach == null or agent == null:
		_odds_label.text = "CHOOSE AN APPROACH AND AN AGENT"
		_commit_button.disabled = true
		return
	_odds_label.text = "ODDS OF SUCCESS  %d%%   (the dilemma can still shift them)" % roundi(OperationResolver.chance(approach, agent, campaign, intel_spent) * 100.0)
	_commit_button.disabled = OperationResolver.blocked_reason(approach, campaign) != ""


func commit_operation() -> void:
	if approach == null or agent == null:
		return
	_rebuild_dilemma()
	show_view("dilemma")


# --- Dilemma -----------------------------------------------------------------

func _dilemma_view() -> Control:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Dilemma"
	rows.add_theme_constant_override("separation", 18)
	rows.add_child(HudStyle.label("A CHOICE", 30, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	_dilemma_text = HudStyle.label("", 20, HudStyle.TEXT, HudStyle.body_font(500))
	_dilemma_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dilemma_text.custom_minimum_size = Vector2(1100, 0)
	rows.add_child(_dilemma_text)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 12)
	rows.add_child(_choice_box)
	return rows


func _rebuild_dilemma() -> void:
	_dilemma_text.text = approach.dilemma
	for child in _choice_box.get_children():
		child.queue_free()
	for choice in approach.choices:
		var odds: int = roundi(OperationResolver.chance(approach, agent, campaign, intel_spent, choice) * 100.0)
		var effects: String = OperationResolver.describe(choice.effects)
		var text: String = "%s\nOdds %d%%%s" % [choice.text, odds, ("  ·  " + effects) if effects != "" else ""]
		var button: Button = _button(text, func() -> void: choose(choice))
		button.custom_minimum_size = Vector2(900, 70)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_choice_box.add_child(button)


## The roll happens here; the campaign applies the result at once - there is
## no checkpoint to retry a council decision from.
func choose(choice: PoliticalChoice) -> void:
	var roll: float = forced_roll if forced_roll >= 0.0 else randf()
	last_outcome = OperationResolver.resolve(definition, approach, agent, campaign, intel_spent, choice, roll)
	campaign.apply(last_outcome)
	_show_result()


# --- Result ------------------------------------------------------------------

func _result_view() -> Control:
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Result"
	rows.add_theme_constant_override("separation", 16)
	_result_title = HudStyle.label("", 40, HudStyle.GOLD_LIGHT, HudStyle.display_font())
	rows.add_child(_result_title)
	_result_body = HudStyle.label("", 19, HudStyle.TEXT, HudStyle.body_font(500))
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_body.custom_minimum_size = Vector2(1100, 0)
	rows.add_child(_result_body)
	_return_button = _button("RETURN", func() -> void:
		if lesson_mission != null:
			get_node("/root/GameManager").flow.advance(get_tree())
		elif home_scene != "":
			go_home()
		else:
			show_view("council"))
	rows.add_child(_return_button)
	return rows


func _show_result() -> void:
	_result_title.text = last_outcome.tier_title()
	_result_title.add_theme_color_override("font_color", TIER_COLORS[last_outcome.tier])
	var lines: PackedStringArray = []
	for key in last_outcome.stats:
		lines.append("%s:  %s" % [key, str(last_outcome.stats[key])])
	lines.append("")
	lines.append("CONSEQUENCES:  " + "  ·  ".join(last_outcome.consequence_lines()))
	if last_outcome.flags.has("operation_exposed"):
		lines.append("")
		lines.append("The operation was exposed. The Harkonnen know someone tried.")
	_result_body.text = "\n".join(lines)
	if lesson_mission != null:
		_return_button.text = "CONTINUE"
	show_view("result")


func _on_back_to_launcher() -> void:
	var game: Node = get_node_or_null("/root/GameManager")
	if game != null:
		game.return_scene = ""
	get_tree().change_scene_to_file(LAUNCHER)


# --------------------------------------------------------------------------
# Widgets
# --------------------------------------------------------------------------

func _panel(border: Color = HudStyle.LINE) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = HudStyle.panel_box(border, HudStyle.PANEL, 1)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", box)
	return panel


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", HudStyle.body_font(600))
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", HudStyle.TEXT)
	button.add_theme_color_override("font_pressed_color", HudStyle.GOLD_LIGHT)
	button.add_theme_color_override("font_hover_color", HudStyle.GOLD_LIGHT)
	button.add_theme_color_override("font_disabled_color", HudStyle.SAND_DIM)
	var states: Dictionary = {
		"normal": HudStyle.panel_box(HudStyle.LINE, HudStyle.PANEL_2, 1),
		"hover": HudStyle.panel_box(HudStyle.GOLD, HudStyle.PANEL_2, 1),
		"pressed": HudStyle.panel_box(HudStyle.GOLD, Color("3a2c16"), 2),
		"disabled": HudStyle.panel_box(HudStyle.LINE, Color(HudStyle.PANEL, 0.6), 1),
		"focus": HudStyle.panel_box(HudStyle.GOLD, Color(0, 0, 0, 0), 1),
	}
	for key in states:
		var box: StyleBoxFlat = states[key]
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		box.shadow_size = 0
		button.add_theme_stylebox_override(key, box)
	button.pressed.connect(action)
	return button
