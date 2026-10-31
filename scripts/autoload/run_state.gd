## RunState — data for one battle run (autoload).
##
## Holds no gameplay logic. Battle systems (M1) reset it with a seed and mutate
## cash/wave; the run is intentionally not resumable in the launch build.
extends Node

var seed: int = 0
var cash: int = 0
var wave: int = 0
var started_at: int = 0


## Starts a fresh run for `run_seed` and clears all per-run values.
func reset(run_seed: int) -> void:
	seed = run_seed
	cash = 0
	wave = 0
	started_at = TimeService.now_unix()


## Returns true when reset() has been called for this run.
func is_active() -> bool:
	return started_at > 0


## Clears the run without starting a new one.
func clear() -> void:
	seed = 0
	cash = 0
	wave = 0
	started_at = 0
