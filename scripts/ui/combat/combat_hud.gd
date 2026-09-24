class_name CombatHud
extends CanvasLayer
## The fight's own interface, Final Fantasy style: the screen flashes and
## letterboxes into combat, the exploring HUD steps aside, and the fight shows
## the turn order across the top, the hero's points, health and prescience
## bottom-left, and a command menu with each action's cost. A vision tints the
## screen and ends in a choice: accept this future, or take it back.

var combat: TurnCombat

var _root: Control
var _flash: ColorRect
var _tint: ColorRect
var _top: ColorRect
var _bottom: ColorRect
var _banner: Label
var _round: Label
var _order: HBoxContainer
var _turn_label: Label
var _hp_bar: HudBar
var _hp_text: Label
var _ap_bar: HudBar
var _ap_text: Label
var _prescience: Label
var _evasion: Label
var _commands: Dictionary = {}
var _log: Label
var _tooltip: PanelContainer
var _tooltip_text: Label
var _prompt: PanelContainer
var _prompt_title: Label
var _prompt_accept: Button
var _vision_label: Label
var _hidden_hud: CanvasItem
var _hidden_title: CanvasItem


func _ready() -> void:
	layer = 15
	_build()
	_root.hide()
	combat.combat_started.connect(_on_started)
	combat.combat_ended.connect(_on_ended)
	combat.turn_changed.connect(func(_actor: Node2D) -> void:
		_refresh()
		_refresh_order())
	combat.points_changed.connect(_refresh)
	combat.roster_changed.connect(_refresh_order)
	combat.vision_changed.connect(_on_vision)
	combat.vision_resolved.connect(_on_resolved)
	combat.event_logged.connect(_on_event)


# --------------------------------------------------------------------------
# Building
# --------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Combat"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_tint = _rect(Color(0.25, 0.45, 1.0, 0.0))
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top = _rect(Color(0.02, 0.02, 0.02, 0.86))
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = 92
	_bottom = _rect(Color(0.02, 0.02, 0.02, 0.86))
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -176
	_build_top()
	_build_bottom()
	_vision_label = HudStyle.label("VISION  ·  one possible future  ·  Q takes it back", 20, Color(0.7, 0.85, 1.0), HudStyle.display_font())
	_vision_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_vision_label.offset_top = 104
	_vision_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_vision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vision_label.hide()
	_root.add_child(_vision_label)
	_turn_label = HudStyle.label("", 22, HudStyle.DANGER, HudStyle.display_font())
	_turn_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_turn_label.offset_top = 140
	_turn_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_turn_label)
	_build_tooltip()
	_build_prompt()
	_banner = HudStyle.label("", 76, HudStyle.GOLD_LIGHT, HudStyle.display_font())
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.pivot_offset = Vector2(300, 50)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_flash = _rect(Color(1, 0.95, 0.85, 0.0))
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)


