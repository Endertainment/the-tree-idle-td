## StatusEffectComponent — timed status effects on one enemy (slow only in M2).
##
## Stack rule (spec 4.7 / M2 brief): a new slow refreshes the timer and keeps the
## strongest percentage; slow percentages never multiply. This component is the
## only place that owns slow state, so movement stays a one-line multiplier.
class_name StatusEffectComponent
extends Node

signal changed(speed_multiplier: float)

var _slow_pct: float = 0.0
var _time_left: float = 0.0


## Clears every status (enemy spawn / pool reuse).
func reset() -> void:
	_slow_pct = 0.0
	_time_left = 0.0


## Applies (or refreshes) a slow. `pct` is the fraction of speed removed.
func apply_slow(pct: float, duration: float) -> void:
	var clamped := clampf(pct, 0.0, 0.9)
	if clamped <= 0.0 or duration <= 0.0:
		return
	# Refresh, never stack: keep the strongest slow, restart the timer.
	_slow_pct = maxf(_slow_pct, clamped)
	_time_left = maxf(_time_left, duration)
	changed.emit(speed_multiplier())


## Advances timers. `delta` must already include battle sim speed.
func tick(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left <= 0.0:
		_slow_pct = 0.0
		changed.emit(1.0)


## Multiplier applied to enemy movement: 1.0 = unslowed, 0.65 = 35 % slow.
func speed_multiplier() -> float:
	return 1.0 - _slow_pct


func slow_pct() -> float:
	return _slow_pct


func time_left() -> float:
	return _time_left


func is_slowed() -> bool:
	return _time_left > 0.0 and _slow_pct > 0.0
