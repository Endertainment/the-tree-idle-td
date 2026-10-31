## RngService — seeded random number generators for deterministic runs (autoload).
##
## Combat must use the RandomNumberGenerator returned by new_run_rng(seed), never
## the global RNG, so a run can be reproduced from its seed.
extends Node

var _fallback_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_fallback_rng.randomize()


## Creates an independent generator seeded with the run seed.
func new_run_rng(run_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	return rng


## Picks a random element from `list`. Uses `rng` when supplied, otherwise the
## service's non-deterministic fallback. Returns null for an empty list.
func pick(list: Array, rng: RandomNumberGenerator = null) -> Variant:
	if list.is_empty():
		return null
	var source: RandomNumberGenerator = rng if rng != null else _fallback_rng
	return list[source.randi_range(0, list.size() - 1)]
