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
	await _partial_outcome()
	print("CAMPAIGN SMOKE: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _definition() -> void:
	var definition: MissionDefinition = load(DEFINITION) as MissionDefinition
	_check(definition != null and definition.id == &"harvester_raid", "the raid definition loads")
	_check(definition.objectives.size() == 6, "it defines the raid's six objectives")
	_check(definition.primary_ids() == [&"sabotage"], "sabotage is the one primary objective")
	_check(definition.objective(&"fremen").optional, "keeping the Fremen alive is optional")
	_check(definition.available_scopes() == [MissionOutcome.Scope.SQUAD], "only the squad scope exists so far")
	var clean: Dictionary = definition.stakes_for(MissionOutcome.Tier.CLEAN)
	var noisy: Dictionary = definition.stakes_for(MissionOutcome.Tier.NOISY)
	_check(clean["heat"] < noisy["heat"], "a clean raid draws less heat than a noisy one")
	_check(clean["standings"][&"fremen"] == 1 and clean["standings"][&"choam"] == -1, "a crippled crawler pleases the Fremen and costs CHOAM")
	_check(definition.stakes_for(MissionOutcome.Tier.FAILURE)["standings"][&"fremen"] == -1, "failing the sietch costs its trust")


func _campaign_state() -> void:
	var campaign: CampaignState = CampaignState.new()
	_check(campaign.heat == 0 and campaign.standing(&"fremen") == 0 and campaign.resources[&"water"] == 0, "a new campaign starts neutral")
	var record: MissionOutcome = MissionOutcome.new()
	record.mission_id = &"test"
	record.standings = {&"fremen": 5, &"guild": -9}
	record.resources = {&"water": 10, &"spice": -20}
	record.heat = 15
	campaign.apply(record)
	_check(campaign.standing(&"fremen") == CampaignState.STANDING_MAX and campaign.standing(&"guild") == CampaignState.STANDING_MIN, "standings clamp to -2..+3")
	_check(campaign.heat == CampaignState.HEAT_MAX, "heat clamps at 10")
	_check(campaign.resources[&"water"] == 10 and campaign.resources[&"spice"] == 0, "resources never go below zero")
	_check(campaign.standing_name(&"fremen") == "Sworn" and campaign.standing_name(&"guild") == "Hostile", "standings have names")
	campaign.apply(record)
	_check(campaign.history.size() == 1 and campaign.resources[&"water"] == 10, "the same outcome is never applied twice")
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
