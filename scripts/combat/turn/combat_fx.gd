class_name CombatFx
extends Node2D
## Short-lived combat feedback in the world: a floating number or word, a
## shot's tracer, a blade's arc. One node per effect; it frees itself.

enum Kind { TEXT, TRACER, SLASH }

var kind: Kind = Kind.TEXT
var text: String = ""
var color: Color = Color.WHITE
var from: Vector2
var to: Vector2
var life: float = 0.9
var _age: float = 0.0


static func float_text(parent: Node, at: Vector2, words: String, tint: Color) -> void:
	var fx: CombatFx = CombatFx.new()
	fx.kind = Kind.TEXT
	fx.text = words
	fx.color = tint
	fx.life = 1.1
	fx.position = at + Vector2(0, -70)
	parent.add_child(fx)


static func tracer(parent: Node, start: Vector2, end: Vector2, tint: Color) -> void:
	var fx: CombatFx = CombatFx.new()
	fx.kind = Kind.TRACER
	fx.from = start
	fx.to = end
	fx.color = tint
	fx.life = 0.22
	parent.add_child(fx)


static func slash(parent: Node, at: Vector2, facing: Vector2, tint: Color) -> void:
	var fx: CombatFx = CombatFx.new()
	fx.kind = Kind.SLASH
	fx.position = at
	fx.to = facing
	fx.color = tint
	fx.life = 0.3
	parent.add_child(fx)


func _ready() -> void:
	z_index = 20
	top_level = kind == Kind.TRACER


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0 - _age / life
	match kind:
		Kind.TEXT:
			var font: Font = ThemeDB.fallback_font
			var size: int = WorldLabel.font_size(self, 22)
			var rise: Vector2 = Vector2(0, -38.0 * (_age / life))
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var point: Vector2 = rise + Vector2(-width * 0.5, 0)
			draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.05, 0.04, 0.03, fade))
			draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, fade))
		Kind.TRACER:
			draw_line(from, to, Color(color, fade), 3.0, true)
			draw_line(from, to, Color(1, 1, 1, fade * 0.7), 1.0, true)
		Kind.SLASH:
			var angle: float = to.angle()
			var sweep: float = lerpf(-0.9, 0.9, minf(_age / life * 1.6, 1.0))
			draw_arc(Vector2(0, -30), 46.0, angle - 0.9, angle + sweep, 16, Color(color, fade), 5.0, true)
