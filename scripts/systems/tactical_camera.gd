class_name TacticalCamera
extends Camera2D
## Mode-driven tactical camera, still a child of the tracked character.
##
## FOLLOW_PAUL keeps the original gameplay feel: local position is the bounded
## mouse-look offset and Camera2D's own smoothing supplies the lag. The
## tactical modes compute a world anchor (and zoom) instead, and the local
## position simply becomes anchor minus Paul, so the camera can leave Paul
## behind without reparenting. Godot zoom is inverted: smaller is zoomed out.

enum Mode { FOLLOW_PAUL, FOLLOW_SELECTION, TACTICAL_FREE }

@export_group("Gameplay follow")
@export_range(0.1, 20.0, 0.1) var follow_smoothing: float = 7.0
@export_range(0.0, 200.0, 1.0) var mouse_look_strength: float = 75.0
@export_range(0.1, 20.0, 0.1) var mouse_look_smoothing: float = 5.0
@export var gameplay_zoom: float = 1.0

@export_group("Tactical framing")
@export var tactical_smoothing: float = 6.0
## Separation below which no zoom-out is attempted (dead zone).
@export var shared_frame_start_distance: float = 300.0
## Separation above which Paul is dropped and the ally becomes the anchor.
@export var shared_frame_max_distance: float = 900.0
## World-space breathing room kept around the framed units.
@export var frame_padding: float = 130.0
## Fraction of the viewport the framed box should occupy before zooming out.
@export_range(0.2, 1.0) var frame_fill: float = 0.68
## Most zoomed-out value; keep above the viewport/arena ratio so bounds stay sane.
@export var min_tactical_zoom: float = 0.62
@export var max_tactical_zoom: float = 1.0
@export var zoom_smoothing: float = 3.5
## Hysteresis: ignore smaller zoom requests so the camera does not feel nervous.
@export var zoom_change_threshold: float = 0.035
## Extra follow lag removed while framing tactically, so panning stays responsive.
@export var tactical_snap_speed: float = 40.0

@export_group("Shake")
## Trauma-based shake, added after framing so it works in every camera mode.
@export var shake_decay: float = 2.4
@export var shake_strength: float = 26.0
@export var shake_frequency: float = 26.0

@export_group("Tactical pan")
@export var tactical_pan_speed: float = 900.0
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 20.0

var mode: Mode = Mode.FOLLOW_PAUL
var anchor: Vector2
var framing_bounds: Rect2
var framing_separation: float = 0.0
var framing_subjects: Array[Node2D] = []
var pan_active: bool = false
var focus_hold: bool = false

var _player: Node2D
var _squad: SquadManager
var _look_offset: Vector2 = Vector2.ZERO
var _free_anchor: Vector2
var _frame_center: Vector2
var _zoom_target: float = 1.0
var _zoom_value: float = 1.0
var _paul_framed: bool = true
var _trauma: float = 0.0
var _shake_time: float = 0.0
## Edge scrolling follows the pointer through motion events rather than the
## polled cursor, so a stale default position cannot pan the camera on its own.
var _pointer_seen: bool = false
var _pointer_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_player = get_parent() as Node2D
	position_smoothing_enabled = true
	position_smoothing_speed = follow_smoothing
	_zoom_value = gameplay_zoom
	_zoom_target = gameplay_zoom
	zoom = Vector2.ONE * gameplay_zoom
	anchor = _player_position()
	_free_anchor = anchor
	_frame_center = anchor
	make_current()
	reset_smoothing()
	call_deferred("_bind_squad")


func _bind_squad() -> void:
	_squad = get_tree().get_first_node_in_group("squad_manager") as SquadManager
	if _squad == null:
		return
	_squad.selection_changed.connect(recenter)
	_squad.command_mode_changed.connect(_on_command_mode_changed)


## Cancels manual panning so the camera resumes framing its current subject.
func recenter() -> void:
	pan_active = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer_seen = true
		_pointer_position = event.position
		return
	if not InputMap.has_action("camera_focus_selection"):
		return
	if event.is_action_pressed("camera_focus_selection"):
		focus_hold = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released("camera_focus_selection"):
		focus_hold = false