func _rect(color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	return rect


func _build_top() -> void:
	_round = HudStyle.label("ROUND 1", 18, HudStyle.SAND_DIM, HudStyle.display_font())
	_round.position = Vector2(28, 30)
	_top.add_child(_round)
	_order = HBoxContainer.new()
	_order.add_theme_constant_override("separation", 10)
	_order.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_order.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_order.grow_vertical = Control.GROW_DIRECTION_BOTH
	_order.alignment = BoxContainer.ALIGNMENT_CENTER
	_top.add_child(_order)


func _build_bottom() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 28
	row.offset_right = -28
	row.offset_top = 18
	row.offset_bottom = -18
	row.add_theme_constant_override("separation", 36)
	_bottom.add_child(row)
	# The hero: portrait, health, points, prescience.
	var hero: HBoxContainer = HBoxContainer.new()
	hero.add_theme_constant_override("separation", 16)
	row.add_child(hero)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = combat.hero.portrait if combat.hero != null and combat.hero.portrait != null else HudStyle.icon("paul")
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(portrait)
	var stats: VBoxContainer = VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	hero.add_child(stats)
	stats.add_child(HudStyle.label(combat.hero.display_name.to_upper() if combat.hero != null else "HERO", 24, HudStyle.TEXT, HudStyle.display_font()))
	_hp_bar = HudBar.new()
	_hp_bar.segments = 15
	_hp_bar.segment_size = Vector2(14, 10)
	_hp_text = HudStyle.label("", 14, HudStyle.MUTED)
	stats.add_child(_pair(_hp_bar, _hp_text))
	_ap_bar = HudBar.new()
	_ap_bar.segments = combat.max_points
	_ap_bar.segment_size = Vector2(18, 14)
	_ap_bar.fill_color = HudStyle.GOLD
	_ap_text = HudStyle.label("", 16, HudStyle.GOLD_LIGHT)
	stats.add_child(_pair(_ap_bar, _ap_text))
	_prescience = HudStyle.label("", 16, Color(0.65, 0.82, 1.0))
	stats.add_child(_prescience)
	_evasion = HudStyle.label("", 13, HudStyle.MUTED)
	stats.add_child(_evasion)
	# Commands, with their keys and costs.
	var menu: GridContainer = GridContainer.new()
	menu.columns = 5
	menu.add_theme_constant_override("h_separation", 8)
	menu.add_theme_constant_override("v_separation", 8)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(menu)
	_command(menu, &"fire", "1", "FIRE", TurnRules.FIRE_COST, func() -> void: combat.select_attack(TurnRules.Attack.FIRE))
	_command(menu, &"quick", "2", "QUICK KNIFE", TurnRules.QUICK_KNIFE_COST, func() -> void: combat.select_attack(TurnRules.Attack.QUICK_KNIFE))
	_command(menu, &"slow", "3", "SLOW KNIFE", TurnRules.SLOW_KNIFE_COST, func() -> void: combat.select_attack(TurnRules.Attack.SLOW_KNIFE))
	_command(menu, &"distract", "4", "DISTRACT", TurnRules.DISTRACT_COST, func() -> void: combat.arm_distract(not combat.distract_armed))
	_command(menu, &"reload", "R", "RELOAD", TurnRules.RELOAD_COST, combat.command_reload)
	_command(menu, &"shield", "T", "SHIELD", TurnRules.SHIELD_COST, combat.command_shield)
	_command(menu, &"sneak", "C", "SNEAK", -1, combat.command_sneak)
	_command(menu, &"vision", "Q", "VISION", -1, _vision_button)
	_command(menu, &"end", "SPACE", "END TURN", -1, combat.end_turn)
	_command(menu, &"spice", "V", "SPICE", -1, func() -> void: combat.command_spice())
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	row.add_child(side)
	var how: Label = HudStyle.label("CLICK a tile to move\nCLICK an enemy: the selected attack", 13, HudStyle.MUTED)
	side.add_child(how)
	_log = HudStyle.label("", 20, HudStyle.SAND, HudStyle.display_font())
	side.add_child(_log)


func _vision_button() -> void:
	if combat.in_vision:
		combat.rewind_vision()
	else:
		combat.command_vision()


func _pair(bar: Control, text: Label) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(bar)
	box.add_child(text)
	return box


func _command(menu: GridContainer, id: StringName, key: String, title: String, cost: int, action: Callable) -> void:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(172, 58)
	button.text = "%s   %s%s" % [key, title, ("   %d AP" % cost) if cost >= 0 else ""]
	_style_button(button, HudStyle.GOLD)
	button.pressed.connect(action)
	menu.add_child(button)
	_commands[id] = button


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.LINE, HudStyle.PANEL_2, 1))
	button.add_theme_stylebox_override("hover", HudStyle.panel_box(HudStyle.SAND_DIM, HudStyle.PANEL_2, 1))
	button.add_theme_stylebox_override("pressed", HudStyle.panel_box(accent, HudStyle.PANEL, 2))
	button.add_theme_stylebox_override("disabled", HudStyle.panel_box(HudStyle.LINE, HudStyle.GROUND, 1))
	button.add_theme_color_override("font_disabled_color", HudStyle.MUTED)


