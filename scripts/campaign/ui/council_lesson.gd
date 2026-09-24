class_name CouncilLesson
extends Node
## The prologue's council lesson: Duke Leto talks Paul through the council,
## one screen at a time, while Paul settles a real matter (the water-sellers'
## petition) whose outcome stands in the campaign.

const LINES: Dictionary = {
	"council": [
		"On the left, the powers of Arrakis, and where we stand with each of them. The Fremen, the Guild, CHOAM, the Bene Gesserit, the Emperor, the smugglers. Every one of them wants something from us.",
		"Above: what we hold. Water, spice, Solari, intelligence, influence. And heat - how much the Harkonnen notice what we do. They are gone from this city. They are not gone from this planet.",
		"Tonight there is one matter before the council. Open its briefing.",
	],
	"briefing": [
		"Every matter can be met more than one way. Some we settle with soldiers, some with one good man in the right place. This one is politics. Work the council.",
	],
	"operation": [
		"Choose how we lean, and on whom. Each approach has its price, and each faction remembers.",
		"Then choose who carries it. Thufir, Gurney, your mother - each has ties that open some doors and not others. Intelligence spent here buys better odds. You will see them before you commit.",
	],
	"dilemma": [
		"There is always a second price. Choose the one you can live with.",
	],
	"result": [
		"You chose, and now it is ours to live with. That is ruling, Paul. Most nights it is no better than this. Go to bed.",
	],
}

var council: CouncilScreen
var _dialogue: DialogueBar
var _said: Dictionary = {}


func _ready() -> void:
	_dialogue = DialogueBar.new()
	_dialogue.name = "DukeLeto"
	_dialogue.at_bottom = true
	add_child(_dialogue)
	council.view_shown.connect(_on_view)
	_on_view("council")


func _on_view(key: String) -> void:
	if _said.has(key) or not LINES.has(key):
		return
	_said[key] = true
	_dialogue.clear()
	for line in LINES[key]:
		_dialogue.say("DUKE LETO", line)
