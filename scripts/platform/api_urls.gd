## ApiUrls — pure URL building shared by ApiClient and its tests.
class_name ApiUrls
extends RefCounted


## Joins a base URL and an API path with exactly one slash between them.
static func join(base: String, path: String) -> String:
	var clean_base := base.strip_edges().trim_suffix("/")
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return clean_base
	if not clean_path.begins_with("/"):
		clean_path = "/" + clean_path
	return clean_base + clean_path


## Appends a query string, skipping null/empty values. Values are URI-encoded.
static func with_query(url: String, query: Dictionary) -> String:
	if query.is_empty():
		return url
	var parts: PackedStringArray = []
	for key: Variant in query.keys():
		var value: Variant = query[key]
		if value == null:
			continue
		if value is String and (value as String).is_empty():
			continue
		parts.append("%s=%s" % [str(key).uri_encode(), str(value).uri_encode()])
	if parts.is_empty():
		return url
	return url + "?" + "&".join(parts)


## Full URL for a request: base + path + optional query.
static func build(base: String, path: String, query: Dictionary = {}) -> String:
	return with_query(join(base, path), query)
