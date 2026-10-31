## Double Shot — Archer Tower level-5 behavior: one extra projectile per attack.
##
## Each extra shot deals `damage_scale` of the main shot's damage, so the total
## damage gain is data-driven rather than a hardcoded multiplier.
extends TowerBehavior


func modify_shots(params: Dictionary, _level: int, shot: Dictionary) -> Array[Dictionary]:
	var shots: Array[Dictionary] = [shot]
	var extra := int(params.get("extra_shots", 1))
	var scale := float(params.get("damage_scale", 0.7))
	for _index in extra:
		var copy: Dictionary = shot.duplicate(true)
		copy["damage"] = float(shot["damage"]) * scale
		shots.append(copy)
	return shots
