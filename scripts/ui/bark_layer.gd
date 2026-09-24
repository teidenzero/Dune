class_name BarkLayer
extends Node2D
## Short spoken lines above units ("MOVING.", "HARKONNEN!") and pulsing rings
## on what they point out. One drawing node for the whole scene, made on first
## use, on real time so it reads the same paused or in prescience.
##
## Every order is acknowledged and every decision a Fremen makes on his own is
## said out loud: the player should never have to guess why a unit moved or fired.

const BARK_SECONDS: float = 1.6
const PING_SECONDS: float = 1.8
## The same line from the same unit is not repeated sooner than this.
const REPEAT_SECONDS: float = 3.0

const SAND: Color = Color(0.96, 0.9, 0.75)
const WARN: Color = Color(1.0, 0.45, 0.35)
const CALM: Color = Color(0.6, 0.95, 0.85)
const OUTLINE: Color = Color(0.03, 0.05, 0.1, 0.9)

## unit -> {text, color, until}
var _barks: Dictionary = {}
## {at, target, color, until}
var _pings: Array[Dictionary] = []
## "<unit id>:<text>" -> msec when it may be said again
var _said: Dictionary = {}


static func layer(tree: SceneTree) -> BarkLayer:
	var found: BarkLayer = tree.get_first_node_in_group("bark_layer") as BarkLayer
	if found != null or tree.current_scene == null:
		return found
	found = BarkLayer.new()
	found.name = "BarkLayer"
	tree.current_scene.add_child(found)
	return found


## `unit` says `text`. Returns false when it was said too recently to repeat.
static func say(unit: Node2D, text: String, color: Color = SAND) -> bool:
	if not is_instance_valid(unit) or not unit.is_inside_tree():
		return false
	var bark: BarkLayer = layer(unit.get_tree())
	return bark != null and bark._say(unit, text, color)


## A pulsing ring on `target` (or at `at`): "that one".
static func ping(tree: SceneTree, at: Vector2, color: Color = WARN, target: Node2D = null) -> void:
	var bark: BarkLayer = layer(tree)
	if bark != null:
		bark._pings.append({"at": at, "target": target, "color": color, "until": Time.get_ticks_msec() + int(PING_SECONDS * 1000.0)})


## What `unit` is saying right now ("" if nothing): for tests and the HUD.
static func current(unit: Node2D) -> String:
	if not is_instance_valid(unit) or not unit.is_inside_tree():
		return ""
	var bark: BarkLayer = unit.get_tree().get_first_node_in_group("bark_layer") as BarkLayer
	if bark == null or not bark._barks.has(unit) or Time.get_ticks_msec() > int(bark._barks[unit].until):
		return ""
	return bark._barks[unit].text


func _ready() -> void:
	add_to_group("bark_layer")
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Above every figure, however deep the isometric view sorts them.
	z_index = 3500


func _say(unit: Node2D, text: String, color: Color) -> bool:
	var now: int = Time.get_ticks_msec()
	var key: String = "%d:%s" % [unit.get_instance_id(), text]
	if now < int(_said.get(key, 0)):
		return false
	_said[key] = now + int(REPEAT_SECONDS * 1000.0)
	_barks[unit] = {"text": text, "color": color, "until": now + int(BARK_SECONDS * 1000.0)}
	return true


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for unit in _barks.keys():
		if not is_instance_valid(unit) or now > int(_barks[unit].until):
			_barks.erase(unit)
	_pings = _pings.filter(func(entry: Dictionary) -> bool: return now <= int(entry.until))
	queue_redraw()


func _draw() -> void:
	var now: int = Time.get_ticks_msec()
	var px: float = IsoView.pixel(self)
	var font: Font = HudStyle.body_font(700)
	var size: int = maxi(int(round(16.0 * px)), 1)
	for entry in _pings:
		var target: Node2D = entry.target if is_instance_valid(entry.target) else null
		var at: Vector2 = to_local(target.global_position if target != null else entry.at)
		var left: float = clampf((int(entry.until) - now) / (PING_SECONDS * 1000.0), 0.0, 1.0)
		var radius: float = (22.0 + (1.0 - fmod(left * 3.0, 1.0)) * 18.0) * px
		draw_arc(at, radius, 0, TAU, 32, OUTLINE, 5.0 * px, true)
		draw_arc(at, radius, 0, TAU, 32, Color(entry.color, 0.4 + 0.6 * left), 2.5 * px, true)
	for unit: Node2D in _barks:
		if not is_instance_valid(unit):
			continue
		var entry: Dictionary = _barks[unit]
		var left: float = clampf((int(entry.until) - now) / (BARK_SECONDS * 1000.0), 0.0, 1.0)
		var alpha: float = minf(left * 4.0, 1.0)
		var text: String = entry.text
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		IsoView.draw_text(self, font, to_local(unit.global_position), Vector2(-width * 0.5, -104.0 * px), text, size, Color(entry.color, alpha), maxi(int(5.0 * px), 1), Color(OUTLINE, alpha))
