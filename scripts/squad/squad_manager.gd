class_name SquadManager
extends Node2D

signal selection_changed
signal command_mode_changed(active: bool)
signal order_issued(order: int)
signal command_rejected(allies: Array)
signal command_blocked(holder: String)

@export var player: PlayerController
@export_range(0.1, 1.0) var command_time_scale: float = 0.4
@export_group("Command link")
## World-space radius around Paul inside which new orders can be issued.
@export var command_range: float = 700.0
## Fraction of the effective range where the link starts warning.
@export_range(0.05, 1.0) var weak_link_fraction: float = 0.75
@export var rejection_display_seconds: float = 2.0
## Tutorial lock; ordinary missions leave squad control available from the start.
@export var commands_enabled: bool = true
var members: Array[AllyCharacter] = []
var selected_members: Array[AllyCharacter] = []
var command_mode: bool = false
var marker_position: Vector2
var marker_attack: bool = false
var rejection_message: String = ""
## Future terrain interference, sandstorms, relays, or Paul progression can
## register a named multiplier here instead of rewriting command_range users.
var command_range_modifiers: Dictionary = {}
var _marker_until: int = 0
var _rejection_until: int = 0


func _ready() -> void:
	TimeScaleManager.reset()
	add_to_group("squad_manager")
	for ally: AllyCharacter in get_tree().get_nodes_in_group("allies"):
		register(ally)
	player.health.died.connect(_on_player_died)


func register(ally: AllyCharacter) -> void:
	if members.has(ally):
		return
	members.append(ally)
	ally.ally_died.connect(_on_ally_died)
	ally.tree_exiting.connect(_on_ally_exiting.bind(ally))


## Single authority for command distance, so modifiers never have to be
## duplicated at each call site.
func get_effective_command_range() -> float:
	var value: float = command_range
	for id in command_range_modifiers:
		value *= float(command_range_modifiers[id])
	return maxf(value, 0.0)


func set_command_range_modifier(id: StringName, multiplier: float) -> void:
	if is_finite(multiplier):
		command_range_modifiers[id] = maxf(multiplier, 0.0)


func clear_command_range_modifier(id: StringName) -> void:
	command_range_modifiers.erase(id)


func link_state(ally: AllyCharacter) -> CommandLinkComponent.State:
	if not is_instance_valid(ally) or ally.command_link == null:
		return CommandLinkComponent.State.OUT_OF_RANGE
	return ally.command_link.state


## Out-of-range allies stay selectable and observable; only new orders stop.
func can_command(ally: AllyCharacter) -> bool:
	return _available(ally) and ally.command_link != null and ally.command_link.can_receive_orders()


## Returns false when another time-slowing system holds the clock; prescience
## and command mode are deliberately mutually exclusive.
func set_command_mode(active: bool) -> bool:
	var wanted: bool = active and is_instance_valid(player) and not player.health.is_dead
	if wanted and not TimeScaleManager.is_available(TimeScaleManager.Source.COMMAND_MODE):
		command_blocked.emit(TimeScaleManager.holder_name())
		return false
	command_mode = wanted
	if command_mode:
		TimeScaleManager.request(TimeScaleManager.Source.COMMAND_MODE, command_time_scale)
	else:
		TimeScaleManager.release(TimeScaleManager.Source.COMMAND_MODE)
	if is_instance_valid(player):
		player.squad_control_locked = command_mode
		if not command_mode:
			player.fire_blocked_until_release = Input.is_action_pressed("fire_primary")
	for ally in members:
		if is_instance_valid(ally):
			ally.command_highlight = command_mode
	command_mode_changed.emit(command_mode)
	return true


func select_slot(slot: int) -> void:
	clear_selection()
	for ally in members:
		if _available(ally) and (slot == 4 or ally.selection_slot == slot):
			selected_members.append(ally)
	_refresh_selection()


func select_ally(ally: AllyCharacter, additive: bool = false) -> void:
	if not additive:
		clear_selection()
	if _available(ally):
		if selected_members.has(ally):
			selected_members.erase(ally)
		else:
			selected_members.append(ally)
	_refresh_selection()


func clear_selection() -> void:
	selected_members.clear()
	_refresh_selection()


