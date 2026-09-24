class_name HeroDefinition
extends Resource
## A named hero as the campaign knows them. For now only their political side
## is used (as an operation's agent); squad and solo traits arrive with the
## roster milestone.

@export var id: StringName = &""
@export var display_name: String = ""
@export var title: String = ""
## Squad-card style portrait; heroes without one show `glyph`.
@export var portrait: Texture2D
@export var glyph: String = "paul"
## The faction this hero has standing with: their approaches go better.
@export var affinity: StringName = &""
## Added to the success chance of an approach through `affinity`.
@export_range(0.0, 0.5, 0.01) var affinity_bonus: float = 0.15
## Added to the success chance of every approach (a mentat's planning).
@export_range(0.0, 0.5, 0.01) var general_bonus: float = 0.0
@export_multiline var political_trait: String = ""

@export_group("Combat")
## Action points per turn in the interiors' turn-based combat.
@export_range(4, 20) var action_points: int = 10
## Visions per fight: each one plays a turn out and lets the hero take it
## back. Grows as the hero develops; most heroes have none.
@export_range(0, 9) var prescience: int = 0
