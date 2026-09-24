class_name TurnSnapshot
extends RefCounted
## Everything a prescient vision can change, captured when the vision begins
## so it can be taken back: the hero, every Harkonnen (alive or not, aware or
## not), the fuel tanks, the mission's objectives and the controller's own
## state. Characters who arrived during the vision are sent away again.
##
## A guard is captured whole - every script variable of the body, its AI,
## perception, weapon, health and shield - so after a rewind he remembers
## exactly what he knew before, and nothing he learnt in the vision.

## The parts of a guard captured whole, by node path.
const ENEMY_PARTS: Array[String] = ["AIController", "Perception", "WeaponController", "HealthComponent", "ShieldComponent"]
## Computed, read-only properties: never written back.
const READ_ONLY: Array[String] = ["can_fire"]

var hero: Dictionary = {}
var enemies: Array[Dictionary] = []
var tanks: Array[Dictionary] = []
var mission: Dictionary = {}
var controller: Dictionary = {}
var combat: Dictionary = {}


static func capture(tree: SceneTree, player: PlayerController, combat_state: Dictionary) -> TurnSnapshot:
	var shot: TurnSnapshot = TurnSnapshot.new()
	var weapon: WeaponController = player.weapon_controller
	shot.hero = {
		"position": player.global_position,
		"aim": player.aim_direction,
		"health": player.health.current_health,
		"crouching": player.is_crouching,
		"shield": player.shield_active(),
		"shield_energy": player.shield.current_energy if player.shield != null else 0.0,
		"slot": player.equipped_slot,
		"ammo": weapon.current_ammo,
		"stored": weapon._stored_ammo.duplicate(),
	}
	for node: Node in tree.get_nodes_in_group("enemies"):
		var enemy: EnemyCharacter = node as EnemyCharacter
		if enemy == null:
			continue
		var parts: Dictionary = {}
		for part in ENEMY_PARTS:
			var node_part: Node = enemy.get_node_or_null(part)
			if node_part != null:
				parts[part] = _vars(node_part)
		shot.enemies.append({
			"node": enemy,
			"position": enemy.global_position,
			"velocity": enemy.velocity,
			"rotation": enemy.aim_pivot.rotation,
			"health": enemy.health.current_health,
			"dead": enemy.health.is_dead,
			"body": _vars(enemy),
			"parts": parts,
		})
	for node: Node in tree.get_nodes_in_group("fuel_tanks"):
		var tank: FuelTank = node as FuelTank
		if tank != null:
			shot.tanks.append({"node": tank, "detonated": tank.detonated, "health": tank.health.current_health})
	var manager: MissionManager = tree.get_first_node_in_group("mission_manager") as MissionManager
	if manager != null:
		shot.mission = manager.snapshot()
	var mission_controller: Node = tree.get_first_node_in_group("mission_controller")
	if mission_controller != null and mission_controller.has_method("vision_snapshot"):
		shot.controller = mission_controller.vision_snapshot()
	shot.combat = combat_state.duplicate(true)
	return shot


func restore(tree: SceneTree, player: PlayerController) -> void:
	# Hero.
	player.global_position = hero.position
	player.velocity = Vector2.ZERO
	player.aim_direction = hero.aim
	player.aim_pivot.rotation = player.aim_direction.angle()
	player.health.current_health = hero.health
	player.health.health_changed.emit(player.health.current_health, player.health.max_health)
	player.set_crouching(hero.crouching)
	if player.shield != null:
		player.set_shield(hero.shield)
		player.shield.current_energy = hero.shield_energy
	if player.equipped_slot != hero.slot:
		player.equip_slot(hero.slot)
	var weapon: WeaponController = player.weapon_controller
	weapon.is_reloading = false
	weapon._stored_ammo = (hero.stored as Dictionary).duplicate()
	weapon.current_ammo = hero.ammo
	weapon.ammo_changed.emit(weapon.current_ammo, weapon.weapon_data.magazine_size)
	# Harkonnen: the ones who were here come back as they were; newcomers go.
	var known: Dictionary = {}
	for entry in enemies:
		var enemy: EnemyCharacter = entry.node
		if not is_instance_valid(enemy):
			continue
		known[enemy] = true
		if enemy.health.is_dead and not entry.dead:
			enemy.revive(entry.health)
		for part: String in entry.parts:
			var node_part: Node = enemy.get_node_or_null(part)
			if node_part != null:
				_apply(node_part, entry.parts[part])
		# The body last: its turn_based setter switches his AI on or off.
		var body: Dictionary = entry.body
		_apply(enemy, body, ["turn_based"])
		enemy.turn_based = body.get("turn_based", enemy.turn_based)
		enemy.global_position = entry.position
		enemy.velocity = entry.velocity
		enemy.aim_pivot.rotation = entry.rotation
		if enemy.has_destination:
			enemy.agent.target_position = enemy.navigation_destination
		enemy.health.health_changed.emit(enemy.health.current_health, enemy.health.max_health)
	for node: Node in tree.get_nodes_in_group("enemies"):
		if not known.has(node):
			node.remove_from_group("enemies")
			node.queue_free()
	for entry in tanks:
		var tank: FuelTank = entry.node
		if is_instance_valid(tank) and tank.detonated and not entry.detonated:
			tank.restore()
		if is_instance_valid(tank):
			tank.health.current_health = entry.health
	var manager: MissionManager = tree.get_first_node_in_group("mission_manager") as MissionManager
	if manager != null and not mission.is_empty():
		manager.restore(mission)
	var mission_controller: Node = tree.get_first_node_in_group("mission_controller")
	if mission_controller != null and mission_controller.has_method("vision_restore") and not controller.is_empty():
		mission_controller.vision_restore(controller)


## Every script variable of a node, arrays and dictionaries copied.
static func _vars(target: Object) -> Dictionary:
	var values: Dictionary = {}
	for property in target.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not READ_ONLY.has(property.name):
			values[property.name] = _copy(target.get(property.name))
	return values


static func _apply(target: Object, values: Dictionary, skip: Array = []) -> void:
	for name: String in values:
		if not skip.has(name):
			target.set(name, _copy(values[name]))


static func _copy(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate()
	if typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value
