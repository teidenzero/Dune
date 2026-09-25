extends Node
## Turns threat stages into things the player can feel without reading a meter:
## periodic ground tremors through the existing camera, rising with the stage,
## and the WORM SIGN! alert with an arrow to the ridge when a worm commits.
##
## It only calls the camera's public shake entry point, so every camera mode -
## FOLLOW_PAUL, FOLLOW_SELECTION, TACTICAL_FREE, prescience, tutorial - keeps
## its own framing.

@export var manager: WormThreatManager
@export var player: PlayerController

## Trauma per tremor and seconds between tremors, indexed by threat stage.
@export var tremor_strength: PackedFloat32Array = PackedFloat32Array([0.0, 0.05, 0.12, 0.24, 0.40, 0.75])
@export var tremor_interval: PackedFloat32Array = PackedFloat32Array([0.0, 4.0, 2.4, 1.4, 0.8, 0.5])
@export var arrival_shake: float = 1.0

var alert: WormSignAlert
var _wait: float = 0.0
var _camera: TacticalCamera


func _ready() -> void:
	call_deferred("_bind")


func _bind() -> void:
	if is_instance_valid(player):
		_camera = player.get_node_or_null("TacticalCamera") as TacticalCamera
	if is_instance_valid(manager):
		manager.worm_arrived.connect(_on_arrived)
		manager.worm_event_finished.connect(_on_finished)
		_make_alert()


## WORM SIGN! and the arrow to the ridge, over everything but menus.
func _make_alert() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "WormSignLayer"
	layer.layer = 8
	add_child(layer)
	alert = WormSignAlert.new()
	alert.name = "WormSignAlert"
	layer.add_child(alert)
	alert.bind(manager)


func _process(delta: float) -> void:
	if not is_instance_valid(manager) or _camera == null:
		return
	# Warning cadence is real time: a slowed world should not slow the warning.
	var real: float = TimeScaleManager.unscaled(delta)
	var stage: int = int(manager.stage)
	var interval: float = tremor_interval[stage] if stage < tremor_interval.size() else 0.0
	if interval <= 0.0:
		_wait = 0.0
		return
	_wait -= real
	if _wait > 0.0:
		return
	_wait = interval
	var strength: float = tremor_strength[stage] if stage < tremor_strength.size() else 0.0
	_camera.add_shake(strength)


func _on_arrived(_position: Vector2, _radius: float) -> void:
	if _camera != null:
		_camera.add_shake(arrival_shake)


func _on_finished() -> void:
	_wait = 0.0
