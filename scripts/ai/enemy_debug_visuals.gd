extends Node2D
## Read-only diagnostic drawing, enabled exclusively by the F1 preference.

var _refresh: float = 0.0
@onready var actor: EnemyCharacter = get_parent() as EnemyCharacter
@onready var label: Label = $Details


func _ready() -> void:
	var manager: Node = get_node("/root/GameManager")
	manager.debug_visibility_changed.connect(_on_visibility)
	_on_visibility(manager.debug_visible)


func _on_visibility(value: bool) -> void:
	visible = value
	set_process(value)
	queue_redraw()


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.1
	var ai: EnemyAIController = actor.ai
	var perception: PerceptionComponent = actor.perception
	var distance: String = "--"
	if is_instance_valid(perception.target):
		distance = "%.0f" % actor.global_position.distance_to(perception.target.global_position)
	var target_name: String = str(ai.target.name) if is_instance_valid(ai.target) else "none"
	var memory: String = str(ai.last_known_target_position.round()) if ai.has_last_known_position else "none"
	var destination: String = str(actor.navigation_destination.round()) if actor.has_destination else "stopped"
	label.text = "%s | %s | HP %.0f\nTarget: %s | Distance: %s\nCan see: %s\nLast seen: %s\nNav: %s" % [actor.name, EnemyAIController.State.keys()[ai.state], actor.health.current_health, target_name, distance, str(perception.can_see_target), memory, destination]
	label.text += "\n%s | Detect: %.1f / %.0f\nGain: %.1f/s | Decay: %.1f/s\nDistance x%.2f | Facing x%.2f\nMove x%.2f | Stance x%.2f | Exposure %.2f\nNoise: %s (priority %d)" % [PerceptionComponent.Awareness.keys()[perception.perception_state], perception.detection_value, perception.detection_max, perception.detection_gain_per_second, perception.detection_decay_per_second, perception.distance_modifier, perception.facing_modifier, perception.movement_modifier, perception.stance_modifier, perception.exposure_modifier, ai.current_disturbance, ai.disturbance_priority]
	if actor.shield != null:
		label.text += "\nShield: %s | Threshold: %.0f\nEnergy: %.0f / %.0f | Last hit: %s (%s v%.0f)" % [
			"ON" if actor.shield.enabled else "OFF", actor.shield.velocity_threshold,
			actor.shield.current_energy, actor.shield.max_energy,
			actor.shield.result_name(), actor.shield.last_attack_label, actor.shield.last_attack_velocity,
		]
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(actor) or actor.ai == null or actor.health.is_dead:
		return
	var perception: PerceptionComponent = actor.perception
	var angle: float = actor.aim_pivot.global_rotation - global_rotation
	var half_fov: float = deg_to_rad(perception.field_of_view_degrees * 0.5)
	var color: Color = Color(0.45, 0.85, 0.95, 0.55)
	var cone: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for index in range(17):
		cone.append(Vector2.RIGHT.rotated(angle - half_fov + 2.0 * half_fov * index / 16.0) * perception.vision_distance)
	draw_colored_polygon(cone, Color(0.4, 0.8, 0.9, 0.06))
	draw_line(Vector2.ZERO, cone[1], color, 1.0)
	draw_line(Vector2.ZERO, cone[17], color, 1.0)
	for edge in [-1.0, 1.0]:
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle + edge * half_fov * 0.55) * perception.vision_distance, Color(0.7, 0.9, 1.0, 0.3), 1.0)
	draw_arc(Vector2.ZERO, perception.vision_distance, angle - half_fov, angle + half_fov, 32, color, 1.0, true)
	if is_instance_valid(perception.target):
		var ray_color: Color = Color.GREEN if perception.can_see_target else Color(0.85, 0.35, 0.25, 0.5)
		draw_line(Vector2.ZERO, to_local(perception.target.global_position), ray_color, 1.0)
	var path: PackedVector2Array = actor.agent.get_current_navigation_path()
	for index in range(1, path.size()):
		draw_line(to_local(path[index - 1]), to_local(path[index]), Color(0.65, 1.0, 0.6, 0.8), 2.0)
	if actor.has_destination:
		draw_circle(to_local(actor.navigation_destination), 7.0, Color(0.65, 1.0, 0.6), false, 2.0)
	if actor.ai.has_last_known_position:
		draw_circle(to_local(actor.ai.last_known_target_position), 10.0, Color(0.95, 0.7, 0.25), false, 2.0)
	if actor.ai.state in [EnemyAIController.State.SUSPICIOUS, EnemyAIController.State.INVESTIGATE]:
		draw_circle(to_local(actor.ai.suspicious_position), 14.0, Color(0.95, 0.5, 0.9), false, 2.0)

