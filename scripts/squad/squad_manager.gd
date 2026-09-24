class_name SquadManager
extends Node2D
## RTS control for the whole squad - Paul and the Fremen alike. The only place
## player input turns into orders:
##
##   Left click / drag     select a unit, or every unit inside the box
##   Left click an enemy   crysknife (Paul selected): click = quick strike,
##                         hold past the charge threshold = slow strike
##   Right click           move / attack / use, depending on what is under it
##   Double right click    run there; Shift + right click queues a waypoint
##   1 / 2 / 3 / 4         Paul / Scout / Warrior / everyone (twice: camera)
##   E                     arm the crysknife for the next left click
##   Z / X                 Paul's weapon slots
##   C  R  H  G            sneak, reload, hold, follow
##   Space                 pause; orders can still be given while paused

## F sent the plan: how many orders went.
signal signal_given(count: int)
signal selection_changed
signal order_issued(order: int)
signal command_rejected(allies: Array)
signal pause_changed(paused: bool)
signal targeting_changed(mode: int)

enum Targeting { NONE, STRIKE }

const DOUBLE_TAP_MS: int = 350
const DRAG_THRESHOLD: float = 8.0
const PICK_RADIUS: float = 30.0

@export var player: PlayerController
@export_group("Command link")
## World-space radius around Paul inside which new orders reach the Fremen.
@export var command_range: float = 700.0
## Fraction of the effective range where the link starts warning.
@export_range(0.05, 1.0) var weak_link_fraction: float = 0.75
@export var rejection_display_seconds: float = 2.0
## Tutorial lock on the Fremen. Paul is always under the player's control.
@export var commands_enabled: bool = true
var members: Array[AllyCharacter] = []
## Selected Fremen. Paul's selection is `paul_selected`.
var selected_members: Array[AllyCharacter] = []
var paul_selected: bool = false
var paused: bool = false
var targeting: Targeting = Targeting.NONE
var marker_position: Vector2
var marker_attack: bool = false
var rejection_message: String = ""
## Short feedback for the HUD ("PICK A TARGET", "NO BLADE YET"...).
var notice: String = ""
## Future terrain interference, sandstorms, relays, or Paul progression can
## register a named multiplier here instead of rewriting command_range users.
var command_range_modifiers: Dictionary = {}
var dragging: bool = false
## Solo scope: the hero is steered directly; this manager only pauses (P).
var solo_mode: bool = false
## The squad's stance: low or standing, the same for everyone. Paul's stance
## is the truth; the Fremen follow it, whatever their orders.
var squad_low: bool = false
## Solo scope on click orders (the isometric interiors): one hero, always
## selected. A click on the floor walks him to that tile, right-click on an
## enemy fires, left-click on one draws the crysknife; Space dodges, T raises
## the shield and P pauses.
var hero_mode: bool = false:
	set(value):
		hero_mode = value
		if hero_mode:
			select_slot(1)
## Left button held on a target: the blade is being charged. How long it is
## held decides the stroke, in real time so it works while paused.
var blade_charging: bool = false
var _charge_target: Node2D
var _charge_start: int = 0
## The held blade will open a turn-based fight on release, not cut in real time.
var _charge_opens_fight: bool = false
var _drag_start: Vector2
## Orders held for the signal, one per unit: {kind, point, target}. Kinds:
## &"move", &"attack", &"melee" (Paul's knife), &"use". F sends them all at once.
var staged: Dictionary = {}
## How many orders the last signal sent (the tutorial reads it).
var last_signal_count: int = 0
## Fremen put on HOLD by crouching, with the discipline each had before:
## standing gives it back; being spotted turns HOLD into RETURN.
var _sneak_hold: Dictionary = {}
var _marker_until: int = 0
var _rejection_until: int = 0
var _notice_until: int = 0
var _last_key_slot: int = -1
var _last_key_time: int = 0
var _last_context_time: int = 0
var _last_context_point: Vector2 = Vector2.INF


func _ready() -> void:
	TimeScaleManager.reset()
	# Selection, orders and the box keep working while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("squad_manager")
	for ally: AllyCharacter in get_tree().get_nodes_in_group("allies"):
		register(ally)
	player.health.died.connect(_on_player_died)
	call_deferred("select_slot", 1)


func register(ally: AllyCharacter) -> void:
	if members.has(ally):
		return
	members.append(ally)
	ally.ally_died.connect(_on_ally_died)
	ally.tree_exiting.connect(_on_ally_exiting.bind(ally))


# --------------------------------------------------------------------------
# Command link
# --------------------------------------------------------------------------

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


# --------------------------------------------------------------------------
# Pause
# --------------------------------------------------------------------------

func set_paused(value: bool) -> void:
	value = value and _paul_alive()
	if paused == value:
		return
	paused = value
	get_tree().paused = paused
	pause_changed.emit(paused)


# --------------------------------------------------------------------------
# Selection
# --------------------------------------------------------------------------

## 1 Paul, 2 Scout, 3 Warrior, 4 everyone.
func select_slot(slot: int) -> void:
	selected_members.clear()
	paul_selected = (slot == 1 or slot == 4) and _paul_alive()
	if commands_enabled:
		for ally in members:
			if _available(ally) and (slot == 4 or ally.selection_slot == slot):
				selected_members.append(ally)
	_refresh_selection()


