class_name PlayerHud
extends Control
## The in-game HUD, laid out for a 1920 x 1080 canvas and anchored to screen
## edges so it holds at any window size:
##
##   top-left      mission title (debug overlay) and objectives (MissionHUD)
##   top-centre    pause banner, crysknife targeting prompt, short notices
##                 (under the tutorial prompt's slot)
##   top-right     worm sign
##   bottom-left   squad cards - click, Shift-click, double-click
##   bottom-right  action bar for the selected unit, every key on a keycap
##   bottom-centre one line of mouse controls
##
## It reads gameplay state and decides nothing, except forwarding card clicks
## to SquadManager.

const RESULT_DISPLAY_MS: int = 1400
const DENIED_DISPLAY_MS: int = 1600
const WORM_COLORS: Array[Color] = [
	Color(0.8, 0.8, 0.8), Color(0.88, 0.84, 0.66), Color(1.0, 0.86, 0.5),
	Color(1.0, 0.7, 0.36), Color(1.0, 0.5, 0.3), Color(1.0, 0.35, 0.28),
]
const MARGIN: float = 28.0

var player: PlayerController
var squad: SquadManager

# Readouts that tests and the tutorial look at.
var down_label: Label
var status_label: Label
var ammo_label: Label
var weapon_name_label: Label
var melee_label: Label
var stealth_label: Label
var prescience_label: Label
var worm_label: Label
var notice_label: Label
var pause_label: Label
var cursor_label: Label
var hints_label: Label

var _cards: Array[HudUnitCard] = []
var offscreen: OffscreenIndicators
var _squad_box: VBoxContainer
var _bar: HBoxContainer
var _weapon_card: PanelContainer
var _weapon_icon: TextureRect
var _pips: HudBar
var _weapon_group: Control
var _weapon_slots: Array[HudSlot] = []
var _blade_group: Control
var _blade_slot: HudSlot
var _ability_group: Control
var _prescience_slot: HudSlot
var _stance_group: Control
var _stance_slot: HudSlot
var _order_group: Control
var _hold_slot: HudSlot
var _follow_slot: HudSlot
var _worm_box: Control
var _worm_bar: HudBar
var _pause_frame: Control
var _prescience_veil: Control
var _icon_standing: Texture2D
var _icon_crouched: Texture2D
## Solo scope: one hero on direct control.
var solo: bool = false
var solo_clicks: bool = false
var _solo_group: Control
var _dodge_slot: HudSlot
var _shield_slot: HudSlot


func setup(paul: PlayerController, manager: SquadManager) -> void:
	player = paul
	squad = manager
	if is_instance_valid(offscreen):
		offscreen.squad = manager
	# SquadManager registers its members in its own _ready; build after it.
	call_deferred("_build_squad_cards")


func _ready() -> void:
	add_to_group("player_hud")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_standing = HudStyle.icon("stance_standing")
	_icon_crouched = HudStyle.icon("stance_crouched")
	_build_prescience_veil()
	_build_pause_frame()
	_build_top()
	_build_squad_box()
	_build_action_bar()
	_build_bottom_line()
	_build_center()
	offscreen = OffscreenIndicators.new()
	offscreen.name = "Offscreen"
	offscreen.squad = squad
	add_child(offscreen)


# --------------------------------------------------------------------------
# Construction
# --------------------------------------------------------------------------

## A spice-blue glow around the screen edge while Paul reads the future, so
## the slowed world is obviously a different mode.
func _build_prescience_veil() -> void:
	_prescience_veil = Control.new()
	_prescience_veil.name = "PrescienceVeil"
	_prescience_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prescience_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prescience_veil.draw.connect(func() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, _prescience_veil.size)
		var bands: int = 28
		for index in range(bands):
			var fade: float = 1.0 - float(index) / bands
			_prescience_veil.draw_rect(rect.grow(-index * 5.0 - 2.5), Color(0.25, 0.6, 0.95, 0.22 * fade * fade), false, 5.0))
	_prescience_veil.hide()
	add_child(_prescience_veil)


