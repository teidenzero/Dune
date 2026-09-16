class_name ReconObserverComponent
extends Node
## Reconnaissance vision source owned by a friendly actor.
## It knows only its radius and how to test sight; ReconManager decides what
## the squad collectively knows. Deliberately independent from command range,
## so a future awareness/relay system can use different distances.

@export var vision_radius: float = 450.0
@export var observer_label: String = "Paul"
## Environment layer only: characters do not block reconnaissance sight.
@export_flags_2d_physics var occlusion_mask: int = 1

var actor: Node2D


func _ready() -> void:
	actor = get_parent() as Node2D
	add_to_group("recon_observers")
	var manager: Node = get_tree().get_first_node_in_group("recon_manager")
	if manager != null and manager.has_method("register_observer"):
		manager.register_observer(self)


func is_active() -> bool:
	if not is_instance_valid(actor) or not actor.can_process():
		return false
	var health: HealthComponent = HealthComponent.find_on(actor)
	return health == null or not health.is_dead


func get_observer_position() -> Vector2:
	return actor.global_position if is_instance_valid(actor) else Vector2.ZERO


func can_see(target: Node2D) -> bool:
	if not is_active() or not is_instance_valid(target):
		return false
	return can_see_point(target.global_position)


func can_see_point(point: Vector2) -> bool:
	if not is_active() or not point.is_finite():
		return false
	var origin: Vector2 = get_observer_position()
	if origin.distance_to(point) > vision_radius:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, point, occlusion_mask)
	if actor is CollisionObject2D:
		query.exclude = [actor.get_rid()]
	return actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
