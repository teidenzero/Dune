class_name HudStyle
extends RefCounted
## Shared palette, fonts and icons for the in-game HUD. One place to retune the
## look; every HUD widget reads from here instead of hard-coding colours.

const GROUND := Color("13100c")
const PANEL := Color("1d1812")
const PANEL_2 := Color("262017")
const LINE := Color("3a3024")
const SAND := Color("dcc08a")
const SAND_DIM := Color("8a7a5e")
const GOLD := Color("eaa53a")
const GOLD_LIGHT := Color("ffd48a")
const SPICE_BLUE := Color("62b8e0")
const DANGER := Color("e0583c")
const OK := Color("8fd18a")
const TEXT := Color("efe4cf")
const MUTED := Color("9c8e75")
const KEYCAP_TOP := Color("f3dfb4")
const KEYCAP_BOTTOM := Color("cfae70")
const KEYCAP_TEXT := Color("1a140c")

const ICON_DIR := "res://assets/ui/icons/"

static var _fonts: Dictionary = {}


static func icon(name: String) -> Texture2D:
	return load(ICON_DIR + name + ".svg") as Texture2D


## Body text: Chakra Petch.
static func body_font(weight: int = 500) -> Font:
	var path: String = "res://assets/ui/fonts/ChakraPetch-Medium.ttf"
	if weight >= 700:
		path = "res://assets/ui/fonts/ChakraPetch-Bold.ttf"
	elif weight >= 600:
		path = "res://assets/ui/fonts/ChakraPetch-SemiBold.ttf"
	return _cached(path)


## Wide display face for headings and mode tags.
static func display_font() -> Font:
	return _cached("res://assets/ui/fonts/Syncopate-Bold.ttf")


## Keycaps and numbers.
static func mono_font() -> Font:
	var key: String = "mono_bold"
	if not _fonts.has(key):
		var variation: FontVariation = FontVariation.new()
		variation.base_font = load("res://assets/ui/fonts/JetBrainsMono-Variable.ttf") as Font
		var server: TextServer = TextServerManager.get_primary_interface()
		variation.variation_opentype = {server.name_to_tag("wght"): 700}
		_fonts[key] = variation
	return _fonts[key]


static func _cached(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path) as Font
	return _fonts[path]


## A label already dressed in the HUD's type.
static func label(text: String = "", size: int = 16, color: Color = TEXT, font: Font = null) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", font if font != null else body_font(600))
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	# Thin outline on small text: heavy outlines smear at caption sizes.
	result.add_theme_constant_override("outline_size", 4 if size >= 18 else 2)
	return result


## Caption under a slot group ("WEAPONS", "BLADE"...).
static func caption(text: String) -> Label:
	var result: Label = label(text, 12, MUTED)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return result


static func panel_box(border: Color = LINE, fill: Color = PANEL, width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 4)
	return box


## Draw a key label on a sand keycap centred on `center_top`.
static func draw_keycap(canvas: CanvasItem, center_top: Vector2, text: String, font_size: int = 14) -> void:
	var font: Font = mono_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var width: float = maxf(text_size.x + 12.0, 24.0)
	var height: float = font_size + 9.0
	var rect: Rect2 = Rect2(center_top.x - width * 0.5, center_top.y, width, height)
	var shadow: StyleBoxFlat = StyleBoxFlat.new()
	shadow.bg_color = Color("7a6440")
	shadow.set_corner_radius_all(4)
	canvas.draw_style_box(shadow, Rect2(rect.position + Vector2(0, 3), rect.size))
	var cap: StyleBoxFlat = StyleBoxFlat.new()
	cap.bg_color = KEYCAP_BOTTOM
	cap.set_corner_radius_all(4)
	cap.border_color = KEYCAP_TOP
	cap.border_width_top = int(height * 0.45)
	cap.border_blend = true
	canvas.draw_style_box(cap, rect)
	var baseline: float = rect.position.y + (height + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	canvas.draw_string(font, Vector2(rect.position.x + (width - text_size.x) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, KEYCAP_TEXT)
