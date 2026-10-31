## SaveService — versioned, atomic, checksummed persistence for meta progress.
##
## Schema v2 is the full document from spec 8.2 (player/wallet/stats/workshop/
## magica/cards/missions/unlocks/settings/shop/ads) plus two local extras
## (`is_onboarded`, `applied_rewards`) needed by the launch build. Writes go to a
## temp file, are size-checked, the previous file becomes `.bak`, then a rename
## replaces the main file. Loading falls back to `.bak` when the main file is
## unparseable or the checksum does not match.
##
## Autosave is event-driven (run start/end, wave cleared, meta purchase, scene
## change) with a <=1/s debounce, plus an immediate flush on app pause and close.
## GameState owns the document shape; SaveService only adds metadata/checksum.
extends Node

const SCHEMA_VERSION := 2
const DEFAULT_SAVE_PATH := "user://save_v1.json"
const DEFAULT_BACKUP_PATH := "user://save_v1.bak.json"
const DEFAULT_TEMP_PATH := "user://save_v1.tmp.json"
const MIN_SAVE_INTERVAL_MSEC := 1000

## Overridable so tests can use isolated files without touching a real save.
var save_path: String = DEFAULT_SAVE_PATH
var backup_path: String = DEFAULT_BACKUP_PATH
var temp_path: String = DEFAULT_TEMP_PATH

## Set by App after GameState exists; returns the full save document.
var save_provider: Callable = Callable()
## True when load() had to recover the previous write from the `.bak` file.
var recovered_from_backup: bool = false
## Schema version found on disk before migration (0 when no save exists).
var migrated_from_version: int = 0

var _dirty: bool = false
var _last_save_msec: int = 0
var _migration_logged: bool = false


func _ready() -> void:
	set_process(true)
	_bind_autosave_events()


## Connects through the runtime node so this script still compiles in headless
## unit-test mode, where autoload globals are not registered yet.
func _bind_autosave_events() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus == null:
		return
	bus.connect(&"run_started", Callable(self, "_on_run_started"))
	bus.connect(&"run_ended", Callable(self, "_on_run_ended"))
	bus.connect(&"wave_cleared", Callable(self, "_on_wave_cleared"))
	bus.connect(&"meta_purchased", Callable(self, "_on_meta_purchased"))
	bus.connect(&"scene_changed", Callable(self, "_on_scene_changed"))


## Registers the callable that builds the full save document.
func set_save_provider(provider: Callable) -> void:
	save_provider = provider


## Queues a save; _process flushes it at most once per second.
func request_save() -> void:
	_dirty = true


## Flushes immediately when a provider is registered (pause/close/run end paths).
func flush() -> bool:
	if not save_provider.is_valid():
		_dirty = false
		return false
	var document: Variant = save_provider.call()
	_dirty = false
	if not (document is Dictionary):
		push_error("SaveService: save provider did not return a Dictionary")
		return false
	return save(document as Dictionary)


