## AdCaps — pure placement cap/period accounting shared by AdsService and tests.
##
## The service owns persistence (GameState.ads); this class only answers "may this
## placement show now?" and records a shown ad. Keeping it free of autoloads makes
## the per-run/per-day caps and the interstitial cadence unit-testable headlessly.
class_name AdCaps
extends RefCounted

const REASON_UNKNOWN := &"unknown_placement"
const REASON_BANNER := &"banner_not_supported"
const REASON_CAP := &"cap_reached"

var definitions: Dictionary = {}
var run_counts: Dictionary = {}
var daily_counts: Dictionary = {}
var day: String = ""


## Copies the placement definitions from MonetizationConfig.placements.
func configure(placements: Dictionary) -> void:
	definitions = placements.duplicate(true)


## Clears per-run counters. Called by AdsService.start_run().
func reset_run() -> void:
	run_counts.clear()


## Rolls the daily counters when the local date changes.
func ensure_day(today: String) -> void:
	if today == day:
		return
	day = today
	daily_counts.clear()


## Number of times `placement` was already shown in the current period.
func used(placement: StringName) -> int:
	var definition: Dictionary = definitions.get(String(placement), {})
	if str(definition.get("period", "run")) == "day":
		return int(daily_counts.get(String(placement), 0))
	return int(run_counts.get(String(placement), 0))


## Configured cap for the placement (0 = not capped, e.g. banner).
func limit(placement: StringName) -> int:
	var definition: Dictionary = definitions.get(String(placement), {})
	return int(definition.get("cap", 0))


## Returns {available, reason, used, limit, remaining} for a placement.
func can_show(placement: StringName, today: String = "") -> Dictionary:
	if not definitions.has(String(placement)):
		return _result(false, REASON_UNKNOWN, 0, 0)
	var definition: Dictionary = definitions.get(String(placement), {})
	if str(definition.get("type", "")) == "banner":
		return _result(false, REASON_BANNER, 0, 0)
	if not today.is_empty():
		ensure_day(today)
	var cap := limit(placement)
	var shown := used(placement)
	if cap > 0 and shown >= cap:
		return _result(false, REASON_CAP, shown, cap)
	var remaining := -1 if cap <= 0 else maxi(cap - shown, 0)
	return _result(true, &"", shown, cap, remaining)


## Records one shown ad for the placement (after it was actually shown/rewarded).
func record(placement: StringName, today: String = "") -> void:
	if not today.is_empty():
		ensure_day(today)
	var definition: Dictionary = definitions.get(String(placement), {})
	if str(definition.get("period", "run")) == "day":
		daily_counts[String(placement)] = int(daily_counts.get(String(placement), 0)) + 1
	else:
		run_counts[String(placement)] = int(run_counts.get(String(placement), 0)) + 1


## Interstitial rule from spec 7.2: every Nth run, min interval, never before wave 5.
## `runs_played` is the lifetime run count after the finished run.
func can_show_interstitial(
	now_unix: int,
	runs_played: int,
	wave: int,
	last_shown_unix: int,
	every_runs: int,
	min_interval_seconds: int,
	min_wave: int
) -> Dictionary:
	if wave < min_wave:
		return _result(false, &"before_min_wave", 0, 0)
	if every_runs > 0 and runs_played % every_runs != 0:
		return _result(false, &"run_cadence", 0, 0)
	if last_shown_unix > 0 and now_unix - last_shown_unix < min_interval_seconds:
		return _result(false, &"min_interval", 0, 0)
	return _result(true, &"", 0, 0)


## Serializes counters into the save's `ads` section.
func to_dict() -> Dictionary:
	return {
		"day": day,
		"daily": daily_counts.duplicate(true),
		"run": run_counts.duplicate(true),
	}


## Restores counters from the save's `ads` section.
func from_dict(data: Dictionary) -> void:
	day = str(data.get("day", ""))
	var daily: Variant = data.get("daily", {})
	daily_counts = (daily as Dictionary).duplicate(true) if daily is Dictionary else {}
	var run: Variant = data.get("run", {})
	run_counts = (run as Dictionary).duplicate(true) if run is Dictionary else {}


func _result(available: bool, reason: StringName, used_count: int, limit_count: int, remaining: int = -1) -> Dictionary:
	return {
		"available": available,
		"reason": reason,
		"used": used_count,
		"limit": limit_count,
		"remaining": remaining,
	}
