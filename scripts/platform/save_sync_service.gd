## SaveSyncService — local-first cloud save with revision-based conflict policy.
##
## Local saves are always written first; the cloud copy is a backup that never
## blocks gameplay. Sync status is surfaced in Settings. The merge rules live in
## SaveSyncMerge and are unit-tested; ADR-034 documents the behaviour:
##   same revision + dirty -> push; server newer + clean -> pull;
##   server newer + dirty -> three-way merge (server wins real conflicts,
##   local-only changes are pushed as a patch); server older -> pull.
extends Node

signal status_changed(status: StringName, detail: Dictionary)

const STATE_PATH := "user://save_sync.json"
const DEBOUNCE_MSEC := 2000
const MAX_MERGE_DEPTH := 2

const STATUS_OFFLINE := &"offline"
const STATUS_PENDING := &"pending"
const STATUS_SYNCING := &"syncing"
const STATUS_SYNCED := &"synced"
const STATUS_CONFLICT := &"conflict_resolved"
const STATUS_ERROR := &"error"

var _initialized: bool = false
var _status: StringName = STATUS_OFFLINE
var _server_revision: int = 0
var _synced_payload: Dictionary = {}
var _pending_conflicts: Array = []
var _last_sync_at: int = 0
var _dirty: bool = false
var _last_change_msec: int = 0
var _sync_in_flight: bool = false
var _applying_remote: bool = false
var _merge_depth: int = 0


func _ready() -> void:
	init_service()


func init_service() -> void:
	if _initialized:
		return
	_initialized = true
	_load_state()
	if _synced_payload.is_empty() and SaveService.has_save() and GameState.is_onboarded:
		# Upgrading from M6 (or a lost sync state): local progress predates M7.
		_dirty = true
	SaveService.saved.connect(_on_saved)
	ApiClient.online_changed.connect(_on_online_changed)
	LoginService.auth_changed.connect(_on_auth_changed)
	set_process(_dirty)
	_boot.call_deferred()


func get_status() -> StringName:
	return _status


func get_server_revision() -> int:
	return _server_revision


func get_last_sync_at() -> int:
	return _last_sync_at


func get_pending_conflicts() -> Array:
	return _pending_conflicts.duplicate()


func is_dirty() -> bool:
	return _dirty


## Human-readable status for Settings; safe when LocaleService is absent.
func status_text() -> String:
	match _status:
		STATUS_OFFLINE:
			return LocaleService.t("settings.sync.offline", "Offline — plays locally")
		STATUS_PENDING:
			return LocaleService.t("settings.sync.pending", "Pending upload")
		STATUS_SYNCING:
			return LocaleService.t("settings.sync.syncing", "Syncing…")
		STATUS_SYNCED:
			if _last_sync_at > 0:
				return LocaleService.t("settings.sync.synced", "Synced") + " · " + Time.get_time_string_from_unix_time(_last_sync_at)
			return LocaleService.t("settings.sync.synced", "Synced")
		STATUS_CONFLICT:
			return LocaleService.t("settings.sync.conflict", "Synced (conflicts resolved)")
		_:
			return LocaleService.t("settings.sync.error", "Sync error")


## Manual "Sync now" from Settings.
func sync_now() -> void:
	await _sync_from_server()


func _boot() -> void:
	await get_tree().process_frame
	if not GameState.is_onboarded:
		# LoginService emits auth_changed after onboarding; sync starts then.
		_set_status(STATUS_OFFLINE)
		return
	await _sync_from_server()


func _process(_delta: float) -> void:
	if not _dirty or _sync_in_flight or _applying_remote:
		return
	if not ApiClient.is_online() or not LoginService.is_authenticated():
		return
	if Time.get_ticks_msec() - _last_change_msec < DEBOUNCE_MSEC:
		return
	_flush_dirty()


func _flush_dirty() -> void:
	if _sync_in_flight:
		return
	_sync_in_flight = true
	_set_status(STATUS_SYNCING)
	var pushed: bool = await _push(_server_revision)
	_sync_in_flight = false
	if not pushed and _status != STATUS_CONFLICT:
		_set_status(STATUS_PENDING)


func _sync_from_server() -> void:
	if _sync_in_flight:
		return
	_sync_in_flight = true
	_set_status(STATUS_SYNCING)
	var authenticated: bool = await LoginService.ensure_login()
	if not authenticated:
		_sync_in_flight = false
		_set_status(STATUS_OFFLINE)
		return
	var result: ApiResult = await ApiClient.request(
		&"GET", "/v1/save", {}, {"queue": false, "retry_attempts": 2}
	)
	if result.status == 404:
		_server_revision = 0
		if not await _push(0):
			_set_status(STATUS_PENDING)
	elif result.ok:
		await _adopt_server(result.data)
	else:
		_set_status(STATUS_OFFLINE if result.status == 0 or result.retryable else STATUS_ERROR)
	_sync_in_flight = false


