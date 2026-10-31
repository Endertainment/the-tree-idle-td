## ModifierService — aggregates stat modifiers from all meta sources (autoload).
##
## Sources are registered by id (card, workshop node, research, run upgrade).
## A source is a dictionary of stat -> number or stat -> {"add": float,
## "mul": float}. Final value = (base + sum(add)) * product(1 + mul). Removing a
## source is idempotent, and an empty registry returns the base value untouched.
extends Node

var _sources: Dictionary = {}


## Registers (or replaces) the modifier set for `source_id`.
func add_source(source_id: StringName, modifiers: Dictionary) -> void:
	_sources[source_id] = modifiers.duplicate(true)


## Removes a source. Unknown ids are ignored.
func remove_source(source_id: StringName) -> void:
	_sources.erase(source_id)


## Removes every source.
func clear() -> void:
	_sources.clear()


## Returns true when a source with this id is registered.
func has_source(source_id: StringName) -> bool:
	return _sources.has(source_id)


## Returns the number of registered sources.
func get_source_count() -> int:
	return _sources.size()


## Returns the final value of `stat_name` for `base_value`.
func get_stat(stat_name: StringName, base_value: float) -> float:
	if _sources.is_empty():
		return base_value

	var additive := 0.0
	var multiplier := 1.0
	for source_value: Variant in _sources.values():
		if not (source_value is Dictionary):
			continue
		var source := source_value as Dictionary
		if not source.has(stat_name):
			continue
		var entry: Variant = source[stat_name]
		if entry is Dictionary:
			var parts := entry as Dictionary
			additive += float(parts.get("add", 0.0))
			multiplier *= 1.0 + float(parts.get("mul", 0.0))
		else:
			additive += float(entry)

	return (base_value + additive) * multiplier


## Same as get_stat(), clamped at the read site (crit chance, reductions...).
func get_stat_clamped(stat_name: StringName, base_value: float, minimum: float, maximum: float) -> float:
	return clampf(get_stat(stat_name, base_value), minimum, maximum)


## Removes every source whose id starts with `prefix` (run-scoped sources).
func remove_sources_with_prefix(prefix: StringName) -> void:
	var wanted := String(prefix)
	for source_id: Variant in _sources.keys():
		if String(source_id).begins_with(wanted):
			_sources.erase(source_id)


## Returns the registered source ids (debug/tests).
func get_source_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for source_id: Variant in _sources.keys():
		ids.append(StringName(str(source_id)))
	return ids
