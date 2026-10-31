## LeaderboardBackend — maps the server JSON into the row shape the UI expects.
##
## This is the one seam between the live API and the screen: the UI keeps using
## `best_wave`/`playtime`/`submitted_at`, while the server speaks
## `max_wave`/`playtime_s`/ISO timestamps. LocalBackendStub speaks the same row
## shape, so an offline fallback is invisible to the screen.
class_name LeaderboardBackend
extends RefCounted


static func parse_entries(raw: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if raw is Array:
		for item: Variant in raw as Array:
			if item is Dictionary:
				entries.append(parse_entry(item as Dictionary))
	return entries


static func parse_entry(raw: Dictionary) -> Dictionary:
	var player_id := str(raw.get("player_id", raw.get("id", "")))
	var wave := int(raw.get("max_wave", raw.get("best_wave", 0)))
	var playtime := int(raw.get("playtime_s", raw.get("playtime", 0)))
	return {
		"id": player_id,
		"player_id": player_id,
		"nickname": str(raw.get("nickname", "")),
		"avatar_id": str(raw.get("avatar_id", "avatar_01")),
		"best_wave": wave,
		"max_wave": wave,
		"playtime": playtime,
		"playtime_s": playtime,
		"submitted_at": to_unix(raw.get("submitted_at", "")),
		"rank": int(raw.get("rank", 0)),
		"is_player": bool(raw.get("is_player", false)),
	}


## ISO-8601 UTC string (server) or unix seconds (stub) -> unix seconds.
static func to_unix(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	var text := str(value).strip_edges()
	if text.length() < 19:
		return 0
	# Godot parses "YYYY-MM-DDTHH:MM:SS" as UTC; the server always emits UTC.
	return int(Time.get_unix_time_from_datetime_string(text.substr(0, 19)))
