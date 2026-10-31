## ApiClient — HTTP, auth, retries and the offline queue (spec 8.4).
##
## HARD RULE: this is the only script in the project that creates an
## HTTPRequest. Every network call is await-able, carries a 10 s timeout (15 s
## for save sync), retries transport/5xx failures on 1/2/4/8/16 s with jitter,
## refreshes an expired access token once, and persists mutating calls that
## cannot be delivered to user://api_queue.json for replay when back online.
##
## Tokens live in user://auth.json, never in the save file and never in logs.
extends Node

signal online_changed(online: bool)
signal tokens_changed(authenticated: bool)
signal request_finished(method: StringName, path: String, result: ApiResult)
signal queue_changed(pending: int)
signal queue_flushed(sent: int, failed: int)

const AUTH_PATH := "user://auth.json"
const QUEUE_PATH := "user://api_queue.json"
const OFFLINE_RETRY_MSEC := 15000

var _env: ApiEnv
var _base_url: String = "http://127.0.0.1:8000"
var _online: bool = true
var _offline_since_msec: int = 0
var _auth: Dictionary = {}
var _queue := ApiQueue.new()
var _initialized: bool = false
var _flushing: bool = false
var _refreshing: bool = false


func _ready() -> void:
	init_service()


## Reads env.tres, stored tokens and the persisted offline queue (idempotent).
func init_service() -> void:
	if _initialized:
		return
	_initialized = true
	_env = load("res://config/env.tres") as ApiEnv
	if _env == null:
		push_error("ApiClient: config/env.tres is missing or not an ApiEnv; using localhost")
	else:
		_base_url = _env.normalized_base_url()
	_load_auth()
	_queue.load_from_file(QUEUE_PATH)
	if not _queue.is_empty():
		queue_changed.emit(_queue.size())


## After a transport failure this reports false for OFFLINE_RETRY_MSEC, then
## becomes true again so a retry can discover that connectivity returned.
func is_online() -> bool:
	if _online:
		return true
	return Time.get_ticks_msec() - _offline_since_msec >= OFFLINE_RETRY_MSEC


func base_url() -> String:
	return _base_url


func is_authenticated() -> bool:
	return not get_access_token().is_empty()


func has_refresh_token() -> bool:
	return not str(_auth.get("refresh_token", "")).is_empty()


## True when the access token expires within `seconds` (or has already).
func access_expires_within(seconds: int = 30) -> bool:
	if not is_authenticated():
		return true
	var expires_at := int(_auth.get("expires_at", 0))
	return expires_at <= TimeService.now_unix() + maxi(seconds, 0)


func get_access_token() -> String:
	return str(_auth.get("access_token", ""))


func get_player_id() -> String:
	return str(_auth.get("player_id", ""))


## Stores a token response from /auth/guest or /auth/refresh.
func store_tokens(payload: Dictionary) -> void:
	if str(payload.get("access_token", "")).is_empty():
		return
	var now := TimeService.now_unix()
	_auth = {
		"player_id": str(payload.get("player_id", _auth.get("player_id", ""))),
		"access_token": str(payload.get("access_token", "")),
		"refresh_token": str(payload.get("refresh_token", _auth.get("refresh_token", ""))),
		"expires_at": now + int(payload.get("expires_in", 900)),
		"refresh_expires_at": now + int(payload.get("refresh_expires_in", 2592000)),
	}
	_write_json(AUTH_PATH, _auth)
	tokens_changed.emit(true)


## Removes persisted credentials (debug reset / revoked refresh token).
func clear_tokens() -> void:
	_auth.clear()
	if FileAccess.file_exists(AUTH_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_PATH))
	tokens_changed.emit(false)


## Rotates the refresh token. Returns true on success; never retries in a loop.
func refresh_session() -> bool:
	if _refreshing or not has_refresh_token():
		return false
	_refreshing = true
	var result: ApiResult = await _send(
		"POST",
		ApiUrls.join(_base_url, "/v1/auth/refresh"),
		{"refresh_token": str(_auth.get("refresh_token", ""))},
		_headers(false, ""),
		10.0
	)
	_refreshing = false
	if result.ok:
		store_tokens(result.data)
		_set_online(true)
		return true
	_set_online(false if result.retryable else _online)
	if result.status == 401:
		clear_tokens()
	return false


## Performs one API call with auth, retry, refresh and optional offline queue.
func request(
	method: StringName,
	path: String,
	body: Dictionary = {},
	opts: Dictionary = {}
) -> ApiResult:
	init_service()
	var upper := String(method).to_upper()
	var auth_required := bool(opts.get("auth", true))
	var idempotency_key := str(opts.get("idempotency_key", ""))
	if idempotency_key.is_empty() and _is_mutating(upper):
		idempotency_key = _new_uuid()
	var query: Dictionary = opts.get("query", {})
	var full_path := ApiUrls.with_query(path, query)
	var url := ApiUrls.join(_base_url, full_path)
	var timeout := float(opts.get("timeout", _timeout_for(path)))
	var max_attempts := clampi(int(opts.get("retry_attempts", ApiBackoff.MAX_ATTEMPTS)), 1, ApiBackoff.MAX_ATTEMPTS)
	var attempt := 0
	var refreshed := false
	var result: ApiResult = ApiResult.failure(0, &"not_sent", "request was not sent", true)

	while attempt < max_attempts:
		result = await _send(upper, url, body, _headers(auth_required, idempotency_key), timeout)
		if not is_inside_tree():
			return ApiResult.failure(0, &"cancelled", "client left the tree", false)
		if result.ok:
			_set_online(true)
			request_finished.emit(method, path, result)
			return result
		if (
			result.status == 401
			and auth_required
			and not refreshed
			and not path.begins_with("/v1/auth")
		):
			refreshed = true
			if await refresh_session():
				continue
		if result.retryable and attempt < max_attempts - 1:
			var delay := ApiBackoff.jittered_delay_msec(attempt)
			attempt += 1
			await get_tree().create_timer(float(delay) / 1000.0).timeout
			continue
		break

	if result.status == 0:
		_set_online(false)
	if result.retryable and _is_mutating(upper) and bool(opts.get("queue", true)):
		if enqueue(ApiQueue.make_op(method, full_path, body, idempotency_key, TimeService.now_unix())):
			result.queued = true
			result.error_code = &"queued_offline"
	request_finished.emit(method, path, result)
	return result


