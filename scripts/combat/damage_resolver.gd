## DamageResolver — the single place where a damage number is computed (spec 4.7).
##
## Pipeline: base * damage_multiplier * splash_falloff -> crit -> flat armor with
## a 10 % floor -> clamp at zero. `is_true_damage` skips armor for future enemy
## resistances/boss mechanics. Callers pass the resolved `amount` to
## Entity.apply_damage(); no other script may subtract HP with its own formula.
class_name DamageResolver
extends RefCounted

const ARMOR_FLOOR_RATIO := 0.10


## Resolves one hit. Returns {amount: float, is_crit: bool}.
static func resolve(
	base: float,
	crit_chance: float,
	crit_mult: float,
	rng: RandomNumberGenerator,
	armor: float,
	damage_multiplier: float = 1.0,
	falloff: float = 1.0,
	is_true_damage: bool = false,
	target_multiplier: float = 1.0
) -> Dictionary:
	var is_crit := rng.randf() < clampf(crit_chance, 0.0, 1.0)
	var damage := maxf(base, 0.0) * maxf(damage_multiplier, 0.0) * clampf(falloff, 0.0, 1.0)
	if is_crit:
		damage *= crit_mult
	var applied := damage
	if not is_true_damage:
		applied = maxf(damage - maxf(armor, 0.0), damage * ARMOR_FLOOR_RATIO)
	return {"amount": maxf(applied * maxf(target_multiplier, 0.0), 0.0), "is_crit": is_crit}


## Linear splash falloff: 1.0 at the impact point, `min_ratio` at the edge.
## A zero radius (or zero ratio) means "no splash" and returns 1.0.
static func splash_falloff(distance: float, radius: float, min_ratio: float) -> float:
	if radius <= 0.0:
		return 1.0
	var ratio := clampf(min_ratio, 0.0, 1.0)
	var t := clampf(distance / radius, 0.0, 1.0)
	return lerpf(1.0, ratio, t)
