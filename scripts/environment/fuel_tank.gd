class_name FuelTank
extends StaticBody2D
## Pressurised spice-fuel canister. Shoot it and it goes up: everything close
## is hurt, the whole site hears it, and the sand feels it. The blast is heat
## and pressure, not a fast projectile, so a Holtzman shield does not stop it.

signal exploded(tank: FuelTank)

@export var blast_radius: float = 170.0
@export var blast_damage: float = 110.0
## Damage falls off to this fraction at the edge of the blast.
@export_range(0.0, 1.0) var edge_falloff: float = 0.35
@export var noise_radius: float = 1100.0
@export var worm_sign: float = 18.0
@export var camera_shake: float = 0.55

var detonated: bool = false
var _flash: float = 0.0

@onready var health: HealthComponent = $HealthComponent


## The painted drum, loaded once (never inside a draw call).
var _drum: Texture2D


func _ready() -> void:
	add_to_group("fuel_tanks")
	_drum = IsoKit.texture(&"residency", "fuel_drum")
	health.died.connect(detonate)


func detonate() -> void:
	if detonated:
		return
	detonated = true
	_flash = 1.0
	set_deferred("collision_layer", 0)
	$CollisionShape2D.set_deferred("disabled", true)
	for group in ["player", "allies", "enemies", "fuel_tanks"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body: Node2D = node as Node2D
			if body == null or body == self:
				continue
			var distance: float = body.global_position.distance_to(global_position)
			if distance > blast_radius:
				continue
			if body is FuelTank:
				# Chain reactions, a beat later.
				get_tree().create_timer(0.18).timeout.connect(func() -> void: if is_instance_valid(body): (body as FuelTank).detonate())
				continue
			var target_health: HealthComponent = HealthComponent.find_on(body)
			if target_health != null and not target_health.is_dead:
				var scale: float = lerpf(1.0, edge_falloff, distance / blast_radius)
				target_health.take_damage(blast_damage * scale, self)
	var bus: DisturbanceBus = get_tree().get_first_node_in_group("disturbance_bus") as DisturbanceBus
	if bus != null:
		bus.emit_noise(global_position, noise_radius, self, DisturbanceBus.Type.IMPACT, 6)
	var worm: WormThreatManager = get_tree().get_first_node_in_group("worm_threat") as WormThreatManager
	if worm != null:
		var terrain: TerrainSafetyComponent = TerrainSafetyComponent.find_on(self)
		if terrain == null or not terrain.is_safe():
			worm.report_sign(global_position, worm_sign, "Fuel explosion")
	var viewport: Viewport = get_viewport()
	var camera: TacticalCamera = viewport.get_camera_2d() as TacticalCamera if viewport != null else null
	if camera != null and camera.sees(global_position, -200.0):
		camera.add_shake(camera_shake)
	exploded.emit(self)


## Whole again: a rewound prescient vision.
func restore() -> void:
	if not detonated:
		return
	detonated = false
	_flash = 0.0
	collision_layer = 2
	$CollisionShape2D.disabled = false
	health.reset_health()
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 1.6, 0.0)
	queue_redraw()


func _draw() -> void:
	if not detonated:
		if _drum != null:
			draw_circle(Vector2(4, 4), 22.0, Color(0.1, 0.08, 0.06, 0.35))
			if IsoView.active:
				# Stood up against the squad scope's isometric view.
				draw_set_transform_matrix(IsoView.upright())
			draw_texture(_drum, -IsoKit.DRUM_ANCHOR)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
		# Canister: a squat drum with hazard bands.
		draw_circle(Vector2(4, 6), 20.0, Color(0.1, 0.08, 0.06, 0.35))
		draw_circle(Vector2.ZERO, 18.0, Color(0.55, 0.32, 0.12))
		draw_arc(Vector2.ZERO, 18.0, 0, TAU, 24, Color(0.15, 0.1, 0.06), 2.5, true)
		draw_arc(Vector2.ZERO, 12.0, 0, TAU, 24, Color(0.9, 0.62, 0.2), 3.0, true)
		draw_circle(Vector2.ZERO, 5.0, Color(0.2, 0.14, 0.08))
		return
	# Scorch, then the fireball fading out.
	draw_circle(Vector2.ZERO, 34.0, Color(0.08, 0.06, 0.05, 0.6))
	if _flash > 0.0:
		var radius: float = blast_radius * (1.0 - _flash * 0.4)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.6, 0.2, 0.35 * _flash))
		draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.85, 0.5, 0.55 * _flash))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(1.0, 0.5, 0.2, 0.8 * _flash), 4.0, true)
