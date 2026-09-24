class_name AllyCharacter
extends CharacterBody2D

signal ally_died(ally: AllyCharacter)
signal selection_changed

@export var data: AllyData
@export var follow_offset: Vector2 = Vector2(-60, 70)
@export var selection_slot: int = 2
@export var acceleration: float = 1000.0
@export var separation_distance: float = 42.0
var selected: bool = false
## Player-set stance (C): stay low and slow on every move until toggled off.
var sneaking: bool = false
var player: PlayerController
var destination: Vector2
var has_destination: bool = false
var move_speed: float = 0.0
var face_travel: bool = true
## Set by the AI: Fremen match Paul's stance and go low when holding.
var is_crouching: bool = false
var command_feedback_text: String = ""
var _command_feedback_until: int = 0
## Stuck recovery: if an ally wanting to move makes no progress, re-path.
var _stuck_anchor: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
@onready var health: HealthComponent = $HealthComponent
@onready var command_link: CommandLinkComponent = $CommandLinkComponent
@onready var recon: ReconObserverComponent = $ReconObserverComponent
@onready var weapon: WeaponController = $WeaponController
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var ai: AllyAIController = $AllyAIController
@onready var aim_pivot: Node2D = $AimPivot
@onready var stealth: StealthProfile = $StealthProfile


func _enter_tree() -> void:
	# Configure composed children before their _ready methods initialize stats.
	if data != null:
		$HealthComponent.max_health = data.max_health
		$WeaponController.weapon_data = data.weapon_data
		$ReconObserverComponent.vision_radius = data.vision_radius
		$ReconObserverComponent.observer_label = data.display_name


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as PlayerController
	$Visuals/Body.color = data.body_color
	if data.art != null and data.art.has_sprites():
		_use_drawn_art()
	$NameLabel.text = data.display_name
	health.died.connect(_on_died)
	health.damage_received.connect(_on_damage_received)
	ai.setup(self)
	for friend in get_tree().get_nodes_in_group("allies") + get_tree().get_nodes_in_group("player"):
		if friend != self and friend is PhysicsBody2D:
			add_collision_exception_with(friend)
			friend.add_collision_exception_with(self)


func _physics_process(delta: float) -> void:
	# A Fremen who moves like a target gets seen like one. Before this, allies
	# had no stealth profile at all and every guard saw them at full visibility
	# whatever they were doing - which gave the player away within seconds.
	stealth.update_profile(is_crouching, false, velocity.length(), delta, not health.is_dead)
	if health.is_dead or not navigation_ready():
		return
	var desired: Vector2 = Vector2.ZERO
	if has_destination:
		var next: Vector2 = agent.get_next_path_position()
		if not agent.is_navigation_finished():
			desired = global_position.direction_to(next) * move_speed
	var separation: Vector2 = Vector2.ZERO
	for friend: Node2D in get_tree().get_nodes_in_group("allies"):
		if friend == self or not friend.can_process() or HealthComponent.find_on(friend).is_dead:
			continue
		var offset: Vector2 = global_position - friend.global_position
		var distance: float = offset.length()
		if distance < separation_distance:
			var away: Vector2 = offset.normalized() if distance > 0.1 else Vector2(-1 if selection_slot == 2 else 1, 0)
			separation += away * (1.0 - distance / separation_distance) * 65.0
	desired += separation
	velocity = velocity.move_toward(desired, acceleration * delta)
	move_and_slide()
	_check_stuck(delta)
	if face_travel and velocity.length_squared() > 16.0:
		face_position(global_position + velocity)


func _check_stuck(delta: float) -> void:
	if not has_destination or agent.is_navigation_finished():
		_stuck_time = 0.0
		_stuck_anchor = global_position
		return
	if global_position.distance_to(_stuck_anchor) > 12.0:
		_stuck_anchor = global_position
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time > 0.8:
		_stuck_time = 0.0
		# Reassigning the target forces a fresh path query from where we are.
		agent.target_position = destination


## Swap the placeholder body for the character art; the shadow stays.
func _use_drawn_art() -> void:
	var sprite: UnitSprite = data.art.make_sprite(self, data.move_speed)
	$Visuals.add_child(sprite)
	data.art.apply_to(sprite, self)
	$Visuals/Body.hide()
	$Visuals/Hood.hide()
	# The figure stands taller than the placeholder disc; keep the name above it.
	$NameLabel.raise(data.art.world_height * 0.75)


func navigation_ready() -> bool:
	return NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) > 0


func navigate_to(point: Vector2, speed: float) -> void:
	move_speed = speed
	if not has_destination or destination.distance_to(point) > 12.0:
		destination = point
		agent.target_position = point
		has_destination = true


func stop_moving() -> void:
	has_destination = false
	move_speed = 0.0


func face_position(point: Vector2) -> void:
	if global_position.distance_squared_to(point) > 1.0:
		aim_pivot.global_rotation = (point - global_position).angle()


## Prototype feedback for an order that could not be delivered.
func flash_command_feedback(text: String, duration_seconds: float = 1.6) -> void:
	command_feedback_text = text
	_command_feedback_until = Time.get_ticks_msec() + int(duration_seconds * 1000.0)


func command_feedback_active() -> bool:
	return Time.get_ticks_msec() < _command_feedback_until


func set_selected(value: bool) -> void:
	selected = value and not health.is_dead
	selection_changed.emit()


func has_line_of_sight(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate):
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, candidate.global_position, 3, [get_rid()])
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == candidate


func _on_damage_received(_amount: float, source: Node) -> void:
	if not health.is_dead and source is Node2D:
		ai.defend_against(source)


func _on_died() -> void:
	ai.die()
	weapon.disable()
	stop_moving()
	velocity = Vector2.ZERO
	set_selected(false)
	if has_node("Visuals/Sprite"):
		# The death animation does the falling; just take the life out of it.
		$Visuals.modulate = Color(0.8, 0.8, 0.8)
	else:
		$Visuals.scale.y = 0.3
		$Visuals.modulate = Color(0.4, 0.4, 0.4)
	$AimPivot.hide()
	$NameLabel.text = data.display_name + " DOWN"
	set_deferred("collision_layer", 0)
	$CollisionShape2D.set_deferred("disabled", true)
	ally_died.emit(self)
