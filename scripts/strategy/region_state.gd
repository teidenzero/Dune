class_name RegionState
extends RefCounted
## One region of Arrakis as the campaign stands: who holds it, how hard the
## Harkonnen grip it, the harvesters working its spice, the worm sign on its
## sand, and whether the storm is on it this week.

enum Holder { HARKONNEN, FREMEN, SMUGGLERS, NEUTRAL }

const CONTROL_NAMES: Array[String] = ["Harkonnen", "Fremen", "Smugglers", "Unclaimed"]
const GRIP_MAX: int = 5
const WORM_MAX: float = 100.0

var id: StringName = &""
var control: Holder = Holder.NEUTRAL
## 0..5: garrison, patrols and cruelty. Higher makes operations harder.
var grip: int = 0
## Harkonnen harvesters working this region's spice.
var harvesters: int = 0
## 0..100; a worm comes when it fills.
var worm_sign: float = 0.0
var storm: bool = false
## Weeks until the Harkonnen can send a new harvester here.
var rebuild_wait: int = 0


static func create(region: StringName, holder: Holder, grip_level: int, machines: int = 0) -> RegionState:
	var state: RegionState = RegionState.new()
	state.id = region
	state.control = holder
	state.grip = grip_level
	state.harvesters = machines
	return state


func title() -> String:
	return ArrakisAtlas.title(id)


func control_name() -> String:
	return CONTROL_NAMES[control]


## Spice the Harkonnen take from here this week.
func harkonnen_production() -> int:
	if control != Holder.HARKONNEN or storm:
		return 0
	return harvesters * 10


func duplicate_state() -> RegionState:
	var copy: RegionState = RegionState.create(id, control, grip, harvesters)
	copy.worm_sign = worm_sign
	copy.storm = storm
	copy.rebuild_wait = rebuild_wait
	return copy
