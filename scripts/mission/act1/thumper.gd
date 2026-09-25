class_name Thumper
extends Node2D
## A Fremen thumper: a spring-driven stake that drums the sand. Planted away
## from your people it becomes the loudest thing in the desert, so the worm
## comes to it - and a worm already on its way turns toward it. It is loud,
## though: planted too early, it only brings the worm sooner.

const DRUM_SECONDS: float = 40.0
## Worm sign a second: louder than a running crawler (2.5) or any column of men.
const DRUM_SIGN: float = 6.0

var remaining: float = DRUM_SECONDS
var _beat: float = 0.0
var _redirected: bool = false


func _ready() -> void:
	add_to_group("thumpers")
	add_to_group("iso_sorted")


func drumming() -> bool:
	return remaining > 0.0


func _process(delta: float) -> void:
	if remaining <= 0.0:
		queue_redraw()
		return
	remaining -= delta
	_beat += delta
	var worm: WormThreatManager = get_tree().get_first_node_in_group("worm_threat") as WormThreatManager
	if _beat >= 1.0:
		_beat -= 1.0
		if worm != null:
			worm.report_sign(global_position, DRUM_SIGN, "Thumper", self)
		Sound.play(&"thumper_thump", global_position, 0.0, 0.03)
	# A worm already coming turns toward the drum.
	if worm != null and not _redirected and worm.is_worm_approaching():
		_redirected = worm.retarget(global_position)
	queue_redraw()


func _draw() -> void:
	var live: bool = drumming()
	# Rings of disturbed sand, on the ground.
	if live:
		for index in range(3):
			var grow: float = fmod(_beat + index / 3.0, 1.0)
			draw_arc(Vector2.ZERO, 30.0 + grow * 140.0, 0, TAU, 32, Color(0.95, 0.8, 0.5, 0.5 * (1.0 - grow)), 3.0, true)
	if IsoView.active:
		draw_set_transform_matrix(IsoView.upright())
	var knock: float = -6.0 * absf(sin(_beat * PI)) if live else 0.0
	draw_rect(Rect2(Vector2(-4, -54), Vector2(8, 54)), Color(0.35, 0.28, 0.2))
	draw_rect(Rect2(Vector2(-10, -64 + knock), Vector2(20, 14)), Color(0.55, 0.45, 0.3))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var font: Font = HudStyle.body_font(700)
	var text: String = "THUMPER  ·  %ds" % ceili(remaining) if live else "THUMPER  ·  SPENT"
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	IsoView.draw_text(self, font, Vector2.ZERO, Vector2(-width * 0.5, -78), text, 12, HudStyle.GOLD_LIGHT if live else HudStyle.MUTED, 3)
