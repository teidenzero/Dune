class_name JessicaFace
extends Control
## The Lady Jessica, large, beside the table: the face Paul reads. She shows
## the guests nothing; her son, watching closely, sees a fraction of warmth
## for a good answer, a cooling for a bad one, a lifted brow for a half-right
## one. The expressions are frames of one drawing (assets/ui/portraits/
## jessica_large/) cross-faded over the neutral face, so only the face moves.
##
## Fair to read: an expression holds for as long as the player stays on a
## reply - nothing is timed. At rest she blinks and, now and then, glances
## towards the guest: life, not information.

const FRAMES: String = "res://assets/ui/portraits/jessica_large/"
const EXPRESSIONS: Array[StringName] = [&"approve", &"warn", &"doubt", &"still", &"glance_left", &"glance_down", &"blink"]
const FADE: float = 0.35

var rest: StringName = &"neutral"
var showing: StringName = &"neutral"
var _base: TextureRect
var _layers: Array[TextureRect] = []
var _front: int = 0
var _textures: Dictionary = {}
var _holding: bool = false
var _idle_left: float = 3.0


func _ready() -> void:
	custom_minimum_size = Vector2(390, 520)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for name in [&"neutral"] + EXPRESSIONS:
		var path: String = FRAMES + String(name) + ".png"
		if ResourceLoader.exists(path):
			_textures[name] = load(path)
	_base = _layer()
	_base.texture = _textures.get(&"neutral")
	for index in range(2):
		var layer: TextureRect = _layer()
		layer.modulate.a = 0.0
		_layers.append(layer)


func _layer() -> TextureRect:
	var layer: TextureRect = TextureRect.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


func has_frames() -> bool:
	return _textures.has(&"neutral")


## A new course: her face at rest (composed, or too still).
func settle(at_rest: StringName) -> void:
	rest = at_rest
	_holding = false
	show_expression(rest, true)


## Paul weighs a reply: her face answers, and holds while he does.
func weigh(expression: StringName) -> void:
	if expression == &"":
		return
	_holding = true
	show_expression(expression)


## He looks away from the reply: she settles back.
func release() -> void:
	_holding = false
	show_expression(rest)


func show_expression(expression: StringName, instant: bool = false) -> void:
	if expression == showing and not instant:
		return
	showing = expression
	var incoming: TextureRect = _layers[1 - _front]
	var outgoing: TextureRect = _layers[_front]
	_front = 1 - _front
	incoming.texture = _textures.get(expression) if expression != &"neutral" else null
	var tween: Tween = create_tween().set_parallel(true)
	var seconds: float = 0.01 if instant else FADE
	if incoming.texture != null:
		tween.tween_property(incoming, "modulate:a", 1.0, seconds).from(0.0)
	else:
		incoming.modulate.a = 0.0
	tween.tween_property(outgoing, "modulate:a", 0.0, seconds)


## Life at rest: a blink, now and then a glance toward the guest.
func _process(delta: float) -> void:
	if not visible or _holding or not has_frames():
		return
	_idle_left -= delta
	if _idle_left > 0.0:
		return
	_idle_left = randf_range(3.5, 6.5)
	var beat: StringName = &"glance_left" if randf() < 0.25 else &"blink"
	var snap: bool = beat == &"blink"
	show_expression(beat, snap)
	get_tree().create_timer(0.16 if snap else 0.9).timeout.connect(func() -> void:
		if not _holding and showing == beat:
			show_expression(rest, snap))
