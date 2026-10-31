## Deep Chill — Frost Spire level-5 behavior: stronger and longer slow.
##
## Adds `slow_pct_bonus` and `duration_bonus` from behavior_params to the shot's
## slow, without changing the authored StatusData resource.
extends TowerBehavior


func modify_shots(params: Dictionary, _level: int, shot: Dictionary) -> Array[Dictionary]:
	var shots: Array[Dictionary] = [shot]
	var result: Dictionary = shot.duplicate(true)
	result["slow_pct"] = clampf(
		float(shot.get("slow_pct", 0.0)) + float(params.get("slow_pct_bonus", 0.15)),
		0.0,
		0.9
	)
	result["slow_duration"] = float(shot.get("slow_duration", 0.0)) + float(params.get("duration_bonus", 0.5))
	shots[0] = result
	return shots
