class_name HeroRoster
extends RefCounted
## The named heroes the campaign can call on. Availability (wounded, captured)
## arrives with the roster milestone; for now every hero is available.

const PATHS: Array[String] = [
	"res://resources/heroes/paul.tres",
	"res://resources/heroes/jessica.tres",
	"res://resources/heroes/gurney.tres",
	"res://resources/heroes/thufir.tres",
	"res://resources/heroes/duncan.tres",
	"res://resources/heroes/stilgar.tres",
]


static func all() -> Array[HeroDefinition]:
	var heroes: Array[HeroDefinition] = []
	for path in PATHS:
		var hero: HeroDefinition = load(path) as HeroDefinition
		if hero != null:
			heroes.append(hero)
	return heroes