func _build_pause_frame() -> void:
	_pause_frame = Control.new()
	_pause_frame.name = "PauseFrame"
	_pause_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_frame.draw.connect(func() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, _pause_frame.size)
		_pause_frame.draw_rect(rect, Color(0.25, 0.55, 0.75, 0.08))
		_pause_frame.draw_rect(rect.grow(-2), HudStyle.SPICE_BLUE, false, 4.0))
	_pause_frame.hide()
	add_child(_pause_frame)


func _build_top() -> void:
	var top: VBoxContainer = VBoxContainer.new()
	top.name = "Top"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	# Below the tutorial prompt, which owns the very top of the screen.
	top.offset_top = 212.0
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	pause_label = HudStyle.label("PAUSED  ·  SPACE TO RESUME  ·  ORDERS STILL WORK", 22, HudStyle.SPICE_BLUE, HudStyle.display_font())
	pause_label.name = "Paused"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.hide()
	top.add_child(pause_label)
	notice_label = HudStyle.label("", 20, HudStyle.GOLD_LIGHT)
	notice_label.name = "Notice"
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(notice_label)
	# Worm sign, top right.
	_worm_box = HBoxContainer.new()
	_worm_box.name = "WormMeter"
	_worm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_worm_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_worm_box.offset_top = MARGIN
	_worm_box.offset_right = -MARGIN
	_worm_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_worm_box.add_theme_constant_override("separation", 12)
	add_child(_worm_box)
	var worm_icon: TextureRect = TextureRect.new()
	worm_icon.texture = HudStyle.icon("worm")
	worm_icon.custom_minimum_size = Vector2(44, 44)
	worm_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	worm_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	worm_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_worm_box.add_child(worm_icon)
	var worm_rows: VBoxContainer = VBoxContainer.new()
	worm_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worm_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_worm_box.add_child(worm_rows)
	worm_label = HudStyle.label("", 16, HudStyle.TEXT)
	worm_label.name = "Worm"
	worm_rows.add_child(worm_label)
	_worm_bar = HudBar.new()
	_worm_bar.segment_size = Vector2(18, 9)
	worm_rows.add_child(_worm_bar)
	_worm_box.hide()


func _build_squad_box() -> void:
	_squad_box = VBoxContainer.new()
	_squad_box.name = "Squad"
	_squad_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_squad_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_squad_box.offset_left = MARGIN
	_squad_box.offset_bottom = -MARGIN - 34.0
	_squad_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_squad_box.add_theme_constant_override("separation", 10)
	add_child(_squad_box)


func _build_squad_cards() -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	if not is_instance_valid(player) or not is_instance_valid(squad):
		return
	_add_card(player, "1", "paul", "Paul")
	var allies: Array[AllyCharacter] = squad.members.duplicate()
	allies.sort_custom(func(a: AllyCharacter, b: AllyCharacter) -> bool: return a.selection_slot < b.selection_slot)
	for ally in allies:
		var glyph: String = "scout" if ally.selection_slot == 2 else "warrior"
		var title: String = ally.data.display_name if ally.data != null else str(ally.name)
		_add_card(ally, str(ally.selection_slot), glyph, title)


func _add_card(unit: Node2D, key: String, glyph: String, title: String) -> void:
	var card: HudUnitCard = HudUnitCard.new()
	card.name = "Card_" + title
	card.setup(unit, squad, key, glyph, title)
	_squad_box.add_child(card)
	_cards.append(card)


