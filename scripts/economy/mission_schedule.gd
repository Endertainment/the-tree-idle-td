## MissionSchedule — pure daily/weekly cycle maths for missions (spec 6.6).
##
## Missions reset at 04:00 local (daily) and Monday 04:00 local (weekly). The save
## stores only ids (`2026-10-31`, `2026-W44`) and service code compares them, so all
## calculations here take `now_unix` plus a UTC offset in minutes and are testable
## without touching the clock. Timestamps themselves are always UTC unix seconds.
class_name MissionSchedule
extends RefCounted

const RESET_HOUR := 4
const SECONDS_PER_DAY := 86400
const SECONDS_PER_WEEK := 604800


## Current UTC offset in minutes, straight from the OS.
static func system_offset_minutes() -> int:
	var zone: Dictionary = Time.get_time_zone_from_system()
	return int(zone.get("bias", 0))


## Wall-clock timestamp for `now_unix` in the given UTC offset (synthetic local).
static func local_unix(now_unix: int, offset_minutes: int) -> int:
	return now_unix + offset_minutes * 60


## Mission-day key ("2026-10-31") for a local wall clock. The day starts at 04:00.
static func day_id(now_unix: int, offset_minutes: int) -> String:
	return _date_key(_shifted(now_unix, offset_minutes))


## ISO week key ("2026-W44") for a local wall clock. The week starts Monday 04:00.
static func week_id(now_unix: int, offset_minutes: int) -> String:
	var shifted := _shifted(now_unix, offset_minutes)
	var date := Time.get_datetime_dict_from_unix_time(shifted)
	var weekday := int(date.get("weekday", 1))
	var iso_weekday := 7 if weekday == 0 else weekday
	var midnight := _midnight(shifted)
	var thursday := midnight + (4 - iso_weekday) * SECONDS_PER_DAY
	var thursday_date := Time.get_datetime_dict_from_unix_time(thursday)
	var year := int(thursday_date.get("year", 1970))
	var jan1 := _unix_from_date(year, 1, 1)
	var ordinal := int(floor(float(thursday - jan1) / float(SECONDS_PER_DAY))) + 1
	var week := int(floor(float(ordinal - 1) / 7.0)) + 1
	return "%04d-W%02d" % [year, week]


## Seconds until the next daily 04:00 reset.
static func seconds_until_daily_reset(now_unix: int, offset_minutes: int) -> int:
	var local := local_unix(now_unix, offset_minutes)
	var seconds_today := _positive_modulo(local, SECONDS_PER_DAY)
	var reset_seconds := RESET_HOUR * 3600
	if seconds_today < reset_seconds:
		return reset_seconds - seconds_today
	return SECONDS_PER_DAY - seconds_today + reset_seconds


## Seconds until the next Monday 04:00 reset.
static func seconds_until_weekly_reset(now_unix: int, offset_minutes: int) -> int:
	var local := local_unix(now_unix, offset_minutes)
	var shifted := _shifted(now_unix, offset_minutes)
	var date := Time.get_datetime_dict_from_unix_time(shifted)
	var weekday := int(date.get("weekday", 1))
	var iso_weekday := 7 if weekday == 0 else weekday
	var midnight := _midnight(shifted)
	var week_start := midnight - (iso_weekday - 1) * SECONDS_PER_DAY
	var next_boundary := week_start + SECONDS_PER_WEEK + RESET_HOUR * 3600
	return maxi(next_boundary - local, 0)


## Monotonic day number, used to rotate the daily template pool.
static func day_index(now_unix: int, offset_minutes: int) -> int:
	return int(floor(float(_shifted(now_unix, offset_minutes)) / float(SECONDS_PER_DAY)))


## Monotonic week number, used to rotate the weekly template pool.
static func week_index(now_unix: int, offset_minutes: int) -> int:
	return int(floor(float(_week_start(now_unix, offset_minutes)) / float(SECONDS_PER_WEEK)))


static func _week_start(now_unix: int, offset_minutes: int) -> int:
	var shifted := _shifted(now_unix, offset_minutes)
	var date := Time.get_datetime_dict_from_unix_time(shifted)
	var weekday := int(date.get("weekday", 1))
	var iso_weekday := 7 if weekday == 0 else weekday
	return _midnight(shifted) - (iso_weekday - 1) * SECONDS_PER_DAY


static func _shifted(now_unix: int, offset_minutes: int) -> int:
	return local_unix(now_unix, offset_minutes) - RESET_HOUR * 3600


static func _midnight(unix: int) -> int:
	var date := Time.get_datetime_dict_from_unix_time(unix)
	return unix - (int(date.get("hour", 0)) * 3600 + int(date.get("minute", 0)) * 60 + int(date.get("second", 0)))


static func _unix_from_date(year: int, month: int, day: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({
		"year": year, "month": month, "day": day,
		"hour": 0, "minute": 0, "second": 0,
	}))


static func _date_key(unix: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1)),
	]


static func _positive_modulo(value: int, divisor: int) -> int:
	return ((value % divisor) + divisor) % divisor
