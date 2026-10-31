## RunState — read-only mirror of the live run for HUD/tools/tests (autoload).
##
## Cash is owned by BattleController's RunWallet (the single mutation point); this
## autoload only mirrors the balance so read-only consumers and tests keep one
## stable address. run_id identifies the run for reward idempotency.
extends Node

var seed: int = 0
var cash: int = 0
var wave: int = 0
var started_at: int = 0
var run_id: String = ""


## Starts a fresh run for `run_seed` and clears all per-run values.
func reset(run_seed: int) -> void:
	seed = run_seed
	cash = 0
	wave = 0
	started_at = TimeService.now_unix()
	run_id = "%d-%d" % [run_seed, started_at]


## Returns true when reset() has been called for this run.
func is_active() -> bool:
	return started_at > 0


## Clears the run without starting a new one.
func clear() -> void:
	seed = 0
	cash = 0
	wave = 0
	started_at = 0
	run_id = ""
