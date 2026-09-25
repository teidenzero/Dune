class_name MapRoom
extends Control
## The sietch map room: the strategic layer's screen. The map of Arrakis on
## the left; on the right the week, the meters that matter (Rabban's spice
## against his quota, the Emperor's attention, Fremen fighters, the
## greening, Harkonnen heat), the act's story, the operations on offer, and
## the chosen one - who leads it, the odds, and whether to send it as an
## order or play it (Squad, Solo, or through the Council).

const SCENE_PATH: String = "res://scenes/campaign/map_room.tscn"
const LAUNCHER: String = "res://scenes/missions/mission_select.tscn"

var game: Node
var state: StrategicState
var selected_op: int = -1
var selected_region: StringName = &""
var leader: StringName = &""

var canvas: MapCanvas
var _header: Label
var _meters: VBoxContainer
var _story: VBoxContainer
var _ops: VBoxContainer
var _detail: VBoxContainer
var _report: Label
var _end_week: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game = get_node_or_null("/root/GameManager")
	var campaign: CampaignState = game.campaign if game != null else CampaignState.new()
	if game != null and game.strategy == null:
		game.strategy = StrategicState.new_act_two(campaign)
	state = game.strategy if game != null else StrategicState.new_act_two(campaign)
	_build()
	if state.pending_op >= 0:
		var text: String = state.absorb_mission_result()
		if text != "":
			state.report = PackedStringArray([text])
	state.changed.connect(_refresh)
	_refresh()


# --------------------------------------------------------------------------
# Building
# --------------------------------------------------------------------------

func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = HudStyle.GROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 24
	columns.offset_top = 20
	columns.offset_right = -24
	columns.offset_bottom = -20
	columns.add_theme_constant_override("separation", 24)
	add_child(columns)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	_header = HudStyle.label("", 30, HudStyle.GOLD_LIGHT, HudStyle.display_font())
	left.add_child(_header)
	canvas = MapCanvas.new()
	canvas.state = state
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.region_selected.connect(_on_region)
	canvas.operation_selected.connect(select_operation)
	left.add_child(canvas)
	_report = HudStyle.label("", 16, HudStyle.SAND, HudStyle.body_font(500))
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report.custom_minimum_size = Vector2(0, 96)
	left.add_child(_report)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	scroll.add_child(right)
	_meters = VBoxContainer.new()
	_meters.add_theme_constant_override("separation", 6)
	right.add_child(_panel(_meters))
	_story = VBoxContainer.new()
	right.add_child(_panel(_story))
	_ops = VBoxContainer.new()
	_ops.add_theme_constant_override("separation", 6)
	right.add_child(_panel(_ops))
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	right.add_child(_panel(_detail, HudStyle.GOLD))
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	right.add_child(bottom)
	_end_week = _button("END WEEK", end_week)
	_end_week.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_end_week)
	bottom.add_child(_button("LAUNCHER", _to_launcher))


func _panel(content: Control, border: Color = HudStyle.LINE) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = HudStyle.panel_box(border, HudStyle.PANEL, 1)
	box.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(content)
	return panel


func _button(text: String, action: Callable, accent: Color = HudStyle.GOLD) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", HudStyle.body_font(600))
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_disabled_color", HudStyle.SAND_DIM)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var border: Color = accent if key in ["hover", "pressed"] else HudStyle.LINE
		var box: StyleBoxFlat = HudStyle.panel_box(border, HudStyle.PANEL_2 if key != "disabled" else HudStyle.GROUND, 2 if key == "pressed" else 1)
		box.set_content_margin_all(10)
		box.shadow_size = 0
		button.add_theme_stylebox_override(key, box)
	button.pressed.connect(action)
	return button


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


# --------------------------------------------------------------------------
# Refreshing
# --------------------------------------------------------------------------

func _refresh() -> void:
	_header.text = "ARRAKIS  ·  ACT II  ·  WEEK %d" % state.week
	_refresh_meters()
	_refresh_story()
	_refresh_ops()
	_refresh_detail()
	_report.text = "\n".join(state.report)
	_end_week.disabled = state.act_complete
	canvas.selected_op = selected_op
	canvas.selected_region = selected_region
	canvas.queue_redraw()


func _meter(title: String, value: float, maximum: float, text: String, color: Color) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label: Label = HudStyle.label(title, 14, HudStyle.MUTED)
	name_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_label)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	row.add_child(HudStyle.label(text, 14, HudStyle.TEXT))
	return row


