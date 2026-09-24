class_name ArrakisAtlas
extends RefCounted
## The fixed geography of the strategic map: regions of Arrakis, where they
## sit on a flat Fremen-style projection (north pole at the top), what kind
## of ground they are, whether spice can be harvested there, and the routes
## between them. What changes during the campaign lives in RegionState.

enum Kind { CITY, ROCK, SAND, SIETCH, VILLAGE, POLAR, HIDDEN }

## Map space: 1000 x 600, the Polar Sink at the top, the southern gardens
## at the bottom. The UI scales it to whatever it has.
const SIZE: Vector2 = Vector2(1000, 600)

const REGIONS: Dictionary = {
	&"polar_sink": {"name": "Polar Sink", "kind": Kind.POLAR, "pos": Vector2(500, 38), "spice": 0,
		"note": "Ice and the Imperial ecological stations."},
	&"arrakeen": {"name": "Arrakeen", "kind": Kind.CITY, "pos": Vector2(420, 104), "spice": 0,
		"note": "The old Atreides seat. Rabban rules it now."},
	&"carthag": {"name": "Carthag", "kind": Kind.CITY, "pos": Vector2(640, 96), "spice": 0,
		"note": "The Harkonnen city, all towers and slave pens."},
	&"imperial_basin": {"name": "Imperial Basin", "kind": Kind.ROCK, "pos": Vector2(530, 150), "spice": 0,
		"note": "Arrakeen's hinterland, under the Shield Wall."},
	&"shield_wall": {"name": "Shield Wall", "kind": Kind.ROCK, "pos": Vector2(420, 190), "spice": 0,
		"note": "The mountain barrier that keeps the storms off Arrakeen."},
	&"old_gap": {"name": "Old Gap", "kind": Kind.ROCK, "pos": Vector2(300, 170), "spice": 0,
		"note": "The pass through the Shield Wall."},
	&"tuono_basin": {"name": "Tuono Basin", "kind": Kind.VILLAGE, "pos": Vector2(640, 196), "spice": 0,
		"note": "Pan and graben villages, taxed to the bone."},
	&"wind_pass": {"name": "Wind Pass", "kind": Kind.ROCK, "pos": Vector2(800, 170), "spice": 0,
		"note": "Smugglers' routes, and nobody asks."},
	&"harg_pass": {"name": "Harg Pass", "kind": Kind.ROCK, "pos": Vector2(210, 240), "spice": 0,
		"note": "A narrow way through the rock. Good for ambushes."},
	&"funeral_plain": {"name": "Funeral Plain", "kind": Kind.SAND, "pos": Vector2(470, 270), "spice": 2,
		"note": "Spice fields, Harkonnen harvesters, and worms."},
	&"great_flat": {"name": "The Great Flat", "kind": Kind.SAND, "pos": Vector2(690, 290), "spice": 3,
		"note": "The richest fields. Rabban's quota comes from here."},
	&"broken_land": {"name": "The Broken Land", "kind": Kind.ROCK, "pos": Vector2(860, 300), "spice": 0,
		"note": "Badlands and caves. The smugglers' base."},
	&"cave_of_birds": {"name": "Cave of Birds", "kind": Kind.SIETCH, "pos": Vector2(110, 300), "spice": 0,
		"note": "A Fremen waypoint high in the rock."},
	&"false_wall": {"name": "False Wall", "kind": Kind.ROCK, "pos": Vector2(250, 330), "spice": 0,
		"note": "Broken cliffs where sietches hide."},
	&"sietch_tabr": {"name": "Sietch Tabr", "kind": Kind.SIETCH, "pos": Vector2(170, 400), "spice": 0,
		"note": "Stilgar's sietch. Home."},
	&"red_chasm": {"name": "Red Chasm", "kind": Kind.SIETCH, "pos": Vector2(360, 400), "spice": 0,
		"note": "A proud sietch with its own naib."},
	&"deep_desert": {"name": "The Deep Desert", "kind": Kind.SAND, "pos": Vector2(740, 420), "spice": 3,
		"note": "Shai-Hulud's country. Only worm riders cross it."},
	&"plaster_basin": {"name": "Plaster Basin", "kind": Kind.SAND, "pos": Vector2(290, 480), "spice": 1,
		"note": "Where the first Fremen plantings hide under the sand."},
	&"cielago": {"name": "Cielago", "kind": Kind.SAND, "pos": Vector2(480, 470), "spice": 2,
		"note": "A deep depression; storms gather here."},
	&"habbanya_ridge": {"name": "Habbanya Ridge", "kind": Kind.ROCK, "pos": Vector2(610, 520), "spice": 0,
		"note": "Southern sietches on the storm's edge."},
	&"southern_gardens": {"name": "Southern Gardens", "kind": Kind.HIDDEN, "pos": Vector2(420, 565), "spice": 0,
		"note": "The secret Fremen plantings. The Harkonnen must never see them."},
}

