class_name SpiceField
extends Node2D
## A patch of spice melange on the sand: rust-orange, faintly shimmering,
## smelling of cinnamon. Standing in it saturates a hero: real-time
## prescience energy returns faster, and permanent saturation slowly builds
## (see Progression.saturate). It is meant to be seen from afar.

@export var radius: float = 150.0
## Saturation gained per second standing in the field.
@export var saturation_per_second: float = 0.5
## Extra prescience energy per second on top of the normal return.
@export var energy_per_second: float = 14.0

var _time: float = 0.0
var _specks: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	add_to_group("spice_fields")
	z_index = -4
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(str(global_position))
	for index in range(36):
		var angle: float = rng.randf() * TAU
		var distance: float = sqrt(rng.randf()) * radius * 0.9
		_specks.append(Vector2(cos(angle), sin(angle) * 0.7) * distance)


func contains(point: Vector2) -> bool:
	var offset: Vector2 = point - global_position
	return Vector2(offset.x, offset.y / 0.7).length() <= radius


func _physics_process(delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group("player"):
		var hero: PlayerController = node as PlayerController
		if hero == null or hero.health.is_dead or not contains(hero.global_position):
			continue
		var energy: PrescienceEnergyComponent = hero.prescience_energy
		if energy != null and energy.current_energy < energy.max_energy:
			energy.current_energy = minf(energy.current_energy + energy_per_second * delta, energy.max_energy)
			energy.energy_changed.emit(energy.current_energy, energy.max_energy)
		Progression.saturate(Progression.campaign_of(hero), hero.hero_id, saturation_per_second * delta)


func _process(delta: float) -> void:
	_time = fmod(_time + delta, TAU * 10.0)
	queue_redraw()


func _draw() -> void:
	# A soft, uneven stain of spice on the sand...
	for ring in range(4):
		var scale: float = 1.0 - ring * 0.2
		var points: PackedVector2Array = PackedVector2Array()
		for index in range(24):
			var angle: float = TAU * index / 24.0
			var wobble: float = 1.0 + 0.08 * sin(angle * 3.0 + ring + _time * 0.3)
			points.append(Vector2(cos(angle), sin(angle) * 0.7) * radius * scale * wobble)
		draw_colored_polygon(points, Color(0.78, 0.36, 0.12, 0.10 + ring * 0.05))
	# ...and its shimmer: specks catching the light, never all at once.
	for index in range(_specks.size()):
		var glow: float = 0.5 + 0.5 * sin(_time * 2.0 + index * 1.7)
		draw_circle(_specks[index], 2.0 + glow * 1.5, Color(1.0, 0.62, 0.25, 0.35 + glow * 0.5))
