class_name TacticalCamera
extends Camera2D
## Free RTS camera. It is still a child of Paul, but it never follows him: it
## keeps its own world anchor and sets `position = anchor - Paul`, so it stays
## put while the squad moves. WASD / arrows / screen edges pan, the wheel zooms,
## and `center_on` (pressing a unit's number twice) jumps to a point.
## Godot zoom is inverted: smaller is zoomed out.

@export var gameplay_zoom: float = 0.93
@export_range(0.1, 30.0, 0.1) var center_smoothing: float = 9.0

@export_group("Shake")
## Trauma-based shake, added on top of the anchor.
@export var shake_decay: float = 2.4
@export var shake_strength: float = 26.0
@export var shake_frequency: float = 26.0

@export_group("Player zoom")
## The mouse wheel scales the base zoom. Planning distance is a preference, so
## it is the player's to set rather than something the camera decides.
@export var player_zoom_enabled: bool = true
@export_range(0.05, 0.5, 0.01) var player_zoom_step: float = 0.08
## Closest the player may pull in. The far end is computed per scene from the
## camera limits, so no mission can be zoomed out past its own edges.
@export var player_zoom_max: float = 1.9
@export var player_zoom_smoothing: float = 10.0

@export_group("Pan")
@export var pan_speed: float = 1100.0
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 20.0

var anchor: Vector2
var pan_active: bool = false
## Solo scope: follow the hero, leaning toward the mouse, instead of panning.
var follow: bool = false
@export var follow_smoothing: float = 8.0
@export var look_ahead: float = 160.0

var _player: Node2D
var _center_target: Vector2
var _centering: bool = false
var _player_zoom: float = 1.0
var _player_zoom_target: float = 1.0
## Turn-based combat's framing: a zoom that overrides the player's while > 0.
var combat_zoom: float = 0.0
var _combat_blend: float = 0.0
var _trauma: float = 0.0
var _shake_time: float = 0.0
## Edge scrolling follows the pointer through motion events rather than the
## polled cursor, so a stale default position cannot pan the camera on its own.
var _pointer_seen: bool = false
var _pointer_position: Vector2 = Vector2.ZERO
## The squad scope's isometric view (IsoView): the camera sets the viewport's
## canvas transform itself, since a Camera2D cannot slant the view. Off in the
## interiors, which are drawn isometric already, and in follow mode.
var iso: bool = false
var _iso_view: IsoView


func _ready() -> void:
	# Panning and zooming keep working while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent() as Node2D
	position_smoothing_enabled = false
	zoom = Vector2.ONE * gameplay_zoom
	anchor = _player_position()
	make_current()
	call_deferred("_settle")


func _settle() -> void:
	_setup_iso()
	anchor = _clamp_to_bounds(_player_position())
	position = anchor - _player_position()
	reset_smoothing()


## Squad maps are seen isometrically unless the game says otherwise; an
## interior (an IsoLevel) never is.
func _setup_iso() -> void:
	var game: Node = get_node_or_null("/root/GameManager")
	var wanted: bool = game == null or game.get("squad_iso") != false
	iso = wanted and not follow and get_tree().get_first_node_in_group("iso_level") == null
	IsoView.active = iso
	if not iso:
		return
	enabled = false
	_iso_view = IsoView.new()
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else _player.get_parent()
	host.add_child.call_deferred(_iso_view)
	_apply_iso_view(0.0)


## The isometric view: centre on the anchor, zoom, slant, shake.
func _apply_iso_view(unscaled: float) -> void:
	var screen: Vector2 = get_viewport_rect().size
	var shake: Vector2 = _shake_offset(unscaled) if unscaled > 0.0 else Vector2.ZERO
	var view: Transform2D = Transform2D(0.0, screen * 0.5 + shake) * Transform2D(0.0, Vector2.ONE * effective_zoom(), 0.0, Vector2.ZERO) * IsoView.BASIS * Transform2D(0.0, -anchor)
	get_viewport().canvas_transform = view


## Jump the view to a world point with no glide.
func snap_to(point: Vector2) -> void:
	_centering = false
	anchor = _clamp_to_bounds(point)
	position = anchor - _player_position()
	reset_smoothing()