func _refresh_selection() -> void:
	for ally in members:
		if is_instance_valid(ally):
			ally.set_selected(selected_members.has(ally))
	selection_changed.emit()


## FOLLOW is a recall, not a tactical order, so it reaches an ally who is out
## of command range. Everything else still needs the link - but a companion sent
## over a ridge must never be strandable with no way to get him back.
func issue_follow() -> void:
	var recipients: Array[AllyCharacter] = []
	for ally in selected_members:
		if _available(ally):
			recipients.append(ally)
	for ally in recipients:
		if not can_command(ally):
			ally.flash_command_feedback("RECALLED")
		ally.ai.issue_order(AllyAIController.Order.FOLLOW)
	if not recipients.is_empty():
		order_issued.emit(AllyAIController.Order.FOLLOW)


func issue_hold() -> void:
	var recipients: Array[AllyCharacter] = _resolve_recipients()
	for ally in recipients:
		ally.ai.issue_order(AllyAIController.Order.HOLD, ally.global_position)
	if not recipients.is_empty():
		order_issued.emit(AllyAIController.Order.HOLD)


func issue_context(point: Vector2) -> void:
	if selected_members.is_empty() or not point.is_finite():
		return
	var recipients: Array[AllyCharacter] = _resolve_recipients()
	if recipients.is_empty():
		return
	var target: Node2D = actor_at(point, "enemies")
	var index: int = 0
	for ally in recipients:
		if not ally.navigation_ready():
			continue
		if target != null:
			ally.ai.issue_order(AllyAIController.Order.ATTACK, point, target)
		else:
			var offset: Vector2 = Vector2((index - (recipients.size() - 1) * 0.5) * 60, 0)
			var destination: Vector2 = NavigationServer2D.map_get_closest_point(ally.agent.get_navigation_map(), point + offset)
			ally.ai.issue_order(AllyAIController.Order.MOVE_TO, destination)
		index += 1
	marker_position = point
	marker_attack = target != null
	_marker_until = Time.get_ticks_msec() + 850
	order_issued.emit(AllyAIController.Order.ATTACK if marker_attack else AllyAIController.Order.MOVE_TO)


## Splits the current selection: connected allies receive the order, the rest
## keep their existing order and produce visible feedback.
func _resolve_recipients() -> Array[AllyCharacter]:
	var recipients: Array[AllyCharacter] = []
	var blocked: Array[AllyCharacter] = []
	for ally in selected_members:
		if not _available(ally):
			continue
		if can_command(ally):
			recipients.append(ally)
		else:
			blocked.append(ally)
	if not blocked.is_empty():
		_report_rejection(blocked)
	return recipients


func _report_rejection(blocked: Array[AllyCharacter]) -> void:
	var names: PackedStringArray = []
	for ally in blocked:
		names.append(ally.data.display_name if ally.data != null else str(ally.name))
		ally.flash_command_feedback("OUT OF COMMAND RANGE")
	rejection_message = "LINK LOST - no orders reach %s" % " / ".join(names)
	_rejection_until = Time.get_ticks_msec() + int(rejection_display_seconds * 1000.0)
	command_rejected.emit(blocked.duplicate())


func rejection_active() -> bool:
	return Time.get_ticks_msec() < _rejection_until


func actor_at(point: Vector2, group: String) -> Node2D:
	var closest: Node2D
	var distance: float = 25.0
	for actor: Node2D in get_tree().get_nodes_in_group(group):
		if not actor.can_process():
			continue
		var health: HealthComponent = HealthComponent.find_on(actor)
		if health == null or health.is_dead:
			continue
		var candidate_distance: float = point.distance_to(actor.global_position)
		if candidate_distance < distance:
			distance = candidate_distance
			closest = actor
	return closest


func _unhandled_input(event: InputEvent) -> void:
	if player.health.is_dead or event.is_echo() or not commands_enabled:
		return
	if event.is_action_pressed("squad_command"):
		set_command_mode(not command_mode)
	elif event.is_action_pressed("squad_paul"):
		clear_selection()
	elif event.is_action_pressed("squad_scout"):
		select_slot(2)
	elif event.is_action_pressed("squad_warrior"):
		select_slot(3)
	elif event.is_action_pressed("squad_all"):
		select_slot(4)
	elif event.is_action_pressed("squad_hold"):
		issue_hold()
	elif event.is_action_pressed("squad_follow"):
		issue_follow()
	elif command_mode and event is InputEventMouseButton and event.pressed:
		var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if event.is_action_pressed("fire_primary"):
			select_ally(actor_at(point, "allies") as AllyCharacter, event.shift_pressed)
		elif event.is_action_pressed("squad_context"):
			issue_context(point)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_links()
	queue_redraw()


