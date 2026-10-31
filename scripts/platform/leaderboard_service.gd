## LeaderboardService — the UI's only leaderboard/tournament access point (spec 6.7).
##
## Online: fetches GET /v1/leaderboard (weekly/all_time/tournament) plus
## /v1/tournaments/current through ApiClient and caches the last result in
## user://leaderboard_cache.json. Offline, unauthenticated, or on any error it
## falls back to LocalBackendStub so the screen is identical to M5b. Screens never
## import the backend or the stub: `_fetch_remote()` is the single swap seam.
extends Node

signal refreshed(board: StringName)
signal refresh_failed(board: StringName, reason: StringName)

const BOARDS: Array[StringName] = [&"weekly", &"all_time", &"tournament"]
const STUB_REASON := &"offline_stub"
const CACHE_PATH := "user://leaderboard_cache.json"

var _cache: Dictionary = {}
var _updated: Dictionary = {}
var _own_ranks: Dictionary = {}
var _own_entries: Dictionary = {}
var _remote_boards: Dictionary = {}
var _fetching: Dictionary = {}
var _tournament: Dictionary = {}
var _offline: bool = true
var _initialized: bool = false


func _ready() -> void:
	init_service()


## Loads the on-disk cache and starts live refreshes when a session exists.
func init_service() -> void:
	if _initialized:
		return
	_initialized = true
	_load_cache()
	for board: StringName in BOARDS:
		if not _cache.has(board) or (_cache[board] as Array).is_empty():
			_cache[board] = _stub(board)
			_updated[board] = TimeService.now_unix()
	LoginService.auth_changed.connect(_on_auth_changed)
	ApiClient.online_changed.connect(_on_online_changed)
	if ApiClient.is_online() and LoginService.is_authenticated():
		_refresh_all()


## Returns the cohort entries for `board` (cached, loaded on first use).
func get_entries(board: StringName, force_refresh: bool = false) -> Array[Dictionary]:
	if not _initialized:
		init_service()
	if force_refresh or not _cache.has(board):
		_load(board)
	if force_refresh and _can_fetch(board):
		_fetch_remote(board)
	var cached: Array[Dictionary] = _cache.get(board, [])
	return cached.duplicate(true)


## Re-fetches one board. Remote data arrives through `refreshed`; when offline
## the deterministic stub is emitted immediately so the UI never blocks.
func refresh(board: StringName) -> Array[Dictionary]:
	if not _initialized:
		init_service()
	if not is_supported(board):
		var empty: Array[Dictionary] = []
		refresh_failed.emit(board, &"unknown_board")
		return empty
	if _can_fetch(board):
		_fetch_remote(board)
	else:
		_load(board)
		refreshed.emit(board)
	return get_entries(board)


## True while a live request for `board` is in flight.
func is_fetching(board: StringName) -> bool:
	return bool(_fetching.get(board, false))


## The player's own entry for `board` (live copy when available).
func get_own_entry(board: StringName = &"weekly") -> Dictionary:
	var remote: Dictionary = _own_entries.get(board, {})
	if not remote.is_empty():
		return remote.duplicate(true)
	return _local_own_entry(board)


## 1-based own rank including the player, or 0 when absent.
func get_own_rank(board: StringName) -> int:
	if _remote_boards.get(board, false):
		return int(_own_ranks.get(board, 0))
	var entries := get_entries(board)
	var own := _local_own_entry(board)
	var with_own := LocalBackendStub.insert_own(entries, own)
	return LocalBackendStub.rank_of(with_own, str(own.get("id", "")))


func _local_own_entry(_board: StringName) -> Dictionary:
	return {
		"id": str(GameState.player.get("id", "local_player")),
		"player_id": str(GameState.player.get("id", "local_player")),
		"nickname": str(GameState.player.get("nickname", "")),
		"avatar_id": str(GameState.player.get("avatar_id", "avatar_01")),
		"best_wave": GameState.get_best_wave(),
		"max_wave": GameState.get_best_wave(),
		"playtime": int(GameState.stats.get("total_playtime", 0)),
		"playtime_s": int(GameState.stats.get("total_playtime", 0)),
		"submitted_at": TimeService.now_unix(),
		"rank": 0,
		"is_player": true,
	}


## Unix time of the last successful fetch for `board` (0 when never fetched).
func get_last_updated(board: StringName) -> int:
	return int(_updated.get(board, 0))


## True while no live response is available (stub/cached data shown).
func is_offline() -> bool:
	return _offline


## True when the player has a run worth placing on the board.
func has_player_runs() -> bool:
	return GameState.get_best_wave() > 0 or int(GameState.stats.get("runs_played", 0)) > 0


## Tournament metadata for the header/cohort panel (server values when live).
func get_tournament_info() -> Dictionary:
	if not _tournament.is_empty():
		return _tournament.duplicate(true)
	var now := TimeService.now_unix()
	var week_index := int(now / 604800)
	return {
		"cohort_id": "cohort-%d" % week_index,
		"ends_at": (week_index + 1) * 604800,
		"requirement_level": 12,
		"eligible": LevelService.get_level() >= 12,
		"cohort_size": 50,
	}


## Reward tiers by final percentile (top 1/10/25/50 and participation).
func get_reward_tiers() -> Array[Dictionary]:
	var tiers: Variant = _tournament.get("reward_tiers", null)
	if tiers is Array and not (tiers as Array).is_empty():
		var parsed: Array[Dictionary] = []
		for tier: Variant in tiers as Array:
			if tier is Dictionary:
				parsed.append((tier as Dictionary).duplicate(true))
		return parsed
	return LocalBackendStub.reward_tiers()


