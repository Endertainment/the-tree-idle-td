## SaveSyncMerge — pure revision policy and three-way merge for cloud saves.
##
## Policy (documented in docs/DECISIONS.md, ADR-034):
## - same revision: push local changes, or no-op when clean;
## - server revision newer and local clean: pull the server copy;
## - server revision newer and local dirty: three-way merge with the last
##   synced payload as the base. True conflicts resolve to the server value;
##   local-only changes are kept and pushed as a patch on top of the server
##   revision. Nothing is silently discarded.
## - server revision older: server is authoritative, pull it.
class_name SaveSyncMerge
extends RefCounted

const DECISION_NOOP := &"noop"
const DECISION_PUSH := &"push"
const DECISION_PULL := &"pull"
const DECISION_MERGE := &"merge"


## What the sync engine should do given the local dirty flag and revisions.
static func decide(local_dirty: bool, local_revision: int, server_revision: int) -> StringName:
	if server_revision < local_revision:
		return DECISION_PULL
	if server_revision > local_revision:
		return DECISION_MERGE if local_dirty else DECISION_PULL
	return DECISION_PUSH if local_dirty else DECISION_NOOP


## Merges `local` and `server` using `base` (last synced payload) as the origin.
## Returns {payload, conflicts: Array[String], local_changes: Array[String]}.
static func three_way_merge(base: Dictionary, local: Dictionary, server: Dictionary) -> Dictionary:
	var conflicts: Array[String] = []
	var local_changes: Array[String] = []
	var merged: Variant = _merge_value(base, local, server, "", conflicts, local_changes)
	var payload: Dictionary = merged if merged is Dictionary else server.duplicate(true)
	return {"payload": payload, "conflicts": conflicts, "local_changes": local_changes}


## Structural equality for JSON-like values (dictionaries/arrays scalars).
static func deep_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		var left: Dictionary = a
		var right: Dictionary = b
		if left.size() != right.size():
			return false
		for key: Variant in left.keys():
			if not right.has(key):
				return false
			if not deep_equal(left[key], right[key]):
				return false
		return true
	if a is Array and b is Array:
		var left_array: Array = a
		var right_array: Array = b
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not deep_equal(left_array[index], right_array[index]):
				return false
		return true
	return a == b


static func _merge_value(
	base: Variant,
	local: Variant,
	server: Variant,
	path: String,
	conflicts: Array[String],
	local_changes: Array[String]
) -> Variant:
	if deep_equal(local, base):
		return _copy(server)
	if deep_equal(server, base):
		if not path.is_empty():
			local_changes.append(path)
		return _copy(local)
	if deep_equal(local, server):
		return _copy(local)
	if base is Dictionary and local is Dictionary and server is Dictionary:
		var result: Dictionary = {}
		var keys: Dictionary = {}
		for key: Variant in (base as Dictionary).keys():
			keys[key] = true
		for key: Variant in (local as Dictionary).keys():
			keys[key] = true
		for key: Variant in (server as Dictionary).keys():
			keys[key] = true
		for key: Variant in keys.keys():
			var child_path := str(key) if path.is_empty() else "%s.%s" % [path, str(key)]
			var value: Variant = _merge_value(
				(base as Dictionary).get(key),
				(local as Dictionary).get(key),
				(server as Dictionary).get(key),
				child_path,
				conflicts,
				local_changes
			)
			if (local as Dictionary).has(key) or (server as Dictionary).has(key):
				result[key] = value
		return result
	if not path.is_empty():
		conflicts.append(path)
	return _copy(server)


static func _copy(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in (value as Dictionary).keys():
			result[key] = _copy((value as Dictionary)[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value as Array:
			result.append(_copy(entry))
		return result
	return value
