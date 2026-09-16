class_name EnemyCharacter
extends CharacterBody2D

signal enemy_died

@export var display_name: String = "GUARD"
@export var patrol_route: PatrolRoute
@export var initial_facing_degrees: float = 0.0
@export var acceleration: float = 900.0
@export var hit_flash_duration: float = 0.16

var move_speed: float = 0.0
var navigation_destination: Vector2
var has_destination: bool = false
var face_travel: bool = true
## Optional; only the Elite composes one.
var shield: ShieldComponent
var _flash: Tween

@onready var health: HealthComponent = $HealthComponent
@onready var weapon: WeaponController = $WeaponController
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var perception: PerceptionComponent = $Perception
@onready var ai: EnemyAIController = $AIController
@onready var aim_pivot: Node2D = $AimPivot


func _ready() -> void:
	shield = ShieldComponent.find_on(self)
	aim_pivot.rotation = deg_to_rad(initial_facing_degrees)
	navigation_destination = global_position
	health.damaged.connect(_on_damaged)
	health.damage_received.connect(_on_damage_received)
	health.died.connect(_on_died)
	ai.setup(self)


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	var desired: Vector2 = Vector2.ZERO
	if has_destination and navigation_ready():
		var next: Vector2 = agent.get_next_path_position()
		if not agent.is_navigation_finished():
			desired = global_position.direction_to(next) * move_speed
	velocity = velocity.move_toward(desired, acceleration * delta)
	move_and_slide()
	if face_travel and velocity.length_squared() > 4.0:
		face_position(global_position + velocity)


func navigation_ready() -> bool:
	return NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) > 0


func navigate_to(destination: Vector2, speed: float) -> void:
	move_speed = speed
	if not has_destination or navigation_destination.distance_to(destination) > 8.0:
		navigation_destination = destination
		agent.target_position = destination
		has_destination = true


func stop_moving() -> void:
	has_destination = false
	move_speed = 0.0


func reached_destination() -> bool:
	return has_destination and navigation_ready() and agent.is_navigation_finished()


func face_position(position: Vector2) -> void:
	if global_position.distance_squared_to(position) > 1.0:
		aim_pivot.global_rotation = (position - global_position).angle()


func _on_damage_received(_amount: float, source: Node) -> void:
	if health.is_dead or not is_instance_valid(source) or not source is Node2D:
		return
	if source.get_meta("team_id", &"") == &"player":
		perception.priority_target = source
		face_position(source.global_position)
		# Resolve this observation before movement/old combat aim can turn us back.
		if perception.is_physics_processing() and can_process():
			perception.scan()


func _on_damaged(_amount: float) -> void:
	if _flash != null:
		_flash.kill()
	$Visuals.modulate = Color(2.5, 2.5, 2.5)
	_flash = create_tween()
	_flash.tween_property($Visuals, "modulate", Color.WHITE, hit_flash_duration)


func _on_died() -> void:
	ai.die()
	stop_moving()
	velocity = Vector2.ZERO
	perception.stop()
	weapon.disable()
	if _flash != null:
		_flash.kill()
	$Visuals.modulate = Color(0.4, 0.4, 0.4)
	$Visuals.scale = Vector2(1.0, 0.3)
	$AimPivot.hide()
	$NameLabel.text = display_name + " DOWN"
	if shield != null:
		shield.shut_down()
	set_deferred("collision_layer", 0)
	$CollisionShape2D.set_deferred("disabled", true)
	enemy_died.emit()