func _build_action_bar() -> void:
	_bar = HBoxContainer.new()
	_bar.name = "ActionBar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_bar.offset_right = -MARGIN
	_bar.offset_bottom = -MARGIN - 34.0
	_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.alignment = BoxContainer.ALIGNMENT_END
	_bar.add_theme_constant_override("separation", 22)
	add_child(_bar)
	_build_weapon_card()
	var weapons: Array = _group("Weapons", "WEAPONS")
	_weapon_group = weapons[0]
	for key in ["Z", "X"]:
		var slot: HudSlot = _slot(key, null)
		_weapon_slots.append(slot)
		weapons[1].add_child(slot)
	var blade: Array = _group("Blade", "CRYSKNIFE · CLICK / HOLD")
	_blade_group = blade[0]
	melee_label = blade[2]
	melee_label.name = "Melee"
	_blade_slot = _slot("E", HudStyle.icon("crysknife"))
	blade[1].add_child(_blade_slot)
	var ability: Array = _group("Ability", "PRESCIENCE")
	_ability_group = ability[0]
	prescience_label = ability[2]
	prescience_label.name = "Prescience"
	_prescience_slot = _slot("Q", HudStyle.icon("prescience"))
	_prescience_slot.accent = HudStyle.SPICE_BLUE
	_prescience_slot.ring_color = HudStyle.SPICE_BLUE
	ability[1].add_child(_prescience_slot)
	var stance: Array = _group("Stance", "SNEAK")
	_stance_group = stance[0]
	stealth_label = stance[2]
	stealth_label.name = "Stealth"
	_stance_slot = _slot("C", _icon_standing)
	stance[1].add_child(_stance_slot)
	var solo_tools: Array = _group("SoloTools", "DODGE · SHIELD")
	_solo_group = solo_tools[0]
	_dodge_slot = _slot("SPC", HudStyle.icon("dodge"))
	_shield_slot = _slot("T", HudStyle.icon("shield"))
	_shield_slot.accent = HudStyle.SPICE_BLUE
	solo_tools[1].add_child(_dodge_slot)
	solo_tools[1].add_child(_shield_slot)
	_solo_group.hide()
	var orders: Array = _group("Orders", "HOLD · FOLLOW")
	_order_group = orders[0]
	_hold_slot = _slot("H", HudStyle.icon("hold"))
	_follow_slot = _slot("G", HudStyle.icon("follow"))
	orders[1].add_child(_hold_slot)
	orders[1].add_child(_follow_slot)


## [label above] [row of slots] [caption]. Returns [group, row, above_label].
func _group(group_name: String, caption_text: String) -> Array:
	var group: VBoxContainer = VBoxContainer.new()
	group.name = group_name
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.alignment = BoxContainer.ALIGNMENT_END
	group.add_theme_constant_override("separation", 6)
	var above: Label = HudStyle.label("", 14, HudStyle.TEXT)
	above.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	group.add_child(above)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	group.add_child(row)
	group.add_child(HudStyle.caption(caption_text))
	_bar.add_child(group)
	return [group, row, above]


func _slot(key: String, texture: Texture2D) -> HudSlot:
	var slot: HudSlot = HudSlot.new()
	slot.key_text = key
	slot.icon = texture
	return slot


func _build_weapon_card() -> void:
	_weapon_card = PanelContainer.new()
	_weapon_card.name = "WeaponCard"
	_weapon_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_card.size_flags_vertical = Control.SIZE_SHRINK_END
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD, Color("1f180f"), 1)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	_weapon_card.add_theme_stylebox_override("panel", box)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 8)
	rows.custom_minimum_size = Vector2(250, 0)
	_weapon_card.add_child(rows)
	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(name_row)
	weapon_name_label = HudStyle.label("", 16, HudStyle.GOLD_LIGHT, HudStyle.body_font(700))
	weapon_name_label.name = "Weapon"
	weapon_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(weapon_name_label)
	_weapon_icon = TextureRect.new()
	_weapon_icon.custom_minimum_size = Vector2(56, 30)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.modulate = HudStyle.GOLD_LIGHT
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(_weapon_icon)
	var ammo_row: HBoxContainer = HBoxContainer.new()
	ammo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_row.add_theme_constant_override("separation", 12)
	rows.add_child(ammo_row)
	_pips = HudBar.new()
	_pips.style = HudBar.Style.PIPS
	_pips.segment_size = Vector2(9, 20)
	_pips.gap = 4.0
	_pips.fill_color = HudStyle.SAND
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ammo_row.add_child(_pips)
	ammo_label = HudStyle.label("", 18, HudStyle.TEXT, HudStyle.mono_font())
	ammo_label.name = "Ammo"
	ammo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_row.add_child(ammo_label)
	status_label = HudStyle.label("", 14, HudStyle.DANGER)
	status_label.name = "Status"
	rows.add_child(status_label)
	_bar.add_child(_weapon_card)


