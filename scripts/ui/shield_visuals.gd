extends Node2D
## Personal-shield placeholder feedback. A blocked hit and a penetrating hit
## must never look alike, and the shimmer has to be readable before the first
## shot so the player can pick shielded targets out of a patrol.

@export var shield: ShieldComponent
@export var actor: Node2D
@export var shimmer_radius: float = 26.0

const BLOCK_COLOR: Color = Color(0.45, 0.85, 1.0)
const PENETRATE_COLOR: Color = Color(1.0, 0.62, 0.3)

var _flash_until: int = 0
var _flash_blocked: bool = true
var _message: String = ""
var _message_until: int = 0
var _pulse: float = 0.0


func _ready() -> void:
	if shield != null:
		shield.shield_blocked.connect(_on_blocked)
		shield.shield_penetrated.connect(_on_penetrated)
	if actor != null:
		var health: HealthComponent = HealthComponent.find_on(actor)
		if health != null:
			health.died.connect(_on_actor_died)


func _on_blocked(hit: HitContext) -> void:
	_flash_blocked = true
	_flash_until = Time.get_ticks_msec() + 260
	_message = "TOO FAST" if hit.attack_type == HitContext.Type.MELEE else "BLOCKED"
	_message_until = Time.get_ticks_msec() + 900


func _on_penetrated(_hit: HitContext) -> void:
	_flash_blocked = false
	_flash_until = Time.get_ticks_msec() + 420
	_message = "PENETRATED"
	_message_until = Time.get_ticks_msec() + 1100


func _on_actor_died() -> void:
	if shield != null:
		shield.shut_down()
	_flash_until = 0
	_message_until = 0
	hide()


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, TAU)
	queue_redraw()


func _draw() -> void:
	if shield == null or not shield.enabled:
		return
	var now: int = Time.get_ticks_msec()
	# Always-on shimmer: the identification cue.
	var idle_alpha: float = 0.16 + 0.06 * sin(_pulse * 2.2)
	draw_arc(Vector2.ZERO, shimmer_radius, 0, TAU, 40, Color(BLOCK_COLOR, idle_alpha * shield.energy_ratio() + 0.08), 2.0, true)
	draw_arc(Vector2.ZERO, shimmer_radius - 4.0, 0, TAU, 40, Color(BLOCK_COLOR, idle_alpha * 0.5), 1.0, true)
	if now < _flash_until:
		if _flash_blocked:
			_draw_block(now)
		else:
			_draw_penetration(now)
	if now < _message_until:
		_draw_message()


## Blocked: a hard outward ring that stops at the shield boundary.
func _draw_block(now: int) -> void:
	var remaining: float = (_flash_until - now) / 260.0
	draw_arc(Vector2.ZERO, shimmer_radius, 0, TAU, 48, Color(BLOCK_COLOR, remaining), 4.0, true)
	draw_arc(Vector2.ZERO, shimmer_radius + (1.0 - remaining) * 14.0, 0, TAU, 48, Color(BLOCK_COLOR, remaining * 0.6), 2.0, true)


## Penetrated: the bubble parts into segments and the ripple travels inward.
func _draw_penetration(now: int) -> void:
	var remaining: float = (_flash_until - now) / 420.0
	var span: float = TAU / 6.0
	for index in range(6):
		var start: float = index * span + (1.0 - remaining) * 0.35
		draw_arc(Vector2.ZERO, shimmer_radius + 4.0, start, start + span * 0.45, 8, Color(PENETRATE_COLOR, remaining * 0.8), 2.0, true)
	draw_arc(Vector2.ZERO, maxf(shimmer_radius * remaining, 2.0), 0, TAU, 32, Color(PENETRATE_COLOR, remaining), 3.0, true)


func _draw_message() -> void:
	var font: Font = ThemeDB.fallback_font
	var color: Color = BLOCK_COLOR if _flash_blocked else PENETRATE_COLOR
	var width: float = font.get_string_size(_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var point: Vector2 = Vector2(-width * 0.5, -shimmer_radius - 16.0)
	draw_string_outline(font, point, _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.05, 0.07, 0.09))
	draw_string(font, point, _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
