## RunRewards — pure reward math for the run summary.
##
## Kept free of autoload access so headless unit tests can call it before the
## service tree exists. Coins: sum over cleared waves of (8 + 2*wave); boss waves
## add 50 each; gems: floor(cleared / 5) plus 5 on a new personal best; XP: 10 per
## cleared wave. RunRewards only computes; RewardBundle carries the values.
class_name RunRewards
extends RefCounted

const COINS_BASE := 8
const COINS_PER_WAVE := 2
const BOSS_WAVE_COINS := 50
const GEMS_PER_WAVES := 5
const NEW_BEST_GEMS := 5
const XP_PER_WAVE := 10


## Returns {coins, gems, xp} for `waves_cleared`. `boss_waves` adds the authored
## boss bonus and `is_new_best` adds the personal-best gem reward.
static func compute(
	waves_cleared: int,
	boss_waves: int = 0,
	is_new_best: bool = false
) -> Dictionary:
	var waves := maxi(waves_cleared, 0)
	var coins := 0
	for wave in range(1, waves + 1):
		coins += COINS_BASE + COINS_PER_WAVE * wave
	coins += maxi(boss_waves, 0) * BOSS_WAVE_COINS
	var gems := waves / GEMS_PER_WAVES
	if is_new_best:
		gems += NEW_BEST_GEMS
	return {
		"coins": coins,
		"gems": gems,
		"xp": waves * XP_PER_WAVE,
	}