func select_ally(ally: AllyCharacter, additive: bool = false) -> void:
	if not additive:
		selected_members.clear()
		paul_selected = false
	if _available(ally) and commands_enabled:
		if selected_members.has(ally):
			selected_members.erase(ally)
		else:
			selected_members.append(ally)
	_refresh_selection()


## Any unit - Paul or a Fremen. Shift toggles it in and out of the selection.
func select_unit(unit: Node2D, additive: bool = false) -> void:
	if unit is AllyCharacter:
		select_ally(unit, additive)
		return
	if unit != player:
		return
	if not additive:
		selected_members.clear()
		paul_selected = _paul_alive()
	else:
		paul_selected = not paul_selected and _paul_alive()
	_refresh_selection()


func select_units(units: Array, additive: bool = false) -> void:
	if not additive:
		selected_members.clear()
		paul_selected = false
	for unit in units:
		if unit == player and _paul_alive():
			paul_selected = true
		elif unit is AllyCharacter and _available(unit) and commands_enabled and not selected_members.has(unit):
			selected_members.append(unit)
	_refresh_selection()


func clear_selection() -> void:
	selected_members.clear()
	paul_selected = hero_mode and _paul_alive()
	_refresh_selection()


## Everything currently selected, Paul first.
func selected_units() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if paul_selected and _paul_alive():
		result.append(player)
	for ally in selected_members:
		if _available(ally):
			result.append(ally)
	return result


func has_selection() -> bool:
	return not selected_units().is_empty()


func _refresh_selection() -> void:
	if is_instance_valid(player):
		player.selected = paul_selected
	for ally in members:
		if is_instance_valid(ally):
			ally.set_selected(selected_members.has(ally))
	if not paul_selected:
		cancel_blade_charge()
		if targeting != Targeting.NONE:
			set_targeting(Targeting.NONE)
	selection_changed.emit()


# --------------------------------------------------------------------------
# Orders
# --------------------------------------------------------------------------

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
		BarkLayer.say(ally, "WITH YOU.", BarkLayer.CALM)
	if not recipients.is_empty():
		order_issued.emit(AllyAIController.Order.FOLLOW)


## Fremen hold their ground; Paul simply stops.
func issue_hold() -> void:
	# Hold also calls off whatever the selection had planned.
	for unit in selected_units():
		staged.erase(unit)
	if paul_selected and _paul_alive():
		player.stop()
	var recipients: Array[AllyCharacter] = _resolve_recipients()
	for ally in recipients:
		ally.ai.issue_order(AllyAIController.Order.HOLD, ally.global_position)
		BarkLayer.say(ally, "HOLDING.", BarkLayer.CALM)
	if not recipients.is_empty():
		order_issued.emit(AllyAIController.Order.HOLD)


## Right click. What is under the cursor decides the order.
func issue_context(point: Vector2, queue: bool = false, run: bool = false) -> void:
	if not point.is_finite() or not has_selection():
		return
	# A direct order replaces a plan.
	for unit in selected_units():
		staged.erase(unit)
	var enemy: Node2D = _click_target(point)
	if hero_mode and enemy != null and _open_fight(enemy, TurnRules.Attack.FIRE):
		return
	var usable: Node2D = interactable_at(point) if enemy == null else null
	var paul_ordered: bool = false
	if paul_selected and _paul_alive():
		paul_ordered = true
		if enemy != null:
			# A guard or a fuel tank: Paul shoots it, once per click.
			player.attack(enemy)
			var weapon: WeaponController = player.weapon_controller
			if weapon.current_ammo <= 0 and not weapon.is_reloading:
				flash_notice("EMPTY - PRESS R TO RELOAD")
		elif usable != null:
			player.interact_with(usable)
		elif queue:
			player.queue_move(_tile_point(point))
		else:
			point = _tile_point(point)
			player.move_to(point, run)
	var recipients: Array[AllyCharacter] = _resolve_recipients()
	var index: int = 0
	for ally in recipients:
		if not ally.navigation_ready():
			continue
		if enemy != null and ordered_target(enemy):
			ally.ai.issue_order(AllyAIController.Order.ATTACK, point, enemy)
			BarkLayer.say(ally, "ON HIM." if enemy.is_in_group("enemies") else "ON IT.", BarkLayer.CALM)
		else:
			# Fan out beside the click so nobody queues for the same spot. Paul
			# takes the click itself, so the Fremen flank him: -1, +1, -2...
			var slot: float = index - (recipients.size() - 1) * 0.5
			if paul_ordered:
				slot = float(floori(index / 2.0) + 1) * (-1.0 if index % 2 == 0 else 1.0)
			var destination: Vector2 = NavigationServer2D.map_get_closest_point(ally.agent.get_navigation_map(), point + Vector2(slot * 60.0, 0.0))
			if not reachable(ally, destination):
				# Not a silent no: he says so, and the marker turns red.
				BarkLayer.say(ally, "NO WAY THERE.", BarkLayer.WARN)
				BarkLayer.ping(get_tree(), point, BarkLayer.WARN)
				index += 1
				continue
			ally.ai.issue_order(AllyAIController.Order.MOVE_TO, destination)
			BarkLayer.say(ally, "MOVING.", BarkLayer.CALM)
		index += 1
	if not paul_ordered and recipients.is_empty():
		return
	marker_position = point
	marker_attack = enemy != null
	_marker_until = Time.get_ticks_msec() + 850
	order_issued.emit(AllyAIController.Order.ATTACK if marker_attack else AllyAIController.Order.MOVE_TO)


