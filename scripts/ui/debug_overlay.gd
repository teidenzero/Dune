extends CanvasLayer
## Hosts the player HUD and the F1 metrics panel. Add rows via set_metric().

@export var player: PlayerController
@export var squad: SquadManager
@export var recon: ReconManager

var metric_labels: Dictionary = {}

@onready var panel: PanelContainer = $Screen/DebugPanel
@onready var metrics: GridContainer = $Screen/DebugPanel/Margin/Scroll/Metrics
@onready var hud: PlayerHud = $Screen/HUD


func _ready() -> void:
	GameManager.debug_visibility_changed.connect(_on_debug_visibility_changed)
	_on_debug_visibility_changed(GameManager.debug_visible)
	if is_instance_valid(player):
		hud.setup(player, squad)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle") and not event.is_echo():
		GameManager.debug_visible = not GameManager.debug_visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not panel.visible:
		return
	if is_instance_valid(squad):
		set_metric("Paused", str(squad.paused))
		set_metric("Targeting", SquadManager.Targeting.keys()[squad.targeting])
		var names: PackedStringArray = []
		if squad.paul_selected:
			names.append("Paul")
		for ally in squad.selected_members:
			if is_instance_valid(ally):
				names.append("Scout" if ally.selection_slot == 2 else "Warrior")
		set_metric("Selected units", ", ".join(names) if not names.is_empty() else "none")
	set_metric("FPS", str(Engine.get_frames_per_second()))
	if is_instance_valid(player):
		set_metric("World position", "%.1f, %.1f" % [player.global_position.x, player.global_position.y])
		set_metric("Speed", "%.1f px/s" % player.get_real_velocity().length())
		set_metric("Sprinting", "YES" if player.is_sprinting else "NO")
		set_metric("Paul order", player.order_name())
		var profile: StealthProfile = player.stealth_profile
		set_metric("Stance", profile.stance)
		set_metric("Movement", profile.movement_mode)
		set_metric("Visibility stance / move", "%.2f / %.2f" % [profile.stance_visibility_modifier, profile.movement_visibility_modifier])
		set_metric("Exposure", "%.2f" % profile.exposure)
		set_metric("Noise radius", "%.0f px" % profile.current_noise_radius)
		set_metric("Player HP", "%.0f / %.0f" % [player.health.current_health, player.health.max_health])
		var weapon: WeaponController = player.weapon_controller
		set_metric("Current weapon", weapon.weapon_data.weapon_name)
		set_metric("Ammo", "%d / %d" % [weapon.current_ammo, weapon.weapon_data.magazine_size])
		set_metric("Is reloading", "YES" if weapon.is_reloading else "NO")
		set_metric("Fire cooldown", "%.2f s" % weapon.cooldown_remaining)
		set_metric("Can fire", "YES" if weapon.can_fire else "NO")
		set_metric("Active projectiles", str(get_tree().get_nodes_in_group("projectiles").size()))
	_update_worm_metrics()
	_update_prescience_metrics()
	_update_tutorial_metrics()
	_update_mission_metrics()
	_update_melee_metrics()
	_update_camera_metrics()
	_update_link_metrics()
	_update_recon_metrics()


func _update_worm_metrics() -> void:
	var worm: WormThreatManager = get_tree().get_first_node_in_group("worm_threat") as WormThreatManager
	if worm == null:
		return
	set_metric("Worm sign", "%.1f / %.0f" % [worm.worm_sign, worm.threshold])
	set_metric("Worm threat stage", worm.stage_name())
	set_metric("Worm event state", worm.state_name())
	set_metric("Worm strongest source", "%s (%.1f)" % [worm.strongest_label, worm.strongest_strength])
	set_metric("Worm source position", "%.0f, %.0f" % [worm.strongest_position.x, worm.strongest_position.y] if worm.strongest_position.is_finite() else "none")
	set_metric("Worm target", "%.0f, %.0f" % [worm.target.x, worm.target.y] if worm.target.is_finite() else "none")
	set_metric("Worm arrival ETA", "%.1f s" % worm.event.eta() if worm.event != null and worm.event.phase == WormApproachEvent.Phase.TRAVEL else "-")
	set_metric("Worm cooldown", "%.1f s" % worm.cooldown_remaining)
	set_metric("Worm emitters", str(get_tree().get_nodes_in_group("worm_emitters").size()))
	if is_instance_valid(player):
		var terrain: TerrainSafetyComponent = TerrainSafetyComponent.find_on(player)
		if terrain != null:
			set_metric("Player terrain", terrain.terrain_name())
			set_metric("Player on safe ground", "YES" if terrain.is_safe() else "NO")
	var camera: TacticalCamera = _camera()
	if camera != null:
		set_metric("Camera shake", "%.2f" % camera.shake_amount())


