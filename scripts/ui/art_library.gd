class_name ArtLibrary
extends RefCounted
## Where painted art lives, looked up by name so screens do not hard-code
## paths. Anything not yet delivered returns null and the caller falls back
## to what it drew before.

const PORTRAITS: String = "res://assets/ui/portraits/"
const EMBLEMS: String = "res://assets/ui/emblems/"
const STORY: String = "res://assets/ui/story/"

## Spoken names as they appear in dialogue and tutorial prompts.
const SPEAKERS: Dictionary = {
	"PAUL": "paul", "DUKE LETO": "duke_leto", "JESSICA": "jessica", "GURNEY": "gurney",
	"THUFIR": "thufir", "KYNES": "kynes",
	# DUNCAN is left out until duncan.png is redone: the delivered one draws
	# him as Paul (docs/art/portrait_fixes_brief.md). Unmapped, his lines show
	# no portrait rather than the wrong face. Put "DUNCAN": "duncan" back then.
}


static func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func portrait(name: String) -> Texture2D:
	return _load(PORTRAITS + name + ".png")


## The portrait for whoever is speaking, or null (narration, unknown voices).
static func speaker_portrait(speaker: String) -> Texture2D:
	var key: String = speaker.to_upper().split(" (")[0].strip_edges()
	return portrait(SPEAKERS[key]) if SPEAKERS.has(key) else null


static func emblem(name: String) -> Texture2D:
	return _load(EMBLEMS + name + ".png")


static func story(name: String) -> Texture2D:
	return _load(STORY + name + ".png") if name != "" else null