## Solo scope: the bar shows the hero's own tools. `clicks` is the interiors'
## click-order scheme; without it the direct (WASD) controls are shown.
func set_solo(value: bool, clicks: bool = false) -> void:
	solo = value
	solo_clicks = value and clicks
	_solo_group.visible = solo
	var direct: bool = solo and not solo_clicks
	melee_label.get_parent().get_child(2).text = "CRYSKNIFE · TAP / HOLD" if direct else "CRYSKNIFE · CLICK / HOLD"
	if solo_clicks:
		hints_label.text = "CLICK a tile to move (twice: run)  ·  RIGHT-CLICK enemy: fire  ·  LEFT-CLICK enemy: knife (hold: slow)  ·  RIGHT-CLICK console or find: use  ·  SPACE dodge  ·  T shield  ·  C crouch  ·  V spice  ·  P pause"
	else:
		hints_label.text = "WASD move  ·  MOUSE aim  ·  LEFT-CLICK fire  ·  E knife (hold: slow)  ·  SPACE dodge  ·  T shield  ·  SHIFT run  ·  C crouch  ·  F use  ·  P pause" if solo else _squad_hints()


func _squad_hints() -> String:
	return "LEFT-CLICK select / knife an enemy (hold: slow strike)  ·  DRAG box  ·  RIGHT-CLICK move / fire / use  ·  DOUBLE RIGHT-CLICK run  ·  SHIFT queue  ·  CTRL plan, F signal  ·  B fire discipline  ·  WASD pan  ·  SPACE pause"


func _build_bottom_line() -> void:
	hints_label = HudStyle.label(_squad_hints(), 14, HudStyle.MUTED)
	hints_label.name = "Hints"
	hints_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hints_label.offset_bottom = -12.0
	hints_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hints_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hints_label)


func _build_center() -> void:
	down_label = HudStyle.label("PAUL IS DOWN  ·  ENTER TO RESTART", 34, HudStyle.DANGER, HudStyle.display_font())
	down_label.name = "Down"
	down_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	down_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	down_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	down_label.hide()
	add_child(down_label)
	cursor_label = HudStyle.label("", 14, HudStyle.TEXT)
	cursor_label.name = "Cursor"
	cursor_label.hide()
	add_child(cursor_label)


# --------------------------------------------------------------------------
# Refresh
# --------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var dead: bool = player.health.is_dead
	down_label.visible = dead
	_bar.visible = not dead
	_refresh_top()
	_refresh_worm()
	_refresh_cursor()
	if dead:
		return
	var primary: Node2D = _primary_unit()
	var paul_view: bool = primary == player
	_refresh_weapon(primary)
	_weapon_group.visible = paul_view
	_blade_group.visible = paul_view
	_ability_group.visible = paul_view and player.prescience != null
	_order_group.visible = not solo and is_instance_valid(squad) and not squad.selected_members.is_empty()
	if solo:
		_refresh_solo_tools()
	if paul_view:
		_refresh_weapon_slots()
		_refresh_melee()
		_refresh_prescience()
	_refresh_stance(primary)
	_refresh_orders()