func _padded(box: StyleBoxFlat, margin: float) -> StyleBoxFlat:
	box.set_content_margin_all(margin)
	return box


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", _padded(HudStyle.panel_box(HudStyle.GOLD, Color(0.07, 0.06, 0.05, 0.94), 1), 12))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text = HudStyle.label("", 16, HudStyle.TEXT)
	_tooltip.add_child(_tooltip_text)
	_tooltip.hide()
	_root.add_child(_tooltip)


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", _padded(HudStyle.panel_box(Color(0.6, 0.78, 1.0), Color(0.05, 0.07, 0.12, 0.96), 2), 28))
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BOTH
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	_prompt.add_child(rows)
	_prompt_title = HudStyle.label("", 30, Color(0.75, 0.88, 1.0), HudStyle.display_font())
	_prompt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_prompt_title)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	rows.add_child(buttons)
	_prompt_accept = Button.new()
	_prompt_accept.text = "ENTER   ACCEPT THIS FUTURE"
	_prompt_accept.focus_mode = Control.FOCUS_NONE
	_prompt_accept.custom_minimum_size = Vector2(300, 56)
	_prompt_accept.pressed.connect(combat.accept_vision)
	_style_button(_prompt_accept, Color(0.6, 0.78, 1.0))
	buttons.add_child(_prompt_accept)
	var rewind: Button = Button.new()
	rewind.text = "Q   TAKE IT BACK"
	rewind.focus_mode = Control.FOCUS_NONE
	rewind.custom_minimum_size = Vector2(300, 56)
	rewind.pressed.connect(combat.rewind_vision)
	_style_button(rewind, Color(0.6, 0.78, 1.0))
	buttons.add_child(rewind)
	_prompt.hide()
	_root.add_child(_prompt)


# --------------------------------------------------------------------------
# Reacting
# --------------------------------------------------------------------------

func _on_started(voluntary: bool) -> void:
	_hidden_hud = get_tree().get_first_node_in_group("player_hud") as CanvasItem
	if _hidden_hud != null:
		_hidden_hud.hide()
	# The mission's title line sits where the turn order goes.
	var scene: Node = get_tree().current_scene
	_hidden_title = scene.get_node_or_null("UI/Screen/Title") as CanvasItem if scene != null else null
	if _hidden_title != null:
		_hidden_title.hide()
	_root.show()
	_prompt.hide()
	_log.text = ""
	_refresh_order()
	_refresh()
	# The swirl into battle: a flash, the bars close in, the word.
	_flash.color.a = 0.85
	_top.offset_top = -92
	_top.offset_bottom = 0
	_bottom.offset_top = 0
	_bottom.offset_bottom = 176
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_flash, "color:a", 0.0, 0.45)
	tween.tween_property(_top, "offset_top", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_top, "offset_bottom", 92.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bottom, "offset_top", -176.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bottom, "offset_bottom", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The banner names how the fight really opened: a vision only for Q.
	match combat.opening:
		&"vision":
			_show_banner("PRESCIENCE", Color(0.7, 0.85, 1.0))
		&"strike":
			_show_banner("YOU STRIKE FIRST", HudStyle.GOLD_LIGHT)
		_:
			_show_banner("SPOTTED", HudStyle.DANGER)


func _on_ended() -> void:
	_prompt.hide()
	_tooltip.hide()
	_tint.color.a = 0.0
	_vision_label.hide()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_top, "offset_top", -92.0, 0.25)
	tween.tween_property(_top, "offset_bottom", 0.0, 0.25)
	tween.tween_property(_bottom, "offset_top", 0.0, 0.25)
	tween.tween_property(_bottom, "offset_bottom", 176.0, 0.25)
	tween.chain().tween_callback(func() -> void:
		if not combat.active():
			_root.hide()
			if _hidden_hud != null:
				_hidden_hud.show()
			if _hidden_title != null:
				_hidden_title.show())


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.scale = Vector2(1.4, 1.4)
	_banner.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.55)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.35)


