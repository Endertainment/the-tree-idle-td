## TargetingStrategy — registry of the four M2 target-selection modes.
##
## Mode ids are authored on TowerData/UnitData (`target_mode`). Selection runs on
## the small candidate list returned by the spatial hash, so no mode scans the
## scene tree. Adding a mode is one entry in MODES plus one branch here.
class_name TargetingStrategy
extends RefCounted

const MODES: Array[StringName] = [&"first", &"last", &"closest", &"strongest"]


static func is_valid(mode: StringName) -> bool:
	return MODES.has(mode)


## Picks the best living candidate for `mode`, or null when none qualifies.
## - first: furthest along its lane (closest to the Tree)
## - last: least advanced
## - closest: shortest distance from `origin`
## - strongest: highest current HP
static func select(mode: StringName, origin: Vector2, candidates: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_score := -INF
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var score := 0.0
		match mode:
			&"last":
				score = -candidate.progress_ratio
			&"closest":
				score = -origin.distance_to(candidate.global_position)
			&"strongest":
				score = candidate.hp
			_:
				score = candidate.progress_ratio
		if best == null or score > best_score:
			best_score = score
			best = candidate
	return best