## Adds a mutating operation to the persisted queue.
func enqueue(op: Dictionary) -> bool:
	if not _queue.enqueue(op):
		return false
	_queue.save_to_file(QUEUE_PATH)
	queue_changed.emit(_queue.size())
	return true


## Replays queued operations in order. Stops at the first retryable failure.
func flush_queue() -> void:
	if _flushing or _queue.is_empty():
		return
	_flushing = true
	var sent := 0
	var failed := 0
	while not _queue.is_empty():
		var op := _queue.peek()
		var result: ApiResult = await request(
			StringName(str(op.get("method", "POST"))),
			str(op.get("path", "/")),
			op.get("body", {}) as Dictionary,
			{
				"auth": true,
				"queue": false,
				"idempotency_key": str(op.get("idempotency_key", "")),
				"retry_attempts": 1,
			}
		)
		if result.ok:
			_queue.pop_front()
			sent += 1
			continue
		if result.retryable:
			_queue.mark_failure(op)
			break
		# 4xx: the request will never succeed as-is; drop it instead of blocking.
		_queue.pop_front()
		failed += 1
	_queue.save_to_file(QUEUE_PATH)
	_flushing = false
	queue_flushed.emit(sent, failed)
	queue_changed.emit(_queue.size())


func pending_ops() -> int:
	return _queue.size()


func has_queued_ops() -> bool:
	return not _queue.is_empty()


## Booleans only: safe to show in debug tooling without leaking token material.
func debug_state() -> Dictionary:
	return {
		"base_url": _base_url,
		"online": _online,
		"authenticated": is_authenticated(),
		"pending_ops": _queue.size(),
		"player_id": get_player_id(),
	}


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_queue.save_to_file(QUEUE_PATH)


func _set_online(value: bool) -> void:
	if _online == value:
		return
	_online = value
	if not value:
		_offline_since_msec = Time.get_ticks_msec()
	online_changed.emit(value)
	if value and not _queue.is_empty():
		flush_queue.call_deferred()


func _timeout_for(path: String) -> float:
	var save_timeout := 15.0
	var default_timeout := 10.0
	if _env != null:
		save_timeout = _env.save_timeout_seconds
		default_timeout = _env.request_timeout_seconds
	return save_timeout if path.begins_with("/v1/save") else default_timeout


func _headers(auth_required: bool, idempotency_key: String) -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if auth_required:
		var token := get_access_token()
		if not token.is_empty():
			headers.append("Authorization: Bearer " + token)
	if not idempotency_key.is_empty():
		headers.append("Idempotency-Key: " + idempotency_key)
	return headers


func _send(
	method: String,
	url: String,
	body: Dictionary,
	headers: PackedStringArray,
	timeout: float
) -> ApiResult:
	var http := HTTPRequest.new()
	http.timeout = maxf(timeout, 1.0)
	http.use_threads = false
	add_child(http)
	var payload := "" if body.is_empty() else JSON.stringify(body)
	var error := http.request(url, headers, _http_method(method), payload)
	if error != OK:
		http.queue_free()
		return ApiResult.failure(0, &"request_failed", "HTTPRequest error %d" % error, true)

	var response: Array = await http.request_completed
	if is_instance_valid(http):
		http.queue_free()
	if not is_inside_tree():
		return ApiResult.failure(0, &"cancelled", "client left the tree", false)

	var result_code := int(response[0])
	var status := int(response[1])
	var raw: PackedByteArray = response[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		var code: StringName = (
			&"timeout" if result_code == HTTPRequest.RESULT_TIMEOUT else &"network_error"
		)
		return ApiResult.failure(0, code, "transport result %d" % result_code, true)

	var text := raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else {}
	var data: Dictionary = parsed as Dictionary if parsed is Dictionary else {}
	if status >= 200 and status < 300:
		return ApiResult.success(status, data)

	var error_code: StringName = &"http_error"
	var message := "HTTP %d" % status
	var detail: Variant = data.get("detail", null)
	if detail is Dictionary:
		error_code = StringName(str((detail as Dictionary).get("code", "http_error")))
		message = str((detail as Dictionary).get("message", message))
	elif detail is String:
		message = detail
	return ApiResult.failure(status, error_code, message, status >= 500)


func _http_method(method: String) -> int:
	match method:
		"GET":
			return HTTPClient.METHOD_GET
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"PATCH":
			return HTTPClient.METHOD_PATCH
		"DELETE":
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_GET


func _is_mutating(method: String) -> bool:
	return ["POST", "PUT", "PATCH", "DELETE"].has(method)


func _new_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
		bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15],
	]


func _load_auth() -> void:
	_auth = _read_json(AUTH_PATH)
	if _auth.get("access_token", "") is not String:
		_auth.clear()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("ApiClient: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