func _on_vision(active: bool) -> void:
	_vision_label.visible = active
	create_tween().tween_property(_tint, "color:a", 0.12 if active else 0.0, 0.3)
	if active and combat.active():
		_show_banner("VISION", Color(0.7, 0.85, 1.0))
	_refresh()


func _on_resolved(fatal: bool) -> void:
	_prompt_title.text = "YOU DIE IN THIS FUTURE" if fatal else "THIS IS ONE FUTURE"
	_prompt_accept.visible = not fatal
	_prompt.show()
	_refresh()


func _on_event(text: String) -> void:
	_log.text = text
	_log.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(_log, "modulate:a", 0.35, 0.6)


func _refresh() -> void:
	if not combat.active():
		return
	if combat.phase != TurnCombat.Phase.PROMPT:
		_prompt.hide()
	var player: PlayerController = combat.player
	_hp_bar.set_value(player.health.current_health, player.health.max_health)
	_hp_bar.fill_color = HudStyle.OK if player.health.current_health > player.health.max_health * 0.35 else HudStyle.DANGER
	_hp_text.text = "%d / %d" % [roundi(player.health.current_health), roundi(player.health.max_health)]
	_ap_bar.set_value(combat.points, combat.max_points)
	_ap_text.text = "%d AP" % combat.points
	_prescience.text = "PRESCIENCE  " + "◆ ".repeat(combat.prescience_left) + "◇ ".repeat(maxi(combat._prescience() - combat.prescience_left, 0))
	_evasion.text = "EVASION +%d%%" % roundi(combat.evasion) if combat.evasion > 0.0 else ""
	_round.text = "ROUND %d" % combat.round_number
	var mine: bool = combat.phase == TurnCombat.Phase.PLAYER
	var enemy_turn: EnemyCharacter = combat.acting as EnemyCharacter
	var enemies_acting: bool = enemy_turn != null and combat.phase == TurnCombat.Phase.ENEMY
	_turn_label.add_theme_color_override("font_color", HudStyle.DANGER)
	_turn_label.add_theme_font_size_override("font_size", 22)
	_turn_label.text = "%s  ·  HARKONNEN TURN" % enemy_turn.display_name if enemies_acting else ""
	var attacks: Dictionary = {&"fire": TurnRules.Attack.FIRE, &"quick": TurnRules.Attack.QUICK_KNIFE, &"slow": TurnRules.Attack.SLOW_KNIFE}
	var titles: Dictionary = {&"fire": "1   FIRE", &"quick": "2   QUICK KNIFE", &"slow": "3   SLOW KNIFE"}
	for id: StringName in attacks:
		var button: Button = _commands[id]
		button.text = "%s   %d AP" % [titles[id], combat.attack_cost(attacks[id])]
		button.disabled = not mine or combat.points < combat.attack_cost(attacks[id])
		button.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.GOLD if combat.selected_attack == attacks[id] else HudStyle.LINE, HudStyle.PANEL_2, 2 if combat.selected_attack == attacks[id] else 1))
	var distract: Button = _commands[&"distract"]
	distract.disabled = not mine or combat.points < TurnRules.DISTRACT_COST
	distract.add_theme_stylebox_override("normal", HudStyle.panel_box(HudStyle.GOLD if combat.distract_armed else HudStyle.LINE, HudStyle.PANEL_2, 2 if combat.distract_armed else 1))
	(_commands[&"reload"] as Button).text = "R   RELOAD   %d AP" % combat.reload_cost()
	(_commands[&"reload"] as Button).disabled = not mine or combat.points < combat.reload_cost()
	(_commands[&"shield"] as Button).disabled = not mine or player.shield == null or combat.points < TurnRules.SHIELD_COST
	(_commands[&"shield"] as Button).text = "T   SHIELD %s   1 AP" % ("OFF" if player.shield_active() else "ON")
	(_commands[&"sneak"] as Button).text = "C   %s" % ("STAND UP" if player.is_crouching else "SNEAK")
	(_commands[&"sneak"] as Button).disabled = not mine
	(_commands[&"vision"] as Button).text = "Q   TAKE IT BACK" if combat.in_vision else "Q   VISION  (%d)" % combat.prescience_left
	(_commands[&"vision"] as Button).disabled = not mine or (not combat.in_vision and combat.prescience_left <= 0)
	(_commands[&"end"] as Button).disabled = not mine
	var campaign: CampaignState = Progression.campaign_of(combat)
	var doses: int = campaign.item_count(&"spice_dose") if campaign != null else 0
	(_commands[&"spice"] as Button).text = "V   SPICE  (%d)" % doses
	(_commands[&"spice"] as Button).disabled = not mine or doses <= 0
	if combat.distract_armed and mine:
		_turn_label.text = "CLICK WHERE THE STONE LANDS  ·  ESC CANCELS"
		_turn_label.add_theme_font_size_override("font_size", 17)
		_turn_label.add_theme_color_override("font_color", HudStyle.GOLD_LIGHT)


