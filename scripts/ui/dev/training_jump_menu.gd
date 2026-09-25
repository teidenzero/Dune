class_name TrainingJumpMenu
extends CanvasLayer
## F10 in a training: every lesson, grouped by section, with the current one
## marked. Pick one and the training reloads straight into it (the same
## checkpoint a retry uses, so the room is set up as it would be on arrival),
## without the briefing. F10 or Esc closes it; the world waits while it is up.
##
## Works with any host that has `steps` (TutorialStep) and `index`: the yard's
## TutorialManager and the training hall's SoloTutorial.

var host: Node
var _root: Control
var _was_paused: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed("dev_jump_menu"):
		get_viewport().set_input_as_handled()
		toggle()
	elif visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if host == null or visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	if _root != null:
		_root.queue_free()
		_root = null
	get_tree().paused = _was_paused


## Reload the training at this lesson.
func jump_to(step_id: StringName) -> void:
	var game: Node = get_node_or_null("/root/GameManager")
	if game == null:
		return
	game.tutorial_checkpoint = step_id
	game.pending_briefing = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.025, 0.02, 0.96)
	_root.add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 120)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	_root.add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	page.add_child(HudStyle.label("JUMP TO A LESSON", 34, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	page.add_child(HudStyle.label("Pick any lesson: the training reloads straight into it.   F10 or Esc closes.", 15, HudStyle.MUTED))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var columns: HFlowContainer = HFlowContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("h_separation", 28)
	columns.add_theme_constant_override("v_separation", 18)
	scroll.add_child(columns)
	var steps: Array = host.get("steps")
	var current: int = int(host.get("index"))
	var section_box: VBoxContainer = null
	var section: String = ""
	var room: int = 0
	for i in range(steps.size()):
		var step: TutorialStep = steps[i]
		if String(step.section) != section:
			section = String(step.section)
			room += 1
			section_box = VBoxContainer.new()
			section_box.custom_minimum_size = Vector2(300, 0)
			section_box.add_theme_constant_override("separation", 4)
			columns.add_child(section_box)
			section_box.add_child(HudStyle.label(_section_name(section, room), 15, HudStyle.GOLD, HudStyle.body_font(800)))
		var button: Button = Button.new()
		button.text = ("▶  " if i == current else "     ") + step.title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", HudStyle.body_font(600))
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", HudStyle.GOLD_LIGHT if i == current else HudStyle.TEXT)
		button.add_theme_color_override("font_hover_color", HudStyle.GOLD_LIGHT)
		for key in ["normal", "hover", "pressed"]:
			var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD if key == "hover" else HudStyle.LINE, HudStyle.PANEL_2, 1)
			box.set_content_margin_all(6)
			button.add_theme_stylebox_override(key, box)
		var id: StringName = step.id
		button.pressed.connect(func() -> void: jump_to(id))
		section_box.add_child(button)


## "movement" -> MOVEMENT; the training hall's rooms r0..r8 -> ROOM 1..9.
func _section_name(section: String, ordinal: int) -> String:
	if section.length() <= 3 and section.begins_with("r") and section.substr(1).is_valid_int():
		return "ROOM %d" % (int(section.substr(1)) + 1)
	return section.replace("_", " ").to_upper()
