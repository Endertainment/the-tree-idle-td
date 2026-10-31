## App — application boot sequence and global helper facade (autoload).
##
## Boot order is explicit and matches the design spec:
## settings -> locale -> audio -> save -> game state. Every step is idempotent,
## so Boot may call init_services() defensively without starting twice.
extends Node

const VERSION := "0.1.0"

var _initialized: bool = false
var _degraded: bool = false


func _ready() -> void:
	# Deferred: guarantees that every autoload declared after App exists before
	# init_services() touches it, even if App is instantiated first.
	init_services.call_deferred()


## Runs the service boot sequence exactly once.
func init_services() -> void:
	if _initialized:
		return
	_initialized = true

	SettingsService.init_service()

	var save_data: Dictionary = {}
	if SaveService.has_save():
		save_data = SaveService.load()
		if save_data.is_empty():
			_degraded = true
			log_warn("save file exists but could not be read; starting with defaults")
		elif SaveService.recovered_from_backup:
			log_warn("main save was corrupt; recovered the previous write from .bak")
		if not save_data.is_empty() and not SettingsService.has_stored_settings():
			SettingsService.apply_save_dict(_section(save_data, "settings"))

	LocaleService.init_service()
	AudioService.init_service()

	GameState.from_dict(save_data)
	LevelService.init_service()
	UnlockService.init_service()
	WorkshopService.init_service(_section(save_data, "workshop"))
	SaveService.set_save_provider(Callable(GameState, "build_save_document"))
	if SaveService.migrated_from_version > 0 and SaveService.migrated_from_version < SaveService.SCHEMA_VERSION:
		# Persist the migrated v2 document on the next frame, so the one-time
		# migration log never repeats after a restart.
		SaveService.request_save()

	log_info("boot complete, version %s" % version_string())


## Returns a dictionary section from the save payload (or {}).
func _section(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		return value as Dictionary
	return {}


## Returns the display version string (matches project.godot's config/version).
func version_string() -> String:
	return VERSION


## Returns true once init_services() has completed.
func is_initialized() -> bool:
	return _initialized


## Returns true for editor/debug builds (debug overlay, fake reward grants).
func is_debug_build() -> bool:
	return OS.is_debug_build()


## Returns true when a non-fatal service failure happened during boot.
func is_degraded() -> bool:
	return _degraded


## Prints an informational line prefixed with the app tag.
func log_info(message: String) -> void:
	print("[App] ", message)


## Prints a non-fatal warning prefixed with the app tag.
func log_warn(message: String) -> void:
	push_warning("[App] " + message)


## Routes back to the main menu and clears any paused state.
func quit_to_menu() -> void:
	get_tree().paused = false
	SceneRouter.goto(&"main_menu")