func _refresh_order() -> void:
	for child in _order.get_children():
		child.queue_free()
	if not combat.active():
		return
	for actor in combat.turn_order():
		var chip: PanelContainer = PanelContainer.new()
		var current: bool = actor == combat.acting
		var hostile: bool = actor != combat.player
		chip.add_theme_stylebox_override("panel", HudStyle.panel_box(HudStyle.GOLD if current else (HudStyle.DANGER if hostile else HudStyle.OK), HudStyle.PANEL, 2 if current else 1))
		var box: VBoxContainer = VBoxContainer.new()
		chip.add_child(box)
		var title: String = (actor as EnemyCharacter).display_name if hostile else (combat.hero.display_name.to_upper() if combat.hero != null else "HERO")
		box.add_child(HudStyle.label(title, 14, HudStyle.TEXT))
		var bar: HudBar = HudBar.new()
		bar.segments = 8
		bar.segment_size = Vector2(12, 6)
		bar.fill_color = HudStyle.DANGER if hostile else HudStyle.OK
		var health: HealthComponent = HealthComponent.find_on(actor)
		box.add_child(bar)
		bar.set_value(health.current_health, health.max_health)
		_order.add_child(chip)


func _process(_delta: float) -> void:
	if combat == null or not combat.active():
		return
	_update_tooltip()


## Hovering a target: what the selected attack would do to it.
func _update_tooltip() -> void:
	if combat.phase != TurnCombat.Phase.PLAYER or get_viewport().gui_get_hovered_control() != null:
		_tooltip.hide()
		return
	var world: Vector2 = combat.level.get_global_mouse_position()
	var target: Node2D = combat.target_at(world)
	if target == null:
		_tooltip.hide()
		return
	var plan: Dictionary = combat.preview_attack(target)
	var lines: PackedStringArray = []
	if target is EnemyCharacter:
		var enemy: EnemyCharacter = target
		lines.append("%s   %d HP%s" % [enemy.display_name, roundi(enemy.health.current_health), "   · SHIELDED" if ShieldComponent.find_on(enemy) != null and ShieldComponent.find_on(enemy).enabled else ""])
		lines.append("%s  ·  %d%%  ·  %d AP" % [TurnRules.attack_name(plan.kind), roundi(plan.chance), plan.cost])
	else:
		lines.append("FUEL TANK")
		lines.append("FIRE  ·  %d%%  ·  %d AP" % [roundi(plan.chance), plan.cost])
	if plan.note != "":
		lines.append(plan.note)
	if not plan.ok and plan.note == "":
		lines.append("NOT ENOUGH POINTS")
	_tooltip_text.text = "\n".join(lines)
	_tooltip_text.add_theme_color_override("font_color", HudStyle.TEXT if plan.ok else HudStyle.MUTED)
	_tooltip.show()
	_tooltip.reset_size()
	var mouse: Vector2 = _root.get_local_mouse_position()
	_tooltip.position = (mouse + Vector2(24, 18)).clamp(Vector2.ZERO, _root.size - _tooltip.size - Vector2(8, 8))
