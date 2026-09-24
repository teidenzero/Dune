extends CanvasLayer
## Objective list, mission banners, and the debrief. It renders what
## MissionManager reports and decides nothing.

@export var mission: MissionManager

const DONE: Color = Color(0.62, 0.86, 0.66)
const ACTIVE: Color = Color(0.98, 0.96, 0.9)
const OPTIONAL: Color = Color(0.74, 0.78, 0.82)
const LOST: Color = Color(1.0, 0.55, 0.45)

var _banner_until: int = 0

@onready var objectives: Label = $Screen/Objectives/Margin/Rows/List
@onready var heading: Label = $Screen/Objectives/Margin/Rows/Heading
@onready var banner: Label = $Screen/Banner
@onready var results: PanelContainer = $Screen/Results
@onready var results_body: Label = $Screen/Results/Margin/Rows/Body
@onready var results_heading: Label = $Screen/Results/Margin/Rows/Heading


func _ready() -> void:
	results.hide()
	banner.hide()
	if not is_instance_valid(mission):
		return
	mission.objectives_changed.connect(_refresh)
	mission.objective_completed.connect(_on_objective_completed)
	mission.objective_failed.connect(func(o: MissionObjective) -> void: _flash("%s FAILED" % o.title.to_upper(), LOST))
	mission.phase_changed.connect(_on_phase)
	mission.mission_completed.connect(_on_completed)
	mission.mission_failed.connect(_on_failed)
	$Screen/Results/Margin/Rows/Buttons/Retry.pressed.connect(_on_retry)
	$Screen/Results/Margin/Rows/Buttons/Launcher.pressed.connect(_on_launcher)
	_refresh()


func _refresh() -> void:
	var lines: PackedStringArray = []
	for objective: MissionObjective in mission.all_objectives():
		if objective.state == MissionObjective.State.INACTIVE:
			continue
		var mark: String = "[x]" if objective.state == MissionObjective.State.COMPLETE else ("[-]" if objective.state == MissionObjective.State.FAILED else "[ ]")
		var suffix: String = "  (optional)" if objective.optional else ""
		lines.append("%s %s%s" % [mark, objective.display_title(), suffix])
	objectives.text = "\n".join(lines)
	heading.text = "OBJECTIVES"


func _on_objective_completed(objective: MissionObjective) -> void:
	_flash("%s" % objective.title.to_upper(), DONE)


func _on_phase(phase: StringName, _previous: StringName) -> void:
	match phase:
		&"ALARM":
			_flash("ALARM RAISED", LOST)
		&"ESCAPE":
			_flash("GET TO THE ROCK", Color(1.0, 0.82, 0.45))


func _flash(text: String, color: Color) -> void:
	banner.text = text
	banner.modulate = color
	banner.show()
	_banner_until = Time.get_ticks_msec() + 2200


func _process(_delta: float) -> void:
	if banner.visible and Time.get_ticks_msec() > _banner_until:
		banner.hide()


func _on_completed(data: Dictionary) -> void:
	results_heading.text = "%s COMPLETE" % mission.mission_name.to_upper()
	results_heading.modulate = DONE
	_show_results(data)


func _on_failed(reason: String) -> void:
	results_heading.text = "MISSION FAILED"
	results_heading.modulate = LOST
	var data: Dictionary = mission.results.duplicate()
	data["Outcome"] = reason
	data["Mission time"] = mission.time_text()
	_show_results(data)


## Factual outcomes only - no score, no grade.
func _show_results(data: Dictionary) -> void:
	var lines: PackedStringArray = []
	var record: MissionOutcome = mission.outcome_record if is_instance_valid(mission) else null
	if record != null:
		lines.append("OUTCOME:  %s" % record.tier_title())
		var consequences: PackedStringArray = record.consequence_lines()
		if not consequences.is_empty():
			lines.append("CONSEQUENCES:  " + "  ·  ".join(consequences))
		if not mission.outcome_committed:
			lines.append("(They stand when you leave. Retrying discards them.)")
		lines.append("")
	for key in data:
		lines.append("%s:  %s" % [key, str(data[key])])
	# There are two ways out of a failed mission and they do different things.
	# Say so, rather than leaving the player to find out by pressing one.
	if is_instance_valid(mission) and mission.checkpoint() != &"":
		lines.append("")
		lines.append("ENTER resumes from the last checkpoint.")
	results_body.text = "\n".join(lines)
	banner.hide()
	results.show()


func _on_retry() -> void:
	if is_instance_valid(mission):
		mission.clear_checkpoint()
	get_tree().reload_current_scene()


func _on_launcher() -> void:
	if is_instance_valid(mission):
		# Leaving accepts the result, failure included.
		mission.commit_outcome()
		mission.clear_checkpoint()
	var game: Node = get_node_or_null("/root/GameManager")
	var target: String = game.return_scene if game != null and game.return_scene != "" else "res://scenes/missions/mission_select.tscn"
	get_tree().change_scene_to_file(target)
