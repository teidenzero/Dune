extends Node2D
## Placeholder crysknife feedback. The player has to be able to tell a fast
## flick from a committed, shield-penetrating stroke before it lands.

@export var melee: MeleeController
@export var aim_pivot: Node2D

@export var fast_color: Color = Color(0.85, 0.95, 1.0)
@export var slow_color: Color = Color(1.0, 0.78, 0.35)

var _swing_until: int = 0
var _swing_slow: bool = false


func _ready() -> void:
	if melee != null:
		melee.attack_started.connect(_on_attack_started)


func _on_attack_started(data: MeleeAttackData) -> void:
	_swing_slow = data == melee.slow_attack
	_swing_until = Time.get_ticks_msec() + int((data.windup_time + data.active_time) * 1000.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if melee == null or aim_pivot == null or not melee.enabled:
		return
	var angle: float = aim_pivot.global_rotation - global_rotation
	var reach: float = melee.hitbox_base_range
	var half_arc: float = deg_to_rad(50.0)
	if melee.state == MeleeController.State.CHARGING:
		_draw_charge(angle, reach, half_arc)
	elif Time.get_ticks_msec() < _swing_until:
		_draw_swing(angle, reach, half_arc)
	if _debug_visible():
		_draw_debug(angle, reach, half_arc)


## A growing blade line while charging; a full bright arc once the slow strike
## is committed-ready, so the wind-up is never a surprise.
func _draw_charge(angle: float, reach: float, half_arc: float) -> void:
	var ratio: float = melee.charge_ratio()
	if melee.slow_ready:
		draw_arc(Vector2.ZERO, reach, angle - half_arc, angle + half_arc, 24, slow_color, 3.0, true)
		for edge in [-1.0, 1.0]:
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle + edge * half_arc) * reach, slow_color, 2.0)
		draw_line(Vector2.RIGHT.rotated(angle) * 16.0, Vector2.RIGHT.rotated(angle) * (reach + 14.0), slow_color, 4.0)
		return
	var tip: float = 18.0 + reach * 0.55 * ratio
	draw_line(Vector2.RIGHT.rotated(angle) * 14.0, Vector2.RIGHT.rotated(angle) * tip, fast_color.lerp(slow_color, ratio), 2.0 + ratio)
	draw_arc(Vector2.ZERO, reach * 0.75, angle - half_arc * ratio, angle + half_arc * ratio, 16, slow_color * Color(1, 1, 1, 0.5), 1.5, true)


func _draw_swing(angle: float, reach: float, half_arc: float) -> void:
	var color: Color = slow_color if _swing_slow else fast_color
	var width: float = 5.0 if _swing_slow else 2.5
	if melee.state == MeleeController.State.WINDUP:
		# The tell: a thin arc that thickens as the blade comes back.
		draw_arc(Vector2.ZERO, reach * 0.9, angle - half_arc, angle + half_arc, 24, Color(color, 0.55), 1.5, true)
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle + half_arc) * reach * 0.8, color, width)
		return
	draw_arc(Vector2.ZERO, reach * 0.9, angle - half_arc, angle + half_arc, 24, color, width, true)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle) * (reach + 8.0), color, width)


func _draw_debug(angle: float, reach: float, half_arc: float) -> void:
	var wedge: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for index in range(9):
		wedge.append(Vector2.RIGHT.rotated(angle - half_arc + 2.0 * half_arc * index / 8.0) * reach)
	wedge.append(Vector2.ZERO)
	draw_polyline(wedge, Color(1.0, 0.45, 0.35, 0.65), 1.0)
	var font: Font = ThemeDB.fallback_font
	var text: String = "%s v%.0f" % [melee.state_name(), melee.attack_velocity()]
	draw_string(font, Vector2(-38, -48), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.75, 0.6))


func _debug_visible() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	return manager != null and manager.debug_visible
