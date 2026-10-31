## ProgressionModel — pure player-level unlock gate (spec 6.2).
##
## Reads a LevelProgression resource and answers "is id unlocked at level N".
## UnlockService wraps this with the live profile level, persistence and toasts;
## keeping the gate pure means level tests need no autoloads.
class_name ProgressionModel
extends RefCounted

var _table: LevelProgression
var _level: int = 1


func _init(table: LevelProgression = null) -> void:
	set_table(table)


func set_table(table: LevelProgression) -> void:
	_table = table


func set_level(level: int) -> void:
	_level = maxi(level, 1)


func get_level() -> int:
	return _level


func is_unlocked(unlock_id: StringName, level: int = -1) -> bool:
	var required := level_for(unlock_id)
	if required <= 0:
		return false
	return (level if level >= 0 else _level) >= required


## Lowest level that unlocks `unlock_id`, or 0 when the id is unknown.
func level_for(unlock_id: StringName) -> int:
	if _table == null:
		return 0
	return _table.level_for(unlock_id)


func unlocks_at(level: int) -> Array[StringName]:
	if _table == null:
		return []
	return _table.unlocks_at(level)


## Ids that become available when the player moves from `old_level` to
## `new_level` (inclusive). Used for unlock toasts and analytics.
func newly_unlocked(old_level: int, new_level: int) -> Array[StringName]:
	var result: Array[StringName] = []
	if new_level <= old_level:
		return result
	for level in range(old_level + 1, new_level + 1):
		for unlock_id: StringName in unlocks_at(level):
			if not result.has(unlock_id):
				result.append(unlock_id)
	return result


func all_unlocked(level: int = -1) -> Array[StringName]:
	var effective := level if level >= 0 else _level
	var result: Array[StringName] = []
	for candidate in range(1, effective + 1):
		for unlock_id: StringName in unlocks_at(candidate):
			if not result.has(unlock_id):
				result.append(unlock_id)
	return result
