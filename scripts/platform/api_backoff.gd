## ApiBackoff — retry schedule for ApiClient: 1, 2, 4, 8, 16 s (+ jitter).
##
## A 4xx is never retried; only transport failures and 5xx reach this schedule.
class_name ApiBackoff
extends RefCounted

const BASE_DELAY_MSEC := 1000
const MAX_DELAY_MSEC := 16000
const MAX_ATTEMPTS := 5
const JITTER_RATIO := 0.15


## Deterministic delay for a zero-based retry index, clamped at 16 s.
static func delay_msec(attempt: int, jitter: float = 0.0) -> int:
	var index := clampi(attempt, 0, 4)
	var delay := mini(BASE_DELAY_MSEC * int(pow(2.0, float(index))), MAX_DELAY_MSEC)
	if jitter <= 0.0:
		return delay
	return int(round(float(delay) * (1.0 + clampf(jitter, 0.0, 0.5))))


## Delay with a fresh ±15 % jitter, used by ApiClient between attempts.
static func jittered_delay_msec(attempt: int) -> int:
	var base := delay_msec(attempt)
	var spread := float(base) * JITTER_RATIO
	return int(round(base + randf_range(-spread, spread)))
