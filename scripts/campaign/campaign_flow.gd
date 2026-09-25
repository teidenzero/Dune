class_name CampaignFlow
extends RefCounted
## The campaign as the player walks it: the intro, the prologue's training,
## then the story missions in order, with a title card between them. Each
## chapter is a page of text (the story screen), a scene to play, or the
## Duke's council lesson. Whatever finishes a chapter calls advance().
##
## Session-only for now, like the rest of the campaign; saving comes later.

const STORY_SCREEN: String = "res://scenes/menu/story_screen.tscn"
const MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
const COUNCIL: String = "res://scenes/campaign/council.tscn"

## All text here is original to this prototype.
const CHAPTERS: Array[Dictionary] = [
	{"id": "intro", "kind": "story", "pages": [
		{"image": "intro_01_spice", "heading": "", "title": "", "text": "It is the year 10191. The Padishah Emperor Shaddam IV rules the known universe, and the known universe runs on one thing: the spice melange. It lengthens life. It opens the mind. It lets the Navigators of the Spacing Guild fold space and carry the Empire from star to star.\n\nIt is found on one world only."},
		{"image": "intro_02_arrakis", "heading": "", "title": "ARRAKIS", "text": "Dune. A planet of sand and wind and killing heat, where water is wealth and the great worms rule the deep desert. For eighty years House Harkonnen has held it, squeezed it, and grown obscenely rich."},
		{"image": "intro_03_the_gift", "heading": "", "title": "", "text": "Now the Emperor has taken Arrakis from the Harkonnen and given it to their oldest enemies, House Atreides.\n\nDuke Leto Atreides knows that a gift from an emperor is never a gift. He also knows that a duke who refuses his emperor is not a duke for long."},
		{"image": "intro_04_arrival", "heading": "", "title": "", "text": "So the Atreides have come to Arrakeen: the Duke; his Bene Gesserit concubine, the Lady Jessica; and their son, Paul.\n\nThe Harkonnen are gone. Their agents are not. And Paul, fifteen years old, is about to learn how little his lessons on Caladan prepared him for this world."},
	]},
	{"id": "prologue", "kind": "card", "image": "card_prologue", "heading": "PROLOGUE", "title": "The Training",
		"text": "The Residency still smells of Harkonnen and is still full of packing crates. Gurney Halleck has cleared one hall of them already.\n\n\"A new world, lad, and the same old question. Can you fight?\""},
	{"id": "training_hall", "kind": "scene", "title": "The Training Hall",
		"path": "res://scenes/missions/tutorial/solo_training.tscn"},
	{"id": "yard_card", "kind": "card", "image": "card_yard", "heading": "PROLOGUE", "title": "The Yard",
		"text": "Duke Leto watches from the gallery above the yard.\n\n\"Gurney makes fighters. A duke makes fighters into a force. Take two of the Fremen guides, and show me you can lead them.\""},
	{"id": "the_yard", "kind": "scene", "title": "The Yard",
		"path": "res://scenes/missions/tutorial/tutorial_arrakeen.tscn"},
	{"id": "council_card", "kind": "card", "image": "card_council", "heading": "PROLOGUE", "title": "The Council Chamber",
		"text": "Evening, in the Duke's council room.\n\n\"Arrakis is not held with knives, Paul. It is held with water and spice, and with the goodwill of people who have no reason to love us. Sit. Watch how it is done. Then do it.\""},
	{"id": "council_lesson", "kind": "council_lesson", "title": "The Council Chamber",
		"mission": "res://resources/missions/prologue_water_sellers.tres"},
	{"id": "act1", "kind": "card", "image": "card_act1", "heading": "ACT I", "title": "The Atreides Year",
		"text": "The Atreides have a year on Arrakis, perhaps less, to make it theirs before the trap they all feel closing closes.\n\nIt begins badly."},
	{"id": "hunter_seeker_card", "kind": "card", "image": "card_hunter_seeker", "heading": "ACT I  ·  1.1", "title": "The Hunter-Seeker",
		"text": "The first night. Paul cannot sleep; the house is too strange, too quiet. Then it is not quite quiet at all."},
	{"id": "hunter_seeker", "kind": "scene", "title": "The Hunter-Seeker",
		"path": "res://scenes/missions/act1/hunter_seeker.tscn"},
	{"id": "banquet_card", "kind": "card", "image": "card_banquet", "heading": "ACT I  ·  1.2", "title": "The Banquet",
		"text": "A week in Arrakeen. The Lady Jessica has invited the town's notables to dine: the water-sellers, a trader of no fixed trade, CHOAM, the Guild's banker, and the Emperor's planetologist.\n\nEvery one of them has come to take the measure of House Atreides. Tonight, House Atreides takes theirs."},
	{"id": "banquet", "kind": "scene", "title": "The Banquet",
		"path": "res://scenes/campaign/banquet.tscn"},
	{"id": "harvester_card", "kind": "card", "image": "card_harvester", "heading": "ACT I  ·  1.3", "title": "The Harvester in the Open",
		"text": "Word comes by radio: a crawler in the open sand, worm sign, and no carryall answering. The Duke goes himself, and takes Paul, Gurney and the planetologist with him.\n\nKynes says nothing on the flight out. He is watching to see what the Duke will value."},
	{"id": "harvester", "kind": "scene", "title": "The Harvester in the Open",
		"path": "res://scenes/missions/act1/harvester_open.tscn"},
	{"id": "to_be_continued", "kind": "card", "image": "menu_background", "heading": "ACT I", "title": "To Be Continued",
		"text": "The next story mission, 1.4 The Embassy, is being built.\n\nThank you for playing this far."},
]

