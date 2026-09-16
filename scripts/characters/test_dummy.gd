extends StaticBody2D

@export var target_name: String = "TARGET"
@export_range(0.05, 1.0, 0.01) var hit_flash_duration: float = 0.16

var _flash: Tween

@onready var health: HealthComponent = $HealthComponent
@onready var visuals: Node2D = $Visuals
@onready var status_label: Label = $Status


func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_on_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: float, maximum: float) -> void:
	status_label.text = "%s\n%.0f / %.0f HP" % [target_name, current, maximum]


func _on_damaged(_amount: float) -> void:
	if _flash != null:
		_flash.kill()
	visuals.modulate = Color(2.5, 2.5, 2.5)
	_flash = create_tween()
	_flash.tween_property(visuals, "modulate", Color.WHITE, hit_flash_duration)


func _on_died() -> void:
	if _flash != null:
		_flash.kill()
	visuals.modulate = Color(0.45, 0.45, 0.45)
	visuals.scale = Vector2(1.0, 0.25)
	status_label.text = "%s\nDESTROYED" % target_name
	set_deferred("collision_layer", 0)
	$CollisionShape2D.set_deferred("disabled", true)