## Serialises `data` and writes it atomically. Returns true on success.
func save(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	payload["checksum"] = _checksum(payload)

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot open temp file '%s' (error %d)" % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()

	if not FileAccess.file_exists(temp_path):
		push_error("SaveService: temp file was not created")
		return false
	var written_size := FileAccess.get_file_as_string(temp_path).length()
	if written_size <= 0:
		push_error("SaveService: temp file is empty")
		_remove_file(temp_path)
		return false

	if FileAccess.file_exists(save_path):
		_backup_current()

	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_target := ProjectSettings.globalize_path(save_path)
	var error: Error = DirAccess.rename_absolute(absolute_temp, absolute_target)
	if error != OK:
		# Windows cannot always replace an existing file in one rename; the
		# previous bytes are already safe in the .bak file.
		_remove_file(save_path)
		error = DirAccess.rename_absolute(absolute_temp, absolute_target)
	if error != OK:
		push_error("SaveService: rename failed (error %d)" % error)
		_remove_file(temp_path)
		return false
	_last_save_msec = Time.get_ticks_msec()
	return true


## Reads the main save, falling back to the backup. Returns {} when neither
## file exists or both are unreadable/corrupt. Older schemas are migrated.
func load() -> Dictionary:
	recovered_from_backup = false
	migrated_from_version = 0

	var main_data := _read_dictionary(save_path)
	if not _is_valid(main_data):
		if FileAccess.file_exists(save_path):
			push_warning("SaveService: main save is invalid, trying backup")
		var backup_data := _read_dictionary(backup_path)
		if _is_valid(backup_data):
			recovered_from_backup = true
			push_warning("SaveService: recovered progress from backup")
			main_data = backup_data
		else:
			return {}

	migrated_from_version = int(main_data.get("schema_version", 0))
	var document := migrate(main_data)
	if migrated_from_version < SCHEMA_VERSION and not _migration_logged:
		_migration_logged = true
		print("[SaveService] save_migrated v%d -> v%d" % [migrated_from_version, SCHEMA_VERSION])
	return document


## Returns true when a main save file exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Deletes the main, backup and temp save files. Used by tests and "new game".
func clear() -> void:
	_remove_file(save_path)
	_remove_file(backup_path)
	_remove_file(temp_path)


# --- schema migration (pure functions) -------------------------------------------


## Migrates a loaded document up to SCHEMA_VERSION. Pure: the input is not
## mutated. Unknown versions are returned unchanged so callers can reject them.
static func migrate(data: Dictionary) -> Dictionary:
	var document := data.duplicate(true)
	var version := int(document.get("schema_version", 0))
	if version <= 0 or version > SCHEMA_VERSION:
		return document
	while version < SCHEMA_VERSION:
		match version:
			1:
				document = migrate_v1_to_v2(document)
				version = 2
			_:
				# No path defined from this version; stop instead of guessing.
				push_error("SaveService: no migration path from v%d" % version)
				return document
		document["schema_version"] = version
	return document


## v1 (M3) profile -> the full v2 document. Pure and tested directly.
static func migrate_v1_to_v2(v1: Dictionary) -> Dictionary:
	var old_player: Dictionary = _as_dictionary(v1.get("player", {}))
	var old_wallet: Dictionary = _as_dictionary(v1.get("wallet", {}))
	var old_stats: Dictionary = _as_dictionary(v1.get("stats", {}))
	var old_settings: Dictionary = _as_dictionary(v1.get("settings", {}))

	var best_wave := maxi(
		int(old_player.get("best_wave", 0)),
		int(old_stats.get("best_wave", 0))
	)
	var player := {
		"id": str(old_player.get("id", "")),
		"nickname": str(old_player.get("nickname", "")),
		"avatar_id": str(old_player.get("avatar_id", "avatar_01")),
		"level": maxi(int(old_player.get("level", 1)), 1),
		"xp": maxi(int(old_player.get("xp", 0)), 0),
		"created_at": int(old_player.get("created_at", 0)),
		"provider": str(old_player.get("provider", "")),
		"provider_uid": str(old_player.get("provider_uid", "")),
		# Local extra: TapGuard's first-three-skips counter survives a reload.
		"next_wave_uses": maxi(int(old_player.get("next_wave_uses", 0)), 0),
	}
	var stats := {
		"best_wave": best_wave,
		"runs_played": int(old_stats.get("runs_played", 0)),
		"total_kills": int(old_stats.get("total_kills", 0)),
		"total_playtime": int(old_stats.get("total_playtime", 0)),
		"weekly_max_wave": int(old_stats.get("weekly_max_wave", 0)),
		"week_id": str(old_stats.get("week_id", "")),
	}
	var settings := {
		"music": float(old_settings.get("music", 0.8)),
		"sfx": float(old_settings.get("sfx", 1.0)),
		"ui": float(old_settings.get("ui", 1.0)),
		"haptics": bool(old_settings.get("haptics", true)),
		"language": str(old_settings.get("language", "en")),
		"text_scale": float(old_settings.get("text_scale", 1.0)),
		"shake": bool(old_settings.get("shake", true)),
	}
	var magica: Dictionary = _as_dictionary(v1.get("magica", {}))
	if magica.is_empty():
		magica = {"research": {}, "completed": []}
	var cards: Dictionary = _as_dictionary(v1.get("cards", {}))
	if cards.is_empty():
		cards = {"owned": [], "equipped": [null, null, null, null]}
	var missions: Dictionary = _as_dictionary(v1.get("missions", {}))
	if missions.is_empty():
		missions = {"day_id": "", "daily": [], "week_id": "", "weekly": []}
	var shop: Dictionary = _as_dictionary(v1.get("shop", {}))
	if shop.is_empty():
		shop = {"owned_products": [], "last_daily_claim": 0}
	var ads: Dictionary = _as_dictionary(v1.get("ads", {}))
	if ads.is_empty():
		ads = {"rv_today": 0, "rv_day": "", "interstitial_last": 0}

	return {
		"schema_version": 2,
		"player": player,
		"wallet": {
			"coins": maxi(int(old_wallet.get("coins", 0)), 0),
			"gems": maxi(int(old_wallet.get("gems", 0)), 0),
			"stones": maxi(int(old_wallet.get("stones", 0)), 0),
		},
		"stats": stats,
		"workshop": _as_dictionary(v1.get("workshop", {})),
		"magica": magica,
		"cards": cards,
		"missions": missions,
		"unlocks": _unlock_array(v1.get("unlocks", null)),
		"settings": settings,
		"shop": shop,
		"ads": ads,
		"is_onboarded": bool(v1.get("is_onboarded", false)),
		"applied_rewards": _as_array(v1.get("applied_rewards", [])),
	}


static func _unlock_array(value: Variant) -> Array:
	var result: Array = []
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			if bool((value as Dictionary)[key]):
				result.append(str(key))
	elif value is Array:
		for entry: Variant in value as Array:
			result.append(str(entry))
	result.sort()
	return result


static func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _as_array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


# --- loading internals -----------------------------------------------------------


func _process(_delta: float) -> void:
	if not _dirty:
		return
	if Time.get_ticks_msec() - _last_save_msec < MIN_SAVE_INTERVAL_MSEC:
		return
	flush()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			flush()


func _on_run_started() -> void:
	request_save()


func _on_run_ended(_waves: int) -> void:
	request_save()


func _on_wave_cleared(_wave: int) -> void:
	request_save()


func _on_meta_purchased(_kind: StringName, _amount: int, _reason: StringName) -> void:
	request_save()


func _on_scene_changed(_scene_id: StringName) -> void:
	request_save()


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _is_valid(data: Dictionary) -> bool:
	if data.is_empty() or not data.has("schema_version"):
		return false
	var version := int(data.get("schema_version", 0))
	if version <= 0 or version > SCHEMA_VERSION:
		push_warning("SaveService: unsupported schema version %d" % version)
		return false
	if data.has("checksum"):
		return str(data.get("checksum", "")) == _checksum(data)
	# v1 (M3) saves were written without a checksum; accept them for migration.
	return version < SCHEMA_VERSION


## Canonical SHA-256 of the document without its checksum field. Numbers parsed
## from JSON are floats, so whole floats are normalised to ints before hashing.
func _checksum(data: Dictionary) -> String:
	var copy := data.duplicate(true)
	copy.erase("checksum")
	return "sha256:" + JSON.stringify(_canonical(copy)).sha256_text()


static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		var result: Dictionary = {}
		for key: Variant in dictionary.keys():
			result[key] = _canonical(dictionary[key])
		return result
	if value is Array:
		var array: Array = value
		var result: Array = []
		for entry: Variant in array:
			result.append(_canonical(entry))
		return result
	if value is float:
		var number: float = value
		if is_finite(number) and number == floorf(number) and absf(number) < 9007199254740992.0:
			return int(number)
	return value


func _backup_current() -> void:
	var source := FileAccess.open(save_path, FileAccess.READ)
	if source == null:
		return
	var bytes := source.get_buffer(source.get_length())
	source.close()
	if bytes.is_empty():
		return
	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		push_warning("SaveService: could not write backup")
		return
	backup.store_buffer(bytes)
	backup.flush()
	backup.close()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
