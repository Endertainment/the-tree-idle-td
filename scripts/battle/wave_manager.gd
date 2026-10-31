## WaveManager — pacing state machine: prep break -> wave -> prep -> ... -> done.
##
## Owns no enemies. It tells the Spawner when to start, counts alive enemies via
## on_enemy_spawned()/on_enemy_removed(), and declares a wave cleared only when
## the queue is empty AND every spawned enemy is dead or leaked.
class_name WaveManager
extends Node

signal wave_started(wave: int)
signal wave_cleared(wave: int)
signal prep_started(next_wave: int, duration: float)
signal prep_skipped(bonus: int)
signal countdown_changed(seconds_left: int)
signal table_finished

enum State { IDLE, PREP, WAVE, FINISHED }

var _table: WaveTable
var _spawner: Spawner
var _state: State = State.IDLE
var _prep_left: float = 0.0
var _next_wave: int = 1
var _current_wave: int = 0
var _alive: int = 0
var _countdown_value: int = -1


func setup(table: WaveTable, spawner: Spawner) -> void:
	_table = table
	_spawner = spawner


## Begins the run with the table's opening prep break before wave 1.
func start() -> void:
	_next_wave = 1
	_alive = 0
	_begin_prep()


## Advances timers and spawns. `delta` must already include battle sim speed.
func tick(delta: float) -> void:
	if _state == State.PREP:
		_prep_left = maxf(_prep_left - delta, 0.0)
		_emit_countdown()
		if _prep_left <= 0.0:
			_begin_wave()
	elif _state == State.WAVE:
		_spawner.tick(delta)
		if _spawner.is_finished() and _alive <= 0:
			_complete_wave()


## Skips the prep break and starts the next wave immediately.
## Returns the granted cash bonus, or -1 when no prep is running.
func skip_prep() -> int:
	if _state != State.PREP:
		return -1
	var bonus := _table.skip_bonus(_next_wave)
	prep_skipped.emit(bonus)
	_begin_wave()
	return bonus


func stop() -> void:
	_state = State.FINISHED
	_spawner.stop()


func on_enemy_spawned() -> void:
	if _state == State.WAVE:
		_alive += 1


func on_enemy_removed() -> void:
	_alive = maxi(_alive - 1, 0)


func get_state() -> State:
	return _state


func get_current_wave() -> int:
	return _current_wave


func get_next_wave() -> int:
	return _next_wave


func get_prep_left() -> float:
	return _prep_left


func _begin_prep() -> void:
	if _next_wave > _table.wave_count():
		_state = State.FINISHED
		table_finished.emit()
		return
	_state = State.PREP
	_prep_left = _table.prep_time
	_countdown_value = -1
	prep_started.emit(_next_wave, _prep_left)
	_emit_countdown()


func _begin_wave() -> void:
	var wave := _table.get_wave(_next_wave)
	if wave == null:
		_state = State.FINISHED
		table_finished.emit()
		return
	_current_wave = _next_wave
	_alive = 0
	_state = State.WAVE
	_spawner.start_wave(wave)
	wave_started.emit(_current_wave)


func _complete_wave() -> void:
	_state = State.PREP
	var cleared := _current_wave
	wave_cleared.emit(cleared)
	_next_wave = cleared + 1
	if _next_wave > _table.wave_count():
		_state = State.FINISHED
		table_finished.emit()
		return
	_prep_left = _table.prep_time
	_countdown_value = -1
	prep_started.emit(_next_wave, _prep_left)
	_emit_countdown()


func _emit_countdown() -> void:
	if _state != State.PREP:
		return
	var seconds := int(ceil(_prep_left))
	if seconds == _countdown_value:
		return
	_countdown_value = seconds
	countdown_changed.emit(seconds)
