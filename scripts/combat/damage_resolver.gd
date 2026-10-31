## DamageResolver — the single place where a damage number is computed (spec 4.7).
##
## Pipeline: base -> crit -> flat armor (with a 10% floor) -> clamp at zero.
## Callers pass the resolved `amount` to Entity.apply_damage(); no other script
## may subtract HP from a damage formula of its own.
class_name DamageResolver
extends RefCounted

const ARMOR_FLOOR_RATIO := 0.10


## Resolves one hit. Returns {amount: float, is_crit: bool}.
static func resolve(
	base: float,
	crit_chance: float,
	crit_mult: float,
	rng: RandomNumberGenerator,
	armor: float
) -> Dictionary:
	var is_crit := rng.randf() < clampf(crit_chance, 0.0, 1.0)
	var damage := maxf(base, 0.0)
	if is_crit:
		damage *= crit_mult
	var after_armor := maxf(damage - maxf(armor, 0.0), damage * ARMOR_FLOOR_RATIO)
	return {"amount": maxf(after_armor, 0.0), "is_crit": is_crit}
