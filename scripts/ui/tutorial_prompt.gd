extends CanvasLayer
## Tutorial presentation: the current instruction, a delayed hint, a brief
## completion tick, the failure banner, and the closing summary. It renders what
## TutorialManager reports and never decides anything itself.

@export var manager: TutorialManager

const FADE_SPEED: float = 6.0

var _note: String = ""
var _note_until: int = 0
var _completed_title: String = ""
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


func _ready() -> void:
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


func _on_step_started(step: TutorialStep) -> void:
	banner.hide()
	speaker.text = step.speaker
	speaker.visible = step.speaker != ""
	title.text = step.title.to_upper()
	instruction.text = step.instruction
	hint.text = step.hint
	hint.hide()
	note.hide()
	panel.show()


func _on_step_completed(step: TutorialStep) -> void:
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
	summary.show()


func _on_restart() -> void:
	_gm().tutorial_checkpoint = &""
	get_tree().reload_current_scene()


func _on_open_arena() -> void:
	_gm().tutorial_checkpoint = &""
	get_tree().change_scene_to_file("res://scenes/missions/harvester_raid_test.tscn")


func _process(delta: float) -> void:
	if not is_instance_valid(manager) or summary.visible:
		return
	var now: int = Time.get_ticks_msec()
	var step: TutorialStep = manager.current_step()
	var showing: bool = step != null and manager.running
	if showing and now < _completed_until:
		title.text = "✓ " + _completed_title.to_upper()
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
