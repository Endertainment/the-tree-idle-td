## GameState — the player's persistent meta profile (autoload).
##
## Runtime model only: no disk access. App loads SaveService at boot and hands the
## document to from_dict(); build_save_document() is the full v2 payload that
## SaveService writes. Permanent currencies are mutated only by WalletService, XP
## only by LevelService, workshop levels only by WorkshopService; this node owns
## the player/stats/section containers so the save shape has one owner.
extends Node

var player: Dictionary = {
	"id": "",
	"nickname": "",
	"avatar_id": "avatar_01",
	"level": 1,
	"xp": 0,
	"created_at": 0,
	"provider": "",
	"provider_uid": "",
	"best_wave": 0,
	"next_wave_uses": 0,
	"last_seen_at": 0,
}

var wallet: Dictionary = {
	"coins": 0,
	"gems": 0,
	"stones": 0,
}

var stats: Dictionary = {
	"best_wave": 0,
	"runs_played": 0,
	"total_kills": 0,
	"total_playtime": 0,
	"weekly_max_wave": 0,
	"week_id": "",
}

var magica: Dictionary = {"research": {}, "completed": [], "pending_claim": ""}
var cards: Dictionary = {"owned": [], "equipped": [null, null, null, null]}
var missions: Dictionary = {
	"day_id": "",
	"daily": [],
	"week_id": "",
	"weekly": [],
	"daily_bonus_claimed": false,
	"weekly_bonus_claimed": false,
}
var shop: Dictionary = {"owned_products": [], "last_daily_claim": 0}
var ads: Dictionary = {"rv_today": 0, "rv_day": "", "interstitial_last": 0}

## Debug/QA unlock grants only (level unlocks are derived by UnlockService).
var unlocks: Dictionary = {}

var is_onboarded: bool = false

## Run ids whose rewards were already granted (reward-bundle idempotency).
var reward_ledger := RewardLedger.new()


## Full schema-v2 document. SaveService adds schema_version/saved_at/checksum.
func build_save_document() -> Dictionary:
	var player_payload := player.duplicate(true)
	# best_wave belongs to `stats` in v2; keep the player copy out of the file.
	player_payload.erase("best_wave")
	return {
		"player": player_payload,
		"wallet": {
			"coins": maxi(int(wallet.get("coins", 0)), 0),
			"gems": maxi(int(wallet.get("gems", 0)), 0),
			"stones": maxi(int(wallet.get("stones", 0)), 0),
		},
		"stats": stats.duplicate(true),
		"workshop": WorkshopService.to_dict(),
		"magica": magica.duplicate(true),
		"cards": cards.duplicate(true),
		"missions": missions.duplicate(true),
		"unlocks": UnlockService.get_all_unlocked(),
		"settings": SettingsService.to_save_dict(),
		"shop": shop.duplicate(true),
		"ads": ads.duplicate(true),
		# Local extras (documented in ADR-022); both must survive a restart.
		"is_onboarded": is_onboarded,
		"applied_rewards": reward_ledger.to_array(),
	}


## Debug-only full profile wipe used by Settings → Reset profile. Services are
## reset by the caller; this restores the in-memory document to first-launch shape.
func reset_profile() -> void:
	player = {
		"id": "", "nickname": "", "avatar_id": "avatar_01", "level": 1, "xp": 0,
		"created_at": 0, "provider": "", "provider_uid": "", "best_wave": 0,
		"next_wave_uses": 0, "last_seen_at": 0,
	}
	wallet = {"coins": 0, "gems": 0, "stones": 0}
	stats = {
		"best_wave": 0, "runs_played": 0, "total_kills": 0,
		"total_playtime": 0, "weekly_max_wave": 0, "week_id": "",
	}
	magica = {"research": {}, "completed": [], "pending_claim": ""}
	cards = {"owned": [], "equipped": [null, null, null, null]}
	missions = {
		"day_id": "", "daily": [], "week_id": "", "weekly": [],
		"daily_bonus_claimed": false, "weekly_bonus_claimed": false,
	}
	shop = {"owned_products": [], "last_daily_claim": 0}
	ads = {"rv_today": 0, "rv_day": "", "interstitial_last": 0}
	unlocks.clear()
	is_onboarded = false
	reward_ledger.from_array([])


## Backwards-compatible alias for tools that snapshot/restore the profile.
func to_dict() -> Dictionary:
	return build_save_document()


