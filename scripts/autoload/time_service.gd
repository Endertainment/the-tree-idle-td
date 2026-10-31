## TimeService — wall-clock and monotonic time helpers (autoload).
extends Node

## Tests/tools set this to a non-negative unix second to freeze wall-clock time.
## Magica research, missions and offline income all read now_unix(), so a simulated
## restart can be verified headlessly without touching the OS clock.
var override_unix: int = -1


## Seconds since the Unix epoch, as an int.
func now_unix() -> int:
	if override_unix >= 0:
		return override_unix
	return int(Time.get_unix_time_from_system())


## Freezes wall-clock time for tests (`value < 0` restores the real clock).
func set_now_override(value: int) -> void:
	override_unix = value


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