var active: bool = false
var index: int = 0


func start(tree: SceneTree) -> void:
	active = true
	index = 0
	var game: Node = tree.root.get_node_or_null("GameManager")
	if game != null:
		game.campaign = CampaignState.new()
		game.strategy = null
		game.tutorial_checkpoint = &""
		game.mission_checkpoint = &""
	go(tree)


func current() -> Dictionary:
	return CHAPTERS[index] if index >= 0 and index < CHAPTERS.size() else {}


## Whether the chapter being played is this scene.
func playing(path: String) -> bool:
	var chapter: Dictionary = current()
	return active and chapter.get("kind", "") == "scene" and chapter.get("path", "") == path


func is_lesson() -> bool:
	return active and current().get("kind", "") == "council_lesson"


## Done with this chapter: on to the next, or back to the menu at the end.
func advance(tree: SceneTree) -> void:
	index += 1
	if index >= CHAPTERS.size():
		active = false
		tree.change_scene_to_file(MAIN_MENU)
		return
	go(tree)


func go(tree: SceneTree) -> void:
	var chapter: Dictionary = current()
	var game: Node = tree.root.get_node_or_null("GameManager")
	if game != null:
		game.tutorial_checkpoint = &""
		game.mission_checkpoint = &""
		game.return_scene = ""
	# The theme plays over the menu and the story pages; play begins in quiet.
	if game != null and chapter.get("kind", "") not in ["story", "card"]:
		game.stop_music()
	match chapter.get("kind", ""):
		"story", "card":
			tree.change_scene_to_file(STORY_SCREEN)
		"scene":
			if game != null:
				game.pending_briefing = true
			tree.change_scene_to_file(chapter.path)
		"council_lesson":
			if game != null:
				game.pending_briefing = true
				game.council_focus = ""
				game.council_home = ""
			tree.change_scene_to_file(COUNCIL)


## The pages the story screen shows for this chapter.
func pages() -> Array:
	var chapter: Dictionary = current()
	if chapter.get("kind", "") == "story":
		return chapter.pages
	return [{"image": chapter.get("image", ""), "heading": chapter.get("heading", ""), "title": chapter.get("title", ""), "text": chapter.get("text", "")}]
