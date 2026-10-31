## LevelProgression — the player-level unlock table (spec 6.2), authored as data.
##
## `unlock_levels` maps a player level to the feature ids it unlocks. The UI and
## gameplay only ask UnlockService.is_unlocked(id), never compare levels directly.
class_name LevelProgression
extends Resource

@export var max_level: int = 20
## {level: [unlock_id, ...]}; levels without unlocks are omitted.
@export var unlock_levels: Dictionary = {}


## Feature ids unlocked exactly at `level` (empty when none).
func unlocks_at(level: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var values: Variant = unlock_levels.get(level, unlock_levels.get(str(level), null))
	if values is Array:
		for value: Variant in values as Array:
			result.append(StringName(str(value)))
	elif values is PackedStringArray:
		for value: String in (values as PackedStringArray):
			result.append(StringName(value))
	return result


## Lowest player level that unlocks `unlock_id`, or 0 when the id is unknown.
func level_for(unlock_id: StringName) -> int:
	var wanted := String(unlock_id)
	for key: Variant in unlock_levels.keys():
		var level := int(key)
		for value: Variant in unlock_levels[key]:
			if str(value) == wanted:
				return level
	return 0


## Every feature id in the table.
func all_unlock_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for level: int in range(1, max_level + 1):
		for unlock_id: StringName in unlocks_at(level):
			if not result.has(unlock_id):
				result.append(unlock_id)
	return result
