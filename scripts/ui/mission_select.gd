extends Control
## Developer launcher, not a game menu. It exists so the tutorial can be the
## default entry point without hiding the technical test arena.

const TUTORIAL: String = "res://scenes/missions/tutorial/tutorial_arrakeen.tscn"
const ARENA: String = "res://scenes/missions/harvester_raid_test.tscn"


func _ready() -> void:
	$Rows/Buttons/Tutorial.pressed.connect(_open.bind(TUTORIAL))
	$Rows/Buttons/Arena.pressed.connect(_open.bind(ARENA))
	$Rows/Buttons/Tutorial.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.physical_keycode == KEY_1:
		_open(TUTORIAL)
	elif event.physical_keycode == KEY_2:
		_open(ARENA)


func _open(path: String) -> void:
	get_node("/root/GameManager").tutorial_checkpoint = &""
	get_tree().change_scene_to_file(path)
