## Shrapnel — Cannon level-5 behavior: a wider splash with a softer edge.
##
## `radius_scale` and `min_ratio` are authored in the cannon's behavior_params;
## the behavior only rewrites the shot dictionary.
extends TowerBehavior


func modify_shots(params: Dictionary, _level: int, shot: Dictionary) -> Array[Dictionary]:
	var shots: Array[Dictionary] = [shot]
	var result: Dictionary = shot.duplicate(true)
	result["splash_radius"] = float(shot.get("splash_radius", 0.0)) * float(params.get("radius_scale", 1.5))
	result["splash_min_ratio"] = maxf(
		float(shot.get("splash_min_ratio", 0.35)),
		float(params.get("min_ratio", 0.6))
	)
	shots[0] = result
	return shots
