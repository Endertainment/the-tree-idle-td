## LevelCurve — per-level growth and price curve shared by towers and units.
##
## All M2 level numbers live here as data: upgrade price, per-level damage/range/
## interval growth and the interval floor. Towers and units read the same class,
## so adding a new tower type never changes a formula.
class_name LevelCurve
extends Resource

@export var max_level: int = 10
## Upgrade price = cost_base * cost_growth^(current_level - 1), where cost_base is
## either `cost_base_override` or `base_cost * cost_factor`.
@export var cost_factor: float = 0.8
@export var cost_growth: float = 1.55
@export var cost_base_override: int = 0
@export var damage_growth: float = 1.18
@export var range_growth: float = 1.02
@export var interval_growth: float = 0.97
@export var min_interval: float = 0.35


## Returns true while the entity can still gain a level.
func can_upgrade(level: int) -> bool:
	return level < max_level


## Price of the next level when the entity is currently at `current_level`.
## Returns 0 at max level so callers can disable the button with one check.
func upgrade_cost(base_cost: int, current_level: int) -> int:
	if not can_upgrade(current_level):
		return 0
	var base := float(cost_base_override)
	if cost_base_override <= 0:
		base = float(base_cost) * cost_factor
	return maxi(1, int(round(base * pow(cost_growth, float(current_level - 1)))))


func damage_at(base_damage: float, level: int) -> float:
	return base_damage * pow(damage_growth, float(level - 1))


func range_at(base_range: float, level: int) -> float:
	return base_range * pow(range_growth, float(level - 1))


## Attack interval for `level`, floored at `min_interval` (spec 4.5).
func interval_at(base_interval: float, level: int) -> float:
	return maxf(base_interval * pow(interval_growth, float(level - 1)), min_interval)
