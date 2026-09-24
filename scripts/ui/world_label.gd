@tool
class_name WorldLabel
extends Label
## Keeps text that lives in the world at a constant size on screen.
##
## World-space labels shrink with the camera, so widening the default view to a
## planning distance made every name and state readout illegible. Rather than
## picking a font size that only suits one zoom, these scale against the camera
## so they read the same whether the player is pulled back to plan or leaning in
## on a firefight.
##
## The label owns its own rect as well as its font size: a bigger font in a rect
## authored for a smaller one just clips, so the box follows the text and stays
## anchored where the scene put it.

## Size the text should appear at on screen, before the camera is taken into
## account. This is the number to tune; the drawn size follows from it.
@export var screen_font_size: int = 12

var _applied: int = -1
var _measured: String = ""
## Authored anchor: horizontal centre and bottom edge, in parent space.
var _anchor_x: float = 0.0
var _anchor_y: float = 0.0
var _anchored: bool = false


func _ready() -> void:
	_capture_anchor()
	_apply()


func _capture_anchor() -> void:
	if _anchored:
		return
	_anchor_x = (offset_left + offset_right) * 0.5
	_anchor_y = offset_bottom
	_anchored = true


func _process(_delta: float) -> void:
	_apply()


## Moves the label's anchor up by `amount` world pixels - for a unit whose
## drawn figure stands taller than its placeholder. Position changes alone are
## undone by the next zoom-driven resize.
func raise(amount: float) -> void:
	_capture_anchor()
	_anchor_y -= amount
	_applied = -1
	_apply()


func _apply() -> void:
	_capture_anchor()
	var want: int = maxi(int(round(screen_font_size / WorldLabel.camera_zoom(self))), 1)
	if want == _applied and text == _measured:
		return
	_applied = want
	_measured = text
	add_theme_font_size_override("font_size", want)
	var font: Font = get_theme_font("font")
	if font == null:
		return
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, want).x + want
	var height: float = float(want) + want * 0.5
	offset_left = _anchor_x - width * 0.5
	offset_right = _anchor_x + width * 0.5
	offset_bottom = _anchor_y
	offset_top = _anchor_y - height


## Current camera zoom, for anything drawing world-space text by hand.
static func camera_zoom(node: CanvasItem) -> float:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return 1.0
	var viewport: Viewport = node.get_viewport()
	if viewport == null:
		return 1.0
	var camera: Camera2D = viewport.get_camera_2d()
	if camera == null:
		return 1.0
	return maxf(camera.zoom.x, 0.05)


## Font size a `draw_string` call should use to land at `base` pixels on screen.
static func font_size(node: CanvasItem, base: int) -> int:
	return maxi(int(round(base / camera_zoom(node))), 1)
