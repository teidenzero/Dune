extends SceneTree
## Run: godot --headless --fixed-fps 60 --path . --script res://tests/campaign_smoke.gd
##
## The shared mission model: the Harvester Raid's definition, the outcome
## record, CampaignState applying it, and the raid's squad scope classifying
## its own ending (including the partial case).

const DEFINITION: String = "res://resources/missions/harvester_raid.tres"
const RAID: String = "res://scenes/missions/harvester_raid/harvester_raid.tscn"

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_definition()
	_campaign_state()
	_outcome_lines()
	_operation_rules()
	await _partial_outcome()
	await _council_flow()
	print("CAMPAIGN SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _definition() -> void:
	var definition: MissionDefinition = load(DEFINITION) as MissionDefinition
	_check(definition != null and definition.id == &"harvester_raid", "the raid definition loads")
	_check(definition.objectives.size() == 6, "it defines the raid's six objectives")
	_check(definition.primary_ids() == [&"sabotage"], "sabotage is the one primary objective")
	_check(definition.objective(&"fremen").optional, "keeping the Fremen alive is optional")
	_check(definition.available_scopes() == [MissionOutcome.Scope.POLITICAL, MissionOutcome.Scope.SQUAD, MissionOutcome.Scope.SOLO], "the raid can be played politically, as a squad, or solo inside the crawler")
	_check(definition.political_approaches.size() == 3, "it offers three political approaches")
	var clean: Dictionary = definition.stakes_for(MissionOutcome.Tier.CLEAN)
	var noisy: Dictionary = definition.stakes_for(MissionOutcome.Tier.NOISY)
	_check(clean["heat"] < noisy["heat"], "a clean raid draws less heat than a noisy one")
	_check(clean["standings"][&"fremen"] == 1 and clean["standings"][&"choam"] == -1, "a crippled crawler pleases the Fremen and costs CHOAM")
	_check(definition.stakes_for(MissionOutcome.Tier.FAILURE)["standings"][&"fremen"] == -1, "failing the sietch costs its trust")


func _campaign_state() -> void:
	var campaign: CampaignState = CampaignState.new()
	_check(campaign.heat == 0 and campaign.standing(&"fremen") == 0, "a new campaign starts neutral")
	_check(campaign.resources[&"solari"] == 40 and campaign.resources[&"intel"] == 3, "and with House Atreides' starting resources")
	var record: MissionOutcome = MissionOutcome.new()
	record.mission_id = &"test"
	record.standings = {&"fremen": 5, &"guild": -9}
	record.resources = {&"water": 10, &"spice": -20}
	record.heat = 15
	campaign.apply(record)
	_check(campaign.standing(&"fremen") == CampaignState.STANDING_MAX and campaign.standing(&"guild") == CampaignState.STANDING_MIN, "standings clamp to -2..+3")
	_check(campaign.heat == CampaignState.HEAT_MAX, "heat clamps at 10")
	_check(campaign.resources[&"water"] == 20 and campaign.resources[&"spice"] == 0, "resources never go below zero")
	_check(campaign.standing_name(&"fremen") == "Sworn" and campaign.standing_name(&"guild") == "Hostile", "standings have names")
	campaign.apply(record)
	_check(campaign.history.size() == 1 and campaign.resources[&"water"] == 20, "the same outcome is never applied twice")
	_check(campaign.last_outcome(&"test") == record, "history remembers the last outcome per mission")
	_check(campaign.summary().contains("Harkonnen heat 10 / 10"), "the summary line reports heat")


func _outcome_lines() -> void:
	var definition: MissionDefinition = load(DEFINITION) as MissionDefinition
	var record: MissionOutcome = MissionOutcome.new()
	record.tier = MissionOutcome.Tier.CLEAN
	record.apply_stakes(definition)
	record.recruits_dead.append("Fremen Warrior")
	var lines: PackedStringArray = record.consequence_lines()
	_check(lines.has("Fremen standing +1") and lines.has("CHOAM standing -1"), "consequences read as standings")
	_check(lines.has("Harkonnen heat +1") and lines.has("Water +10"), "and as heat and resources")
	_check(lines.has("Fremen Warrior killed"), "and name the dead")
	_check(record.succeeded() and record.tier_title() == "CLEAN SUCCESS", "a clean tier is a success")
	var data: Dictionary = record.to_dict()
	_check(data["tier"] == "clean" and data["heat"] == 1, "the record serialises for a save game")


## The Political scope's rules: odds, blocking, tiers, what the record carries.
func _operation_rules() -> void:
	var definition: MissionDefinition = load(DEFINITION) as MissionDefinition
	var campaign: CampaignState = CampaignState.new()
	var bribe: PoliticalApproach = definition.political_approaches[0]
	var guild: PoliticalApproach = definition.political_approaches[1]
	var heroes: Array[HeroDefinition] = HeroRoster.all()
	var thufir: HeroDefinition = heroes[3]
	var gurney: HeroDefinition = heroes[2]
	_check(heroes.size() == 7, "seven heroes can act as agents (Chani joined)")
	var plain: float = OperationResolver.chance(bribe, gurney, campaign, 0)
	_check(is_equal_approx(plain, bribe.base_chance), "an agent without the right ties adds nothing")
	_check(OperationResolver.chance(bribe, thufir, campaign, 0) > plain, "a mentat improves any operation")
	var smugglers: PoliticalApproach = definition.political_approaches[2]
	_check(OperationResolver.chance(smugglers, gurney, campaign, 0) > smugglers.base_chance + 0.15, "Gurney's smuggler ties improve their approach")
	_check(is_equal_approx(OperationResolver.chance(bribe, gurney, campaign, 2), plain + 2 * OperationResolver.INTEL_STEP), "each Intel spent adds its step")
	campaign.standings[&"choam"] = 2
	_check(OperationResolver.chance(bribe, gurney, campaign, 0) > plain, "goodwill with the faction improves the odds")
	campaign.standings[&"guild"] = -1
	_check(OperationResolver.blocked_reason(guild, campaign).contains("will not deal"), "a faction that dislikes us refuses to help")
	campaign.standings[&"guild"] = 0
	campaign.resources[&"spice"] = 5
	_check(OperationResolver.blocked_reason(guild, campaign).contains("Not enough"), "an approach we cannot afford is blocked")
	_check(OperationResolver.tier_for(0.1, 0.6) == MissionOutcome.Tier.CLEAN and OperationResolver.tier_for(0.5, 0.6) == MissionOutcome.Tier.NOISY, "rolls inside the odds succeed, clean or noisy")
	_check(OperationResolver.tier_for(0.65, 0.6) == MissionOutcome.Tier.PARTIAL and OperationResolver.tier_for(0.9, 0.6) == MissionOutcome.Tier.FAILURE, "rolls outside are partial or failure")
	var fresh: CampaignState = CampaignState.new()
	var record: MissionOutcome = OperationResolver.resolve(definition, bribe, thufir, fresh, 1, bribe.choices[1], 0.05)
	_check(record.scopes == [MissionOutcome.Scope.POLITICAL] and record.tier == MissionOutcome.Tier.CLEAN, "a political resolution is recorded in the political scope")
	_check(record.objectives[&"sabotage"] == MissionObjective.State.COMPLETE, "success completes the primary objective")
	_check(record.resources[&"solari"] == -25 and record.resources[&"intel"] == -1, "the approach's cost and the Intel are spent")
	_check(record.heat == 1 + 1 and record.standings[&"choam"] == -1 - 1, "the stakes and the dilemma's price both land")
	var failed: MissionOutcome = OperationResolver.resolve(definition, bribe, thufir, fresh, 0, bribe.choices[0], 0.99)
	_check(failed.tier == MissionOutcome.Tier.FAILURE and failed.flags.has("operation_exposed") and failed.objectives[&"sabotage"] == MissionObjective.State.FAILED, "a failed operation is exposed and achieves nothing")


## The Council screen end to end: briefing, operation, dilemma, result, and
## the campaign updated through the same door as the squad scope.
func _council_flow() -> void:
	var game: Node = root.get_node("GameManager")
	game.campaign = CampaignState.new()
	var council: CouncilScreen = (load("res://scenes/campaign/council.tscn") as PackedScene).instantiate()
	root.add_child(council)
	current_scene = council
	await _frames(3)
	_check(council.get_node_or_null(".") != null and council.campaign == game.campaign, "the Council reads the campaign")
	council.open_briefing(load(DEFINITION))
	council.open_operation()
	await _frames(2)
	_check(council._commit_button.disabled, "nothing can be committed before an approach and an agent are chosen")
	var definition: MissionDefinition = council.definition
	council.select_approach(definition.political_approaches[2])
	council.select_agent(HeroRoster.all()[2])
	council.set_intel(99)
	_check(council.intel_spent == 2, "Intel spent is capped by what we hold, less the approach's cost")
	_check(not council._commit_button.disabled, "with both chosen the operation can be committed")
	council.commit_operation()
	council.forced_roll = 0.1
	council.choose(council.approach.choices[1])
	var record: MissionOutcome = council.last_outcome
	_check(record != null and game.campaign.history.has(record), "the result is applied to the campaign")
	_check(game.campaign.standing(&"smugglers") == -1 and game.campaign.resources[&"spice"] == 35, "the smugglers resent the cut, and the spice comes in")
	_check(game.campaign.resources[&"intel"] == 0, "the Intel and the approach's cost are spent")
	council.show_view("council")
	await _frames(2)
	council.queue_free()
	game.campaign = CampaignState.new()
	await _frames(2)


## Sabotage done, then Paul is lost: the crawler is still crippled, so the
## raid counts as partial, not a plain failure.
func _partial_outcome() -> void:
	var scene: Node = (load(RAID) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(20)
	var mission: MissionManager = scene.get_node("Mission")
	var player: PlayerController = scene.get_node("Player")
	_check(mission.definition != null and mission.all_objectives().size() == 6, "the raid builds its objectives from the shared definition")
	for node: Node in get_nodes_in_group("sabotage_points"):
		(node as InteractionPoint).force_complete()
	await _frames(4)
	player.health.die()
	await _frames(6)
	var record: MissionOutcome = mission.outcome_record
	_check(record != null and record.tier == MissionOutcome.Tier.PARTIAL, "losing Paul after the sabotage is a partial success")
	_check(record.flags.has("alarm_raised") and record.flags.has("comms_intact"), "the alarm and the standing mast are flagged")
	_check(record.heat == 3 and record.standings.get(&"choam", 0) == -1, "partial stakes applied to the record")
	root.get_node("GameManager").mission_checkpoint = &""
	scene.queue_free()
	await _frames(2)


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
