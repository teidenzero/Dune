class_name DisturbanceBus
extends Node
## Mission-local sound events; no propagation simulation or global alert state.

signal noise_emitted(position: Vector2, radius: float, source: Node, type: int, priority: int)

enum Type { GENERIC, GUNSHOT, IMPACT, FOOTSTEP }


func emit_noise(position: Vector2, radius: float, source: Node = null, type: Type = Type.GENERIC, priority: int = -1) -> void:
	if radius > 0.0 and is_finite(radius) and position.is_finite():
		var effective_priority: int = priority if priority >= 0 else (4 if type == Type.GUNSHOT else (3 if type == Type.IMPACT else 1))
		noise_emitted.emit(position, radius, source, type, effective_priority)
