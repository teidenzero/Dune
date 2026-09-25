extends SceneTree
## Run: godot --headless --path . --script res://tests/audio_smoke.gd
##
## Sound: every slot the game asks for exists and loads; each mood has a
## track; each kind of scene gets its mood (open sand, a palace at night, a
## council table); the game's own signals make sounds without the game
## knowing (a shot, a guard raising the alarm, a shield blocking a round),
## and a sound hook can never break play.

const SLOTS: Array[StringName] = [
	&"pistol_shot", &"lasgun_shot", &"reload", &"empty_click", &"knife_swing", &"knife_hit",
	&"shield_on", &"shield_block", &"shield_down", &"hit_body", &"hit_stone", &"step_sand", &"step_stone",
	&"worm_rumble", &"worm_erupt", &"thumper_thump", &"harvester_engine", &"door_open", &"console_beep",
	&"explosion", &"click", &"hover", &"objective_complete", &"alert_spotted", &"dialogue_blip",
	&"prescience_on", &"prescience_rewind",
]

var failures: int = 0
var sfx: Node
var director: SoundDirector


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	sfx = root.get_node("Sfx")
	director = sfx.get_node("Director")
	_library()
	await _moods()
	await _hooks()
	print("AUDIO SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _library() -> void:
	var missing: Array = []
	for slot in SLOTS:
		if not sfx.has(slot):
			missing.append(slot)
	_check(missing.is_empty(), "every sound slot has a file %s" % str(missing))
	for mood in [&"desert_explore", &"stealth_interior", &"council", &"combat", &"worm_tension"]:
		var path: String = director.track(mood)
		_check(path != "" and load(path) is AudioStream, "music for %s" % mood)


func _moods() -> void:
	for case in [
		["res://scenes/missions/act1/harvester_open.tscn", SoundDirector.MOOD_SQUAD],
		["res://scenes/missions/act1/hunter_seeker.tscn", SoundDirector.MOOD_SOLO],
		["res://scenes/campaign/banquet.tscn", SoundDirector.MOOD_COUNCIL],
	]:
		var scene: Node = (load(case[0]) as PackedScene).instantiate()
		root.add_child(scene)
		current_scene = scene
		await _frames(5)
		_check(director._mood_of(scene) == case[1], "%s sounds like %s" % [case[0].get_file(), case[1]])
		scene.queue_free()
		await _frames(2)


func _hooks() -> void:
	var scene: Node = (load("res://scenes/missions/harvester_raid/harvester_raid.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(20)
	var player: PlayerController = scene.get_node("Player")
	player.weapon_controller.weapon_fired.emit()
	_check(_playing() > 0, "a shot is heard")
	var guard: EnemyCharacter = scene.get_tree().get_first_node_in_group("enemies") as EnemyCharacter
	var ai: EnemyAIController = guard.ai
	ai.state_changed.emit(EnemyAIController.State.PATROL, EnemyAIController.State.COMBAT)
	await _frames(2)
	_check(director._hunting.has(ai) and director._wanted_path() == director.track(SoundDirector.MOOD_COMBAT), "a guard hunting: the alarm, and the fight music")
	ai.state_changed.emit(EnemyAIController.State.COMBAT, EnemyAIController.State.SEARCH)
	_check(director._hunting.is_empty() and director._combat_left > 0.0, "he gives up: the music holds a moment")
	# A shield blocking a round must sound, and must not break the hit.
	var shield: ShieldComponent = ShieldComponent.new()
	player.add_child(shield)
	shield.shield_blocked.emit(HitContext.ranged(5.0, 900.0, null, &"harkonnen", "test", player.global_position, Vector2.RIGHT))
	_check(true, "a shield block plays without error")
	scene.queue_free()
	await _frames(2)


func _playing() -> int:
	var count: int = 0
	for child in sfx.get_children():
		if (child is AudioStreamPlayer2D or child is AudioStreamPlayer) and child.playing:
			count += 1
	return count


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