## Glide the view to a world point.
func center_on(point: Vector2) -> void:
	# Near a map edge the view cannot centre on the point; aim for the closest
	# legal anchor so the glide actually finishes.
	_center_target = _clamp_to_bounds(point)
	_centering = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer_seen = true
		_pointer_position = event.position
		return
	if player_zoom_enabled and event is InputEventMouseButton and event.pressed:
		var step: float = 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = player_zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = -player_zoom_step
		if step != 0.0:
			_player_zoom_target = clampf(_player_zoom_target + step, _minimum_player_zoom(), player_zoom_max)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Prescience slows the world; the camera must not slow down with it.
	var unscaled: float = delta / maxf(Engine.time_scale, 0.01)
	_player_zoom_target = clampf(_player_zoom_target, _minimum_player_zoom(), player_zoom_max)
	_player_zoom = lerpf(_player_zoom, _player_zoom_target, 1.0 - exp(-player_zoom_smoothing * unscaled))
	_combat_blend = move_toward(_combat_blend, 1.0 if combat_zoom > 0.0 else 0.0, unscaled * 2.5)
	zoom = Vector2.ONE * effective_zoom()
	if follow:
		pan_active = false
		_centering = false
		var half: Vector2 = get_viewport_rect().size * 0.5
		var lean: Vector2 = ((get_viewport().get_mouse_position() - half) / half).limit_length(1.0) * look_ahead / effective_zoom()
		anchor = anchor.lerp(_player_position() + lean, 1.0 - exp(-follow_smoothing * unscaled))
		anchor = _clamp_to_bounds(anchor)
		position = anchor - _player_position() + _shake_offset(unscaled)
		return
	var direction: Vector2 = _pan_input()
	pan_active = not direction.is_zero_approx()
	if pan_active:
		_centering = false
		var step: Vector2 = direction * pan_speed * unscaled / effective_zoom()
		# In the isometric view "right" is right on screen, not along world x.
		anchor += IsoView.BASIS.affine_inverse().basis_xform(step) if iso else step
	elif _centering:
		anchor = anchor.lerp(_center_target, 1.0 - exp(-center_smoothing * unscaled))
		if anchor.distance_to(_center_target) < 2.0:
			anchor = _center_target
			_centering = false
	anchor = _clamp_to_bounds(anchor)
	if iso:
		_apply_iso_view(unscaled)
		return
	# Local position participates in Camera2D limits, unlike Camera2D.offset.
	position = anchor - _player_position() + _shake_offset(unscaled)


## Adds trauma without disturbing the anchor.
func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + maxf(amount, 0.0), 0.0, 1.0)


func clear_shake() -> void:
	_trauma = 0.0


func shake_amount() -> float:
	return _trauma


## Real time, so a nearly frozen world still shakes at a readable rate.
func _shake_offset(unscaled: float) -> Vector2:
	if _trauma <= 0.0:
		return Vector2.ZERO
	_trauma = maxf(_trauma - shake_decay * unscaled, 0.0)
	_shake_time += unscaled * shake_frequency
	var magnitude: float = _trauma * _trauma * shake_strength
	return Vector2(sin(_shake_time * 1.7), cos(_shake_time * 2.3)) * magnitude


## The zoom actually applied: the base view scaled by the player's preference,
## floored so the view never leaves the mission.
func effective_zoom() -> float:
	var normal: float = maxf(maxf(gameplay_zoom * _player_zoom, _scene_minimum_zoom()), 0.01)
	if _combat_blend <= 0.0:
		return normal
	var framed: float = maxf(combat_zoom if combat_zoom > 0.0 else normal, _scene_minimum_zoom())
	return lerpf(normal, framed, smoothstep(0.0, 1.0, _combat_blend))


## Turn-based combat takes the view: framing on, following off. Pass zoom 0
## to hand it back as it was.
func set_combat_view(zoom_level: float) -> void:
	if zoom_level > 0.0:
		if combat_zoom <= 0.0:
			_was_following = follow
		follow = false
	elif combat_zoom > 0.0:
		follow = _was_following
	combat_zoom = zoom_level


var _was_following: bool = false


