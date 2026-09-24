class_name StoryScreen
extends Control
## The campaign's pages of text: the intro, and the title card before each
## chapter. One page at a time, fading in; a click, Space or Enter turns the
## page, Escape skips the rest. The last page hands on to the next chapter.

var pages: Array = []
var page: int = -1

var _heading: Label
var _title: Label
var _text: Label
var _hint: Label
var _body: VBoxContainer
var _backdrop: DuneBackdrop
var _image: TextureRect
var _shade: ColorRect
var _turning: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = DuneBackdrop.new()
	_backdrop.dim = 0.55
	add_child(_backdrop)
	# A painted page, when there is one, over the drawn desert.
	_image = TextureRect.new()
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.02, 0.015, 0.01, 0.55)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(980, 0)
	_body.add_theme_constant_override("separation", 18)
	center.add_child(_body)
	_heading = HudStyle.label("", 18, HudStyle.GOLD, HudStyle.body_font(700))
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_heading)
	_title = HudStyle.label("", 58, HudStyle.GOLD_LIGHT, HudStyle.display_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_title)
	_text = HudStyle.label("", 24, HudStyle.TEXT, HudStyle.body_font(500))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_text)
	_hint = HudStyle.label("CLICK OR SPACE TO CONTINUE   ·   ESC TO SKIP", 14, HudStyle.MUTED)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -60
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	var game: Node = get_node_or_null("/root/GameManager")
	if game != null:
		game.play_music()
	var flow: CampaignFlow = _flow()
	pages = flow.pages() if flow != null else [{"heading": "", "title": "DUNE", "text": ""}]
	next_page()


func _flow() -> CampaignFlow:
	var game: Node = get_node_or_null("/root/GameManager")
	return game.flow if game != null and game.get("flow") != null else null


func next_page() -> void:
	if _turning:
		return
	page += 1
	if page >= pages.size():
		_finish()
		return
	var entry: Dictionary = pages[page]
	var picture: Texture2D = ArtLibrary.story(entry.get("image", ""))
	_image.texture = picture
	_image.visible = picture != null
	_shade.visible = picture != null
	_heading.text = entry.get("heading", "")
	_heading.visible = _heading.text != ""
	_title.text = entry.get("title", "")
	_title.visible = _title.text != ""
	_text.text = entry.get("text", "")
	_body.modulate.a = 0.0
	_image.modulate.a = 0.0
	_turning = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_image, "modulate:a", 1.0, 0.8)
	tween.tween_property(_body, "modulate:a", 1.0, 0.6)
	tween.chain()
	tween.tween_callback(func() -> void: _turning = false)


func _finish() -> void:
	var flow: CampaignFlow = _flow()
	if flow != null and flow.active:
		flow.advance(get_tree())
	else:
		get_tree().change_scene_to_file(CampaignFlow.MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	# Handled first: turning the last page changes scene under us.
	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			call_deferred("_skip")
		elif event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			call_deferred("_turn")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		call_deferred("_turn")


func _skip() -> void:
	_turning = false
	page = pages.size()
	_finish()


## A click mid-fade finishes the fade first.
func _turn() -> void:
	if _turning:
		_body.modulate.a = 1.0
		_image.modulate.a = 1.0
		_turning = false
		return
	next_page()
