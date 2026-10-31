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
	LocaleService.init_service()
	AudioService.init_service()

	var save_data: Dictionary = {}
	if SaveService.has_save():
		save_data = SaveService.load()
		if save_data.is_empty():
			_degraded = true
			log_warn("save file exists but could not be read; starting with defaults")
	GameState.from_dict(save_data)

	log_info("boot complete, version %s" % version_string())


## Returns the display version string (matches project.godot's config/version).
func version_string() -> String:
	return VERSION


## Returns true once init_services() has completed.
func is_initialized() -> bool:
	return _initialized


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