## The unit whose tools the bar shows: Paul whenever he is selected (or when
## nothing is), otherwise the first selected Fremen.
func _primary_unit() -> Node2D:
	if not is_instance_valid(squad) or squad.paul_selected or squad.selected_members.is_empty():
		return player
	return squad.selected_members[0]


func _refresh_top() -> void:
	var vision: bool = player.prescience != null and player.prescience.active
	if _prescience_veil.visible != vision:
		_prescience_veil.visible = vision
		_prescience_veil.queue_redraw()
	var is_paused: bool = is_instance_valid(squad) and squad.paused
	pause_label.visible = is_paused
	_pause_frame.visible = is_paused
	if is_paused:
		_pause_frame.queue_redraw()
	var text: String = ""
	var color: Color = HudStyle.GOLD_LIGHT
	if is_instance_valid(squad):
		if squad.blade_charging:
			if squad.blade_charge_ratio() >= 1.0:
				text = "SLOW STRIKE READY  ·  RELEASE TO COMMIT  ·  PIERCES SHIELDS"
			else:
				text = "QUICK STRIKE  ·  KEEP HOLDING FOR A SLOW ONE"
		elif squad.targeting == SquadManager.Targeting.STRIKE:
			text = "CRYSKNIFE  ·  CLICK A TARGET TO CUT, HOLD FOR A SLOW STRIKE  ·  RIGHT-CLICK CANCELS"
		elif squad.rejection_active():
			text = squad.rejection_message
			color = HudStyle.DANGER
		elif squad.notice_active():
			text = squad.notice
	var prescience: PrescienceController = player.prescience
	if text == "" and prescience != null and Time.get_ticks_msec() - prescience.last_denied_time < DENIED_DISPLAY_MS:
		text = prescience.last_denied_reason
		color = HudStyle.DANGER
	notice_label.text = text
	notice_label.add_theme_color_override("font_color", color)
	notice_label.visible = text != ""


func _refresh_weapon(unit: Node2D) -> void:
	var weapon: WeaponController = player.weapon_controller if unit == player else (unit as AllyCharacter).weapon
	if weapon == null or weapon.weapon_data == null:
		_weapon_card.hide()
		return
	_weapon_card.show()
	var data: WeaponData = weapon.weapon_data
	var owner_name: String = "" if unit == player else "%s · " % (unit as AllyCharacter).data.display_name.to_upper()
	weapon_name_label.text = owner_name + data.weapon_name.to_upper()
	_weapon_icon.texture = data.icon
	_pips.segments = data.magazine_size
	_pips.set_value(weapon.current_ammo, data.magazine_size)
	_pips.fill_color = HudStyle.DANGER if weapon.current_ammo == 0 else HudStyle.SAND
	ammo_label.text = "%d / %d" % [weapon.current_ammo, data.magazine_size]
	if not weapon.enabled:
		status_label.text = "NOT YET ISSUED"
		status_label.add_theme_color_override("font_color", HudStyle.MUTED)
	elif weapon.is_reloading:
		status_label.text = "RELOADING"
		status_label.add_theme_color_override("font_color", HudStyle.GOLD)
	elif weapon.current_ammo == 0:
		status_label.text = "EMPTY  ·  R TO RELOAD"
		status_label.add_theme_color_override("font_color", HudStyle.DANGER)
	else:
		status_label.text = "R RELOAD  ·  LEFT-CLICK TO FIRE" if solo and not solo_clicks else "R RELOAD  ·  RIGHT-CLICK AN ENEMY TO FIRE"
		status_label.add_theme_color_override("font_color", HudStyle.MUTED)


