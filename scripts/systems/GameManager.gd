extends Node
## Session-wide debug display preference; gameplay stays in its own scenes.

signal debug_visibility_changed(is_visible: bool)

## Step id the tutorial resumes at after a reload. Session-only; there is no
## save-game persistence.
var tutorial_checkpoint: StringName = &""

var debug_visible: bool = false:
	set(value):
		if debug_visible == value:
			return
		debug_visible = value
		debug_visibility_changed.emit(debug_visible)
