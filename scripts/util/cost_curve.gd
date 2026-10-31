## CostCurve — shared price curve helper.
##
## cost_at() is the single formula used by upgrades and meta tracks; balance
## data supplies base_cost and growth so no numbers live in gameplay scripts.
class_name CostCurve
extends RefCounted


## Returns the integer cost at `level` (1-based):
## base_cost * growth^(level - 1), rounded and clamped to at least 1.
static func cost_at(base_cost: int, growth: float, level: int) -> int:
	var safe_level := maxi(level, 1)
	var raw := float(base_cost) * pow(growth, float(safe_level - 1))
	return maxi(1, int(round(raw)))