## Ctrl + right-click: plan, do not act. Each selected unit keeps one order
## for the signal; `melee` (Ctrl + left-click on a guard) plans Paul's knife.
func stage_context(point: Vector2, melee: bool = false) -> void:
	if not point.is_finite() or not has_selection():
		return
	var enemy: Node2D = _click_target(point)
	var usable: Node2D = interactable_at(point) if enemy == null else null
	var planned: int = 0
	var fremen: Array[AllyCharacter] = []
	for unit in selected_units():
		if unit is AllyCharacter:
			fremen.append(unit)
	var paul_plans: bool = paul_selected and _paul_alive()
	if paul_plans:
		if melee and enemy != null and enemy.is_in_group("enemies") and player.melee.enabled:
			staged[player] = {"kind": &"melee", "point": enemy.global_position, "target": enemy}
		elif enemy != null:
			staged[player] = {"kind": &"attack", "point": enemy.global_position, "target": enemy}
		elif usable != null:
			staged[player] = {"kind": &"use", "point": usable.global_position, "target": usable}
		else:
			staged[player] = {"kind": &"move", "point": _tile_point(point), "target": null}
		planned += 1
	var index: int = 0
	for ally in fremen:
		if enemy != null and ordered_target(enemy):
			staged[ally] = {"kind": &"attack", "point": enemy.global_position, "target": enemy}
		else:
			# The same fan-out as a direct order, fixed now so the plan shows it.
			var slot: float = index - (fremen.size() - 1) * 0.5
			if paul_plans:
				slot = float(floori(index / 2.0) + 1) * (-1.0 if index % 2 == 0 else 1.0)
			var destination: Vector2 = point + Vector2(slot * 60.0, 0.0)
			if ally.navigation_ready():
				destination = NavigationServer2D.map_get_closest_point(ally.agent.get_navigation_map(), destination)
			staged[ally] = {"kind": &"move", "point": destination, "target": null}
		index += 1
		planned += 1
	if planned > 0:
		var count: int = staged.size()
		flash_notice("PLANNED - %d ORDER%s WAIT FOR YOUR SIGNAL (F)" % [count, "" if count == 1 else "S"], 2.4)
		queue_redraw()


## F: every planned order goes at the same instant. The command link still
## decides who hears it; a Fremen out of range is told so, as with any order.
func give_signal() -> void:
	var plan: Dictionary = staged.duplicate()
	staged.clear()
	last_signal_count = 0
	if plan.is_empty():
		flash_notice("NOTHING PLANNED - CTRL + RIGHT-CLICK TO PLAN AN ORDER")
		return
	var blocked: Array[AllyCharacter] = []
	for unit: Node2D in plan:
		if not is_instance_valid(unit):
			continue
		var order: Dictionary = plan[unit]
		var target: Node2D = order.target if is_instance_valid(order.target) else null
		if order.kind != &"move" and target == null:
			continue
		if unit == player:
			if not _paul_alive():
				continue
			match order.kind:
				&"move":
					player.move_to(order.point, false)
				&"attack":
					player.attack(target)
				&"melee":
					player.melee_strike(target, false)
				&"use":
					player.interact_with(target)
			last_signal_count += 1
			continue
		var ally: AllyCharacter = unit as AllyCharacter
		if ally == null or not _available(ally):
			continue
		if not can_command(ally):
			blocked.append(ally)
			continue
		if order.kind == &"attack":
			ally.ai.issue_order(AllyAIController.Order.ATTACK, target.global_position, target)
		else:
			ally.ai.issue_order(AllyAIController.Order.MOVE_TO, order.point)
		BarkLayer.say(ally, "NOW!", BarkLayer.CALM)
		last_signal_count += 1
	if not blocked.is_empty():
		_report_rejection(blocked)
	if last_signal_count > 0:
		flash_notice("ON MY SIGNAL - %d GO" % last_signal_count, 2.0)
	else:
		flash_notice("NOBODY HEARD THE SIGNAL", 2.0)
	signal_given.emit(last_signal_count)
	queue_redraw()