## Restores known fields from a save payload (v1 or v2). Missing fields keep
## defaults, so older or partial saves never wipe the profile.
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	var stored_player: Variant = data.get("player", null)
	if stored_player is Dictionary:
		_merge_keys(player, stored_player as Dictionary)

	var stored_wallet: Variant = data.get("wallet", null)
	if stored_wallet is Dictionary:
		_merge_keys(wallet, stored_wallet as Dictionary)

	var stored_stats: Variant = data.get("stats", null)
	if stored_stats is Dictionary:
		_merge_keys(stats, stored_stats as Dictionary)

	var stored_sections := {
		"magica": magica,
		"cards": cards,
		"missions": missions,
		"shop": shop,
		"ads": ads,
	}
	for section: String in stored_sections.keys():
		var stored: Variant = data.get(section, null)
		if stored is Dictionary:
			(stored_sections[section] as Dictionary).clear()
			(stored_sections[section] as Dictionary).merge((stored as Dictionary).duplicate(true), true)

	var stored_unlocks: Variant = data.get("unlocks", null)
	if stored_unlocks is Dictionary:
		unlocks = (stored_unlocks as Dictionary).duplicate(true)
	elif stored_unlocks is Array:
		unlocks.clear()
		for entry: Variant in stored_unlocks as Array:
			unlocks[str(entry)] = true

	var stored_rewards: Variant = data.get("applied_rewards", null)
	if stored_rewards is Array:
		reward_ledger.from_array(stored_rewards as Array)

	# v1 stored best_wave on the player; v2 owns it in stats. Keep both in sync.
	var best := maxi(int(player.get("best_wave", 0)), int(stats.get("best_wave", 0)))
	stats["best_wave"] = best
	player["best_wave"] = best
	is_onboarded = bool(data.get("is_onboarded", is_onboarded))


## Returns a wallet balance with a safe int conversion (read only).
func get_balance(kind: StringName) -> int:
	return maxi(int(wallet.get(String(kind), 0)), 0)


## True when a QA/debug unlock was granted for `unlock_id`.
func has_extra_unlock(unlock_id: StringName) -> bool:
	return bool(unlocks.get(String(unlock_id), false))


## Records a QA/debug unlock flag. Gameplay gates use UnlockService.
func grant_extra_unlock(unlock_id: StringName) -> void:
	var key := String(unlock_id)
	if key.is_empty() or bool(unlocks.get(key, false)):
		return
	unlocks[key] = true


## Grants a RewardBundle exactly once per `run_id`. Returns false when the run was
## already paid (or the bundle is empty), so a re-shown summary cannot double-pay.
func claim_run_reward(run_id: String) -> bool:
	return reward_ledger.claim(run_id)


## Applies a bundle through WalletService (currencies + xp) and returns true.
func grant_bundle(bundle: RewardBundle, source: StringName = &"reward") -> bool:
	if bundle == null or bundle.is_empty():
		return false
	return WalletService.add_bundle(bundle, source)


## Updates lifetime stats and the best wave after a run.
func record_run_end(waves: int, kills: int, elapsed_seconds: float) -> void:
	stats["runs_played"] = int(stats.get("runs_played", 0)) + 1
	stats["total_kills"] = int(stats.get("total_kills", 0)) + maxi(kills, 0)
	stats["total_playtime"] = int(stats.get("total_playtime", 0)) + maxi(int(roundf(elapsed_seconds)), 0)
	if waves > int(stats.get("best_wave", 0)):
		stats["best_wave"] = waves
		player["best_wave"] = waves


## Increments the "Next wave" skip counter used by TapGuard (first 3 need a hold).
func record_next_wave_use() -> void:
	player["next_wave_uses"] = int(player.get("next_wave_uses", 0)) + 1


func get_next_wave_uses() -> int:
	return int(player.get("next_wave_uses", 0))


func get_best_wave() -> int:
	return int(stats.get("best_wave", player.get("best_wave", 0)))


func _merge_keys(target: Dictionary, source: Dictionary) -> void:
	for key: String in target.keys():
		if not source.has(key):
			continue
		var current: Variant = target[key]
		var incoming: Variant = source[key]
		if current is String:
			target[key] = str(incoming)
		elif current is int:
			target[key] = int(incoming)
		else:
			target[key] = incoming
