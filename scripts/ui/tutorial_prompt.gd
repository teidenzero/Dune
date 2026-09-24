extends CanvasLayer
## Tutorial presentation: the current instruction, a delayed hint, a brief
## completion tick, the failure banner, and the closing summary. It renders what
## TutorialManager reports and never decides anything itself.

## A TutorialManager, or any node with the same signals, current_step(),
## `running` and `hint_shown` (the solo tutorial).
@export var manager: Node
## Where the summary's second button goes, and what it says.
@export_file("*.tscn") var next_scene: String = "res://scenes/missions/harvester_raid_test.tscn"
@export var next_label: String = ""

const FADE_SPEED: float = 6.0

var _note: String = ""
var _note_until: int = 0
var _completed_title: String = ""
var _completed_step: TutorialStep
var _completed_until: int = 0

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


func _on_step_completed(step: TutorialStep) -> void:
	_completed_step = step
	_completed_title = step.title
	_completed_until = Time.get_ticks_msec() + 1200
	if step.note != "":
		_note = step.note
		_note_until = Time.get_ticks_msec() + int(maxf(step.delay_after, 1.2) * 1000.0) + 400


func _on_failed(reason: String) -> void:
	banner.text = "TRAINING FAILED\n%s" % reason
	banner.show()


func _on_completed() -> void:
	panel.hide()
	banner.hide()
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
	# The tick belongs to the lesson just done, and only while it is still
	# the one on screen; the next lesson always shows its own name.
	if showing:
		if step == _completed_step and now < _completed_until:
			title.text = "✓ " + _completed_title.to_upper()
		else:
			title.text = step.title.to_upper()
	hint.visible = showing and manager.hint_shown and hint.text != ""
	note.visible = now < _note_until and _note != ""
	note.text = _note
	panel.visible = showing or note.visible
	var target: float = 1.0 if panel.visible else 0.0
	panel.modulate.a = move_toward(panel.modulate.a, target, FADE_SPEED * delta)

## Autoload path lookup, not the global identifier: a --script test harness
## can compile these before autoloads are registered.
func _gm() -> Node:
	return get_node("/root/GameManager")
