## RemoteConfigService — GET /config merged over config/remote_defaults.tres.
##
## The last response is cached in user://remote_config.json for one hour, so an
## offline boot still gets the last known feature flags and ad frequency.
extends Node

signal config_changed

const CACHE_PATH := "user://remote_config.json"
const TTL_SECONDS := 3600

var _defaults: Dictionary = {}
var _remote: Dictionary = {}
var _resolved: Dictionary = {}
var _fetched_at: int = 0
var _initialized: bool = false


func _ready() -> void:
	init_service()


func init_service() -> void:
	if _initialized:
		return
	_initialized = true
	var resource := load("res://config/remote_defaults.tres") as RemoteConfig
	if resource == null:
		push_warning("RemoteConfigService: config/remote_defaults.tres is missing")
	else:
		_defaults = {
			"version": resource.version,
			"feature_flags": resource.feature_flags.duplicate(true),
			"ad_frequency": resource.ad_frequency.duplicate(true),
			"balance_overrides": resource.balance_overrides.duplicate(true),
			"shop_catalog_version": resource.shop_catalog_version,
		}
	_load_cache()
	_recompute()
	LoginService.auth_changed.connect(_on_auth_changed)
	if not is_cache_fresh():
		refresh()


## Fetches the server config. Returns true when a response was merged.
func refresh() -> bool:
	if not ApiClient.is_online():
		return false
	var result: ApiResult = await ApiClient.request(
		&"GET", "/v1/config", {}, {"retry_attempts": 2, "queue": false}
	)
	if not result.ok:
		if result.status == 401 and await LoginService.ensure_login():
			result = await ApiClient.request(
				&"GET", "/v1/config", {}, {"retry_attempts": 1, "queue": false}
			)
		if not result.ok:
			return false
	_remote = result.data.duplicate(true)
	_fetched_at = TimeService.now_unix()
	_recompute()
	_save_cache()
	config_changed.emit()
	return true


func is_cache_fresh() -> bool:
	return RemoteConfigMerger.is_fresh(_fetched_at, TimeService.now_unix(), TTL_SECONDS)


func get_config() -> Dictionary:
	return _resolved.duplicate(true)


func get_version() -> int:
	return int(_resolved.get("version", 1))


func get_feature(flag: String, fallback: bool = true) -> bool:
	var flags: Dictionary = _resolved.get("feature_flags", {})
	return bool(flags.get(flag, fallback))


func get_ad_frequency() -> Dictionary:
	var frequency: Dictionary = _resolved.get("ad_frequency", {})
	return frequency.duplicate(true)


func get_value(key: String, fallback: Variant = null) -> Variant:
	return _resolved.get(key, fallback)


func _recompute() -> void:
	_resolved = RemoteConfigMerger.merge(_defaults, _remote)


func _on_auth_changed(authenticated: bool) -> void:
	if authenticated and not is_cache_fresh():
		refresh()


func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
	if not parsed is Dictionary:
		return
	var cache: Dictionary = parsed
	_fetched_at = int(cache.get("fetched_at", 0))
	var config: Variant = cache.get("config", {})
	if config is Dictionary:
		_remote = (config as Dictionary).duplicate(true)


func _save_cache() -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("RemoteConfigService: cannot write cache")
		return
	file.store_string(JSON.stringify({"fetched_at": _fetched_at, "config": _remote}, "\t"))
	file.close()
