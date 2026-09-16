class_name DamageResolver
extends RefCounted
## The single path from "an attack contacted a body" to "health changed".
##
## Faction filtering and shield evaluation both happen here, before any health
## call, so HealthComponent stays a plain damage container that knows nothing
## about Dune shield rules. Projectiles and melee share this so their outcomes
## can never drift apart.

enum Outcome { MISSED, FRIENDLY, BLOCKED, DAMAGED }


static func resolve(target: Node, hit: HitContext) -> Outcome:
	if not is_instance_valid(target) or hit == null:
		return Outcome.MISSED
	if hit.source_team != &"" and target.get_meta("team_id", &"") == hit.source_team:
		return Outcome.FRIENDLY
	var health: HealthComponent = HealthComponent.find_on(target)
	if health == null or health.is_dead:
		return Outcome.MISSED
	var shield: ShieldComponent = ShieldComponent.find_on(target)
	if shield != null and shield.evaluate(hit) == ShieldComponent.Result.BLOCKED:
		return Outcome.BLOCKED
	health.take_damage(hit.damage, hit.source)
	return Outcome.DAMAGED


static func outcome_name(outcome: Outcome) -> String:
	return Outcome.keys()[outcome]
