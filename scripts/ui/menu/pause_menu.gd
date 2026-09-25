class_name PauseMenu
extends CanvasLayer
## Escape in play: the world stops, and a small menu offers to go on, change
## the few settings there are, go back to the main menu, or quit. Anything
## else that uses Escape (closing a briefing, cancelling a knife target or a
## distraction, skipping a story page) gets it first; the menu only opens when
## Escape would otherwise do nothing. Leaving asks once more, because a
## mission left is a mission lost.
##
## A child of GameManager, so it is there in every scene.

const MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
## Screens with their own way out: no pause menu over them.
const OWN_EXIT: Array[String] = [
	"res://scenes/menu/main_menu.tscn",
	"res://scenes/menu/story_screen.tscn",
	"res://scenes/missions/mission_select.tscn",
]

var _was_paused: bool = false
var _root: Control
var _confirm: String = ""
var _rows: VBoxContainer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed() or not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		get_viewport().set_input_as_handled()
		close()
		return
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path in OWN_EXIT:
		return
	# Another screen already up (a briefing, the lesson list) closes itself.
	if get_tree().get_first_node_in_group("briefing_screen") != null:
		return
	get_viewport().set_input_as_handled()
	open()


func open() -> void:
	if visible:
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	_confirm = ""
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


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.025, 0.02, 0.78)
	_root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD, Color(0.07, 0.06, 0.05, 0.96), 1)
	box.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(420, 0)
	_rows.add_theme_constant_override("separation", 10)
	panel.add_child(_rows)
	_fill()


func _fill() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var game: Node = get_parent()
	if _confirm != "":
		var question: String = "Quit the game?" if _confirm == "quit" else "Return to the main menu?"
		_rows.add_child(HudStyle.label(question, 26, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
		var note: Label = HudStyle.label("Progress in this mission will be lost." if _confirm == "quit" else "CONTINUE on the main menu starts this chapter again.", 16, HudStyle.MUTED)
		_rows.add_child(note)
		_rows.add_child(_button("YES, " + ("QUIT" if _confirm == "quit" else "LEAVE"), _leave))
		_rows.add_child(_button("NO, GO BACK", func() -> void:
			_confirm = ""
			_fill()))
		return
	_rows.add_child(HudStyle.label("PAUSED", 30, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
	_rows.add_child(_button("RESUME   ·   ESC", close))
	var music: bool = game.music_enabled if game != null else true
	_rows.add_child(_button("MUSIC:  %s" % ("ON" if music else "OFF"), func() -> void:
		game.music_enabled = not game.music_enabled
		_fill()))
	var fullscreen: bool = get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	_rows.add_child(_button("FULLSCREEN:  %s   ·   F11" % ("ON" if fullscreen else "OFF"), func() -> void:
		game.set_fullscreen(not fullscreen)
		_fill()))
	_rows.add_child(_button("MAIN MENU", func() -> void:
		_confirm = "menu"
		_fill()))
	_rows.add_child(_button("QUIT GAME", func() -> void:
		_confirm = "quit"
		_fill()))


func _leave() -> void:
	var action: String = _confirm
	visible = false
	if _root != null:
		_root.queue_free()
		_root = null
	get_tree().paused = false
	if action == "quit":
		get_tree().quit()
		return
	var game: Node = get_parent()
	if game != null:
		game.pending_briefing = false
		game.tutorial_checkpoint = &""
		game.mission_checkpoint = &""
		game.return_scene = ""
		# The story stays where it is: CONTINUE replays this chapter.
	get_tree().change_scene_to_file(MAIN_MENU)


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", HudStyle.body_font(700))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", HudStyle.TEXT)
	button.add_theme_color_override("font_hover_color", HudStyle.GOLD_LIGHT)
	for key in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD if key == "hover" else HudStyle.LINE, HudStyle.PANEL_2, 1)
		style.set_content_margin_all(12)
		button.add_theme_stylebox_override(key, style)
	button.pressed.connect(action)
	return button
