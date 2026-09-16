class_name HitContext
extends RefCounted
## One incoming attack, described independently of how it was delivered.
##
## Projectiles and melee swings both produce this, so defensive components can
## judge an attack without knowing which system created it. `attack_velocity`
## is the field personal shields care about.

enum Type { RANGED, MELEE }

var damage: float = 0.0
var source: Node = null
var source_team: StringName = &""
var attack_velocity: float = 0.0
var attack_type: Type = Type.RANGED
var label: String = "attack"
var position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT


static func ranged(hit_damage: float, velocity: float, actor: Node, team: StringName, name: String, point: Vector2, travel: Vector2) -> HitContext:
	var hit: HitContext = HitContext.new()
	hit.damage = hit_damage
	hit.attack_velocity = velocity
	hit.source = actor
	hit.source_team = team
	hit.label = name
	hit.position = point
	hit.direction = travel
	hit.attack_type = Type.RANGED
	return hit


static func melee(data: MeleeAttackData, actor: Node, point: Vector2, travel: Vector2) -> HitContext:
	var hit: HitContext = HitContext.new()
	hit.damage = data.damage
	hit.attack_velocity = data.attack_velocity
	hit.source = actor
	hit.source_team = actor.get_meta("team_id", &"") if is_instance_valid(actor) else &""
	hit.label = data.attack_name
	hit.position = point
	hit.direction = travel
	hit.attack_type = Type.MELEE
	return hit


func type_name() -> String:
	return Type.keys()[attack_type]
