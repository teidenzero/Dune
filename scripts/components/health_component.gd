class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal damage_received(amount: float, source: Node)
signal died

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0

var current_health: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	reset_health()


func take_damage(amount: float, source: Node = null) -> void:
	if is_dead or not is_finite(amount) or amount <= 0.0:
		return
	var applied: float = minf(amount, current_health)
	current_health = maxf(current_health - applied, 0.0)
	# Mark death before notifying listeners, so reentrant damage cannot kill twice.
	var lethal: bool = current_health <= 0.0
	is_dead = lethal
	health_changed.emit(current_health, max_health)
	damaged.emit(applied)
	damage_received.emit(applied, source)
	if lethal:
		died.emit()


func heal(amount: float) -> void:
	if is_dead or not is_finite(amount) or amount <= 0.0:
		return
	current_health = clampf(current_health + amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)


func reset_health() -> void:
	max_health = maxf(1.0, max_health)
	is_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	health_changed.emit(current_health, max_health)
	died.emit()


static func find_on(actor: Node) -> HealthComponent:
	# Damageable physics bodies compose a direct child with this stable name.
	return actor.get_node_or_null("HealthComponent") as HealthComponent
