class_name HudUnitCard
extends Control
## One squad member: number key, portrait glyph, health, current order, and -
## for the Fremen - the strength of Paul's command link. Click to select,
## Shift-click to add, double-click to jump the camera there.

const CARD_SIZE := Vector2(318, 66)
const ORDER_TEXT := {
	"IDLE": "READY", "MOVE": "MOVING", "ATTACK": "ATTACKING", "MELEE": "CLOSING IN", "INTERACT": "WORKING",
	"FOLLOW": "FOLLOWING", "MOVE_TO": "MOVING", "HOLD": "HOLDING", "COMBAT": "FIGHTING", "DEAD": "DOWN",
}
const ORDER_ICON := {
	"MOVE": "move", "ATTACK": "attack", "MELEE": "crysknife", "INTERACT": "interact",
	"FOLLOW": "follow", "MOVE_TO": "move", "HOLD": "hold", "COMBAT": "attack",
}

var unit: Node2D
var squad: SquadManager
var key_text: String = ""
var portrait: Texture2D
## Painted portrait; drawn untinted in place of the glyph when present.
var painting: Texture2D
var display_name: String = ""
var _health_bar: HudBar
var _icons: Dictionary = {}


func setup(target: Node2D, manager: SquadManager, key: String, glyph: String, title: String) -> void:
	unit = target
	squad = manager
	key_text = key
	portrait = HudStyle.icon(glyph)
	display_name = title
	if target is AllyCharacter and target.data != null and target.data.art != null:
		painting = target.data.art.portrait
	elif target is PlayerController and target.art != null:
		painting = target.art.portrait


func _ready() -> void:
	custom_minimum_size = CARD_SIZE + Vector2(0, HudSlot.KEY_OVERHANG * 0.5)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_health_bar = HudBar.new()
	_health_bar.segment_size = Vector2(14, 7)
	_health_bar.gap = 2.0
	_health_bar.position = Vector2(80, 55)
	add_child(_health_bar)
	for name in ORDER_ICON.values():
		_icons[name] = HudStyle.icon(name)


func _process(_delta: float) -> void:
	if not is_instance_valid(unit):
		hide()
		return
	var health: HealthComponent = HealthComponent.find_on(unit)
	if health != null:
		_health_bar.set_value(health.current_health, health.max_health)
		var ratio: float = _health_bar.ratio
		_health_bar.fill_color = HudStyle.OK if ratio > 0.6 else (HudStyle.GOLD if ratio > 0.3 else HudStyle.DANGER)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not is_instance_valid(squad) or not is_instance_valid(unit):
		return
	squad.select_unit(unit, event.shift_pressed)
	if event.double_click:
		var camera: TacticalCamera = squad.player.get_node_or_null("TacticalCamera") as TacticalCamera
		if camera != null:
			camera.center_on(unit.global_position)
	accept_event()


func _selected() -> bool:
	if unit == squad.player:
		return squad.paul_selected
	return unit is AllyCharacter and unit.selected


func _order_key() -> String:
	if unit is PlayerController:
		return unit.order_name()
	if unit is AllyCharacter:
		if unit.ai.behavior == AllyAIController.Behavior.COMBAT or unit.ai.behavior == AllyAIController.Behavior.DEAD:
			return AllyAIController.Behavior.keys()[unit.ai.behavior]
		return AllyAIController.Order.keys()[unit.ai.current_order]
	return "IDLE"


