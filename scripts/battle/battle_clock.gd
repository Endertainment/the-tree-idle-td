## BattleClock — the only owner of simulation speed for one battle.
##
## Systems multiply their delta by scaled(). Speed never touches Engine.time_scale,
## so UI tweens and audio pitch stay at real time (spec 4.11). Pausing the clock
## freezes the simulation while modal sheets are open (spec 13.4 decision).
class_name BattleClock
extends Node

## Segmented HUD speeds (spec 4.11); tools may use up to MAX_SPEED for fast sims.
const SPEEDS: Array[float] = [1.0, 1.5, 2.0]
const MAX_SPEED := 8.0

var sim_speed: float = 1.0
var paused: bool = false


## Changes the simulation speed. Values are clamped to [0, MAX_SPEED].
func set_speed(value: float) -> void:
	sim_speed = clampf(value, 0.0, MAX_SPEED)


## Selects one of the segmented HUD speeds by index (0 = 1x, 1 = 1.5x, 2 = 2x).
func set_speed_index(index: int) -> void:
	var safe_index := clampi(index, 0, SPEEDS.size() - 1)
	sim_speed = SPEEDS[safe_index]


## Index of the current speed in SPEEDS (nearest when a tool set a custom speed).
func get_speed_index() -> int:
	var best_index := 0
	var best_delta := INF
	for index in SPEEDS.size():
		var delta := absf(SPEEDS[index] - sim_speed)
		if delta < best_delta:
			best_delta = delta
			best_index = index
	return best_index


func get_speed() -> float:
	return sim_speed


## Freezes or resumes the battle simulation.
func set_paused(value: bool) -> void:
	paused = value


func is_paused() -> bool:
	return paused


## Returns the delta a battle system should use this tick.
func scaled(delta: float) -> float:
	if paused:
		return 0.0
	return delta * sim_speed
