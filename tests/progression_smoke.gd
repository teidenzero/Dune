extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/progression_smoke.gd
##
## Growth: ranks and the per-mission cap, spice saturation and story ranks,
## growth by use through real hits (turn-based), ranks changing play (costs,
## points, visions), spice doses and fields, lore and caches (reward once,
## the Codex, the card), and the results' growth lines.

const TRAINING: String = "res://scenes/missions/tutorial/solo_training.tscn"
const INTERIOR: String = "res://scenes/missions/harvester_raid/harvester_interior.tscn"

var failures: int = 0
var game: Node
var scene: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = root.get_node("GameManager")
	_rules()
	await _growth_by_use()
	await _ranks_change_play()
	await _spice()
	await _finds()
	await _codex()
	print("PROGRESSION SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _fresh() -> CampaignState:
	game.campaign = CampaignState.new()
	return game.campaign


func _load(path: String) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await _frames(2)
	game.tutorial_checkpoint = &""
	game.mission_checkpoint = &""
	scene = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(25)


func _rules() -> void:
	var campaign: CampaignState = _fresh()
	_check(Progression.rank_for(9) == 0 and Progression.rank_for(10) == 1 and Progression.rank_for(45) == 3 and Progression.rank_for(200) == 5, "ranks at 10, 25, 45, 70, 100")
	for index in range(20):
		Progression.award(campaign, &"paul", &"knife_kill")
	_check(int(campaign.hero_progress(&"paul").xp[&"blade"]) == Progression.MISSION_CAP, "no more than the cap in one mission: growth, not grinding")
	_check(campaign.growth_log.size() >= 2, "rank-ups are recorded for the results")
	campaign.begin_mission()
	Progression.award(campaign, &"paul", &"knife_kill")
	_check(int(campaign.hero_progress(&"paul").xp[&"blade"]) == Progression.MISSION_CAP + 4, "a new mission, a new allowance")
	Progression.saturate(campaign, &"paul", 24.0)
	_check(campaign.hero_progress(&"paul").prescience_bonus() == 0, "saturation builds quietly...")
	Progression.saturate(campaign, &"paul", 1.0)
	_check(campaign.hero_progress(&"paul").prescience_bonus() == 1, "...and every 25 points is a prescience rank")
	Progression.raise_prescience(campaign, &"paul", "The Water of Life")
	var paul: HeroDefinition = load("res://resources/heroes/paul.tres")
	_check(Progression.visions(campaign, paul) == paul.prescience + 2, "a story moment raises prescience for good")
	Progression.raise_discipline(campaign, &"paul", "The Weirding Way")
	_check(Progression.action_points(campaign, paul) == paul.action_points + 1, "discipline: one more action point")
	_check(campaign.hero_progress(&"jessica").rank(&"blade") == 0, "every hero keeps growth of their own")


func _growth_by_use() -> void:
	_fresh()
	await _load(INTERIOR)
	var controller: HarvesterInteriorController = scene.get_node("InteriorController")
	var combat: TurnCombat = controller.combat
	var player: PlayerController = scene.get_node("World/Player")
	var campaign: CampaignState = game.campaign
	for enemy: Node in get_nodes_in_group("enemies"):
		(enemy as EnemyCharacter).set_physics_process(false)
		(enemy as EnemyCharacter).ai.set_physics_process(false)
		(enemy as EnemyCharacter).perception.set_physics_process(false)
	var guard: EnemyCharacter = scene.get_node("World/Enemies/Guard_b")
	guard.global_position = IsoMath.cell_to_world(Vector2i(20, 7))
	guard.face_position(IsoMath.cell_to_world(Vector2i(24, 7)))
	player.teleport_to(IsoMath.cell_to_world(Vector2i(18, 7)))
	await _frames(3)
	combat.begin(true)
	await _frames(12)
	guard.face_position(IsoMath.cell_to_world(Vector2i(24, 7)))
	combat.forced_roll = 99.0
	combat.select_attack(TurnRules.Attack.QUICK_KNIFE)
	await combat.command_attack(guard)
	await _frames(3)
	var paul: HeroProgress = campaign.hero_progress(&"paul")
	_check(guard.health.is_dead and int(paul.xp[&"desert_craft"]) >= 6, "a silent kill: desert craft grows")
	_check(int(paul.xp[&"blade"]) >= 5 + 2 + 4, "and the blade: the silent kill, the hit, the kill")
	var other: EnemyCharacter = scene.get_node("World/Enemies/Guard_a")
	other.global_position = IsoMath.cell_to_world(Vector2i(22, 7))
	combat._make_aware(other)
	combat.forced_roll = 0.0
	combat.select_attack(TurnRules.Attack.FIRE)
	var before: int = int(paul.xp[&"firearms"])
	await combat.command_attack(other)
	await _frames(3)
	_check(int(paul.xp[&"firearms"]) > before, "a shot that lands: firearms grows")
	_check(not GrowthReport.lines(campaign).is_empty(), "the results will say what grew")


func _ranks_change_play() -> void:
	var campaign: CampaignState = _fresh()
	campaign.hero_progress(&"paul").xp[&"blade"] = 45
	campaign.hero_progress(&"paul").xp[&"firearms"] = 45
	campaign.hero_progress(&"paul").discipline = 1
	campaign.hero_progress(&"paul").saturation = 25.0
	await _load(INTERIOR)
	var combat: TurnCombat = scene.get_node("InteriorController").combat
	var player: PlayerController = scene.get_node("World/Player")
	player.teleport_to(IsoMath.cell_to_world(Vector2i(3, 6)))
	await _frames(3)
	combat.begin(true)
	await _frames(12)
	var paul: HeroDefinition = load("res://resources/heroes/paul.tres")
	_check(combat.max_points == paul.action_points + 1 and combat.points == paul.action_points + 1, "discipline rank 1: eleven action points")
	_check(combat.prescience_left == paul.prescience + 1 - 1, "a prescience rank from the spice: one more vision (one already spent going in)")
	_check(combat.attack_cost(TurnRules.Attack.QUICK_KNIFE) == 2 and combat.reload_cost() == 1, "blade and firearms rank 3: a cheaper cut and a quicker reload")
	var hud: CombatHud = scene.get_node("InteriorController/CombatHud")
	_check((hud._commands[&"quick"] as Button).text.contains("2 AP"), "and the command menu shows it")
	combat.rewind_vision()
	await _frames(5)
	_check(player.melee.slow_charge_threshold < 0.35, "in real time the slow blade charges faster")


func _spice() -> void:
	var campaign: CampaignState = _fresh()
	await _load(INTERIOR)
	var combat: TurnCombat = scene.get_node("InteriorController").combat
	var player: PlayerController = scene.get_node("World/Player")
	_check(campaign.item_count(&"spice_dose") == 1, "a campaign starts with one dose of spice")
	player.teleport_to(IsoMath.cell_to_world(Vector2i(3, 6)))
	await _frames(3)
	combat.begin(true)
	await _frames(12)
	var visions: int = combat.prescience_left
	_key(KEY_V)
	await _frames(2)
	_check(combat.prescience_left == visions + 1 and campaign.item_count(&"spice_dose") == 0, "V in a fight: the dose is eaten, one more vision")
	_check(campaign.hero_progress(&"paul").saturation >= 2.0, "and the spice saturates, a little, for good")
	combat.rewind_vision()
	await _frames(5)
	campaign.add_item(&"spice_dose", 1)
	player.prescience_energy.current_energy = 0.0
	_check(player.use_spice() and is_equal_approx(player.prescience_energy.current_energy, player.prescience_energy.max_energy), "V out of a fight: prescience refilled")
	# A field in the desert.
	var field: SpiceField = SpiceField.new()
	field.radius = 200.0
	scene.add_child(field)
	field.global_position = player.global_position
	player.prescience_energy.current_energy = 0.0
	var saturation: float = campaign.hero_progress(&"paul").saturation
	await _frames(60)
	_check(campaign.hero_progress(&"paul").saturation > saturation, "standing in a spice field saturates")
	_check(player.prescience_energy.current_energy > player.prescience_energy.regen_per_second * 1.2, "and prescience comes back faster there")


func _finds() -> void:
	var campaign: CampaignState = _fresh()
	await _load(TRAINING)
	var finds: Array[Node] = get_nodes_in_group("finds")
	_check(finds.size() == 6, "six things to find in the training hall")
	var tally: FindPoint = null
	var dose: FindPoint = null
	for node in finds:
		if (node as FindPoint).id == &"harkonnen_tally":
			tally = node
		elif (node as FindPoint).id == &"spice_dose":
			dose = node
	var intel: int = int(campaign.resources[&"intel"])
	var lines: PackedStringArray = tally.take()
	await _frames(2)
	_check(campaign.codex.has(&"harkonnen_tally") and int(campaign.resources[&"intel"]) == intel + 1, "read: into the Codex, and a small reward (Intel +1)")
	var card: LoreCard = get_first_node_in_group("lore_card") as LoreCard
	_check(card != null and paused, "the card opens and the world waits")
	card.close()
	await _frames(2)
	_check(not paused and get_first_node_in_group("lore_card") == null, "closed: the world moves again")
	var doses: int = campaign.item_count(&"spice_dose")
	dose.take()
	await _frames(2)
	_check(campaign.item_count(&"spice_dose") == doses + 1 and not is_instance_valid(dose), "a cache: a dose of spice, and it is gone")
	# Played again: lore already known pays nothing more.
	await _load(TRAINING)
	for node in get_nodes_in_group("finds"):
		if (node as FindPoint).id == &"harkonnen_tally":
			tally = node
	_check(tally.already_known(), "a replay remembers what was read")
	intel = int(campaign.resources[&"intel"])
	tally.take()
	await _frames(2)
	_check(int(campaign.resources[&"intel"]) == intel, "and lore pays only the first time")
	var again: LoreCard = get_first_node_in_group("lore_card") as LoreCard
	if again != null:
		again.close()
	await _frames(2)


func _codex() -> void:
	change_scene_to_file("res://scenes/menu/codex.tscn")
	await _frames(5)
	var codex: CodexScreen = current_scene as CodexScreen
	_check(codex != null, "the Codex opens from the menu")
	codex.show_entry(&"harkonnen_tally")
	_check(codex._title.text == "A Harkonnen Tally, Left Behind", "a found entry can be read again")
	codex.show_entry(&"kynes_notes")
	_check(codex._title.text == "Not yet found" and codex._text.text.contains("inside the harvester"), "an unfound one says only where it waits")


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
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
