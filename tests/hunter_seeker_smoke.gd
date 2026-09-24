extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/hunter_seeker_smoke.gd
##
## Act I, 1.1 The Hunter-Seeker: the seeker leaves a still Paul searching and
## strikes a moving one; seized within reach, it opens the search; Mapes
## names the operator's hiding place; the operator found is a clean night,
## the operator escaping a partial one, the needle a failure.

const SCENE: String = "res://scenes/missions/act1/hunter_seeker.tscn"

var failures: int = 0
var scene: Node
var controller: HunterSeekerController
var player: PlayerController
var mission: MissionManager


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _still_and_seized()
	await _operator_escapes()
	await _needle_finds_him()
	print("HUNTER SEEKER SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load(hideout: String) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await _frames(2)
	scene = (load(SCENE) as PackedScene).instantiate()
	(scene.get_node("Controller") as HunterSeekerController).forced_hideout = hideout
	root.add_child(scene)
	current_scene = scene
	await _frames(20)
	controller = scene.get_node("Controller")
	player = scene.get_node("World/Player")
	mission = scene.get_node("Mission")


func _still_and_seized() -> void:
	await _load("1")
	var seeker: HunterSeeker = controller.seeker
	_check(controller.phase == &"still" and is_instance_valid(seeker), "night: the seeker is loose, Paul must be still")
	_check(controller.operator.get_meta("dormant") and not controller.mapes_point.enabled, "the operator hides; Mapes is not yet to be found")
	await _frames(180)
	_check(seeker.state == HunterSeeker.State.DRIFT and not player.health.is_dead, "while Paul is still, it only searches")
	# It drifts within reach.
	seeker.global_position = player.global_position + Vector2(40, -40)
	await _frames(3)
	_check(seeker.can_seize(), "within reach, and Paul still: it can be taken")
	_click(seeker.global_position)
	await _frames(3)
	_check(controller.phase == &"search" and mission.is_complete(HunterSeekerController.OBJ_NEEDLE), "a click seizes it")
	_check(not controller.operator.get_meta("dormant") and controller.mapes_point.enabled, "the search begins; Mapes can be found")
	controller.mapes_point.force_complete()
	await _frames(2)
	_check(controller.talked_to_mapes and HunterSeekerController.HIDEOUTS["1"] in _all_lines(), "Mapes names the west storerooms")
	# Found: the operator falls.
	controller.operator.health.die()
	await _frames(120)
	var record: MissionOutcome = mission.outcome_record
	_check(mission.outcome == MissionManager.Outcome.COMPLETE and record.tier == MissionOutcome.Tier.CLEAN, "the operator found and Paul unhurt: a clean night")
	_check(record.flags.has("mapes_trust") and record.standings.get(&"fremen", 0) >= 1, "and Mapes tells her people the young master listened")


func _operator_escapes() -> void:
	await _load("2")
	controller.seeker.global_position = player.global_position + Vector2(40, -40)
	await _frames(3)
	controller.seeker.seize()
	await _frames(2)
	controller.flee_timer = 0.05
	await _frames(10)
	_check(controller.fleeing and not controller.operator.ai.is_physics_processing(), "time runs out: the operator makes for the cellar door")
	controller.operator.global_position = scene.get_node("World").mark("X") + Vector2(10, 0)
	await _frames(5)
	var record: MissionOutcome = mission.outcome_record
	_check(mission.outcome == MissionManager.Outcome.FAILED and record.tier == MissionOutcome.Tier.PARTIAL, "he gets out: the needle taken, but a partial night")
	_check(record.flags.has("operator_loose"), "and a Harkonnen agent is loose in Arrakeen")


func _needle_finds_him() -> void:
	await _load("3")
	var seeker: HunterSeeker = controller.seeker
	seeker.global_position = player.global_position + Vector2(160, -60)
	player.move_to(player.global_position + Vector2(-120, 60))
	await _frames(8)
	_check(seeker.state == HunterSeeker.State.HUNT, "Paul moves: the seeker locks on")
	await _frames(60)
	var record: MissionOutcome = mission.outcome_record
	_check(mission.outcome == MissionManager.Outcome.FAILED and record != null and record.tier == MissionOutcome.Tier.FAILURE, "the needle finds him: the night is lost")
	_check(record.heroes_wounded.has("Paul"), "Paul is wounded, not killed")


func _all_lines() -> String:
	var bar: DialogueBar = scene.get_node("Dialogue")
	var lines: PackedStringArray = [bar.current_text]
	for line in bar._queue:
		lines.append(line.text)
	return " ".join(lines)


func _click(world: Vector2) -> void:
	var viewport: Viewport = scene.get_viewport()
	var screen: Vector2 = viewport.get_screen_transform() * (viewport.get_canvas_transform() * world)
	for pressed in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		Input.parse_input_event(event)


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