func _update_prescience_metrics() -> void:
	if not is_instance_valid(player) or player.prescience == null:
		return
	var prescience: PrescienceController = player.prescience
	var energy: PrescienceEnergyComponent = player.prescience_energy
	set_metric("Time scale holder", "%s (%.2f)" % [TimeScaleManager.holder_name(), Engine.time_scale])
	set_metric("Prescience active", "YES" if prescience.active else "NO")
	set_metric("Prescience energy", "%.0f / %.0f" % [energy.current_energy, energy.max_energy])
	set_metric("Prescience regen", "%.1f/s (%s)" % [energy.regen_per_second, "on" if energy.regenerating else "paused"])
	set_metric("Prescience remaining", "%.2f s" % prescience.remaining)
	set_metric("Prediction horizon", "%.1f s" % prescience.prediction_horizon)
	set_metric("Projection updates", "%.0f/s" % prescience.updates_per_second)
	set_metric("Tracked actors", str(prescience.tracked_count()))
	set_metric("Incoming fire warning", "YES" if prescience.danger else "NO")
	for projection: FuturePredictor.FutureTrack in prescience.projections:
		if not is_instance_valid(projection.actor):
			continue
		var label: String = str(projection.actor.name)
		var samples: PackedStringArray = []
		for point in projection.positions:
			samples.append("%.0f,%.0f" % [point.x, point.y])
		set_metric(label + " prediction", "%s c%.2f%s" % [projection.state_name, projection.certainty, " FIRES" if projection.fires else ""])
		set_metric(label + " future", " | ".join(samples))


func _update_tutorial_metrics() -> void:
	var tutorial: Node = get_tree().get_first_node_in_group("tutorial_manager")
	if tutorial == null:
		return
	var rows: Dictionary = tutorial.debug_rows()
	for title in rows:
		set_metric(title, rows[title])


func _update_mission_metrics() -> void:
	var controller: Node = get_tree().get_first_node_in_group("mission_controller")
	if controller == null:
		return
	var rows: Dictionary = controller.debug_rows()
	for title in rows:
		set_metric(title, rows[title])


func _update_melee_metrics() -> void:
	if not is_instance_valid(player) or player.melee == null:
		return
	var melee: MeleeController = player.melee
	set_metric("Melee state", melee.state_name())
	set_metric("Melee attack", melee.attack_name())
	set_metric("Melee reach", "%.0f px" % melee.hitbox_base_range)
	set_metric("Slow charge", "%d%% (%s)" % [roundi(melee.charge_ratio() * 100.0), "READY" if melee.slow_ready else "-"])
	set_metric("Melee velocity", "%.0f" % melee.attack_velocity())
	set_metric("Last melee result", "%s -> %s (%s)" % [melee.last_attack_name, melee.last_target, melee.last_result])


func _update_camera_metrics() -> void:
	var camera: TacticalCamera = _camera()
	if camera == null:
		return
	set_metric("Camera mode", camera.mode_name())
	set_metric("Camera zoom", "%.2f" % camera.zoom.x)
	set_metric("Camera panning", "YES" if camera.pan_active else "NO")


func _update_link_metrics() -> void:
	if not is_instance_valid(squad):
		return
	set_metric("Paul command range", "%.0f px" % squad.get_effective_command_range())
	for ally in squad.members:
		if not is_instance_valid(ally) or ally.command_link == null:
			continue
		var label: String = "Scout" if ally.selection_slot == 2 else "Warrior"
		set_metric(label + " distance from Paul", "%.0f px" % ally.command_link.distance)
		set_metric(label + " link state", ally.command_link.state_name())


func _update_recon_metrics() -> void:
	if is_instance_valid(player) and player.recon != null:
		set_metric("Paul vision radius", "%.0f px" % player.recon.vision_radius)
	if is_instance_valid(squad):
		for ally in squad.members:
			if is_instance_valid(ally) and ally.recon != null:
				set_metric(("Scout" if ally.selection_slot == 2 else "Warrior") + " vision radius", "%.0f px" % ally.recon.vision_radius)
	if not is_instance_valid(recon):
		return
	set_metric("Registered observers", "%d (%d active)" % [recon.observers.size(), recon.active_observers().size()])
	set_metric("Enemies seen by squad", "%d of %d known" % [recon.visible_count(), recon.known_count()])
	var freshest: String = "none"
	for id in recon.contacts:
		var contact: Dictionary = recon.contacts[id]
		if not contact["visible"]:
			freshest = "%s %.1fs ago" % [contact["observer"], recon.get_last_seen_age(contact["enemy"])]
			break
	set_metric("Last unseen contact", freshest)


func _camera() -> TacticalCamera:
	if not is_instance_valid(player):
		return null
	return player.get_node_or_null("TacticalCamera") as TacticalCamera


func set_metric(title: String, value: String) -> void:
	if not metric_labels.has(title):
		var title_label: Label = Label.new()
		title_label.text = title
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		metrics.add_child(title_label)
		var value_label: Label = Label.new()
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		metrics.add_child(value_label)
		metric_labels[title] = value_label
	var label: Label = metric_labels[title]
	label.text = value


func _on_debug_visibility_changed(is_visible: bool) -> void:
	panel.visible = is_visible
