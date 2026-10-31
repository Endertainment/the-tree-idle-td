## LoginService — guest account on first online boot and token refresh (M7).
##
## The device id is the player's UUID from the save, so a reinstall with the same
## save keeps the same guest account. Tokens are owned by ApiClient; this service
## only decides when a guest login or a refresh is needed.
extends Node

signal auth_changed(authenticated: bool)
signal login_failed(reason: StringName)

var _initialized: bool = false
var _authenticated: bool = false
var _waiting_for_onboarding: bool = false
var _next_retry_msec: int = 0


func _ready() -> void:
	init_service()


func init_service() -> void:
	if _initialized:
		return
	_initialized = true
	_authenticated = ApiClient.is_authenticated()
	ApiClient.tokens_changed.connect(_on_tokens_changed)
	set_process(true)
	_boot.call_deferred()


func is_authenticated() -> bool:
	return _authenticated


## Ensures a usable access token. Returns false when offline/login is impossible.
func ensure_login() -> bool:
	if not ApiClient.is_online():
		_set_authenticated(ApiClient.is_authenticated())
		return _authenticated
	var device_id := _ensure_device_id()
	if (
		ApiClient.is_authenticated()
		and not ApiClient.get_player_id().is_empty()
		and ApiClient.get_player_id() != device_id
	):
		# The save was reset or replaced: old tokens belong to another profile.
		ApiClient.clear_tokens()
	if ApiClient.is_authenticated() and not ApiClient.access_expires_within(60):
		_set_authenticated(true)
		return true
	if ApiClient.has_refresh_token():
		if await ApiClient.refresh_session():
			_set_authenticated(true)
			return true
	var nickname := str(GameState.player.get("nickname", "")).strip_edges()
	if nickname.is_empty():
		nickname = "Gardener"
	var result: ApiResult = await ApiClient.request(
		&"POST",
		"/v1/auth/guest",
		{
			"device_id": device_id,
			"nickname": nickname,
			"avatar_id": str(GameState.player.get("avatar_id", "avatar_01")),
		},
		{"auth": false, "queue": false, "retry_attempts": 2}
	)
	if result.ok:
		ApiClient.store_tokens(result.data)
		_authenticated = true
		auth_changed.emit(true)
		return true
	login_failed.emit(result.error_code if not String(result.error_code).is_empty() else &"login_failed")
	_set_authenticated(false)
	return false


func _boot() -> void:
	await get_tree().process_frame
	if not GameState.is_onboarded:
		# First launch: wait for the onboarding wizard to create the player UUID.
		_waiting_for_onboarding = true
		set_process(true)
		return
	await ensure_login()


func _process(_delta: float) -> void:
	if _waiting_for_onboarding:
		if GameState.is_onboarded:
			_waiting_for_onboarding = false
			ensure_login()
		return
	# Recover from a lost connection without a restart.
	if _authenticated or not ApiClient.is_online():
		return
	if Time.get_ticks_msec() < _next_retry_msec:
		return
	_next_retry_msec = Time.get_ticks_msec() + ApiClient.OFFLINE_RETRY_MSEC
	ensure_login()


func _ensure_device_id() -> String:
	var player_id := str(GameState.player.get("id", ""))
	if not player_id.is_empty():
		return player_id
	player_id = ProfileRules.make_uuid_v4()
	GameState.player["id"] = player_id
	GameState.player["created_at"] = TimeService.now_unix()
	SaveService.request_save()
	return player_id


func _on_tokens_changed(authenticated: bool) -> void:
	_set_authenticated(authenticated)


func _set_authenticated(value: bool) -> void:
	if _authenticated == value:
		return
	_authenticated = value
	auth_changed.emit(value)
