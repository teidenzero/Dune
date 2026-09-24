class_name ReconManager
extends Node2D
## Minimal shared-reconnaissance bookkeeping: which hostiles any friendly
## observer can currently see, where each was last seen, and by whom.
##
## This is data architecture only. No fog-of-war mask, visibility texture, or
## hidden-terrain rendering exists; every enemy the mission spawns is still
## drawn normally. A later milestone can consume these contacts to hide
## unobserved actors without changing the observer components.

signal contact_gained(enemy: Node2D)
signal contact_lost(enemy: Node2D)

@export var scan_interval: float = 0.25
@export var hostile_group: StringName = &"enemies"

var observers: Array[ReconObserverComponent] = []
## instance id -> {enemy, visible, last_seen_position, last_seen_time, observer}
var contacts: Dictionary = {}
var _scan_remaining: float = 0.0


func _ready() -> void:
	add_to_group("recon_manager")
	call_deferred("refresh_observers")


func refresh_observers() -> void:
	observers.clear()
	for node: Node in get_tree().get_nodes_in_group("recon_observers"):
		var observer: ReconObserverComponent = node as ReconObserverComponent
		if observer != null:
			observers.append(observer)


func register_observer(observer: ReconObserverComponent) -> void:
	if observer != null and not observers.has(observer):
		observers.append(observer)


func unregister_observer(observer: ReconObserverComponent) -> void:
	observers.erase(observer)


func active_observers() -> Array[ReconObserverComponent]:
	var result: Array[ReconObserverComponent] = []
	for observer in observers:
		if is_instance_valid(observer) and observer.is_active():
			result.append(observer)
	return result


func is_enemy_visible(enemy: Node2D) -> bool:
	var contact: Dictionary = get_contact(enemy)
	return contact.get("visible", false)


func get_contact(enemy: Node2D) -> Dictionary:
	if not is_instance_valid(enemy):
		return {}
	return contacts.get(enemy.get_instance_id(), {})


func get_last_seen_position(enemy: Node2D) -> Vector2:
	var contact: Dictionary = get_contact(enemy)
	return contact.get("last_seen_position", Vector2.INF)


## Seconds since the squad last saw this enemy, or -1.0 if it was never seen.
func get_last_seen_age(enemy: Node2D) -> float:
	var contact: Dictionary = get_contact(enemy)
	if contact.is_empty():
		return -1.0
	return _now() - float(contact["last_seen_time"])


func visible_count() -> int:
	var total: int = 0
	for id in contacts:
		if contacts[id]["visible"]:
			total += 1
	return total


func known_count() -> int:
	return contacts.size()


func _process(delta: float) -> void:
	_scan_remaining -= delta
	if _scan_remaining <= 0.0:
		_scan_remaining = maxf(scan_interval, 0.05)
		_scan()
	queue_redraw()


func _scan() -> void:
	_prune()
	var live: Array[ReconObserverComponent] = active_observers()
	for enemy: Node2D in get_tree().get_nodes_in_group(hostile_group):
		if not is_instance_valid(enemy):
			continue
		var health: HealthComponent = HealthComponent.find_on(enemy)
		if not enemy.can_process() or (health != null and health.is_dead):
			_forget(enemy)
			continue
		var id: int = enemy.get_instance_id()
		var was_visible: bool = contacts.has(id) and contacts[id]["visible"]
		var spotter: ReconObserverComponent = null
		for observer in live:
			if observer.can_see(enemy):
				spotter = observer
				break
		if spotter != null:
			contacts[id] = {
				"enemy": enemy,
				"visible": true,
				"last_seen_position": enemy.global_position,
				"last_seen_time": _now(),
				"observer": spotter.observer_label,
			}
			if not was_visible:
				contact_gained.emit(enemy)
		elif contacts.has(id):
			contacts[id]["visible"] = false
			if was_visible:
				contact_lost.emit(enemy)


func _forget(enemy: Node2D) -> void:
	var id: int = enemy.get_instance_id()
	if contacts.has(id):
		var was_visible: bool = contacts[id]["visible"]
		contacts.erase(id)
		if was_visible:
			contact_lost.emit(enemy)


func _prune() -> void:
	for index in range(observers.size() - 1, -1, -1):
		if not is_instance_valid(observers[index]):
			observers.remove_at(index)
	for id in contacts.keys():
		if not is_instance_valid(contacts[id]["enemy"]):
			contacts.erase(id)


func _now() -> float:
	# Real seconds, so command-mode slowdown cannot distort "last seen" ages.
	return Time.get_ticks_msec() / 1000.0


func _draw() -> void:
	if not _debug_visible():
		return
	for observer in active_observers():
		draw_arc(to_local(observer.get_observer_position()), observer.vision_radius, 0, TAU, 72, Color(0.5, 0.9, 1.0, 0.14), 1.5, true)
	var font: Font = ThemeDB.fallback_font
	for id in contacts:
		var contact: Dictionary = contacts[id]
		if contact["visible"]:
			continue
		var point: Vector2 = to_local(contact["last_seen_position"])
		var color: Color = Color(1.0, 0.75, 0.45, 0.55)
		draw_line(point - Vector2(7, 7), point + Vector2(7, 7), color, 1.5)
		draw_line(point - Vector2(7, -7), point + Vector2(7, -7), color, 1.5)
		IsoView.draw_text(self, font, point, Vector2(10, -6), "LAST SEEN: %.1fs ago" % (_now() - float(contact["last_seen_time"])), 11, color)


## Autoload path lookup, not the global identifier: these scripts can be
## compiled by a --script test harness before autoloads are registered.
func _debug_visible() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	return manager != null and manager.debug_visible
