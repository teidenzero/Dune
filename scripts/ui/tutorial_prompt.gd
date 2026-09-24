extends CanvasLayer
## Tutorial presentation: the current instruction, a delayed hint, the
## completion tick and closing note (held on screen until they can be read),
## the failure banner and the closing summary. Tab folds the panel away to a
## small tab for a clear view of the field; L opens the last lessons again.
## It renders what TutorialManager reports and never decides anything itself.

## A TutorialManager, or any node with the same signals, current_step(),
## `running` and `hint_shown` (the solo tutorial).
@export var manager: Node
## Where the summary's second button goes, and what it says.
@export_file("*.tscn") var next_scene: String = "res://scenes/missions/harvester_raid_test.tscn"
@export var next_label: String = ""

const FADE_SPEED: float = 6.0
const HISTORY_SIZE: int = 8

## Folded away with Tab: only a small tab shows there is a lesson.
var collapsed: bool = false
var _history: Array[TutorialStep] = []
var _tab: PanelContainer
var _tab_label: Label
var _tab_pulse_until: int = 0
var _log: PanelContainer
var _log_text: Label

@onready var panel: PanelContainer = $Screen/Prompt
@onready var speaker: Label = $Screen/Prompt/Margin/Rows/Speaker
@onready var title: Label = $Screen/Prompt/Margin/Rows/Title
@onready var instruction: Label = $Screen/Prompt/Margin/Rows/Instruction
@onready var hint: Label = $Screen/Prompt/Margin/Rows/Hint
@onready var note: Label = $Screen/Prompt/Margin/Rows/Note
@onready var banner: Label = $Screen/Banner
@onready var summary: PanelContainer = $Screen/Summary
@onready var restart_button: Button = $Screen/Summary/Margin/Rows/Buttons/Restart
@onready var arena_button: Button = $Screen/Summary/Margin/Rows/Buttons/Arena
var portrait: TextureRect


func _ready() -> void:
	_add_portrait()
	_build_tab()
	_build_log()
	summary.hide()
	banner.hide()
	panel.modulate.a = 0.0
	if not is_instance_valid(manager):
		return
	manager.tutorial_step_started.connect(_on_step_started)
	manager.tutorial_step_completed.connect(_on_step_completed)
	manager.tutorial_failed.connect(_on_failed)
	manager.tutorial_completed.connect(_on_completed)
	restart_button.pressed.connect(_on_restart)
	arena_button.pressed.connect(_on_open_arena)
	if next_label != "":
		arena_button.text = next_label
	if _flow_scene():
		arena_button.text = "Continue"


## The teacher's face beside the lesson: the rows move into a row with it.
func _add_portrait() -> void:
	var margin: Node = $Screen/Prompt/Margin
	var rows: Control = $Screen/Prompt/Margin/Rows
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "Line"
	line.add_theme_constant_override("separation", 18)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.remove_child(rows)
	margin.add_child(line)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(portrait)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(rows)
	portrait.hide()


func _on_step_started(step: TutorialStep) -> void:
	banner.hide()
	portrait.texture = ArtLibrary.speaker_portrait(step.speaker)
	portrait.visible = portrait.texture != null
	speaker.text = step.speaker
	speaker.visible = step.speaker != ""
	title.text = step.title.to_upper()
	instruction.text = step.instruction
	hint.text = step.hint
	hint.hide()
	note.hide()
	panel.show()
	_history.erase(step)
	_history.push_front(step)
	if _history.size() > HISTORY_SIZE:
		_history.pop_back()
	if _log.visible:
		_refresh_log()
	# Folded away: the tab catches the eye when a new lesson arrives.
	_tab_pulse_until = Time.get_ticks_msec() + 2500


func _on_step_completed(_step: TutorialStep) -> void:
	pass


## The folded panel: a small tab at the top of the screen.
func _build_tab() -> void:
	_tab = PanelContainer.new()
	_tab.name = "Tab"
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.LINE, Color(HudStyle.PANEL, 0.88), 1)
	box.set_content_margin_all(8)
	box.content_margin_left = 16
	box.content_margin_right = 16
	_tab.add_theme_stylebox_override("panel", box)
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_tab.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tab.offset_top = 10.0
	$Screen.add_child(_tab)
	_tab_label = HudStyle.label("", 15, HudStyle.SAND, HudStyle.body_font(600))
	_tab.add_child(_tab_label)
	_tab.hide()


