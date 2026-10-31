## Rooted Gift — Totem level-5 behavior: stronger aura for nearby towers and Tree.
##
## Aura values are additive fractions; the behavior adds the authored bonuses on
## top of the tower's base aura.
extends TowerBehavior


func modify_aura(params: Dictionary, _level: int, aura: Dictionary) -> Dictionary:
	var result: Dictionary = aura.duplicate(true)
	result["damage"] = float(aura.get("damage", 0.0)) + float(params.get("damage_bonus", 0.10))
	result["speed"] = float(aura.get("speed", 0.0)) + float(params.get("speed_bonus", 0.05))
	return result