## True when the board is one of the supported ids.
func is_supported(board: StringName) -> bool:
	return BOARDS.has(board)


func _load(board: StringName) -> void:
	if not is_supported(board):
		var empty: Array[Dictionary] = []
		_cache[board] = empty
		_updated[board] = TimeService.now_unix()
		refresh_failed.emit(board, &"unknown_board")
		return
	# Keep cached/live data; only seed the deterministic stub on first use.
	if not _cache.has(board) or (_cache[board] as Array).is_empty():
		_cache[board] = _stub(board)
		_updated[board] = TimeService.now_unix()


func _stub(board: StringName) -> Array[Dictionary]:
	var week_id := str(int(TimeService.now_unix() / 604800))
	return LocalBackendStub.generate(board, GameState.get_best_wave(), TimeService.now_unix(), week_id)


func _can_fetch(board: StringName) -> bool:
	return (
		ApiClient.is_online()
		and LoginService.is_authenticated()
		and not bool(_fetching.get(board, false))
	)


func _refresh_all() -> void:
	for board: StringName in BOARDS:
		if _can_fetch(board):
			_fetch_remote(board)


func _fetch_remote(board: StringName) -> void:
	if not _can_fetch(board):
		return
	_fetching[board] = true
	var result: ApiResult = await ApiClient.request(
		&"GET",
		"/v1/leaderboard",
		{},
		{
			"query": {"scope": String(board), "limit": 100},
			"queue": false,
			"retry_attempts": 2,
		}
	)
	_fetching.erase(board)
	if not is_inside_tree():
		return
	if result.ok:
		_cache[board] = LeaderboardBackend.parse_entries(result.data.get("entries", []))
		var own_rank: Variant = result.data.get("own_rank", null)
		_own_ranks[board] = int(own_rank) if own_rank != null else 0
		var own_entry: Variant = result.data.get("own_entry", null)
		_own_entries[board] = (
			LeaderboardBackend.parse_entry(own_entry as Dictionary)
			if own_entry is Dictionary
			else {}
		)
		_remote_boards[board] = true
		_updated[board] = TimeService.now_unix()
		_offline = false
		if board == &"tournament":
			await _fetch_tournament_info()
		_save_cache()
		refreshed.emit(board)
	else:
		_offline = true
		if not _cache.has(board) or (_cache[board] as Array).is_empty():
			_cache[board] = _stub(board)
			_updated[board] = TimeService.now_unix()
		var reason: StringName = result.error_code
		if String(reason).is_empty():
			reason = &"network_error"
		refresh_failed.emit(board, reason)


func _fetch_tournament_info() -> void:
	var result: ApiResult = await ApiClient.request(
		&"GET", "/v1/tournaments/current", {}, {"queue": false, "retry_attempts": 2}
	)
	if not is_inside_tree() or not result.ok:
		return
	_tournament = {
		"cohort_id": str(result.data.get("cohort_id", "")),
		"ends_at": LeaderboardBackend.to_unix(result.data.get("ends_at", "")),
		"starts_at": LeaderboardBackend.to_unix(result.data.get("starts_at", "")),
		"requirement_level": int(result.data.get("min_level", 12)),
		"eligible": bool(result.data.get("eligible", false)),
		"cohort_size": int(result.data.get("cohort_size", 50)),
		"week_id": str(result.data.get("week_id", "")),
		"entries_count": int(result.data.get("entries_count", 0)),
		"reward_tiers": result.data.get("reward_tiers", []),
	}


func _on_auth_changed(authenticated: bool) -> void:
	if authenticated:
		_refresh_all()


func _on_online_changed(online: bool) -> void:
	if online and LoginService.is_authenticated():
		_refresh_all()


func _save_cache() -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"entries": _cache,
		"updated": _updated,
		"own_ranks": _own_ranks,
		"own_entries": _own_entries,
		"remote_boards": _remote_boards,
		"tournament": _tournament,
	}, "\t"))
	file.close()


func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
	if not parsed is Dictionary:
		return
	var cache: Dictionary = parsed
	var entries: Variant = cache.get("entries", {})
	if entries is Dictionary:
		for board: StringName in BOARDS:
			var key := String(board)
			if (entries as Dictionary).has(key):
				_cache[board] = LeaderboardBackend.parse_entries((entries as Dictionary)[key])
	var updated: Variant = cache.get("updated", {})
	if updated is Dictionary:
		for board: StringName in BOARDS:
			_updated[board] = int((updated as Dictionary).get(String(board), 0))
	var ranks: Variant = cache.get("own_ranks", {})
	if ranks is Dictionary:
		for board: StringName in BOARDS:
			_own_ranks[board] = int((ranks as Dictionary).get(String(board), 0))
	var own_entries: Variant = cache.get("own_entries", {})
	if own_entries is Dictionary:
		for board: StringName in BOARDS:
			var entry: Variant = (own_entries as Dictionary).get(String(board), {})
			if entry is Dictionary:
				_own_entries[board] = LeaderboardBackend.parse_entry(entry as Dictionary)
	var remotes: Variant = cache.get("remote_boards", {})
	if remotes is Dictionary:
		for board: StringName in BOARDS:
			_remote_boards[board] = bool((remotes as Dictionary).get(String(board), false))
			if _remote_boards[board]:
				_offline = false
	var tournament: Variant = cache.get("tournament", {})
	if tournament is Dictionary:
		_tournament = (tournament as Dictionary).duplicate(true)
