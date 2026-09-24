class_name DialogueBar
extends CanvasLayer
## Spoken lines, one at a time: a speaker's name and what they say, in a
## panel under the mission title. Lines queue; each stays long enough to read.
## Missions call say(); nothing here decides anything.

signal line_shown(speaker: String, text: String)

const SECONDS_PER_WORD: float = 0.32
const MIN_SECONDS: float = 2.6

var _queue: Array[Dictionary] = []
var _remaining: float = 0.0
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _portrait: TextureRect
## Docked at the bottom of the screen instead of under the title.
var at_bottom: bool = false
var current_speaker: String = ""
var current_text: String = ""


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialogue_bar")
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD, Color(0.07, 0.06, 0.05, 0.92), 1)
	box.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", box)
	if at_bottom:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_panel.offset_bottom = -36
		_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_panel.offset_top = 96
	_panel.offset_left = -420
	_panel.offset_right = 420
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	_panel.add_child(line)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(_portrait)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(rows)
	_speaker = HudStyle.label("", 15, HudStyle.GOLD, HudStyle.body_font(700))
	rows.add_child(_speaker)
	_text = HudStyle.label("", 19, HudStyle.TEXT, HudStyle.body_font(500))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(690, 0)
	rows.add_child(_text)
	_panel.hide()


## Queue a line. `seconds` 0 means long enough to read it.
func say(speaker: String, text: String, seconds: float = 0.0) -> void:
	var time: float = seconds if seconds > 0.0 else maxf(MIN_SECONDS, text.split(" ").size() * SECONDS_PER_WORD)
	_queue.append({"speaker": speaker, "text": text, "time": time})
	if not _panel.visible:
		_next()


func clear() -> void:
	_queue.clear()
	_remaining = 0.0
	_panel.hide()


func busy() -> bool:
	return _panel.visible or not _queue.is_empty()


func _next() -> void:
	if _queue.is_empty():
		_panel.hide()
		current_speaker = ""
		current_text = ""
		return
	var line: Dictionary = _queue.pop_front()
	current_speaker = line.speaker
	current_text = line.text
	_speaker.text = current_speaker.to_upper()
	_speaker.visible = current_speaker != ""
	_portrait.texture = ArtLibrary.speaker_portrait(current_speaker)
	_portrait.visible = _portrait.texture != null
	_text.text = current_text
	_remaining = line.time
	_panel.show()
	line_shown.emit(current_speaker, current_text)


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_next()