func _refresh_weapon_slots() -> void:
	var weapon: WeaponController = player.weapon_controller
	for index in range(_weapon_slots.size()):
		var slot: HudSlot = _weapon_slots[index]
		var data: WeaponData = player.loadout[index] if index < player.loadout.size() else null
		slot.icon = data.icon if data != null else null
		slot.sweep = 0.0
		if data == null:
			slot.state = HudSlot.State.OPEN
		elif index == player.equipped_slot:
			if not weapon.enabled:
				slot.state = HudSlot.State.UNAVAILABLE
			elif weapon.current_ammo == 0 and not weapon.is_reloading:
				slot.state = HudSlot.State.EMPTY
			else:
				slot.state = HudSlot.State.EQUIPPED
			if weapon.is_reloading:
				slot.sweep = 1.0 - weapon.reload_ratio()
		else:
			slot.state = HudSlot.State.NORMAL


## Crysknife readiness, charge progress, and the outcome of the last swing.
func _refresh_melee() -> void:
	var melee: MeleeController = player.melee
	var armed: bool = is_instance_valid(squad) and (squad.targeting != SquadManager.Targeting.NONE or squad.blade_charging)
	_blade_slot.state = HudSlot.State.ACTIVE if armed else (HudSlot.State.NORMAL if melee.enabled else HudSlot.State.UNAVAILABLE)
	# The ring is the player's own hold on the button, then Paul's raised blade.
	_blade_slot.ring = squad.blade_charge_ratio() if is_instance_valid(squad) else 0.0
	if _blade_slot.ring >= 1.0:
		_blade_slot.state = HudSlot.State.PRIMED
	var color: Color = HudStyle.TEXT
	var text: String = ""
	match melee.state:
		MeleeController.State.CHARGING:
			_blade_slot.ring = melee.charge_ratio()
			if melee.slow_ready:
				_blade_slot.state = HudSlot.State.PRIMED
				text = "PENETRATING STRIKE READY"
				color = HudStyle.GOLD
			else:
				text = "Slow Attack: %d%%" % roundi(melee.charge_ratio() * 100.0)
		MeleeController.State.IDLE:
			if Time.get_ticks_msec() - melee.last_result_time < RESULT_DISPLAY_MS:
				var blocked: bool = melee.last_result == "BLOCKED"
				text = "%s: %s" % [melee.last_attack_name, "TOO FAST - BLOCKED" if blocked else "HIT " + melee.last_target]
				color = HudStyle.SPICE_BLUE if blocked else HudStyle.OK
		_:
			text = "Crysknife: " + melee.attack_name()
			color = HudStyle.GOLD if melee.current_attack == melee.slow_attack else HudStyle.TEXT
			if melee.current_attack == melee.slow_attack:
				_blade_slot.state = HudSlot.State.PRIMED
	if player.order == PlayerController.Order.MELEE and melee.state == MeleeController.State.IDLE:
		text = "CLOSING IN"
	melee_label.text = text
	melee_label.add_theme_color_override("font_color", color)


func _refresh_prescience() -> void:
	var prescience: PrescienceController = player.prescience
	var energy: PrescienceEnergyComponent = player.prescience_energy
	if prescience == null or energy == null:
		return
	_prescience_slot.ring = energy.ratio()
	if prescience.active:
		_prescience_slot.state = HudSlot.State.ACTIVE
		_prescience_slot.sweep = 1.0 - prescience.remaining_ratio()
		prescience_label.text = "%.1fs" % prescience.remaining
		prescience_label.add_theme_color_override("font_color", HudStyle.SPICE_BLUE)
		return
	_prescience_slot.sweep = 0.0
	_prescience_slot.state = HudSlot.State.NORMAL if energy.can_spend() else HudSlot.State.UNAVAILABLE
	prescience_label.text = "%d / %d" % [roundi(energy.current_energy), roundi(energy.max_energy)]
	prescience_label.add_theme_color_override("font_color", HudStyle.TEXT if energy.can_spend() else HudStyle.MUTED)