## What a Fremen will shoot when told to: a Harkonnen, a training target, a
## fuel tank. Never chosen on his own - only on the player's order.
static func ordered_target(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false
	if target is FuelTank:
		return not (target as FuelTank).detonated
	return target.is_in_group("enemies") or target.is_in_group("training_targets")


## Whether a unit can walk to `point` at all: its navigation path ends there,
## not at the edge of a section it cannot leave. Before the map is ready,
## assume yes.
func reachable(unit: Node2D, point: Vector2) -> bool:
	var agent: NavigationAgent2D = unit.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if agent == null or NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) <= 0:
		return true
	var path: PackedVector2Array = NavigationServer2D.map_get_path(agent.get_navigation_map(), unit.global_position, point, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(point) <= 48.0


## What `unit` is waiting to do on the signal, for its card ("" if nothing).
func staged_kind(unit: Node2D) -> String:
	if not staged.has(unit):
		return ""
	var names: Dictionary = {&"move": "MOVE", &"attack": "ATTACK", &"melee": "KNIFE", &"use": "USE"}
	return names.get(staged[unit].kind, "")


## In an isometric interior a move goes to the centre of the clicked tile.
func _tile_point(point: Vector2) -> Vector2:
	if not player.isometric:
		return point
	var level: IsoLevel = get_tree().get_first_node_in_group("iso_level") as IsoLevel
	var cell: Vector2i = IsoMath.world_to_cell(point)
	if level != null and level.is_wall(cell):
		return point
	return IsoMath.cell_to_world(cell)


## C: the whole squad goes low, or stands - never half and half.
func toggle_sneak() -> void:
	set_stance(not squad_low)


func set_stance(low: bool) -> void:
	var changed: bool = low != squad_low
	squad_low = low
	if _paul_alive():
		player.set_crouching(low)
	for member in members:
		if is_instance_valid(member):
			member.sneaking = low
			if not member.health.is_dead:
				member.is_crouching = low
	if changed:
		_sneak_discipline(low)


## A crouching squad holds its fire until it is seen: getting into position
## must not start the fight. Standing up gives each Fremen his own back.
func _sneak_discipline(low: bool) -> void:
	if low:
		for member in members:
			if is_instance_valid(member) and member.ai.fire_discipline != AllyAIController.Fire.HOLD:
				_sneak_hold[member] = member.ai.fire_discipline
				member.ai.fire_discipline = AllyAIController.Fire.HOLD
		return
	for member: AllyCharacter in _sneak_hold:
		if is_instance_valid(member):
			member.ai.fire_discipline = _sneak_hold[member]
	_sneak_hold.clear()


## Spotted while low: the ones holding because of the stance answer back now.
func _spotted_while_low() -> void:
	var holding: Array[AllyCharacter] = []
	for member: AllyCharacter in _sneak_hold:
		if is_instance_valid(member) and member.ai.fire_discipline == AllyAIController.Fire.HOLD:
			holding.append(member)
	if holding.is_empty():
		return
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyCharacter = node as EnemyCharacter
		if enemy != null and not enemy.health.is_dead and enemy.ai.state == EnemyAIController.State.COMBAT:
			for member in holding:
				member.ai.fire_discipline = AllyAIController.Fire.RETURN
			flash_notice("SPOTTED - THE FREMEN RETURN FIRE")
			return


## B: the selected Fremen (or all of them, with only Paul selected) move to
## the next fire discipline: HOLD, RETURN, AT WILL.
func cycle_fire_discipline() -> void:
	var chosen: Array[AllyCharacter] = []
	for ally in selected_members:
		if _available(ally):
			chosen.append(ally)
	if chosen.is_empty():
		for ally in members:
			if _available(ally):
				chosen.append(ally)
	if chosen.is_empty():
		return
	var next: AllyAIController.Fire = ((chosen[0].ai.fire_discipline + 1) % 3) as AllyAIController.Fire
	var names: PackedStringArray = []
	for ally in chosen:
		ally.ai.fire_discipline = next
		# The player's word replaces the stance's.
		_sneak_hold.erase(ally)
		BarkLayer.say(ally, ["HOLDING FIRE.", "ON RETURN FIRE.", "FIRE AT WILL."][next], BarkLayer.CALM)
		names.append(ally.data.display_name.to_upper() if ally.data != null else str(ally.name))
	var text: String = "%s: %s" % [", ".join(names), AllyAIController.FIRE_NAMES[next]]
	if chosen[0].ai.hold_fire:
		text += "  (THE DRILL: HOLDING FOR NOW)"
	flash_notice(text, 2.4)


func reload_selected() -> void:
	for unit in selected_units():
		if unit == player:
			player.weapon_controller.start_reload()
		elif unit is AllyCharacter:
			unit.weapon.start_reload()


## E arms the crysknife; the next left click (or hold) on a target delivers it.
## Clicking an enemy with Paul selected does the same without arming first.
func set_targeting(mode: Targeting) -> void:
	if mode != Targeting.NONE:
		if not paul_selected or not _paul_alive():
			flash_notice("SELECT PAUL FOR THE CRYSKNIFE")
			mode = Targeting.NONE
		elif not player.melee.enabled:
			flash_notice("THE CRYSKNIFE IS NOT YOURS YET")
			mode = Targeting.NONE
	if targeting == mode:
		return
	targeting = mode
	targeting_changed.emit(targeting)


## Seconds the button must be held for the slow, shield-penetrating stroke.
func slow_hold_seconds() -> float:
	return player.melee.slow_charge_threshold if is_instance_valid(player) else 0.35


## 0..1 while the left button is held on a target; 1 means release = slow.
func blade_charge_ratio() -> float:
	if not blade_charging:
		return 0.0
	# Paul's own raised blade is the truth; the clock only covers a press
	# that landed while his last stroke was still recovering.
	if player.melee.state == MeleeController.State.CHARGING:
		return 1.0 if player.melee.slow_ready else player.melee.charge_ratio()
	var held: float = (Time.get_ticks_msec() - _charge_start) / 1000.0
	return clampf(held / maxf(slow_hold_seconds(), 0.01), 0.0, 1.0)


func _begin_blade_charge(target: Node2D) -> void:
	if not player.melee.enabled:
		flash_notice("THE CRYSKNIFE IS NOT YOURS YET")
		return
	blade_charging = true
	_charge_target = target
	_charge_start = Time.get_ticks_msec()
	# In an interior the cut opens the fight: Paul holds still while the
	# player decides quick or slow, and strikes first on release.
	var combat: TurnCombat = _turn_combat()
	_charge_opens_fight = combat != null and combat.can_open_with(target, TurnRules.Attack.QUICK_KNIFE)
	if not _charge_opens_fight:
		# The blade comes up now, not on release.
		player.melee_hold(target)
	marker_position = target.global_position
	marker_attack = true
	_marker_until = Time.get_ticks_msec() + 850


## Button released: a quick click cuts fast, a held one commits the slow stroke.
func _release_blade_charge() -> void:
	var slow: bool = blade_charge_ratio() >= 1.0
	var target: Node2D = _charge_target
	var opens: bool = _charge_opens_fight
	blade_charging = false
	_charge_target = null
	_charge_opens_fight = false
	set_targeting(Targeting.NONE)
	if not _paul_alive():
		return
	if opens:
		var kind: TurnRules.Attack = TurnRules.Attack.SLOW_KNIFE if slow else TurnRules.Attack.QUICK_KNIFE
		if _open_fight(target, kind):
			return
		# Out of reach for one turn: the real-time order walks him up.
		player.melee_strike(target, slow)
		return
	player.melee_let_go(slow)


func cancel_blade_charge() -> void:
	var was_charging: bool = blade_charging
	blade_charging = false
	_charge_target = null
	_charge_opens_fight = false
	if was_charging and _paul_alive() and player.order == PlayerController.Order.MELEE:
		player.stop()


## An interior's turn-based fights, if this level has them.
func _turn_combat() -> TurnCombat:
	return get_tree().get_first_node_in_group("turn_combat") as TurnCombat


## Whoever attacks first acts first: in an interior, an attack Paul could make
## on his first turn opens the fight with it. False leaves it to real time.
func _open_fight(target: Node2D, kind: TurnRules.Attack) -> bool:
	var combat: TurnCombat = _turn_combat()
	if combat == null or not combat.can_open_with(target, kind):
		return false
	combat.open_with_attack(target, kind)
	return true


func flash_notice(text: String, seconds: float = 1.8) -> void:
	notice = text
	_notice_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func notice_active() -> bool:
	return Time.get_ticks_msec() < _notice_until


## Splits the selected Fremen: connected allies receive the order, the rest
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


# --------------------------------------------------------------------------
# Picking
# --------------------------------------------------------------------------

func actor_at(point: Vector2, group: String, radius: float = PICK_RADIUS) -> Node2D:
	var closest: Node2D
	var distance: float = radius
	for actor: Node2D in get_tree().get_nodes_in_group(group):
		if not actor.can_process() and not get_tree().paused:
			continue
		# Behind a door the level has not opened yet: not in play.
		if actor.get_meta("dormant", false):
			continue
		var health: HealthComponent = HealthComponent.find_on(actor)
		if health == null or health.is_dead:
			continue
		var candidate_distance: float = point.distance_to(actor.global_position)
		if candidate_distance < distance:
			distance = candidate_distance
			closest = actor
	return closest


## Anything Paul may attack: Harkonnen, and the tutorial's training targets.
func hostile_at(point: Vector2) -> Node2D:
	var enemy: Node2D = actor_at(point, "enemies")
	if enemy == null and hero_mode:
		# Close up, the player clicks a guard's body, not his feet.
		enemy = actor_at(point + Vector2(0, 40), "enemies", PICK_RADIUS + 6.0)
	return enemy if enemy != null else actor_at(point, "training_targets")


## A fuel tank under the cursor that a shot could set off.
func tank_at(point: Vector2) -> FuelTank:
	var best: FuelTank
	var distance: float = 34.0
	for node: Node in get_tree().get_nodes_in_group("fuel_tanks"):
		var tank: FuelTank = node as FuelTank
		if tank == null or tank.detonated or tank.get_meta("dormant", false):
			continue
		var gap: float = point.distance_to(tank.global_position)
		if gap < distance:
			distance = gap
			best = tank
	return best


## What a click here is aimed at: a tank right under the cursor beats a
## guard caught only by the lenient body probe.
func _click_target(point: Vector2) -> Node2D:
	var enemy: Node2D = hostile_at(point)
	var tank: FuelTank = tank_at(point)
	if tank == null:
		return enemy
	if enemy == null or point.distance_to(tank.global_position) < point.distance_to(enemy.global_position):
		return tank
	return enemy


## The unit under the cursor: the nearest of Paul and the Fremen, measured to
## the feet or to the body above them, since the player clicks the figure.
func unit_at(point: Vector2) -> Node2D:
	if hero_mode:
		return null
	var candidates: Array[Node2D] = []
	if _paul_alive():
		candidates.append(player)
	if commands_enabled:
		for ally in members:
			if _available(ally):
				candidates.append(ally)
	var best: Node2D = null
	var best_distance: float = PICK_RADIUS + 12.0
	for unit in candidates:
		var gap: float = minf(point.distance_to(unit.global_position), (point + Vector2(0, 40)).distance_to(unit.global_position))
		if gap < best_distance:
			best_distance = gap
			best = unit
	return best


## Spice machines and hold-to-use points (beacons, sabotage panels).
func interactable_at(point: Vector2) -> Node2D:
	var best: Node2D
	# Interior consoles stand up off the floor: a click on the box counts.
	var distance: float = 110.0 if hero_mode else 70.0
	for node: Node in get_tree().get_nodes_in_group("interaction_points") + get_tree().get_nodes_in_group("worm_machines"):
		var candidate: Node2D = node as Node2D
		if candidate == null or not (candidate is InteractionPoint or candidate is SpiceMachine):
			continue
		if candidate is InteractionPoint and not candidate.available():
			continue
		var candidate_distance: float = point.distance_to(candidate.global_position)
		if candidate_distance < distance:
			distance = candidate_distance
			best = candidate
	return best


## What a right click here would do, for the cursor readout.
func context_kind(point: Vector2) -> String:
	if blade_charging:
		return "SLOW STRIKE - RELEASE" if blade_charge_ratio() >= 1.0 else "QUICK STRIKE - HOLD FOR SLOW"
	if targeting != Targeting.NONE:
		return "STRIKE" if hostile_at(point) != null else "PICK TARGET"
	if unit_at(point) != null:
		return "SELECT"
	if not has_selection():
		return ""
	var aimed: Node2D = _click_target(point)
	if aimed is FuelTank:
		return "FIRE" if paul_selected else "MOVE"
	if aimed != null:
		return "LEFT: KNIFE · RIGHT: FIRE" if paul_selected and player.melee.enabled else "ATTACK"
	if paul_selected and interactable_at(point) != null:
		return "USE"
	return "MOVE"


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player):
		return
	if event is InputEventMouseMotion:
		if dragging:
			queue_redraw()
		return
	if player.health.is_dead:
		return
	if solo_mode:
		if event.is_action_pressed("solo_pause") and not event.is_echo():
			set_paused(not paused)
			get_viewport().set_input_as_handled()
		return
	if hero_mode and _hero_key(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		_handle_mouse(event as InputEventMouseButton)
		return
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed("pause_game"):
		set_paused(not paused)
	elif event.is_action_pressed("squad_paul"):
		_select_key(1)
	elif event.is_action_pressed("squad_scout"):
		_select_key(2)
	elif event.is_action_pressed("squad_warrior"):
		_select_key(3)
	elif event.is_action_pressed("squad_all"):
		_select_key(4)
	elif event.is_action_pressed("squad_hold"):
		issue_hold()
	elif event.is_action_pressed("squad_follow"):
		issue_follow()
	elif event.is_action_pressed("crouch"):
		toggle_sneak()
	elif event.is_action_pressed("fire_discipline"):
		cycle_fire_discipline()
	elif event.is_action_pressed("squad_signal"):
		give_signal()
	elif event.is_action_pressed("reload"):
		reload_selected()
	elif event.is_action_pressed("melee_attack"):
		set_targeting(Targeting.NONE if targeting == Targeting.STRIKE else Targeting.STRIKE)
	elif event.is_action_pressed("weapon_1") and paul_selected:
		player.equip_slot(0)
	elif event.is_action_pressed("weapon_2") and paul_selected:
		player.equip_slot(1)
	elif event.is_action_pressed("ui_cancel") and (targeting != Targeting.NONE or blade_charging):
		cancel_blade_charge()
		set_targeting(Targeting.NONE)
	else:
		return
	get_viewport().set_input_as_handled()


## The hero's own keys, and the squad keys that mean nothing with one hero.
func _hero_key(event: InputEvent) -> bool:
	if event is InputEventMouseButton or event.is_echo() or not event.is_pressed():
		return false
	if event.is_action_pressed("solo_pause"):
		set_paused(not paused)
	elif event.is_action_pressed("dodge"):
		if not paused:
			player.try_dodge()
	elif event.is_action_pressed("shield_toggle"):
		player.set_shield(not player.shield_active())
	elif event.is_action_pressed("squad_paul") or event.is_action_pressed("squad_scout") or event.is_action_pressed("squad_warrior") or event.is_action_pressed("squad_all"):
		var camera: TacticalCamera = player.get_node_or_null("TacticalCamera") as TacticalCamera
		if camera != null:
			camera.center_on(player.global_position)
	elif event.is_action_pressed("squad_hold") or event.is_action_pressed("squad_follow"):
		pass
	else:
		return false
	return true


func _handle_mouse(event: InputEventMouseButton) -> void:
	var point: Vector2 = get_canvas_transform().affine_inverse() * event.position
	if event.ctrl_pressed and event.pressed and not hero_mode and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		# Ctrl: plan for the signal instead of acting now. Ctrl + left-click on
		# a guard plans Paul's knife; anything else is a plain plan.
		stage_context(point, event.button_index == MOUSE_BUTTON_LEFT and hostile_at(point) != null)
		get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hostile: Node2D = hostile_at(point)
			if targeting != Targeting.NONE:
				if hostile != null:
					_begin_blade_charge(hostile)
				else:
					flash_notice("LEFT-CLICK A TARGET · RIGHT-CLICK CANCELS")
			elif hostile != null and paul_selected and _paul_alive():
				_begin_blade_charge(hostile)
			elif hero_mode:
				# One hero: a left click on the floor is a move, as in Crusader.
				_context_click(point, event.shift_pressed)
			else:
				dragging = true
				_drag_start = point
		elif blade_charging:
			_release_blade_charge()
		elif dragging:
			dragging = false
			_finish_drag(point, event.shift_pressed)
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if blade_charging or targeting != Targeting.NONE:
			cancel_blade_charge()
			set_targeting(Targeting.NONE)
		else:
			_context_click(point, event.shift_pressed)
		get_viewport().set_input_as_handled()


## A second click on the same spot in quick succession runs.
func _context_click(point: Vector2, queue: bool) -> void:
	var now: int = Time.get_ticks_msec()
	var run: bool = now - _last_context_time <= DOUBLE_TAP_MS and point.distance_to(_last_context_point) <= 60.0
	_last_context_time = now
	_last_context_point = point
	issue_context(point, queue, run)


func _finish_drag(point: Vector2, additive: bool) -> void:
	var zoom: float = maxf(get_canvas_transform().get_scale().x, 0.01)
	if _drag_start.distance_to(point) * zoom < DRAG_THRESHOLD:
		var unit: Node2D = unit_at(point)
		if unit != null:
			select_unit(unit, additive)
		elif not additive:
			clear_selection()
		return
	var box: Rect2 = Rect2(_drag_start, Vector2.ZERO).expand(point)
	var inside: Array = []
	if _paul_alive() and box.has_point(player.global_position):
		inside.append(player)
	for ally in members:
		if _available(ally) and box.has_point(ally.global_position):
			inside.append(ally)
	select_units(inside, additive)


## Pressing the same number twice jumps the camera to that unit.
func _select_key(slot: int) -> void:
	var now: int = Time.get_ticks_msec()
	var repeated: bool = slot == _last_key_slot and now - _last_key_time <= DOUBLE_TAP_MS
	_last_key_slot = slot
	_last_key_time = now
	select_slot(slot)
	if repeated:
		var units: Array[Node2D] = selected_units()
		var camera: TacticalCamera = player.get_node_or_null("TacticalCamera") as TacticalCamera
		if camera != null and not units.is_empty():
			camera.center_on(units[0].global_position)


# --------------------------------------------------------------------------
# Runtime
# --------------------------------------------------------------------------

func _process(_delta: float) -> void:
	# Anything that stands Paul up (a run order, a tutorial) stands everyone.
	if _paul_alive() and player.is_crouching != squad_low:
		set_stance(player.is_crouching)
	_spotted_while_low()
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
	if solo_mode:
		return
	_draw_command_range()
	_draw_links()
	_draw_staged()
	_draw_marker()
	_draw_box()


func _draw_command_range() -> void:
	if not is_instance_valid(player):
		return
	var reveal: bool = not selected_members.is_empty() or _debug_visible()
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


## The plan: a dashed line along the route each unit will walk (gold), red
## where it crosses a guard's view as he stands now, and red rings on what it
## will attack. In Paul's vision the plan is drawn by the vision, in time.
func _draw_staged() -> void:
	var font: Font = HudStyle.body_font(700)
	var vision: bool = _paul_alive() and player.prescience != null and player.prescience.active
	var watchers: Array[EnemyCharacter] = []
	if not vision:
		watchers = _known_guards()
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for unit: Node2D in staged:
		if not is_instance_valid(unit):
			continue
		var order: Dictionary = staged[unit]
		var target: Node2D = order.target if is_instance_valid(order.target) else null
		var at: Vector2 = target.global_position if target != null else order.point
		var hostile: bool = order.kind == &"attack" or order.kind == &"melee"
		var color: Color = Color(1.0, 0.45, 0.3, 0.85) if hostile else Color(1.0, 0.82, 0.4, 0.85)
		if not vision:
			_draw_plan_route(plan_route(unit, at), watchers, space)
		var number: String = "1" if unit == player else str((unit as AllyCharacter).selection_slot)
		if hostile:
			draw_arc(to_local(at), 26.0, 0, TAU, 32, color, 2.5, true)
			var label: String = number + (" KNIFE" if order.kind == &"melee" else "")
			draw_string(font, to_local(at) + Vector2(24, -24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		else:
			draw_circle(to_local(at), 16.0, Color(color, 0.18))
			draw_arc(to_local(at), 16.0, 0, TAU, 24, color, 2.0, true)
			draw_string(font, to_local(at) + Vector2(-5, 6), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


## The route a planned unit will walk: a read-only navigation query.
func plan_route(unit: Node2D, to: Vector2) -> PackedVector2Array:
	var agent: NavigationAgent2D = unit.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if agent != null and NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) > 0:
		var route: PackedVector2Array = NavigationServer2D.map_get_path(agent.get_navigation_map(), unit.global_position, to, true)
		if route.size() >= 2:
			return route
	return PackedVector2Array([unit.global_position, to])


## Guards the squad can see: only their views are shown, never a hidden one's.
func _known_guards() -> Array[EnemyCharacter]:
	var result: Array[EnemyCharacter] = []
	var recon: ReconManager = get_tree().get_first_node_in_group("recon_manager") as ReconManager
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyCharacter = node as EnemyCharacter
		if enemy == null or enemy.health.is_dead or enemy.get_meta("dormant", false) or not enemy.can_process():
			continue
		var known: bool = recon.is_enemy_visible(enemy) if is_instance_valid(recon) else (_paul_alive() and player.recon != null and player.recon.can_see(enemy))
		if known:
			result.append(enemy)
	return result


## Whether a point along a route is in a guard's view as he stands now.
func in_view_now(point: Vector2, watchers: Array[EnemyCharacter], space: PhysicsDirectSpaceState2D) -> bool:
	for enemy in watchers:
		var facing: Vector2 = Vector2.RIGHT.rotated(enemy.aim_pivot.global_rotation)
		if FuturePredictor.sees_from(enemy, enemy.global_position, facing, point, space):
			return true
	return false


## Dashes along the route, each gold or red by whether that stretch is watched.
func _draw_plan_route(route: PackedVector2Array, watchers: Array[EnemyCharacter], space: PhysicsDirectSpaceState2D) -> void:
	var clear: Color = Color(1.0, 0.82, 0.4, 0.85)
	var watched: Color = Color(1.0, 0.3, 0.25, 0.95)
	for index in range(1, route.size()):
		var a: Vector2 = route[index - 1]
		var b: Vector2 = route[index]
		var length: float = a.distance_to(b)
		var travelled: float = 0.0
		while travelled < length:
			var end: float = minf(travelled + 12.0, length)
			var from: Vector2 = a.lerp(b, travelled / maxf(length, 0.001))
			var to: Vector2 = a.lerp(b, end / maxf(length, 0.001))
			var seen: bool = not watchers.is_empty() and in_view_now(from.lerp(to, 0.5), watchers, space)
			draw_line(to_local(from), to_local(to), watched if seen else clear, 3.0 if seen else 2.0)
			travelled = end + 8.0


func _draw_marker() -> void:
	var remaining: float = (_marker_until - Time.get_ticks_msec()) / 850.0
	if remaining <= 0:
		return
	var color: Color = Color(1.0, 0.4, 0.2, remaining) if marker_attack else Color(0.5, 1.0, 0.95, remaining)
	draw_circle(to_local(marker_position), 22 + (1 - remaining) * 12, color, false, 2)
	draw_line(to_local(marker_position) - Vector2(10, 0), to_local(marker_position) + Vector2(10, 0), color, 2)
	draw_line(to_local(marker_position) - Vector2(0, 10), to_local(marker_position) + Vector2(0, 10), color, 2)


func _draw_box() -> void:
	if not dragging:
		return
	var here: Vector2 = get_global_mouse_position()
	var zoom: float = maxf(get_canvas_transform().get_scale().x, 0.01)
	if _drag_start.distance_to(here) * zoom < DRAG_THRESHOLD:
		return
	var box: Rect2 = Rect2(to_local(_drag_start), Vector2.ZERO).expand(to_local(here))
	draw_rect(box, Color(0.55, 0.95, 0.75, 0.1))
	draw_rect(box, Color(0.55, 0.95, 0.75, 0.8), false, 1.5 / zoom)


func _available(ally: AllyCharacter) -> bool:
	return is_instance_valid(ally) and (ally.can_process() or get_tree().paused) and not ally.health.is_dead


func _paul_alive() -> bool:
	return is_instance_valid(player) and not player.health.is_dead


func _on_ally_died(ally: AllyCharacter) -> void:
	selected_members.erase(ally)
	_refresh_selection()


func _on_ally_exiting(ally: AllyCharacter) -> void:
	selected_members.erase(ally)
	members.erase(ally)
	selection_changed.emit()


func _on_player_died() -> void:
	cancel_blade_charge()
	set_targeting(Targeting.NONE)
	set_paused(false)
	paul_selected = false
	_refresh_selection()


func _exit_tree() -> void:
	TimeScaleManager.reset()
	if paused and is_inside_tree():
		get_tree().paused = false


## Autoload path lookup, not the global identifier: these scripts can be
## compiled by a --script test harness before autoloads are registered.
func _debug_visible() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	return manager != null and manager.debug_visible
