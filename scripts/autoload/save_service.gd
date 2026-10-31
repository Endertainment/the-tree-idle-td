## SaveService — versioned, atomic persistence for meta progress (autoload).
##
## Writes to a temp file, verifies that bytes landed, keeps the previous file as
## .bak, then renames the temp file over the save. load() falls back to the
## backup when the main file is missing or unparseable. GameState owns the shape
## of the payload; SaveService only supplies schema_version and saved_at.
extends Node

const SCHEMA_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save_v1.json"
const DEFAULT_BACKUP_PATH := "user://save_v1.bak.json"
const DEFAULT_TEMP_PATH := "user://save_v1.tmp.json"

## Overridable so tests can use isolated files without touching a real save.
var save_path: String = DEFAULT_SAVE_PATH
var backup_path: String = DEFAULT_BACKUP_PATH
var temp_path: String = DEFAULT_TEMP_PATH


## Serialises `data` and writes it atomically. Returns true on success.
func save(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["schema_version"] = SCHEMA_VERSION
	payload["saved_at"] = int(Time.get_unix_time_from_system())

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
	return true


## Reads the main save, falling back to the backup. Returns {} when neither
## file exists or both are unreadable/corrupt.
func load() -> Dictionary:
	var main_data := _read_dictionary(save_path)
	if not main_data.is_empty() and _is_supported(main_data):
		return main_data

	if FileAccess.file_exists(save_path):
		push_warning("SaveService: main save is invalid, trying backup")

	var backup_data := _read_dictionary(backup_path)
	if not backup_data.is_empty() and _is_supported(backup_data):
		push_warning("SaveService: recovered progress from backup")
		return backup_data

	return {}


## Returns true when a main save file exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Deletes the main, backup and temp save files. Used by tests and "new game".
func clear() -> void:
	_remove_file(save_path)
	_remove_file(backup_path)
	_remove_file(temp_path)


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


func _is_supported(data: Dictionary) -> bool:
	if not data.has("schema_version"):
		return false
	var version := int(data.get("schema_version", 0))
	if version <= 0 or version > SCHEMA_VERSION:
		push_warning("SaveService: unsupported schema version %d" % version)
		return false
	return true


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