func _refresh_meters() -> void:
	_clear(_meters)
	var campaign: CampaignState = state.campaign
	_meters.add_child(HudStyle.caption("THE WAR FOR SPICE"))
	_meters.add_child(_meter("Harkonnen spice", state.production, maxf(StrategicState.QUOTA * 1.5, state.production), "%d / quota %d" % [state.production, StrategicState.QUOTA], HudStyle.DANGER))
	_meters.add_child(_meter("Emperor's attention", state.attention, StrategicState.ATTENTION_MAX, "%d%%" % roundi(state.attention), HudStyle.GOLD))
	_meters.add_child(_meter("Fremen fighters", state.free_fighters(), maxf(state.fighters, 1), "%d free of %d" % [state.free_fighters(), state.fighters], HudStyle.SPICE_BLUE))
	_meters.add_child(_meter("Greening", state.greening, 100.0, "%d" % roundi(state.greening), HudStyle.OK))
	_meters.add_child(_meter("Harkonnen heat", campaign.heat, CampaignState.HEAT_MAX, "%d / %d" % [campaign.heat, CampaignState.HEAT_MAX], HudStyle.DANGER))
	var resources: PackedStringArray = []
	for key in [&"water", &"spice", &"solari", &"intel"]:
		resources.append("%s %d" % [CampaignState.RESOURCE_NAMES[key], int(campaign.resources.get(key, 0))])
	_meters.add_child(HudStyle.label("   ·   ".join(resources), 15, HudStyle.SAND))


func _refresh_story() -> void:
	_clear(_story)
	_story.add_child(HudStyle.caption("ACT II  ·  MUAD'DIB"))
	for entry in StrategicState.STORY:
		var done: bool = state.story_done.has(entry.code)
		var built: bool = entry.has("mission")
		var mark: String = "✓" if done else ("◆" if built else "·")
		var note: String = "" if built else "   (to be built)"
		var color: Color = HudStyle.OK if done else (HudStyle.GOLD_LIGHT if built else HudStyle.SAND_DIM)
		_story.add_child(HudStyle.label("%s  %s  %s%s" % [mark, entry.code, entry.title, note], 15, color))


func _refresh_ops() -> void:
	_clear(_ops)
	_ops.add_child(HudStyle.caption("OPERATIONS THIS WEEK"))
	for op in state.open_operations():
		var region: RegionState = state.region(op.region)
		var tail: String = "ORDERED · %s" % state.hero(op.leader).display_name if op.status == StrategicOperation.Status.ORDERED else ("story" if op.story else "%d wk" % op.weeks_left)
		var storm: String = "  ·  STORM" if region.storm else ""
		var button: Button = _button("%s  —  %s   [%s]%s" % [op.title, region.title(), tail, storm], select_operation.bind(op.id), MapCanvas.OP_COLORS.get(op.kind, HudStyle.GOLD))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if op.id == selected_op:
			button.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.GOLD, HudStyle.PANEL_2, 2))
		_ops.add_child(button)


func _refresh_detail() -> void:
	_clear(_detail)
	var op: StrategicOperation = state.operation(selected_op)
	if op == null or not op.is_open():
		_region_detail()
		return
	var region: RegionState = state.region(op.region)
	_detail.add_child(HudStyle.label(op.title.to_upper(), 22, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	_detail.add_child(HudStyle.label("%s  ·  %s  ·  grip %d%s" % [region.title(), region.control_name(), region.grip, "  ·  in the storm" if region.storm else ""], 14, HudStyle.MUTED))
	var text: Label = HudStyle.label(op.briefing, 16, HudStyle.TEXT, HudStyle.body_font(500))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(540, 0)
	_detail.add_child(text)
	var costs: String = "Commits %d fighters" % op.fighters + ("  ·  %d water" % op.water_cost if op.water_cost > 0 else "")
	_detail.add_child(HudStyle.label(costs, 14, HudStyle.SAND))
	_detail.add_child(HudStyle.caption("WHO LEADS?"))
	var heroes: HBoxContainer = HBoxContainer.new()
	heroes.add_theme_constant_override("separation", 8)
	_detail.add_child(heroes)
	var free: Array[StringName] = state.available_heroes()
	for id in StrategicState.HEROES:
		var data: HeroDefinition = state.hero(id)
		var wounded: int = int(state.wounded.get(id, 0))
		var label: String = data.display_name + ("  (wounded %d wk)" % wounded if wounded > 0 else "")
		var button: Button = _button(label, select_leader.bind(id))
		button.disabled = not free.has(id) and op.leader != id
		if id == leader:
			button.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.GOLD, HudStyle.PANEL_2, 2))
		heroes.add_child(button)
	if op.status == StrategicOperation.Status.ORDERED:
		_detail.add_child(HudStyle.label("Ordered: %s leads it. It resolves when the week ends." % state.hero(op.leader).display_name, 15, HudStyle.OK))
		_detail.add_child(_button("CANCEL THE ORDER", cancel_order))
		return
	var why: String = state.blocked(op, leader) if leader != &"" else "Choose a leader"
	if op.story:
		_detail.add_child(HudStyle.label("A story mission: play it, in any scope.", 15, HudStyle.GOLD_LIGHT))
	elif leader != &"" and why == "":
		var data: HeroDefinition = state.hero(leader)
		_detail.add_child(HudStyle.label("As an order under %s: %d%% to succeed" % [data.display_name, roundi(state.odds(op, leader) * 100.0)], 16, HudStyle.GOLD_LIGHT))
	elif why != "":
		_detail.add_child(HudStyle.label(why, 15, HudStyle.DANGER))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_detail.add_child(actions)
	var send: Button = _button("SEND AS AN ORDER", send_order)
	send.disabled = why != "" or op.story
	actions.add_child(send)
	if op.playable():
		var definition: MissionDefinition = op.definition()
		var scopes: Array[MissionOutcome.Scope] = definition.available_scopes()
		var can_play: bool = leader != &"" and state.available_heroes().has(leader)
		for pair in [[MissionOutcome.Scope.SQUAD, "PLAY: SQUAD"], [MissionOutcome.Scope.SOLO, "PLAY: SOLO"], [MissionOutcome.Scope.POLITICAL, "COUNCIL"]]:
			var button: Button = _button(pair[1], play.bind(pair[0]))
			button.disabled = not can_play or not scopes.has(pair[0])
			actions.add_child(button)


