## RunRewards — pure reward math for the run summary.
##
## Kept free of autoload access so headless unit tests can call it before the
## service tree exists. Coins: sum over cleared waves of (8 + 2*wave).
class_name RunRewards
extends RefCounted

const COINS_BASE := 8
const COINS_PER_WAVE := 2
const GEMS_PER_WAVES := 5
const XP_PER_WAVE := 10


## Returns {coins, gems, xp} for `waves_cleared`.
static func compute(waves_cleared: int) -> Dictionary:
	var waves := maxi(waves_cleared, 0)
	var coins := 0
	for wave in range(1, waves + 1):
		coins += COINS_BASE + COINS_PER_WAVE * wave
	return {
		"coins": coins,
		"gems": waves / GEMS_PER_WAVES,
		"xp": waves * XP_PER_WAVE,
	}
