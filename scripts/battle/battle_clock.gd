## BattleClock — the only owner of simulation speed for one battle.
##
## Systems multiply their delta by scaled(). Speed never touches Engine.time_scale,
## so UI tweens and audio pitch stay at real time (spec 4.11). Pausing the clock
## freezes the simulation while modal sheets are open (spec 13.4 decision).
class_name BattleClock
extends Node

const MAX_SPEED := 8.0

var sim_speed: float = 1.0
var paused: bool = false


## Changes the simulation speed. Values are clamped to [0, MAX_SPEED].
func set_speed(value: float) -> void:
	sim_speed = clampf(value, 0.0, MAX_SPEED)


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