func _update_links() -> void:
	if not is_instance_valid(player):
		return
	var effective: float = get_effective_command_range()
	for ally in members:
		if is_instance_valid(ally) and ally.command_link != null:
			ally.command_link.update_link(player.global_position.distance_to(ally.global_position), effective, weak_link_fraction)


func _draw() -> void:
	_draw_command_range()
	_draw_links()
	_draw_marker()


func _draw_command_range() -> void:
	if not is_instance_valid(player):
		return
	var reveal: bool = command_mode or _debug_visible()
	if not reveal:
		for ally in members:
			if _available(ally) and link_state(ally) != CommandLinkComponent.State.CONNECTED:
				reveal = true
				break
	if not reveal:
		return
	var center: Vector2 = to_local(player.global_position)
	var effective: float = get_effective_command_range()
	draw_arc(center, effective, 0, TAU, 96, Color(0.55, 0.88, 0.82, 0.22), 2.0, true)
	draw_arc(center, effective * weak_link_fraction, 0, TAU, 96, Color(0.55, 0.88, 0.82, 0.11), 1.0, true)


func _draw_links() -> void:
	if not is_instance_valid(player):
		return
	for ally in members:
		if not _available(ally) or not ally.selected:
			continue
		var from: Vector2 = to_local(player.global_position)
		var to: Vector2 = to_local(ally.global_position)
		match link_state(ally):
			CommandLinkComponent.State.CONNECTED:
				draw_line(from, to, Color(0.55, 0.95, 0.85, 0.5), 1.5)
			CommandLinkComponent.State.WEAK_LINK:
				_draw_dashes(from, to, 16.0, 10.0, Color(1.0, 0.86, 0.45, 0.6), 1.5)
			_:
				_draw_dashes(from, to, 6.0, 26.0, Color(1.0, 0.5, 0.4, 0.45), 1.0)


func _draw_dashes(from: Vector2, to: Vector2, dash: float, gap: float, color: Color, width: float) -> void:
	var total: float = from.distance_to(to)
	if total < 1.0:
		return
	var step: Vector2 = (to - from) / total
	var travelled: float = 0.0
	while travelled < total:
		var end: float = minf(travelled + dash, total)
		draw_line(from + step * travelled, from + step * end, color, width)
		travelled = end + gap


func _draw_marker() -> void:
	var remaining: float = (_marker_until - Time.get_ticks_msec()) / 850.0
	if remaining <= 0:
		return
	var color: Color = Color(1.0, 0.4, 0.2, remaining) if marker_attack else Color(0.5, 1.0, 0.95, remaining)
	draw_circle(to_local(marker_position), 22 + (1 - remaining) * 12, color, false, 2)
	draw_line(to_local(marker_position) - Vector2(10, 0), to_local(marker_position) + Vector2(10, 0), color, 2)
	draw_line(to_local(marker_position) - Vector2(0, 10), to_local(marker_position) + Vector2(0, 10), color, 2)


func _available(ally: AllyCharacter) -> bool:
	return is_instance_valid(ally) and ally.can_process() and not ally.health.is_dead


func _on_ally_died(ally: AllyCharacter) -> void:
	selected_members.erase(ally)
	_refresh_selection()


func _on_ally_exiting(ally: AllyCharacter) -> void:
	selected_members.erase(ally)
	members.erase(ally)
	selection_changed.emit()


func _on_player_died() -> void:
	set_command_mode(false)


func _exit_tree() -> void:
	TimeScaleManager.reset()
	if is_instance_valid(player):
		player.squad_control_locked = false


## Autoload path lookup, not the global identifier: these scripts can be
## compiled by a --script test harness before autoloads are registered.
func _debug_visible() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	return manager != null and manager.debug_visible
