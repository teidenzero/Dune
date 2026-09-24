class_name PoliticalChoice
extends Resource
## One answer to an operation's dilemma: a trade-off, never a free win.
## `effects` uses the stakes format: { "resources": {}, "standings": {}, "heat": 0 }.

@export var text: String = ""
@export_range(-0.5, 0.5, 0.01) var chance_bonus: float = 0.0
@export var effects: Dictionary = {}
