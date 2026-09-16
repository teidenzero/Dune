class_name PlayerController
extends CharacterBody2D

@export_range(1.0, 1000.0, 1.0) var walk_speed: float = 180.0
@export_range(1.0, 1000.0, 1.0) var sprint_speed: float = 280.0
@export_range(1.0, 1000.0, 1.0) var crouch_speed: float = 110.0
@export_range(1.0, 5000.0, 1.0) var acceleration: float = 1200.0
@export_range(1.0, 5000.0, 1.0) var deceleration: float = 1600.0

var is_sprinting: bool = false
var is_crouching: bool = false
var current_speed: float = 0.0
var squad_control_locked: bool = false
var fire_blocked_until_release: bool = false
var aim_direction: Vector2 = Vector2.RIGHT

@onready var aim_pivot: Node2D = $AimPivot
@onready var weapon_controller: WeaponController = $WeaponController
@onready var health: HealthComponent = $HealthComponent
@onready var stealth_profile: StealthProfile = $StealthProfile
@onready var recon: ReconObserverComponent = $ReconObserverComponent
@onready var melee: MeleeController = $MeleeController
@onready var prescience: PrescienceController = $PrescienceController
@onready var prescience_energy: PrescienceEnergyComponent = $PrescienceEnergy


func _ready() -> void:
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health.is_dead:
		if Input.is_action_just_pressed("restart_mission"):
			get_tree().reload_current_scene()
		return
	if not Input.is_action_pressed("fire_primary"):
		fire_blocked_until_release = false
	if squad_control_locked:
		# Command mode owns the controls; an in-progress charge is abandoned.
		melee.cancel()
		velocity = Vector2.ZERO
		current_speed = 0.0
		is_sprinting = false
		stealth_profile.update_profile(is_crouching, false, 0.0, delta)
		return
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("crouch"):
		is_crouching = not is_crouching
	if Input.is_action_pressed("sprint"):
		is_crouching = false
	is_sprinting = Input.is_action_pressed("sprint") and not direction.is_zero_approx() and not prescience.blocks_sprint()
	var target_speed: float = crouch_speed if is_crouching else (sprint_speed if is_sprinting else walk_speed)
	# A committed crysknife stroke, above all the slow one, costs mobility, and
	# Paul only walks while he is reading the future.
	target_speed *= melee.get_move_speed_multiplier() * prescience.get_move_speed_multiplier()
	var rate: float = deceleration if direction.is_zero_approx() else acceleration
	velocity = velocity.move_toward(direction * target_speed, rate * delta)
	move_and_slide()
	current_speed = get_real_velocity().length()
	stealth_profile.update_profile(is_crouching, is_sprinting, current_speed, delta)
	$Body.scale = Vector2(1.0, 0.65) if is_crouching else Vector2.ONE
	$Hood.scale = $Body.scale
	_update_aim()
	if prescience.blocks_combat():
		melee.cancel()
	elif Input.is_action_just_pressed("melee_attack"):
		melee.begin_input()
	elif Input.is_action_just_released("melee_attack"):
		melee.release_input()
	if Input.is_action_just_pressed("reload"):
		weapon_controller.start_reload()
	var firing: bool = Input.is_action_pressed("fire_primary") if weapon_controller.weapon_data.automatic else Input.is_action_just_pressed("fire_primary")
	if firing and not fire_blocked_until_release and not prescience.blocks_combat():
		weapon_controller.try_fire()


func _process(_delta: float) -> void:
	if not health.is_dead:
		_update_aim()


func _update_aim() -> void:
	var mouse_delta: Vector2 = get_global_mouse_position() - global_position
	if mouse_delta.length_squared() > 1.0:
		aim_direction = mouse_delta.normalized()
		aim_pivot.rotation = aim_direction.angle()


func _on_died() -> void:
	velocity = Vector2.ZERO
	is_sprinting = false
	current_speed = 0.0
	stealth_profile.update_profile(is_crouching, false, 0.0, 0.0, false)
	weapon_controller.disable()
	melee.disable()
	prescience.deactivate()
	$Body.modulate = Color(0.4, 0.4, 0.4)
	$NameLabel.text = "DOWN"
