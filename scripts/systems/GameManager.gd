extends Node
## Session-wide debug display preference; gameplay stays in its own scenes.

signal debug_visibility_changed(is_visible: bool)

## Step id the tutorial resumes at after a reload. Session-only; there is no
## save-game persistence.
var tutorial_checkpoint: StringName = &""

## Same idea for missions: the phase a restart resumes from.
var mission_checkpoint: StringName = &""

## Resources, faction standings and Harkonnen heat between missions.
## Session-only until the campaign loop brings a save game.
var campaign: CampaignState = CampaignState.new()

var debug_visible: bool = false:
	set(value):
		if debug_visible == value:
			return
		debug_visible = value
		debug_visibility_changed.emit(debug_visible)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		var window: Window = get_window()
		var fullscreen: bool = window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
		window.mode = Window.MODE_WINDOWED if fullscreen else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