func _adopt_server(server: Dictionary) -> void:
	_merge_depth += 1
	if _merge_depth > MAX_MERGE_DEPTH:
		_merge_depth = 0
		return
	var server_revision := int(server.get("revision", 0))
	var server_payload: Dictionary = server.get("payload", {}) as Dictionary
	var local_payload: Dictionary = GameState.build_save_document()
	var local_dirty := _dirty
	if not _synced_payload.is_empty() and not SaveSyncMerge.deep_equal(local_payload, _synced_payload):
		local_dirty = true
	var decision := SaveSyncMerge.decide(local_dirty, _server_revision, server_revision)
	match decision:
		SaveSyncMerge.DECISION_NOOP:
			_set_status(STATUS_SYNCED)
		SaveSyncMerge.DECISION_PUSH:
			await _push(_server_revision)
		SaveSyncMerge.DECISION_PULL:
			_apply_remote(server_payload)
			_server_revision = server_revision
			_synced_payload = server_payload.duplicate(true)
			_dirty = false
			_last_sync_at = TimeService.now_unix()
			_persist_state()
			_set_status(STATUS_SYNCED)
		SaveSyncMerge.DECISION_MERGE:
			var merged := SaveSyncMerge.three_way_merge(_synced_payload, local_payload, server_payload)
			var merged_payload: Dictionary = merged.get("payload", server_payload)
			_apply_remote(merged_payload)
			_server_revision = server_revision
			_synced_payload = server_payload.duplicate(true)
			_pending_conflicts = merged.get("conflicts", [])
			_dirty = true
			_persist_state()
			var pushed: bool = await _push(server_revision, merged_payload)
			if pushed:
				_set_status(STATUS_CONFLICT if not _pending_conflicts.is_empty() else STATUS_SYNCED)
			else:
				_set_status(STATUS_PENDING)
	_merge_depth -= 1


func _push(revision: int, payload_override: Dictionary = {}) -> bool:
	var payload: Dictionary = (
		payload_override.duplicate(true) if not payload_override.is_empty() else GameState.build_save_document()
	)
	var result: ApiResult = await ApiClient.request(
		&"PUT",
		"/v1/save",
		{"revision": revision, "payload": payload, "checksum": _checksum(payload)},
		{"queue": false, "timeout": 15.0}
	)
	if result.ok:
		_server_revision = int(result.data.get("revision", revision + 1))
		_synced_payload = payload.duplicate(true)
		_pending_conflicts = []
		_dirty = false
		_last_sync_at = TimeService.now_unix()
		_persist_state()
		_set_status(STATUS_SYNCED)
		return true
	if result.status == 409:
		var detail := result.conflict_detail()
		var server: Variant = detail.get("server", null)
		if server is Dictionary and not (server as Dictionary).is_empty():
			await _adopt_server(server as Dictionary)
			return true
		if str(detail.get("code", "")) == "save_missing":
			_server_revision = 0
			return await _push(0, payload)
	if result.status == 0 or result.retryable:
		_dirty = true
		_persist_state()
		return false
	_dirty = true
	_persist_state()
	return false


func _apply_remote(payload: Dictionary) -> void:
	_applying_remote = true
	App.reload_services_from_save(payload)
	SaveService.save(GameState.build_save_document())
	_applying_remote = false


func _on_saved(payload: Dictionary) -> void:
	if _applying_remote:
		return
	_dirty = true
	_last_change_msec = Time.get_ticks_msec()
	_persist_state()
	if _status != STATUS_SYNCING:
		_set_status(STATUS_PENDING)
	set_process(true)


func _on_online_changed(online: bool) -> void:
	if online:
		_sync_from_server.call_deferred()


func _on_auth_changed(authenticated: bool) -> void:
	if authenticated:
		_sync_from_server.call_deferred()


func _set_status(status: StringName, detail: Dictionary = {}) -> void:
	if _status == status and detail.is_empty():
		return
	_status = status
	status_changed.emit(status, detail)


func _checksum(payload: Dictionary) -> String:
	return "sha256:" + JSON.stringify(payload).sha256_text()


func _load_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE_PATH))
	if not parsed is Dictionary:
		return
	var state: Dictionary = parsed
	_server_revision = int(state.get("server_revision", 0))
	_synced_payload = (state.get("synced_payload", {}) as Dictionary).duplicate(true)
	_dirty = bool(state.get("dirty", false))
	_last_sync_at = int(state.get("last_sync_at", 0))
	_pending_conflicts = state.get("pending_conflicts", []) as Array


func _persist_state() -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSyncService: cannot write sync state")
		return
	file.store_string(JSON.stringify({
		"server_revision": _server_revision,
		"synced_payload": _synced_payload,
		"dirty": _dirty,
		"last_sync_at": _last_sync_at,
		"pending_conflicts": _pending_conflicts,
	}, "\t"))
	file.close()
