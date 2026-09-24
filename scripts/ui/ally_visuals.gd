extends Node2D

@onready var actor: AllyCharacter = get_parent() as AllyCharacter
@onready var debug_label: Label = $Details


func _ready() -> void:
	debug_label.position = Vector2(-330, -55) if actor.selection_slot == 2 else Vector2(-180, 75)


func _process(_delta: float) -> void:
	var debug: bool = get_node("/root/GameManager").debug_visible
	debug_label.visible = debug
	if debug:
		var target_name: String = str(actor.ai.combat_target.name) if is_instance_valid(actor.ai.combat_target) else "none"
		var nav: String = str(actor.destination.round()) if actor.has_destination else "stopped"
		var distance: float = actor.global_position.distance_to(actor.player.global_position) if is_instance_valid(actor.player) else 0
		var link: String = "%s (%.0f / %.0f px)" % [actor.command_link.state_name(), actor.command_link.distance, actor.command_link.effective_range] if actor.command_link != null else "unknown"
		debug_label.text = "%s | HP %.0f/%.0f\nOrder: %s | Behavior: %s\nSelected: %s | Target: %s\nNav: %s | Paul: %.0f px\nLink: %s | Vision: %.0f px" % [actor.data.display_name, actor.health.current_health, actor.health.max_health, AllyAIController.Order.keys()[actor.ai.current_order], AllyAIController.Behavior.keys()[actor.ai.behavior], str(actor.selected), target_name, nav, distance, link, actor.recon.vision_radius if actor.recon != null else 0.0]
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(actor) or actor.health == null or actor.health.is_dead:
		return
	var state: int = actor.command_link.state if actor.command_link != null else CommandLinkComponent.State.CONNECTED
	var color: Color = Color(0.45, 0.85, 0.8, 0.55)
	if actor.selected:
		color = Color(0.75, 1, 0.95)
	# Shape, not only colour, distinguishes a lost command link.
	_draw_link_ring(23, color, 3 if actor.selected else 2, state)
	if actor.selected:
		_draw_link_ring(28, color, 1, state)
		draw_line(Vector2(-7, 33), Vector2(7, 33), color, 3)
	if actor.command_feedback_active():
		var font: Font = ThemeDB.fallback_font
		var text: String = actor.command_feedback_text
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(font, Vector2(-width * 0.5, -46), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.06, 0.08, 0.07))
		draw_string(font, Vector2(-width * 0.5, -46), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.55, 0.45))
	if get_node("/root/GameManager").debug_visible:
		var path: PackedVector2Array = actor.agent.get_current_navigation_path()
		for i in range(1, path.size()):
			draw_line(to_local(path[i - 1]), to_local(path[i]), Color(0.4, 1, 0.85), 1)


## CONNECTED draws a solid ring, WEAK_LINK a finely broken one, and
## OUT_OF_RANGE a widely segmented one.
func _draw_link_ring(radius: float, color: Color, width: float, state: int) -> void:
	if state == CommandLinkComponent.State.CONNECTED:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, width, true)
		return
	var segments: int = 12 if state == CommandLinkComponent.State.WEAK_LINK else 6
	var fill: float = 0.72 if state == CommandLinkComponent.State.WEAK_LINK else 0.4
	var span: float = TAU / segments
	for i in range(segments):
		draw_arc(Vector2.ZERO, radius, i * span, i * span + span * fill, 6, color, width, true)
