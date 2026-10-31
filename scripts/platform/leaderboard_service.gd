## LeaderboardService — the UI's only leaderboard/tournament access point (spec 6.7).
##
## M5b runs entirely on LocalBackendStub so the screens work offline. M7 replaces
## `_fetch()` with the FastAPI/Neon client and keeps the public API (boards,
## entries, own rank, last-updated, offline flag, reward tiers) unchanged; screens
## never import the stub directly.
extends Node

signal refreshed(board: StringName)
signal refresh_failed(board: StringName, reason: StringName)

const BOARDS: Array[StringName] = [&"weekly", &"all_time", &"tournament"]
const STUB_REASON := &"offline_stub"

var _cache: Dictionary = {}
var _updated: Dictionary = {}


## Returns the 50 cohort entries for `board` (loaded on first use).
func get_entries(board: StringName, force_refresh: bool = false) -> Array[Dictionary]:
	if force_refresh or not _cache.has(board):
		_load(board)
	var cached: Array[Dictionary] = _cache.get(board, [])
	return cached.duplicate(true)


## Re-fetches one board and notifies the screen. Returns the fresh entries.
func refresh(board: StringName) -> Array[Dictionary]:
	var entries := get_entries(board, true)
	refreshed.emit(board)
	return entries


## The player's own entry, built from the live profile.
func get_own_entry() -> Dictionary:
	return {
		"id": str(GameState.player.get("id", "local_player")),
		"nickname": str(GameState.player.get("nickname", "")),
		"avatar_id": str(GameState.player.get("avatar_id", "avatar_01")),
		"best_wave": GameState.get_best_wave(),
		"playtime": int(GameState.stats.get("total_playtime", 0)),
		"submitted_at": TimeService.now_unix(),
		"is_player": true,
	}


## 1-based own rank among the cohort including the player, or 0 when absent.
func get_own_rank(board: StringName) -> int:
	var entries := get_entries(board)
	var own := get_own_entry()
	var with_own := LocalBackendStub.insert_own(entries, own)
	return LocalBackendStub.rank_of(with_own, str(own.get("id", "")))


## Unix time of the last successful fetch for `board` (0 when never fetched).
func get_last_updated(board: StringName) -> int:
	return int(_updated.get(board, 0))


## True while the stub serves cached data (always true in M5b).
func is_offline() -> bool:
	return true


## True when the player has a run worth placing on the board.
func has_player_runs() -> bool:
	return GameState.get_best_wave() > 0 or int(GameState.stats.get("runs_played", 0)) > 0


## Tournament metadata for the header/cohort panel.
func get_tournament_info() -> Dictionary:
	var now := TimeService.now_unix()
	var week_index := int(now / 604800)
	return {
		"cohort_id": "cohort-%d" % week_index,
		"ends_at": (week_index + 1) * 604800,
		"requirement_level": 12,
		"eligible": LevelService.get_level() >= 12,
	}


## Reward tiers by final percentile (top 1/10/25/50 and participation).
func get_reward_tiers() -> Array[Dictionary]:
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
	var now := TimeService.now_unix()
	var week_id := str(int(now / 604800))
	# M7 swap point: replace this call with the HTTP fetch.
	var entries := LocalBackendStub.generate(board, GameState.get_best_wave(), now, week_id)
	_cache[board] = entries
	_updated[board] = now