func _draw() -> void:
	if not is_instance_valid(unit) or not is_instance_valid(squad):
		return
	var top: float = HudSlot.KEY_OVERHANG * 0.5
	var box: Rect2 = Rect2(Vector2(0, top), CARD_SIZE)
	var health: HealthComponent = HealthComponent.find_on(unit)
	var dead: bool = health != null and health.is_dead
	var selected: bool = _selected() and not dead
	var available: bool = unit == squad.player or squad.commands_enabled
	var border: Color = HudStyle.GOLD if selected else HudStyle.LINE
	var alerted: bool = unit is AllyCharacter and unit.alert_active()
	if alerted:
		border = Color(HudStyle.DANGER, 0.55 + 0.45 * sin(Time.get_ticks_msec() / 110.0))
	var panel: StyleBoxFlat = HudStyle.panel_box(border, Color(HudStyle.PANEL, 0.92), 2 if selected or alerted else 1)
	if selected:
		var halo: StyleBoxFlat = StyleBoxFlat.new()
		halo.bg_color = Color(HudStyle.GOLD, 0.16)
		halo.set_corner_radius_all(9)
		draw_style_box(halo, box.grow(4))
	draw_style_box(panel, box)
	var tint: Color = HudStyle.GOLD_LIGHT if selected else HudStyle.SAND
	if dead or not available:
		tint = Color(HudStyle.SAND_DIM, 0.5)
	# Portrait tile.
	var tile: Rect2 = Rect2(box.position + Vector2(10, 9), Vector2(48, 48))
	draw_rect(tile, Color(0, 0, 0, 0.25))
	if painting != null:
		var shade: Color = Color(0.45, 0.45, 0.45) if dead or not available else Color.WHITE
		draw_texture_rect(painting, tile, false, shade)
		draw_rect(tile, HudStyle.GOLD if selected else HudStyle.LINE, false, 1.0)
	elif portrait != null:
		draw_texture_rect(portrait, tile.grow(-5), false, tint)
	HudStyle.draw_keycap(self, Vector2(tile.get_center().x, 0.0), key_text, 13)
	# Name and order.
	var font: Font = HudStyle.body_font(700)
	var small: Font = HudStyle.body_font(600)
	var name_at: Vector2 = box.position + Vector2(80, 22)
	draw_string(font, name_at, display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, HudStyle.TEXT if not dead else HudStyle.MUTED)

	var order_key: String = "DEAD" if dead else _order_key()
	var status: String = ORDER_TEXT.get(order_key, order_key)
	if not dead:
		if unit is PlayerController and unit.is_crouching or unit is AllyCharacter and unit.sneaking:
			status += " · LOW"
		if unit is AllyCharacter and unit.alert_active():
			status = unit.alert_text
		if unit is AllyCharacter and unit.command_feedback_active():
			status = unit.command_feedback_text
		var planned: String = squad.staged_kind(unit)
		if planned != "":
			status = "ON SIGNAL: " + planned
		if not available:
			status = "NOT UNDER YOUR COMMAND YET"
	var status_color: Color = HudStyle.DANGER if dead else (HudStyle.GOLD if squad.staged_kind(unit) != "" else HudStyle.MUTED)
	if unit is AllyCharacter and (unit.command_feedback_active() or unit.alert_active()):
		status_color = HudStyle.DANGER
	draw_string(small, box.position + Vector2(80, 40), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, status_color)
	if unit is AllyCharacter and not dead and available:
		_draw_discipline(Vector2(box.end.x - 44.0, box.position.y + 40.0))
	_health_bar.visible = not dead
	# Order glyph and command link on the right edge.
	var right: float = box.end.x - 12.0
	if unit is AllyCharacter and not dead:
		right = _draw_link(Vector2(right, box.position.y + 14), squad.link_state(unit))
	var icon_name: String = ORDER_ICON.get(order_key, "")
	if icon_name != "" and not dead:
		var icon_rect: Rect2 = Rect2(Vector2(right - 26, box.position.y + 34), Vector2(24, 24))
		draw_texture_rect(_icons[icon_name], icon_rect, false, HudStyle.SPICE_BLUE if order_key == "HOLD" or order_key == "FOLLOW" else HudStyle.SAND)


## Three signal bars; returns the x where the next element may end.
func _draw_link(top_right: Vector2, state: CommandLinkComponent.State) -> float:
	var bars: int = 3
	var color: Color = HudStyle.OK
	match state:
		CommandLinkComponent.State.WEAK_LINK:
			bars = 2
			color = HudStyle.GOLD
		CommandLinkComponent.State.OUT_OF_RANGE:
			bars = 0
			color = HudStyle.DANGER
	for index in range(3):
		var height: float = 6.0 + index * 5.0
		var rect: Rect2 = Rect2(top_right + Vector2(-26 + index * 9, 16 - height), Vector2(6, height))
		draw_rect(rect, color if index < bars else Color(1, 1, 1, 0.12))
	if bars == 0:
		draw_line(top_right + Vector2(-27, -1), top_right + Vector2(-1, 17), HudStyle.DANGER, 2.0)
	return top_right.x


## Fire discipline as a small tag beside the name: blue holds, gold answers
## back, red fires at will.
func _draw_discipline(at: Vector2) -> void:
	var ai: AllyAIController = unit.ai
	var text: String = ai.fire_name().replace("FIRE AT WILL", "AT WILL").replace("RETURN FIRE", "RETURN").replace("HOLD FIRE", "HOLD")
	var color: Color = HudStyle.SPICE_BLUE if ai.holding_fire() else (HudStyle.GOLD if ai.fire_discipline == AllyAIController.Fire.RETURN else HudStyle.DANGER)
	var small: Font = HudStyle.body_font(700)
	var width: float = small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
	# Right-aligned on `at`, beside the order glyph.
	var rect: Rect2 = Rect2(at + Vector2(-width, -13), Vector2(width, 17))
	draw_rect(rect, Color(color, 0.18))
	draw_rect(rect, color, false, 1.0)
	draw_string(small, rect.position + Vector2(6, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
