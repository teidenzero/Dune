class_name PoliticalApproach
extends Resource
## One way to resolve a mission through the Council instead of on the ground.
## An approach goes through one faction: it needs their goodwill, costs
## resources up front, and always leaves a mark (`effects`) - success or not.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
## The faction whose help this approach relies on.
@export var faction: StringName = &""
## Standing with `faction` needed to try it at all.
@export_range(-2, 3) var min_standing: int = -1
@export_range(0.05, 0.95, 0.01) var base_chance: float = 0.5
## Paid when the operation is committed, whatever happens: { &"solari": 20 }.
@export var costs: Dictionary = {}
## Side effects of trying, in the stakes format.
@export var effects: Dictionary = {}
@export_multiline var dilemma: String = ""
@export var choices: Array[PoliticalChoice] = []