const ROUTES: Array = [
	[&"polar_sink", &"arrakeen"], [&"polar_sink", &"carthag"], [&"arrakeen", &"imperial_basin"],
	[&"arrakeen", &"shield_wall"], [&"carthag", &"imperial_basin"], [&"carthag", &"tuono_basin"],
	[&"carthag", &"wind_pass"], [&"imperial_basin", &"shield_wall"], [&"imperial_basin", &"tuono_basin"],
	[&"shield_wall", &"old_gap"], [&"shield_wall", &"funeral_plain"], [&"old_gap", &"harg_pass"],
	[&"old_gap", &"funeral_plain"], [&"tuono_basin", &"funeral_plain"], [&"tuono_basin", &"great_flat"],
	[&"wind_pass", &"great_flat"], [&"wind_pass", &"broken_land"], [&"harg_pass", &"cave_of_birds"],
	[&"harg_pass", &"false_wall"], [&"funeral_plain", &"false_wall"], [&"funeral_plain", &"great_flat"],
	[&"funeral_plain", &"red_chasm"], [&"great_flat", &"broken_land"], [&"great_flat", &"deep_desert"],
	[&"broken_land", &"deep_desert"], [&"cave_of_birds", &"false_wall"], [&"cave_of_birds", &"sietch_tabr"],
	[&"false_wall", &"sietch_tabr"], [&"false_wall", &"red_chasm"], [&"sietch_tabr", &"plaster_basin"],
	[&"red_chasm", &"plaster_basin"], [&"red_chasm", &"cielago"], [&"red_chasm", &"deep_desert"],
	[&"deep_desert", &"cielago"], [&"deep_desert", &"habbanya_ridge"], [&"plaster_basin", &"southern_gardens"],
	[&"cielago", &"southern_gardens"], [&"cielago", &"habbanya_ridge"], [&"habbanya_ridge", &"southern_gardens"],
]

const KIND_NAMES: Array[String] = ["City", "Rock", "Open sand", "Sietch", "Village", "Polar", "Hidden"]


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in REGIONS:
		result.append(id)
	return result


static func info(id: StringName) -> Dictionary:
	return REGIONS.get(id, {})


static func title(id: StringName) -> String:
	return info(id).get("name", String(id))


static func kind(id: StringName) -> Kind:
	return info(id).get("kind", Kind.ROCK)


static func position(id: StringName) -> Vector2:
	return info(id).get("pos", Vector2.ZERO)


static func spice(id: StringName) -> int:
	return info(id).get("spice", 0)


static func neighbours(id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for route in ROUTES:
		if route[0] == id:
			result.append(route[1])
		elif route[1] == id:
			result.append(route[0])
	return result


## Latitude, 0 at the north pole to 1 at the south: the storm band works in it.
static func latitude(id: StringName) -> float:
	return position(id).y / SIZE.y
