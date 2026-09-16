class_name CommandLinkComponent
extends Node
## Communication link between Paul and one companion.
## SquadManager owns the range (and any future modifiers); this component only
## classifies the reported distance and exposes it to UI and order gating.

signal link_state_changed(state: int)

enum State { CONNECTED, WEAK_LINK, OUT_OF_RANGE }

var state: State = State.CONNECTED
var distance: float = 0.0
var effective_range: float = 0.0
## 1.0 next to Paul, 0.0 at the command-range limit.
var quality: float = 1.0


func update_link(new_distance: float, range_value: float, weak_fraction: float) -> void:
	if not is_finite(new_distance) or not is_finite(range_value):
		return
	distance = maxf(new_distance, 0.0)
	effective_range = maxf(range_value, 0.0)
	quality = 0.0 if effective_range <= 0.0 else clampf(1.0 - distance / effective_range, 0.0, 1.0)
	var next_state: State = State.CONNECTED
	if distance > effective_range:
		next_state = State.OUT_OF_RANGE
	elif distance > effective_range * clampf(weak_fraction, 0.0, 1.0):
		next_state = State.WEAK_LINK
	if next_state != state:
		state = next_state
		link_state_changed.emit(state)


func can_receive_orders() -> bool:
	return state != State.OUT_OF_RANGE


func state_name() -> String:
	return State.keys()[state]


func short_label() -> String:
	match state:
		State.WEAK_LINK:
			return "WEAK"
		State.OUT_OF_RANGE:
			return "LOST"
		_:
			return "OK"
