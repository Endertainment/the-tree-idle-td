## App — application boot sequence and global helper facade (autoload).
##
## Boot order is explicit and matches the design spec:
## settings -> locale -> audio -> save -> game state. Every step is idempotent,
## so Boot may call init_services() defensively without starting twice.
extends Node

const VERSION := "0.8.0"

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
	MagicaService.init_service(_section(save_data, "magica"))
	CardService.init_service(_section(save_data, "cards"))
	MissionService.init_service(_section(save_data, "missions"))
	OfflineService.init_service(save_data)
	# Monetization/telemetry services only read their config and defer SDK init;
	# a missing store or ad SDK must never stop the boot (spec 8.1).
	AdsService.init_service()
	IapService.init_service()
	AnalyticsService.init_service()
	AnalyticsService.track(&"app_open", {"version": version_string()})
	SaveService.set_save_provider(Callable(GameState, "build_save_document"))
	# M7 local-first networking. Every service degrades to offline and must never
	# block or fail the boot (spec 8.1); ApiClient is the only HTTPRequest owner.
	ApiClient.init_service()
	LoginService.init_service()
	RemoteConfigService.init_service()
	SaveSyncService.init_service()
	LeaderboardService.init_service()
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


## Rebuilds the live stateful services from a save payload pulled from the cloud.
## Settings stay device-local on purpose; OfflineService is not re-run because
## that would grant offline income twice.
func reload_services_from_save(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	GameState.from_dict(payload)
	WorkshopService.init_service(_section(payload, "workshop"))
	MagicaService.init_service(_section(payload, "magica"))
	CardService.init_service(_section(payload, "cards"))
	MissionService.init_service(_section(payload, "missions"))
	LevelService.init_service()
	UnlockService.init_service()


## Routes back to the main menu and clears any paused state.
func quit_to_menu() -> void:
	get_tree().paused = false
	SceneRouter.goto(&"main_menu")
