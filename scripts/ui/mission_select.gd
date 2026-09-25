extends Control
## Developer launcher, not a game menu. It exists so the tutorial can be the
## default entry point without hiding the technical test arena.

const TUTORIAL: String = "res://scenes/missions/tutorial/tutorial_arrakeen.tscn"
const RAID: String = "res://scenes/missions/harvester_raid/harvester_raid.tscn"
const INTERIOR: String = "res://scenes/missions/harvester_raid/harvester_interior.tscn"
const SOLO_TRAINING: String = "res://scenes/missions/tutorial/solo_training.tscn"
const MAP_ROOM: String = "res://scenes/campaign/map_room.tscn"
const HUNTER_SEEKER: String = "res://scenes/missions/act1/hunter_seeker.tscn"
const BANQUET: String = "res://scenes/campaign/banquet.tscn"
const MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
const ARENA: String = "res://scenes/missions/harvester_raid_test.tscn"
const COUNCIL: String = "res://scenes/campaign/council.tscn"


func _ready() -> void:
	$Rows/Buttons/Tutorial.pressed.connect(_open.bind(TUTORIAL))
	$Rows/Buttons/Raid.pressed.connect(_open.bind(RAID))
	$Rows/Buttons/Interior.pressed.connect(_open.bind(INTERIOR))
	$Rows/Buttons/SoloTraining.pressed.connect(_open.bind(SOLO_TRAINING))
	$Rows/Buttons/MapRoom.pressed.connect(_open.bind(MAP_ROOM))
	$Rows/Buttons/HunterSeeker.pressed.connect(_open.bind(HUNTER_SEEKER))
	$Rows/Buttons/Banquet.pressed.connect(_open.bind(BANQUET))
	$Rows/Buttons/MainMenu.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	$Rows/Buttons/Arena.pressed.connect(_open.bind(ARENA))
	$Rows/Buttons/Council.pressed.connect(_open.bind(COUNCIL))
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
	elif event.physical_keycode == KEY_4:
		_open(COUNCIL)
	elif event.physical_keycode == KEY_5:
		_open(INTERIOR)
	elif event.physical_keycode == KEY_6:
		_open(SOLO_TRAINING)
	elif event.physical_keycode == KEY_7:
		_open(MAP_ROOM)
	elif event.physical_keycode == KEY_8:
		_open(HUNTER_SEEKER)
	elif event.physical_keycode == KEY_9:
		_open(BANQUET)
	elif event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(MAIN_MENU)



## Launching anything starts it clean; checkpoints are for retrying in place.
func _open(path: String) -> void:
	var game: Node = get_node("/root/GameManager")
	game.tutorial_checkpoint = &""
	game.mission_checkpoint = &""
	game.return_scene = ""
	get_tree().change_scene_to_file(path)
