class_name TerrainSafetyComponent
extends Node
## Reports what an actor is standing on. Polls a few times a second rather than
## keeping an Area2D on every character, and defaults to OTHER so ground nobody
## classified - a stone courtyard, say - never carries worm sign.

signal terrain_changed(kind: int)
signal safety_changed(safe: bool)

@export var actor: Node2D
## Terrain zones sit on their own physics layer so this query is cheap.
@export_flags_2d_physics var terrain_mask: int = 4
@export var poll_interval: float = 0.2

var terrain: TerrainZone.Kind = TerrainZone.Kind.OTHER
var sign_multiplier: float = 0.0
var zone: TerrainZone
var _wait: float = 0.0


func _ready() -> void:
	if actor == null:
		actor = get_parent() as Node2D
	_refresh()


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = maxf(poll_interval, 0.05)
		_refresh()


## Rock wins over sand where zones overlap, so a rock island inside a sand field
## needs no cut-out.
func _refresh() -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = actor.global_position
	query.collision_mask = terrain_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var found: TerrainZone
	for hit: Dictionary in actor.get_world_2d().direct_space_state.intersect_point(query, 8):
		var candidate: TerrainZone = hit.get("collider") as TerrainZone
		if candidate == null:
			continue
		if found == null or candidate.is_safe():
			found = candidate
		if candidate.is_safe():
			break
	_apply(found)


func _apply(found: TerrainZone) -> void:
	var kind: TerrainZone.Kind = found.kind if found != null else TerrainZone.Kind.OTHER
	var was_safe: bool = is_safe()
	zone = found
	sign_multiplier = found.sign_multiplier if found != null else 0.0
	if kind != terrain:
		terrain = kind
		terrain_changed.emit(terrain)
	if is_safe() != was_safe:
		safety_changed.emit(is_safe())


func is_safe() -> bool:
	return terrain == TerrainZone.Kind.SAFE_ROCK


func carries_sign() -> bool:
	return terrain == TerrainZone.Kind.OPEN_SAND


func terrain_name() -> String:
	return TerrainZone.Kind.keys()[terrain]


static func find_on(actor: Node) -> TerrainSafetyComponent:
	return actor.get_node_or_null("TerrainSafety") as TerrainSafetyComponent if is_instance_valid(actor) else null
