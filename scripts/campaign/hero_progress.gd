class_name HeroProgress
extends RefCounted
## How far one hero has grown: experience in the skills that grow by use,
## ranks given by milestones, and spice saturation. The effects of all this
## are worked out in Progression; this only holds the numbers.

var hero_id: StringName = &""
## Skill -> experience points (blade, firearms, desert_craft).
var xp: Dictionary = {}
## +1 action point per rank (training, milestones).
var discipline: int = 0
## Prescience ranks granted by the story's great spice moments.
var prescience_rank: int = 0
## Permanent spice saturation; every Progression.SATURATION_PER_RANK adds a
## prescience rank.
var saturation: float = 0.0


static func create(id: StringName) -> HeroProgress:
	var progress: HeroProgress = HeroProgress.new()
	progress.hero_id = id
	for skill in Progression.SKILLS:
		progress.xp[skill] = 0
	return progress


func rank(skill: StringName) -> int:
	return Progression.rank_for(int(xp.get(skill, 0)))


## Everything prescience gets beyond the hero's base: story ranks plus the
## ranks saturation has built.
func prescience_bonus() -> int:
	return prescience_rank + floori(saturation / Progression.SATURATION_PER_RANK)
