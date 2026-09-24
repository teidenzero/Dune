class_name TutorialStep
extends RefCounted
## One teaching beat: what to say, what to highlight, and how to tell that the
## player actually did it. Completion is a Callable rather than an enum, so each
## step's condition lives beside its own text instead of in a growing match
## statement. Steps are built in code because a Callable cannot be serialised.

enum State { INACTIVE, ACTIVE, COMPLETE, FAILED }

var id: StringName = &""
var section: StringName = &""
var title: String = ""
var instruction: String = ""
var hint: String = ""
var hint_delay: float = 10.0
var speaker: String = ""
## Marker node names activated while this step runs.
var markers: PackedStringArray = PackedStringArray()
## () -> bool, checked once per frame. Signal-driven steps only read a counter.
var completion: Callable = Callable()
var on_start: Callable = Callable()
var on_complete: Callable = Callable()
## Short teaching line shown for a moment after the step is satisfied.
var note: String = ""
var delay_after: float = 0.9
## A failure later in this section restarts here instead of at its first step,
## so a long lesson is not replayed from the top for one late mistake.
var retry_here: bool = false
var state: State = State.INACTIVE


static func create(data: Dictionary) -> TutorialStep:
	var step: TutorialStep = TutorialStep.new()
	step.id = StringName(data.get("id", "step"))
	step.section = StringName(data.get("section", "general"))
	step.title = data.get("title", "")
	step.instruction = data.get("instruction", "")
	step.hint = data.get("hint", "")
	step.hint_delay = data.get("hint_delay", 10.0)
	step.speaker = data.get("speaker", "")
	step.note = data.get("note", "")
	step.delay_after = data.get("delay_after", 0.9)
	step.retry_here = data.get("retry_here", false)
	step.completion = data.get("completion", Callable())
	step.on_start = data.get("on_start", Callable())
	step.on_complete = data.get("on_complete", Callable())
	for name in data.get("markers", []):
		step.markers.append(str(name))
	return step


func is_satisfied() -> bool:
	return completion.is_valid() and bool(completion.call())


func state_name() -> String:
	return State.keys()[state]
