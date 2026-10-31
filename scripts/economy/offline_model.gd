## OfflineModel — pure offline-income maths (spec 6.1 + M4b).
##
## Coins accrued while the app was closed: `rate * seconds`, clamped to the
## Offline Cap (8 h base + the workshop `offline_cap_minutes` track). The rate is
## 0.01 coins/s base and is multiplied by `offline_coin_rate` (workshop + Night
## Harvest). Keeping this pure makes 0 s / under-cap / over-cap testable without a
## clock or a wallet.
class_name OfflineModel
extends RefCounted

const BASE_COINS_PER_SECOND := 0.01
const BASE_CAP_SECONDS := 8 * 3600
const MIN_AWAY_SECONDS := 60


## Cap in seconds: 8 h + 20 min per workshop level.
static func cap_seconds(offline_cap_minutes: float) -> int:
	return int(BASE_CAP_SECONDS + maxf(offline_cap_minutes, 0.0) * 60.0)


## Computes the reward for a `last_seen` -> `now` delta.
## Returns {coins, away_seconds, counted_seconds, cap_seconds, capped, eligible}.
static func compute(
	last_seen_unix: int,
	now_unix: int,
	rate_multiplier: float = 1.0,
	offline_cap_minutes: float = 0.0
) -> Dictionary:
	var cap := cap_seconds(offline_cap_minutes)
	var away := maxi(now_unix - last_seen_unix, 0)
	var counted := mini(away, cap)
	var eligible := last_seen_unix > 0 and counted >= MIN_AWAY_SECONDS
	var coins := 0
	if eligible:
		var rate := maxf(BASE_COINS_PER_SECOND * maxf(rate_multiplier, 0.0), 0.0)
		coins = int(floor(float(counted) * rate))
	return {
		"coins": coins,
		"away_seconds": away,
		"counted_seconds": counted,
		"cap_seconds": cap,
		"capped": away > cap,
		"eligible": eligible,
	}
