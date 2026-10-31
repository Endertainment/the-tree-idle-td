## TimeService — wall-clock and monotonic time helpers (autoload).
extends Node


## Seconds since the Unix epoch, as an int.
func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


## Milliseconds since engine start (monotonic, for timers/benchmarks).
func now_msec() -> int:
	return Time.get_ticks_msec()


## Formats a duration as MM:SS, or H:MM:SS once it reaches an hour.
func format_clock(seconds: int) -> String:
	var total := maxi(seconds, 0)
	var hours := int(total / 3600.0)
	var minutes := int((total % 3600) / 60.0)
	var secs := total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]
