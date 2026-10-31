## Spawner — turns one WaveDefinition's groups into timed spawn requests.
##
## Groups run sequentially; each group waits for its own start_delay and then
## emits one spawn per interval. The Spawner owns no scene nodes: BattleController
## instantiates enemies and tells WaveManager when they are alive/gone. Boss groups
## carry their own HP multiplier (x1.6 of the wave-scaled HP).
class_name Spawner
extends Node

signal spawn_requested(
	enemy_id: StringName,
	lane: StringName,
	hp_multiplier: float,
	speed_multiplier: float,
	cash_multiplier: float,
	group_hp_multiplier: float
)

var _wave: WaveDefinition
var _groups: Array[SpawnGroup] = []
var _index: int = 0
var _group_timer: float = 0.0
var _group_started: bool = false
var _spawned_in_group: int = 0
var _active: bool = false
var _prefer_north: bool = true


## Starts spawning `wave`. Any previous wave is replaced.
func start_wave(wave: WaveDefinition) -> void:
	_wave = wave
	_groups = wave.groups
	_index = 0
	_group_timer = 0.0
	_group_started = false
	_spawned_in_group = 0
	_active = true


## Stops all pending spawns (run ended or tree defeated).
func stop() -> void:
	_active = false


## Returns true once every authored group has emitted all of its enemies.
func is_finished() -> bool:
	return _index >= _groups.size()


## Advances the spawn schedule by one already-simulated delta.
func tick(delta: float) -> void:
	if not _active or _index >= _groups.size():
		return
	var group := _groups[_index]
	_group_timer += delta
	if not _group_started:
		if _group_timer < group.start_delay:
			return
		_group_timer -= group.start_delay
		_group_started = true
		_spawn(group)
		_spawned_in_group = 1
		if _spawned_in_group >= group.count:
			_next_group()
		return

	var interval := maxf(group.interval, 0.01)
	while _group_timer >= interval and _spawned_in_group < group.count:
		_group_timer -= interval
		_spawn(group)
		_spawned_in_group += 1
	if _spawned_in_group >= group.count:
		_next_group()


func _next_group() -> void:
	_index += 1
	_group_started = false
	_group_timer = 0.0
	_spawned_in_group = 0


func _spawn(group: SpawnGroup) -> void:
	var lane := group.lane
	if lane == &"both":
		lane = &"north" if _prefer_north else &"south"
		_prefer_north = not _prefer_north
	spawn_requested.emit(
		group.enemy_id,
		lane,
		_wave.hp_multiplier,
		_wave.speed_multiplier,
		_wave.cash_multiplier,
		group.hp_multiplier
	)
