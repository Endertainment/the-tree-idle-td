## HoldToBuy — repeat-purchase scheduler for hold-to-buy buttons (8 purchases/s).
##
## Pure: it owns only timing. Each attempt goes through a Callable that must return
## a SpendResult; the scheduler stops on any failure, so it can never double-spend
## or keep buying past the balance. UI code feeds it wall-clock time from
## `_process` because purchase cadence is input feel, not battle simulation.
class_name HoldToBuy
extends RefCounted

## 8 purchases per second, i.e. one every 0.125 s (spec 4.10).
const REPEAT_INTERVAL := 0.125
## Safety rail for a huge/lagging delta: never attempt more than this per tick.
const MAX_ATTEMPTS_PER_TICK := 64

var _active: bool = false
var _cooldown: float = 0.0
var _purchases: int = 0


func start() -> void:
	_active = true
	_cooldown = 0.0
	_purchases = 0


func stop() -> void:
	_active = false


func is_active() -> bool:
	return _active


func get_purchases() -> int:
	return _purchases


## Advances the scheduler. Returns how many purchases happened this tick.
## `attempt` is a Callable with no arguments returning SpendResult.
func tick(delta: float, attempt: Callable) -> int:
	if not _active:
		return 0
	_cooldown -= maxf(delta, 0.0)
	var purchases := 0
	var attempts := 0
	while _active and _cooldown <= 0.0 and attempts < MAX_ATTEMPTS_PER_TICK:
		attempts += 1
		var result: Variant = attempt.call()
		if not (result is SpendResult) or not (result as SpendResult).is_ok():
			_active = false
			break
		purchases += 1
		_purchases += 1
		_cooldown += REPEAT_INTERVAL
	return purchases