func _process(delta: float) -> void:
	# Command mode slows gameplay; camera control must not slow down with it.
	var unscaled: float = delta / maxf(Engine.time_scale, 0.01)
	var subjects: Array[Node2D] = _selected_subjects()
	var commanding: bool = is_instance_valid(_squad) and _squad.command_mode
	if commanding:
		_read_pan_input(unscaled)
	else:
		pan_active = false
	_update_mode(commanding, subjects)
	_update_look_offset(unscaled)
	_commit_zoom(_resolve_frame(subjects), unscaled)
	var target: Vector2 = _clamp_to_bounds(_frame_center)
	if mode == Mode.FOLLOW_PAUL and anchor.distance_to(target) < 1.5:
		anchor = target
	else:
		anchor = anchor.lerp(target, 1.0 - exp(-_anchor_speed() * unscaled))
	position_smoothing_speed = follow_smoothing if mode == Mode.FOLLOW_PAUL else tactical_snap_speed
	# Local position participates in Camera2D limits, unlike Camera2D.offset.
	position = anchor - _player_position() + _shake_offset(unscaled)
	queue_redraw()


## Adds trauma without disturbing the framing: shake is an offset applied to the
## resolved local position, so every mode keeps its own anchor and zoom.
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


func _anchor_speed() -> float:
	return follow_smoothing if mode == Mode.FOLLOW_PAUL else tactical_smoothing


func _update_mode(commanding: bool, subjects: Array[Node2D]) -> void:
	var previous: Mode = mode
	if commanding and pan_active:
		mode = Mode.TACTICAL_FREE
	elif (commanding or focus_hold) and not subjects.is_empty():
		mode = Mode.FOLLOW_SELECTION
	else:
		mode = Mode.FOLLOW_PAUL
	# Entering a tactical mode is a deliberate act with the mouse already where
	# the player wants it, so adopt the real cursor now. Waiting for a motion
	# event left edge scrolling dead until the player happened to jiggle it.
	if mode != previous and mode != Mode.FOLLOW_PAUL and not _pointer_seen:
		_adopt_pointer()


## Seeds the tracked pointer from the live cursor, but only when the cursor is
## genuinely inside the window - a stale default must still not pan the camera.
func _adopt_pointer() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var here: Vector2 = viewport.get_mouse_position()
	var size: Vector2 = viewport.get_visible_rect().size
	if here.x < 0.0 or here.y < 0.0 or here.x > size.x or here.y > size.y:
		return
	_pointer_position = here
	_pointer_seen = true


func _resolve_frame(subjects: Array[Node2D]) -> float:
	framing_subjects.clear()
	if mode == Mode.TACTICAL_FREE:
		_frame_center = _free_anchor
		framing_bounds = Rect2(_free_anchor, Vector2.ZERO)
		framing_separation = _player_position().distance_to(_free_anchor)
		return _zoom_target
	if mode == Mode.FOLLOW_SELECTION and not subjects.is_empty():
		return _resolve_shared_frame(subjects)
	_paul_framed = true
	framing_separation = 0.0
	_frame_center = _player_position() + _look_offset
	framing_bounds = Rect2(_frame_center, Vector2.ZERO)
	if is_instance_valid(_player):
		framing_subjects.append(_player)
	return gameplay_zoom


func _resolve_shared_frame(subjects: Array[Node2D]) -> float:
	var paul: Vector2 = _player_position()
	var bounds: Rect2 = Rect2(subjects[0].global_position, Vector2.ZERO)
	framing_separation = 0.0
	for subject in subjects:
		bounds = bounds.expand(subject.global_position)
		framing_separation = maxf(framing_separation, paul.distance_to(subject.global_position))
		framing_subjects.append(subject)
	# Hysteresis: once Paul is dropped, re-include him only well inside the limit.
	var limit: float = shared_frame_max_distance if _paul_framed else shared_frame_max_distance * 0.9
	_paul_framed = framing_separation <= limit
	if _paul_framed:
		bounds = bounds.expand(paul)
		if is_instance_valid(_player):
			framing_subjects.append(_player)
	framing_bounds = bounds
	_frame_center = bounds.get_center()
	if framing_separation <= shared_frame_start_distance:
		return max_tactical_zoom
	var view: Vector2 = get_viewport_rect().size
	var usable: Vector2 = view * frame_fill
	# Equal screen-space margin, not equal world-space margin.
	var pad: Vector2 = Vector2(frame_padding, frame_padding * view.y / maxf(view.x, 1.0))
	var needed: Vector2 = bounds.size + pad * 2.0
	var fit: float = minf(usable.x / maxf(needed.x, 1.0), usable.y / maxf(needed.y, 1.0))
	return clampf(fit, min_tactical_zoom, max_tactical_zoom)


