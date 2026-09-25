class_name SoundDirector
extends Node
## Listens to the game and gives it sound, without the game knowing: as nodes
## enter the tree, their existing signals are wired to sound slots (a gun
## fired, a blade landing on a shield, a guard raising the alarm, a worm on
## its way). It also picks the music: the scene's mood track once any
## briefing is closed, combat while a fight is on, tension while a worm
## comes. Sound carries information here, so the loudest cues are the ones
## that matter: spotted, the worm, a shot.
##
## A child of the Sfx autoload. Music is found by slot name under
## assets/audio/music/: the first file whose name begins with the slot.

const MUSIC_ROOT: String = "res://assets/audio/music/"
const MOOD_SQUAD: StringName = &"desert_explore"
const MOOD_SOLO: StringName = &"stealth_interior"
const MOOD_COUNCIL: StringName = &"council"
const MOOD_COMBAT: StringName = &"combat"
const MOOD_WORM: StringName = &"worm_tension"
## How long the combat track holds after the last guard stops hunting.
const COMBAT_LINGER: float = 5.0
## Steps: how loud each gait is.
const STEP_DB: Dictionary = {"CROUCH": -18.0, "WALK": -9.0, "SPRINT": -3.0}

var _tracks: Dictionary = {}
var _scene: Node
var _mood: StringName = &""
var _fights: int = 0
var _hunting: Dictionary = {}
var _combat_left: float = 0.0
var _worm_coming: bool = false
var _rumble: AudioStreamPlayer2D
var _worm: WormThreatManager
var _last_alert: int = -10000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scan_music()
	get_tree().node_added.connect(_on_node_added)


func _scan_music() -> void:
	var dir: DirAccess = DirAccess.open(MUSIC_ROOT)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file in files:
		var name: String = file.trim_suffix(".import").trim_suffix(".remap")
		if not name.get_extension() in ["ogg", "mp3", "wav"]:
			continue
		for slot in [MOOD_SQUAD, MOOD_SOLO, MOOD_COUNCIL, MOOD_COMBAT, MOOD_WORM]:
			if name.begins_with(String(slot)) and not _tracks.has(slot):
				_tracks[slot] = MUSIC_ROOT + name


func track(slot: StringName) -> String:
	return _tracks.get(slot, "")


# --------------------------------------------------------------------------
# Wiring: every node that makes a sound, as it arrives
# --------------------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is WeaponController:
		var weapon: WeaponController = node
		weapon.weapon_fired.connect(func() -> void: Sound.play(_shot_slot(weapon), _at(weapon)))
		weapon.reload_started.connect(func() -> void: Sound.play(&"reload", _at(weapon), -4.0))
		weapon.dry_fired.connect(func() -> void: Sound.play(&"empty_click", _at(weapon), -2.0))
	elif node is MeleeController:
		var blade: MeleeController = node
		blade.attack_started.connect(func(_data: MeleeAttackData) -> void: Sound.play(&"knife_swing", _at(blade), -3.0))
		blade.attack_landed.connect(func(_target: Node, _data: MeleeAttackData, outcome: int) -> void:
			Sound.play(&"shield_block" if outcome == DamageResolver.Outcome.BLOCKED else &"knife_hit", _at(blade)))
	elif node is ShieldComponent:
		var shield: ShieldComponent = node
		shield.shield_blocked.connect(func(hit: HitContext) -> void:
			if hit.attack_type == HitContext.Type.RANGED:
				Sound.play(&"shield_block", _at(shield), -2.0))
	elif node is FuelTank:
		(node as FuelTank).exploded.connect(func(tank: FuelTank) -> void: Sound.play(&"explosion", tank.global_position, 2.0, 0.1))
	elif node is WormSignEmitter:
		(node as WormSignEmitter).stepped.connect(_on_step)
	elif node is InteractionPoint:
		var point: InteractionPoint = node
		point.interaction_completed.connect(func(_id: StringName) -> void: Sound.play(&"console_beep", point.global_position, -4.0))
	elif node is PrescienceController:
		(node as PrescienceController).prescience_started.connect(func() -> void: Sound.ui(&"prescience_on"))
	elif node is TurnCombat:
		var combat: TurnCombat = node
		combat.combat_started.connect(func(_voluntary: bool) -> void:
			_fights += 1
			_update_music())
		combat.combat_ended.connect(func() -> void:
			_fights = maxi(_fights - 1, 0)
			_update_music())
		combat.vision_changed.connect(func(active: bool) -> void:
			if active:
				Sound.ui(&"prescience_on"))
		combat.vision_rewound.connect(func() -> void: Sound.ui(&"prescience_rewind"))
	elif node is EnemyAIController:
		var ai: EnemyAIController = node
		ai.state_changed.connect(func(previous: int, current: int) -> void: _on_guard_state(ai, previous, current))
	elif node is WormThreatManager:
		_bind_worm(node as WormThreatManager)
	elif node is DialogueBar:
		(node as DialogueBar).line_shown.connect(func(_speaker: String, _text: String) -> void: Sound.ui(&"dialogue_blip", -8.0))
	elif node is MissionManager:
		var mission: MissionManager = node
		mission.objective_completed.connect(func(_objective: MissionObjective) -> void: Sound.ui(&"objective_complete"))
	elif node is BaseButton:
		var button: BaseButton = node
		button.pressed.connect(func() -> void: Sound.ui(&"click", -6.0))
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				Sound.ui(&"hover", -16.0))