func _region_detail() -> void:
	if selected_region == &"":
		_detail.add_child(HudStyle.label("Choose an operation, or a region on the map.", 16, HudStyle.MUTED))
		return
	var region: RegionState = state.region(selected_region)
	var info: Dictionary = ArrakisAtlas.info(selected_region)
	_detail.add_child(HudStyle.label(region.title().to_upper(), 22, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	_detail.add_child(HudStyle.label("%s  ·  %s" % [ArrakisAtlas.KIND_NAMES[ArrakisAtlas.kind(selected_region)], region.control_name()], 15, HudStyle.MUTED))
	var note: Label = HudStyle.label(info.get("note", ""), 16, HudStyle.TEXT, HudStyle.body_font(500))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(540, 0)
	_detail.add_child(note)
	var facts: PackedStringArray = ["Harkonnen grip %d" % region.grip]
	if ArrakisAtlas.spice(selected_region) > 0:
		facts.append("%d harvester%s" % [region.harvesters, "" if region.harvesters == 1 else "s"])
		facts.append("worm sign %d%%" % roundi(region.worm_sign))
	if region.storm:
		facts.append("under the storm")
	_detail.add_child(HudStyle.label("  ·  ".join(facts), 15, HudStyle.SAND))


# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------

func select_operation(op_id: int) -> void:
	selected_op = op_id
	var op: StrategicOperation = state.operation(op_id)
	if op != null:
		selected_region = op.region
		leader = op.leader if op.leader != &"" else _default_leader(op)
	_refresh()


func _on_region(id: StringName) -> void:
	selected_region = id
	if canvas.selected_op < 0:
		selected_op = -1
	_refresh()


## The free hero with the best odds for it.
func _default_leader(op: StrategicOperation) -> StringName:
	var best: StringName = &""
	var best_odds: float = -1.0
	for id in state.available_heroes():
		var value: float = state.odds(op, id)
		if value > best_odds:
			best_odds = value
			best = id
	return best


func select_leader(id: StringName) -> void:
	leader = id
	_refresh()


func send_order() -> void:
	var op: StrategicOperation = state.operation(selected_op)
	if op != null and state.order(op, leader):
		leader = &""


func cancel_order() -> void:
	var op: StrategicOperation = state.operation(selected_op)
	if op != null:
		state.cancel(op)
		leader = _default_leader(op)
		_refresh()


## Play the operation as a mission, in the chosen scope.
func play(scope: MissionOutcome.Scope) -> void:
	var op: StrategicOperation = state.operation(selected_op)
	if op == null or not state.launch(op, leader):
		return
	var definition: MissionDefinition = op.definition()
	game.return_scene = SCENE_PATH
	game.mission_checkpoint = &""
	game.pending_briefing = scope != MissionOutcome.Scope.POLITICAL
	match scope:
		MissionOutcome.Scope.SQUAD:
			get_tree().change_scene_to_file(definition.squad_scene)
		MissionOutcome.Scope.SOLO:
			get_tree().change_scene_to_file(definition.solo_scene)
		MissionOutcome.Scope.POLITICAL:
			game.council_focus = op.mission_path
			game.council_home = SCENE_PATH
			get_tree().change_scene_to_file(CouncilScreen.SCENE_PATH)


func end_week() -> void:
	selected_op = -1
	leader = &""
	state.end_week()


func _to_launcher() -> void:
	game.return_scene = ""
	get_tree().change_scene_to_file(LAUNCHER)