func _commit_zoom(desired: float, unscaled: float) -> void:
	if absf(desired - _zoom_target) > zoom_change_threshold or is_equal_approx(desired, gameplay_zoom):
		_zoom_target = desired
	_zoom_value = lerpf(_zoom_value, _zoom_target, 1.0 - exp(-zoom_smoothing * unscaled))
	zoom = Vector2.ONE * _zoom_value


func _read_pan_input(unscaled: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if edge_scroll_enabled:
		direction += _edge_scroll_vector()
	direction = direction.limit_length(1.0)
	if direction.is_zero_approx():
		return
	if not pan_active:
		_free_anchor = anchor
		pan_active = true
	_free_anchor = _clamp_to_bounds(_free_anchor + direction * tactical_pan_speed * unscaled / maxf(_zoom_value, 0.01))


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


func _update_look_offset(unscaled: float) -> void:
	var desired: Vector2 = Vector2.ZERO
	if mode == Mode.FOLLOW_PAUL:
		var half_size: Vector2 = get_viewport_rect().size * 0.5
		var from_center: Vector2 = get_viewport().get_mouse_position() - half_size
		desired = (from_center / half_size).limit_length(1.0) * mouse_look_strength / maxf(_zoom_value, 0.01)
	_look_offset = _look_offset.lerp(desired, 1.0 - exp(-mouse_look_smoothing * unscaled))


func _clamp_to_bounds(point: Vector2) -> Vector2:
	var half_view: Vector2 = get_viewport_rect().size / maxf(_zoom_value, 0.01) * 0.5
	var result: Vector2 = point
	var min_x: float = limit_left + half_view.x
	var max_x: float = limit_right - half_view.x
	var min_y: float = limit_top + half_view.y
	var max_y: float = limit_bottom - half_view.y
	result.x = (limit_left + limit_right) * 0.5 if min_x > max_x else clampf(point.x, min_x, max_x)
	result.y = (limit_top + limit_bottom) * 0.5 if min_y > max_y else clampf(point.y, min_y, max_y)
	return result


func _selected_subjects() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not is_instance_valid(_squad):
		return result
	for ally in _squad.selected_members:
		if is_instance_valid(ally) and ally.can_process() and not ally.health.is_dead:
			result.append(ally)
	return result


func _player_position() -> Vector2:
	return _player.global_position if is_instance_valid(_player) else anchor


func mode_name() -> String:
	return Mode.keys()[mode]


func get_target_description() -> String:
	if mode == Mode.TACTICAL_FREE:
		return "free look"
	if mode == Mode.FOLLOW_PAUL:
		return "Paul"
	var names: PackedStringArray = []
	for subject in framing_subjects:
		names.append(str(subject.name))
	return ", ".join(names) if not names.is_empty() else "Paul"


func _on_command_mode_changed(active: bool) -> void:
	pan_active = false
	if not active:
		focus_hold = false


func _draw() -> void:
	if not _debug_visible():
		return
	if mode != Mode.FOLLOW_PAUL and framing_bounds.size.length_squared() > 1.0:
		draw_rect(Rect2(to_local(framing_bounds.position), framing_bounds.size), Color(0.6, 1.0, 0.9, 0.35), false, 1.5)
	var center: Vector2 = to_local(anchor)
	draw_line(center - Vector2(12, 0), center + Vector2(12, 0), Color(1.0, 0.9, 0.5, 0.7), 1.5)
	draw_line(center - Vector2(0, 12), center + Vector2(0, 12), Color(1.0, 0.9, 0.5, 0.7), 1.5)


## Autoload path lookup, not the global identifier: these scripts can be
## compiled by a --script test harness before autoloads are registered.
func _debug_visible() -> bool:
	var manager: Node = get_node_or_null("/root/GameManager")
	return manager != null and manager.debug_visible