## L: the last lessons, newest first, for whatever went by too fast.
func _build_log() -> void:
	_log = PanelContainer.new()
	_log.name = "Log"
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD, Color(HudStyle.PANEL, 0.96), 2)
	box.set_content_margin_all(22)
	_log.add_theme_stylebox_override("panel", box)
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_log.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_log.grow_vertical = Control.GROW_DIRECTION_BOTH
	_log.offset_right = -24.0
	$Screen.add_child(_log)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	_log.add_child(rows)
	rows.add_child(HudStyle.label("LESSONS SO FAR   ·   L TO CLOSE", 15, HudStyle.GOLD, HudStyle.body_font(700)))
	_log_text = HudStyle.label("", 16, HudStyle.TEXT, HudStyle.body_font(500))
	_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_text.custom_minimum_size = Vector2(560, 0)
	rows.add_child(_log_text)
	_log.hide()


func _refresh_log() -> void:
	var lines: PackedStringArray = []
	for step in _history:
		var head: String = step.title.to_upper()
		if step.speaker != "":
			head = step.speaker + "  ·  " + head
		var entry: String = head + "
" + step.instruction
		if step.state == TutorialStep.State.COMPLETE and step.note != "":
			entry += "
" + step.note
		lines.append(entry)
	_log_text.text = "

".join(lines) if not lines.is_empty() else "Nothing yet."


func toggle_collapsed() -> void:
	collapsed = not collapsed


func toggle_log() -> void:
	_log.visible = not _log.visible
	if _log.visible:
		_refresh_log()


func _input(event: InputEvent) -> void:
	if summary.visible or event.is_echo():
		return
	# Before the GUI: Tab would otherwise move keyboard focus.
	if event.is_action_pressed("tutorial_toggle"):
		toggle_collapsed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tutorial_log"):
		toggle_log()
		get_viewport().set_input_as_handled()


func _on_failed(reason: String) -> void:
	banner.text = "TRAINING FAILED\n%s" % reason
	banner.show()


func _on_completed() -> void:
	panel.hide()
	banner.hide()
	_tab.hide()
	_log.hide()
	var growth: PackedStringArray = GrowthReport.lines(Progression.campaign_of(self))
	var taught: Label = get_node_or_null("Screen/Summary/Margin/Rows/Taught") as Label
	if taught != null and not growth.is_empty():
		taught.text += "\n\n" + "\n".join(growth)
	summary.show()


func _on_restart() -> void:
	_gm().tutorial_checkpoint = &""
	get_tree().reload_current_scene()


func _on_open_arena() -> void:
	_gm().tutorial_checkpoint = &""
	if _flow_scene():
		_gm().flow.advance(get_tree())
		return
	get_tree().change_scene_to_file(next_scene)


## Played as a chapter of the campaign.
func _flow_scene() -> bool:
	var scene: Node = get_tree().current_scene
	return _gm().get("flow") != null and scene != null and _gm().flow.playing(scene.scene_file_path)


func _process(delta: float) -> void:
	if not is_instance_valid(manager) or summary.visible:
		return
	var now: int = Time.get_ticks_msec()
	var step: TutorialStep = manager.current_step()
	var showing: bool = step != null and manager.running
	# A finished lesson stays on screen, ticked, with its closing note, until
	# the manager has held it long enough to be read.
	var done: bool = showing and step.state == TutorialStep.State.COMPLETE
	if showing:
		title.text = ("✓ " if done else "") + step.title.to_upper()
		note.text = step.note
	hint.visible = showing and not done and manager.hint_shown and hint.text != ""
	note.visible = done and step.note != ""
	panel.visible = showing and not collapsed
	var target: float = 1.0 if panel.visible else 0.0
	panel.modulate.a = move_toward(panel.modulate.a, target, FADE_SPEED * delta)
	_tab.visible = showing and collapsed
	if _tab.visible:
		_tab_label.text = "TAB  ·  SHOW LESSON:  " + title.text
		var pulse: float = 0.5 + 0.5 * sin(now / 120.0) if now < _tab_pulse_until else 1.0
		_tab.modulate = Color(1, 1, 1, 0.55 + 0.45 * pulse)

## Autoload path lookup, not the global identifier: a --script test harness
## can compile these before autoloads are registered.
func _gm() -> Node:
	return get_node("/root/GameManager")
