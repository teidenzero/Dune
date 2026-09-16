class_name TimeScaleManager
extends RefCounted
## Single owner of `Engine.time_scale`.
##
## Command mode and prescience both slow the world. Before this existed each
## wrote the global directly, so whichever released last decided the result.
## Now a source must hold the clock to change it, and only one may hold it at a
## time, which is what makes the two features mutually exclusive rather than
## some scattered `if` in both of them.
##
## Static rather than an Autoload so `class_name` resolves at compile time; a
## `--script` test harness compiles mission scripts before autoloads register.

enum Source { NONE, COMMAND_MODE, PRESCIENCE }

static var _holder: Source = Source.NONE
static var _scale: float = 1.0


## Takes the clock for `source`, or fails if another source already holds it.
static func request(source: Source, scale: float) -> bool:
	if source == Source.NONE or not is_finite(scale):
		return false
	if _holder != Source.NONE and _holder != source:
		return false
	_holder = source
	_scale = clampf(scale, 0.01, 1.0)
	Engine.time_scale = _scale
	return true


## Returns the clock to normal, but only for the source that took it.
static func release(source: Source) -> void:
	if _holder != source:
		return
	reset()


## Unconditional restore, for scene teardown, death, and checkpoint reloads.
static func reset() -> void:
	_holder = Source.NONE
	_scale = 1.0
	Engine.time_scale = 1.0


static func holder() -> Source:
	return _holder


static func holder_name() -> String:
	return Source.keys()[_holder]


static func is_available(source: Source) -> bool:
	return _holder == Source.NONE or _holder == source


static func is_held_by(source: Source) -> bool:
	return _holder == source


## Real elapsed time for a scaled delta, for timers and input that must stay
## responsive while the world crawls.
static func unscaled(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)
