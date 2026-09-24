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
	# A dodging hero is not where the round arrives.
	if target.has_method("evades") and target.evades(hit):
		return Outcome.MISSED
	var shield: ShieldComponent = ShieldComponent.find_on(target)
	if shield != null and shield.evaluate(hit) == ShieldComponent.Result.BLOCKED:
		return Outcome.BLOCKED
	health.take_damage(hit.damage, hit.source)
	_count_growth(target, hit, health.is_dead)
	return Outcome.DAMAGED


## The hero grows by use: every hit a hero lands on an enemy counts toward
## blade or firearms, whichever did it. Real time and turn-based alike pass
## through here.
static func _count_growth(target: Node, hit: HitContext, killed: bool) -> void:
	var hero: PlayerController = hit.source as PlayerController
	if hero == null or not target.is_in_group("enemies"):
		return
	var campaign: CampaignState = Progression.campaign_of(hero)
	var melee: bool = hit.attack_type == HitContext.Type.MELEE
	Progression.award(campaign, hero.hero_id, &"knife_hit" if melee else &"shot_hit")
	if killed:
		Progression.award(campaign, hero.hero_id, &"knife_kill" if melee else &"shot_kill")


static func outcome_name(outcome: Outcome) -> String:
	return Outcome.keys()[outcome]