func _refresh_stance(unit: Node2D) -> void:
	var low: bool = player.is_crouching if unit == player else (unit as AllyCharacter).sneaking
	_stance_slot.icon = _icon_crouched if low else _icon_standing
	_stance_slot.state = HudSlot.State.ACTIVE if low else HudSlot.State.NORMAL
	if unit == player:
		var profile: StealthProfile = player.stealth_profile
		var mode: String = profile.stance if player.is_crouching else profile.movement_mode
		if mode == "STILL":
			mode = "STANDING"
		stealth_label.text = "%s · NOISE %.0f" % [mode, profile.current_noise_radius]
	else:
		stealth_label.text = "SNEAKING" if low else "STANDING"


func _refresh_orders() -> void:
	if not _order_group.visible:
		return
	var all_hold: bool = true
	var all_follow: bool = true
	for ally in squad.selected_members:
		if not is_instance_valid(ally):
			continue
		all_hold = all_hold and ally.ai.current_order == AllyAIController.Order.HOLD
		all_follow = all_follow and ally.ai.current_order == AllyAIController.Order.FOLLOW
	_hold_slot.state = HudSlot.State.ACTIVE if all_hold else HudSlot.State.NORMAL
	_follow_slot.state = HudSlot.State.ACTIVE if all_follow else HudSlot.State.NORMAL


## Shown from the first real vibration; once the worm commits, the bar is its
## approach and fills exactly when it surfaces.
func _refresh_worm() -> void:
	var worm: WormThreatManager = get_tree().get_first_node_in_group("worm_threat") as WormThreatManager
	if worm == null or player.health.is_dead:
		_worm_box.hide()
		return
	_worm_box.visible = worm.meter_visible()
	var color: Color = WORM_COLORS[mini(int(worm.stage), WORM_COLORS.size() - 1)]
	var text: String = worm.stage_text() if worm.stage > WormThreatManager.Stage.CALM else "WORM SIGN"
	var eta: float = worm.arrival_eta()
	if eta > 0.0:
		text = "WORM APPROACHING  ·  %ds" % ceili(eta)
		color = WORM_COLORS[WORM_COLORS.size() - 1]
	worm_label.text = text
	worm_label.add_theme_color_override("font_color", color)
	_worm_bar.ratio = worm.display_ratio()
	_worm_bar.fill_color = color


func _refresh_solo_tools() -> void:
	_dodge_slot.sweep = 1.0 - player.dodge_ready_ratio()
	_dodge_slot.state = HudSlot.State.ACTIVE if player.dodging else HudSlot.State.NORMAL
	if player.shield == null:
		_shield_slot.state = HudSlot.State.UNAVAILABLE
		return
	_shield_slot.state = HudSlot.State.ACTIVE if player.shield_active() else HudSlot.State.NORMAL


## A word beside the pointer saying what a click there will do.
func _refresh_cursor() -> void:
	if (solo and not solo_clicks) or not is_instance_valid(squad) or player.health.is_dead or get_viewport().gui_get_hovered_control() != null:
		cursor_label.hide()
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var point: Vector2 = squad.get_canvas_transform().affine_inverse() * mouse
	var kind: String = squad.context_kind(point)
	if kind == "" or kind == "MOVE":
		cursor_label.hide()
		return
	cursor_label.show()
	cursor_label.text = kind
	var colors: Dictionary = {"ATTACK": HudStyle.DANGER, "STRIKE": HudStyle.GOLD, "USE": HudStyle.SPICE_BLUE, "SELECT": HudStyle.OK}
	var color: Color = colors.get(kind, HudStyle.DANGER if kind.begins_with("LEFT") else HudStyle.TEXT)
	if squad.blade_charging:
		color = HudStyle.GOLD if squad.blade_charge_ratio() >= 1.0 else HudStyle.TEXT
	cursor_label.add_theme_color_override("font_color", color)
	cursor_label.position = (mouse + Vector2(18, 14)).clamp(Vector2.ZERO, size - Vector2(cursor_label.size.x + 8, 30))
