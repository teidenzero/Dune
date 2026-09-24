extends Control
## Developer launcher, not a game menu. It exists so the tutorial can be the
## default entry point without hiding the technical test arena.

const TUTORIAL: String = "res://scenes/missions/tutorial/tutorial_arrakeen.tscn"
const RAID: String = "res://scenes/missions/harvester_raid/harvester_raid.tscn"
const ARENA: String = "res://scenes/missions/harvester_raid_test.tscn"


func _ready() -> void:
	$Rows/Buttons/Tutorial.pressed.connect(_open.bind(TUTORIAL))
	$Rows/Buttons/Raid.pressed.connect(_open.bind(RAID))
	$Rows/Buttons/Arena.pressed.connect(_open.bind(ARENA))
	$Rows/Buttons/Tutorial.grab_focus()
	var game: Node = get_node("/root/GameManager")
	var campaign: CampaignState = game.campaign
	if campaign != null and not campaign.history.is_empty():
		var last: MissionOutcome = campaign.history[campaign.history.size() - 1]
		$Rows/Footer.text = "CAMPAIGN  ·  %s\nLast: %s - %s" % [campaign.summary(), last.mission_id, last.tier_title()]


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.physical_keycode == KEY_1:
		_open(TUTORIAL)
	elif event.physical_keycode == KEY_2:
		_open(RAID)
	elif event.physical_keycode == KEY_3:
		_open(ARENA)


## Launching anything starts it clean; checkpoints are for retrying in place.
func _open(path: String) -> void:
	var game: Node = get_node("/root/GameManager")
	game.tutorial_checkpoint = &""
	game.mission_checkpoint = &""
	get_tree().change_scene_to_file(path)
