class_name MainMenu
extends Control
## The title screen: a new campaign, carrying on with the one in progress
## this session, the developer's mission launcher, and quitting.

const LAUNCHER: String = "res://scenes/missions/mission_select.tscn"

var _continue: Button
var _music: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(DuneBackdrop.new())
	# The title is painted into the title screen itself.
	var painting: Texture2D = ArtLibrary.story("title_screen")
	var painted_title: bool = painting != null
	if painting == null:
		painting = ArtLibrary.story("menu_background")
	if painting != null:
		var image: TextureRect = TextureRect.new()
		image.texture = painting
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	add_child(rows)
	if painted_title:
		# On the right, across from the painted title, clear of the banner.
		rows.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		rows.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		rows.grow_vertical = Control.GROW_DIRECTION_BOTH
		rows.offset_right = -110
		rows.offset_left = -110 - 420
		rows.offset_top = -210
		rows.offset_bottom = 210
	else:
		rows.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		rows.offset_left = 140
		rows.offset_top = -260
		rows.offset_bottom = 300
		rows.add_child(HudStyle.label("DUNE", 120, HudStyle.GOLD_LIGHT, HudStyle.display_font()))
		var gap: Control = Control.new()
		gap.custom_minimum_size = Vector2(0, 40)
		rows.add_child(gap)
	rows.add_child(_button("NEW CAMPAIGN", new_campaign))
	_continue = _button("CONTINUE", continue_campaign)
	rows.add_child(_continue)
	rows.add_child(_button("CODEX", func() -> void: get_tree().change_scene_to_file("res://scenes/menu/codex.tscn")))
	rows.add_child(_button("MISSIONS  (developer)", func() -> void:
		get_node("/root/GameManager").stop_music()
		get_tree().change_scene_to_file(LAUNCHER)))
	_music = _button("", toggle_music)
	rows.add_child(_music)
	rows.add_child(_button("QUIT", func() -> void: get_tree().quit()))
	_refresh_music()
	var game: Node = get_node_or_null("/root/GameManager")
	if game != null:
		game.play_music()
	var flow: CampaignFlow = _flow()
	_continue.disabled = flow == null or not flow.active
	_continue.tooltip_text = "Carry on with this session's campaign" if not _continue.disabled else "No campaign in progress"


func _flow() -> CampaignFlow:
	var game: Node = get_node_or_null("/root/GameManager")
	return game.flow if game != null else null


func toggle_music() -> void:
	var game: Node = get_node_or_null("/root/GameManager")
	if game == null:
		return
	game.music_enabled = not game.music_enabled
	if game.music_enabled:
		game.play_music()
	_refresh_music()


func _refresh_music() -> void:
	var game: Node = get_node_or_null("/root/GameManager")
	var on: bool = game == null or game.music_enabled
	_music.text = "MUSIC:  ON" if on else "MUSIC:  OFF"


func new_campaign() -> void:
	var flow: CampaignFlow = _flow()
	if flow != null:
		flow.start(get_tree())


func continue_campaign() -> void:
	var flow: CampaignFlow = _flow()
	if flow != null and flow.active:
		flow.go(get_tree())


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 60)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", HudStyle.body_font(700))
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", HudStyle.TEXT)
	button.add_theme_color_override("font_hover_color", HudStyle.GOLD_LIGHT)
	button.add_theme_color_override("font_disabled_color", Color(HudStyle.SAND_DIM, 0.6))
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = HudStyle.panel_box(HudStyle.GOLD if key in ["hover", "pressed", "focus"] else Color(0, 0, 0, 0), Color(0.06, 0.03, 0.02, 0.78) if key != "focus" else Color(0, 0, 0, 0), 1)
		box.set_content_margin_all(14)
		box.shadow_size = 0
		button.add_theme_stylebox_override(key, box)
	button.pressed.connect(action)
	return button
