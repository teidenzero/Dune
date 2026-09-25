class_name CombatProjectile
extends CharacterBody2D
## Swept body motion detects the entire distance traveled each physics tick.

var damage: float = 0.0
var speed: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var owner_actor: PhysicsBody2D
var source_team: StringName = &""
var weapon_name: String = "weapon"
var worm_sign_impact: float = 0.0
var lifetime: float = 0.0
var impact_noise_radius: float = 0.0

var _launch_origin: Vector2
var _check_muzzle: bool = true
var _spent: bool = false


func configure(data: WeaponData, shot_direction: Vector2, actor: PhysicsBody2D) -> void:
	damage = data.damage
	speed = data.projectile_speed
	weapon_name = data.weapon_name
	worm_sign_impact = data.worm_sign_impact
	lifetime = data.projectile_lifetime
	impact_noise_radius = data.impact_noise_radius
	direction = shot_direction.normalized()
	owner_actor = actor
	source_team = actor.get_meta("team_id", &"")
	_launch_origin = actor.global_position
	rotation = direction.angle()
	add_collision_exception_with(actor)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	if _check_muzzle:
		_check_muzzle = false
		# Sweep the short barrel segment too: a muzzle pushed inside/through a
		# rock must not create a projectile on its far side.
		var muzzle_position: Vector2 = global_position
		global_position = _launch_origin
		if _travel(muzzle_position - _launch_origin):
			return
	var travel_time: float = minf(delta, maxf(lifetime, 0.0))
	if _travel(direction * speed * travel_time):
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()


func _travel(motion: Vector2) -> bool:
	var collision: KinematicCollision2D = move_and_collide(motion)
	if collision == null:
		return false
	var actor: Node = collision.get_collider() as Node
	if is_instance_valid(actor) and source_team != &"" and actor.get_meta("team_id", &"") == source_team and actor is PhysicsBody2D:
		# A friend in the line of fire: the round goes past him, not into him.
		add_collision_exception_with(actor)
		return _travel(collision.get_remainder())
	if is_instance_valid(actor) and actor != owner_actor:
		var health: HealthComponent = HealthComponent.find_on(actor)
		if health != null:
			# Faction filtering and shield evaluation both live in the resolver,
			# so a bullet and a blade reach health through the same gate.
			var source: Node = owner_actor if is_instance_valid(owner_actor) else null
			Sound.play(&"hit_body", global_position, -4.0)
			DamageResolver.resolve(actor, HitContext.ranged(damage, speed, source, source_team, weapon_name, global_position, direction))
		else:
			Sound.play(&"hit_stone", global_position, -6.0)
			var bus: DisturbanceBus = get_tree().get_first_node_in_group("disturbance_bus") as DisturbanceBus
			if bus != null:
				var noise_source: Node = owner_actor if is_instance_valid(owner_actor) else null
				bus.emit_noise(global_position, impact_noise_radius, noise_source, DisturbanceBus.Type.IMPACT)
			var worm: Node = get_tree().get_first_node_in_group("worm_threat")
			if worm != null and worm_sign_impact > 0.0:
				worm.report_sign(global_position, worm_sign_impact, "Impact")
	_expire()
	return true


func _expire() -> void:
	_spent = true
	set_physics_process(false)
	hide()
	queue_free()
