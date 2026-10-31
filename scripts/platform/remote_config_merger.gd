## RemoteConfigMerger — pure merge + TTL rules for the remote config cache.
class_name RemoteConfigMerger
extends RefCounted

const DEFAULT_TTL_SECONDS := 3600


## Recursively merges `remote` over `defaults`; dictionaries merge, lists replace.
static func merge(defaults: Dictionary, remote: Dictionary) -> Dictionary:
	var result: Dictionary = defaults.duplicate(true)
	for key: Variant in remote.keys():
		var value: Variant = remote[key]
		if value is Dictionary and result.get(key, null) is Dictionary:
			result[key] = merge(result[key], value)
		else:
			result[key] = _copy(value)
	return result


## True when the cached fetch is younger than the TTL (1 h by default).
static func is_fresh(fetched_at: int, now_unix: int, ttl_seconds: int = DEFAULT_TTL_SECONDS) -> bool:
	if fetched_at <= 0:
		return false
	return now_unix - fetched_at < maxi(ttl_seconds, 0)


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