## The widest this mission can be shown without the view running past the camera
## limits. Each scene gets whatever its own bounds can support.
func _scene_minimum_zoom() -> float:
	if iso:
		# The map's outline on screen: its four corners through the slant.
		var box: Rect2 = Rect2(IsoView.BASIS * Vector2(limit_left, limit_top), Vector2.ZERO)
		for corner in [Vector2(limit_right, limit_top), Vector2(limit_left, limit_bottom), Vector2(limit_right, limit_bottom)]:
			box = box.expand(IsoView.BASIS * corner)
		var shown: Vector2 = get_viewport_rect().size
		return clampf(maxf(shown.x / maxf(box.size.x, 1.0), shown.y / maxf(box.size.y, 1.0)) * 0.6, 0.05, 1.0)
	var span: Vector2 = Vector2(float(limit_right - limit_left), float(limit_bottom - limit_top))
	if span.x <= 0.0 or span.y <= 0.0:
		return 0.05
	var view: Vector2 = get_viewport_rect().size
	return maxf(view.x / span.x, view.y / span.y)


func _minimum_player_zoom() -> float:
	return clampf(_scene_minimum_zoom() / maxf(gameplay_zoom, 0.01), 0.35, player_zoom_max)


## Whether a world point is actually on screen.
func sees(point: Vector2, margin: float = 0.0) -> bool:
	if iso:
		var on_screen: Vector2 = get_viewport().canvas_transform * point
		return Rect2(Vector2.ZERO, get_viewport_rect().size).grow(-margin * effective_zoom()).has_point(on_screen)
	var half: Vector2 = visible_world_size() * 0.5
	var centre: Vector2 = get_screen_center_position()
	return absf(point.x - centre.x) <= half.x - margin and absf(point.y - centre.y) <= half.y - margin


## Diagnostics and tests read the effective view rather than the raw zoom.
func visible_world_size() -> Vector2:
	return get_viewport_rect().size / effective_zoom()


func _pan_input() -> Vector2:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if edge_scroll_enabled:
		direction += _edge_scroll_vector()
	return direction.limit_length(1.0)


func _edge_scroll_vector() -> Vector2:
	if not _pointer_seen:
		return Vector2.ZERO
	var viewport: Viewport = get_viewport()
	# HUD panels sit against the screen edges; never edge-scroll while using them.
	if viewport.gui_get_hovered_control() != null:
		return Vector2.ZERO
	var size: Vector2 = viewport.get_visible_rect().size
	var mouse: Vector2 = _pointer_position
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > size.x or mouse.y > size.y:
		return Vector2.ZERO
	var result: Vector2 = Vector2.ZERO
	if mouse.x < edge_scroll_margin:
		result.x -= 1.0
	elif mouse.x > size.x - edge_scroll_margin:
		result.x += 1.0
	if mouse.y < edge_scroll_margin:
		result.y -= 1.0
	elif mouse.y > size.y - edge_scroll_margin:
		result.y += 1.0
	return result


func _clamp_to_bounds(point: Vector2) -> Vector2:
	if iso:
		# The slanted view shows past the corners anyway: keep the centre on the map.
		return Vector2(clampf(point.x, limit_left, limit_right), clampf(point.y, limit_top, limit_bottom))
	var half_view: Vector2 = get_viewport_rect().size / effective_zoom() * 0.5
	var result: Vector2 = point
	var min_x: float = limit_left + half_view.x
	var max_x: float = limit_right - half_view.x
	var min_y: float = limit_top + half_view.y
	var max_y: float = limit_bottom - half_view.y
	result.x = (limit_left + limit_right) * 0.5 if min_x > max_x else clampf(point.x, min_x, max_x)
	result.y = (limit_top + limit_bottom) * 0.5 if min_y > max_y else clampf(point.y, min_y, max_y)
	return result


func _player_position() -> Vector2:
	return _player.global_position if is_instance_valid(_player) else anchor


func mode_name() -> String:
	if follow:
		return "FOLLOW"
	return "CENTERING" if _centering else ("PANNING" if pan_active else "FREE")


func _draw() -> void:
	if not _debug_visible():
		return
	var center: Vector2 = to_local(anchor)
	draw_line(center - Vector2(12, 0), center + Vector2(12, 0), Color(1.0, 0.9, 0.5, 0.7), 1.5)
	draw_line(center - Vector2(0, 12), center + Vector2(0, 12), Color(1.0, 0.9, 0.5, 0.7), 1.5)


## Autoload path lookup, not the global identifier: these scripts can be
## compiled by a --script test harness before autoloads are registered.
func _debug_visible() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	return manager != null and manager.debug_visible
