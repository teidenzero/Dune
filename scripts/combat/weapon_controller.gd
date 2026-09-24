class_name WeaponController
extends Node

signal weapon_fired
signal ammo_changed(current_ammo: int, magazine_size: int)
signal reload_started
signal reload_finished
signal dry_fired
signal weapon_changed(data: WeaponData)

@export var weapon_data: WeaponData
@export var muzzle: Marker2D
@export var owner_actor: PhysicsBody2D
@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")

var current_ammo: int = 0
var is_reloading: bool = false
var cooldown_remaining: float = 0.0
var reload_remaining: float = 0.0
var enabled: bool = true
## Rounds left in weapons that are not in hand, so switching never refills a gun.
var _stored_ammo: Dictionary = {}
var can_fire: bool:
	get:
		return enabled and weapon_data != null and current_ammo > 0 and not is_reloading and cooldown_remaining <= 0.0


func _ready() -> void:
	assert(weapon_data != null and muzzle != null and owner_actor != null, "Weapon requires data, muzzle and actor")
	current_ammo = weapon_data.magazine_size
	ammo_changed.emit(current_ammo, weapon_data.magazine_size)


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if is_reloading:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0.0:
			is_reloading = false
			current_ammo = weapon_data.magazine_size
			ammo_changed.emit(current_ammo, weapon_data.magazine_size)
			reload_finished.emit()


func try_fire() -> bool:
	if not enabled or is_reloading or cooldown_remaining > 0.0:
		return false
	if current_ammo <= 0:
		dry_fired.emit()
		return false
	if not can_fire:
		return false
	var shot: CombatProjectile = projectile_scene.instantiate() as CombatProjectile
	var spread: float = deg_to_rad(randf_range(-weapon_data.spread_degrees, weapon_data.spread_degrees))
	var direction: Vector2 = Vector2.RIGHT.rotated(muzzle.global_rotation + spread)
	shot.configure(weapon_data, direction, owner_actor)
	# World parent keeps projectiles independent of actor motion and lifetime.
	get_tree().current_scene.add_child(shot)
	shot.global_position = muzzle.global_position
	shot.global_rotation = direction.angle()
	current_ammo -= 1
	cooldown_remaining = 1.0 / maxf(weapon_data.fire_rate, 0.1)
	ammo_changed.emit(current_ammo, weapon_data.magazine_size)
	weapon_fired.emit()
	var bus: DisturbanceBus = get_tree().get_first_node_in_group("disturbance_bus") as DisturbanceBus
	if bus != null:
		bus.emit_noise(owner_actor.global_position, weapon_data.noise_radius, owner_actor, DisturbanceBus.Type.GUNSHOT)
	_report_worm_sign()
	return true


## Enemy hearing and desert vibration stay separate systems; a shot feeds both.
func _report_worm_sign() -> void:
	if weapon_data.worm_sign_shot <= 0.0:
		return
	var emitter: WormSignEmitter = owner_actor.get_node_or_null("WormSignEmitter") as WormSignEmitter
	if emitter != null:
		emitter.impulse(weapon_data.worm_sign_shot, "Gunshot")


func start_reload() -> bool:
	if not enabled or is_reloading or current_ammo >= weapon_data.magazine_size:
		return false
	is_reloading = true
	reload_remaining = maxf(weapon_data.reload_time, 0.01)
	reload_started.emit()
	return true


## Swap the weapon in hand. An interrupted reload is lost; the magazine each
## weapon had is remembered.
func equip(data: WeaponData) -> bool:
	if data == null or data == weapon_data:
		return false
	if weapon_data != null:
		_stored_ammo[weapon_data] = current_ammo
	weapon_data = data
	is_reloading = false
	reload_remaining = 0.0
	current_ammo = int(_stored_ammo.get(data, data.magazine_size))
	weapon_changed.emit(data)
	ammo_changed.emit(current_ammo, data.magazine_size)
	return true


func reload_ratio() -> float:
	if not is_reloading or weapon_data == null:
		return 0.0
	return clampf(1.0 - reload_remaining / maxf(weapon_data.reload_time, 0.01), 0.0, 1.0)


func disable() -> void:
	enabled = false
	is_reloading = false
	reload_remaining = 0.0
	set_physics_process(false)
