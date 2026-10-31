## LocalBackendStub — deterministic offline data for the leaderboard UI (spec 6.7).
##
## M7 swaps LeaderboardService's backend for the FastAPI/Neon client; this class
## stays as the offline/test fixture. Entries are generated from a stable hash of
## the board and week so screenshots, tests and QA see the same 50 names every
## launch. No autoload access: callers pass the player's best wave and clock.
class_name LocalBackendStub
extends RefCounted

const COHORT_SIZE := 50
const REWARD_TIERS: Array[Dictionary] = [
	{"label_key": "leaderboard.reward.top1", "percentile": 1, "stones": 100},
	{"label_key": "leaderboard.reward.top10", "percentile": 10, "stones": 40},
	{"label_key": "leaderboard.reward.top25", "percentile": 25, "stones": 20},
	{"label_key": "leaderboard.reward.top50", "percentile": 50, "stones": 10},
	{"label_key": "leaderboard.reward.participation", "percentile": 100, "stones": 5},
]
const FIRST_NAMES: Array[String] = [
	"Elandra", "Thorn", "Bramble", "Oaken", "Sylva",
	"Fen", "Rowan", "Moss", "Willow", "Ash",
]
const LAST_NAMES: Array[String] = [
	"Warden", "Whisper", "Root", "Bloom", "Shade",
	"Keeper", "Grove", "Spire", "Fern", "Bark",
]


## Generates exactly 50 deterministic cohort entries around `player_best`.
static func generate(
	board: StringName,
	player_best: int,
	now_unix: int,
	week_id: String = ""
) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [String(board), week_id, 5])
	var base := maxi(player_best, 6)
	var spread_min := -4
	var spread_max := 14
	match board:
		&"all_time":
			base = maxi(player_best, 10)
			spread_min = -8
			spread_max = 22
		&"tournament":
			base = maxi(player_best, 12)
			spread_min = -6
			spread_max = 18
	var entries: Array[Dictionary] = []
	for index in COHORT_SIZE:
		var wave := maxi(1, base + rng.randi_range(spread_min, spread_max))
		var playtime := rng.randi_range(900, 12000)
		var submitted := now_unix - rng.randi_range(0, 6 * 86400)
		var name_index := index % FIRST_NAMES.size()
		var last_index := (int(index / FIRST_NAMES.size())) % LAST_NAMES.size()
		entries.append({
			"id": "stub_%s_%02d" % [String(board), index],
			"nickname": "%s %s" % [FIRST_NAMES[name_index], LAST_NAMES[last_index]],
			"avatar_id": "avatar_%02d" % (index % 6 + 1),
			"best_wave": wave,
			"playtime": playtime,
			"submitted_at": submitted,
			"is_player": false,
		})
	return sort_entries(entries)


## Sorts by best wave desc, then earlier submission, then lower play time (6.7).
static func sort_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var sorted := entries.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var wave_a := int(a.get("best_wave", 0))
		var wave_b := int(b.get("best_wave", 0))
		if wave_a != wave_b:
			return wave_a > wave_b
		var submitted_a := int(a.get("submitted_at", 0))
		var submitted_b := int(b.get("submitted_at", 0))
		if submitted_a != submitted_b:
			return submitted_a < submitted_b
		return int(a.get("playtime", 0)) < int(b.get("playtime", 0))
	)
	return sorted


## Returns a sorted copy with exactly one entry for the player's id.
static func insert_own(entries: Array[Dictionary], own: Dictionary) -> Array[Dictionary]:
	var own_id := str(own.get("id", ""))
	var merged: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) != own_id:
			merged.append(entry.duplicate(true))
	merged.append(own.duplicate(true))
	return sort_entries(merged)


## 1-based rank of `player_id` in `entries`, or 0 when absent.
static func rank_of(entries: Array[Dictionary], player_id: String) -> int:
	for index in entries.size():
		if str(entries[index].get("id", "")) == player_id:
			return index + 1
	return 0


## Reward tiers by final percentile (spec 6.7).
static func reward_tiers() -> Array[Dictionary]:
	return REWARD_TIERS.duplicate(true)