func _at(node: Node) -> Vector2:
	var owner_2d: Node2D = node.get_parent() as Node2D
	return owner_2d.global_position if owner_2d != null else Vector2.INF


## A maula pistol cracks; anything else is a lasgun.
func _shot_slot(weapon: WeaponController) -> StringName:
	var data: WeaponData = weapon.weapon_data
	if data != null and "pistol" in data.weapon_name.to_lower():
		return &"pistol_shot"
	return &"lasgun_shot"


## Footsteps, as loud as the worm hears them: sand crunches, stone clicks.
func _on_step(at: Vector2, profile: String, on_sand: bool) -> void:
	Sound.play(&"step_sand" if on_sand else &"step_stone", at, float(STEP_DB.get(profile, -9.0)), 0.1)


## A guard who starts hunting: the one sound that must never be missed.
func _on_guard_state(ai: EnemyAIController, previous: int, current: int) -> void:
	var combat: int = EnemyAIController.State.COMBAT
	if current == combat and previous != combat:
		_hunting[ai] = true
		var now: int = Time.get_ticks_msec()
		if now - _last_alert > 1500:
			_last_alert = now
			Sound.ui(&"alert_spotted")
	elif previous == combat and current != combat:
		_hunting.erase(ai)
		if _hunting.is_empty():
			# The fight music holds a moment after the last one gives up.
			_combat_left = COMBAT_LINGER
	_update_music()


func _bind_worm(worm: WormThreatManager) -> void:
	_worm = worm
	worm.worm_approach_started.connect(func(_target: Vector2) -> void:
		_worm_coming = true
		_start_rumble()
		_update_music())
	worm.worm_arrived.connect(func(at: Vector2, _radius: float) -> void:
		Sound.play(&"worm_erupt", at, 4.0, 0.05))
	worm.worm_event_finished.connect(func() -> void:
		_worm_coming = false
		_stop_rumble()
		_update_music())


## The ridge's rumble travels with it.
func _start_rumble() -> void:
	if _rumble != null and is_instance_valid(_rumble):
		return
	if _worm == null or _worm.event == null:
		return
	_rumble = Sound.loop(&"worm_rumble", _worm.event, 0.0)


func _stop_rumble() -> void:
	if _worm != null and is_instance_valid(_worm) and _worm.event != null:
		Sound.stop_loop(&"worm_rumble", _worm.event)
	_rumble = null


# --------------------------------------------------------------------------
# Music
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_fights = 0
		_hunting.clear()
		_worm_coming = false
		_rumble = null
		_mood = _mood_of(scene)
		_update_music()
	if _rumble != null and is_instance_valid(_rumble) and _worm != null and is_instance_valid(_worm) and _worm.event != null:
		_rumble.global_position = _worm.event.position_on_path if _worm.event.position_on_path.is_finite() else _rumble.global_position
	if _combat_left > 0.0:
		_combat_left -= delta
		if _combat_left <= 0.0:
			_update_music()
	# The track waits for the briefing to close.
	if _mood != &"" and get_tree().get_first_node_in_group("briefing_screen") == null:
		var game: Node = get_node_or_null("/root/GameManager")
		if game != null and game.music_playing() != _wanted_path() and _wanted_path() != "":
			_update_music()


## What a scene sounds like: open sand, a palace at night, a council table.
func _mood_of(scene: Node) -> StringName:
	if scene == null:
		return &""
	if scene is CouncilScreen or scene is BanquetScreen:
		return MOOD_COUNCIL
	var squad: SquadManager = scene.find_child("SquadManager", true, false) as SquadManager
	if not scene.find_children("*", "IsoLevel", true, false).is_empty():
		return MOOD_SOLO
	if squad != null:
		return MOOD_SOLO if squad.solo_mode else MOOD_SQUAD
	return &""


func _wanted_path() -> String:
	if _mood == &"":
		return ""
	if (_fights > 0 or not _hunting.is_empty() or _combat_left > 0.0) and track(MOOD_COMBAT) != "":
		return track(MOOD_COMBAT)
	if _worm_coming and track(MOOD_WORM) != "":
		return track(MOOD_WORM)
	return track(_mood)


func _update_music() -> void:
	if get_tree().get_first_node_in_group("briefing_screen") != null:
		return
	var path: String = _wanted_path()
	var game: Node = get_node_or_null("/root/GameManager")
	if game == null or path == "":
		return
	game.play_music(path, 2.0)
