## GameState — the player's persistent meta profile (autoload).
##
## Runtime model only: no disk access. App loads SaveService data at boot and
## hands it to from_dict(); to_dict() is exactly the payload SaveService writes.
## Meta rewards enter through grant_bundle() (a RewardBundle), and run rewards are
## idempotent through `reward_ledger` keyed by run id. WalletService proper lands
## in M4; until then this is the one meta-wallet mutation point.
extends Node

var player: Dictionary = {
	"id": "",
	"nickname": "",
	"avatar_id": "avatar_01",
	"level": 1,
	"xp": 0,
	"best_wave": 0,
	"next_wave_uses": 0,
}

var wallet: Dictionary = {
	"coins": 0,
	"gems": 0,
	"stones": 0,
}

## Feature unlock flags, e.g. &"speed_1_5". M4 replaces this with data levels.
var unlocks: Dictionary = {}

## Last 50 meta-wallet grants, for support/debug (spec 6.1).
var wallet_log: Array[Dictionary] = []

## Run ids whose rewards were already granted (reward-bundle idempotency).
var reward_ledger := RewardLedger.new()

var is_onboarded: bool = false


## Serialises the profile into a plain dictionary.
func to_dict() -> Dictionary:
	return {
		"player": player.duplicate(true),
		"wallet": wallet.duplicate(true),
		"unlocks": unlocks.duplicate(true),
		"is_onboarded": is_onboarded,
		"applied_rewards": reward_ledger.to_array(),
		"wallet_log": wallet_log.duplicate(true),
	}


## Restores known fields from a save payload. Missing fields keep defaults, so
## older or partial saves never wipe the profile.
func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return

	var stored_player: Variant = data.get("player", null)
	if stored_player is Dictionary:
		var player_data := stored_player as Dictionary
		for key: String in player.keys():
			if player_data.has(key):
				player[key] = player_data[key]

	var stored_wallet: Variant = data.get("wallet", null)
	if stored_wallet is Dictionary:
		var wallet_data := stored_wallet as Dictionary
		for key: String in wallet.keys():
			if wallet_data.has(key):
				wallet[key] = int(wallet_data[key])

	var stored_unlocks: Variant = data.get("unlocks", null)
	if stored_unlocks is Dictionary:
		unlocks = (stored_unlocks as Dictionary).duplicate(true)

	var stored_rewards: Variant = data.get("applied_rewards", null)
	if stored_rewards is Array:
		reward_ledger.from_array(stored_rewards as Array)

	var stored_log: Variant = data.get("wallet_log", null)
	if stored_log is Array:
		wallet_log.clear()
		for entry in stored_log as Array:
			if entry is Dictionary:
				wallet_log.append((entry as Dictionary).duplicate(true))
		while wallet_log.size() > 50:
			wallet_log.remove_at(0)

	is_onboarded = bool(data.get("is_onboarded", is_onboarded))


## Returns a wallet balance with a safe int conversion.
func get_balance(kind: StringName) -> int:
	return int(wallet.get(String(kind), 0))


## Applies a wallet balance and notifies listeners (meta currencies only).
func set_balance(kind: StringName, amount: int) -> void:
	var key := String(kind)
	if not wallet.has(key):
		push_warning("GameState: unknown currency '%s'" % key)
		return
	wallet[key] = maxi(amount, 0)
	EventBus.currency_changed.emit(kind, int(wallet[key]))


## Returns true when a feature flag was explicitly unlocked.
func is_unlocked(unlock_id: StringName) -> bool:
	return bool(unlocks.get(String(unlock_id), false))


## Enables a feature flag once and notifies listeners.
func unlock(unlock_id: StringName) -> void:
	var key := String(unlock_id)
	if key.is_empty() or bool(unlocks.get(key, false)):
		return
	unlocks[key] = true
	EventBus.currency_changed.emit(&"unlock", 1)


## Grants a RewardBundle exactly once per `run_id`. Returns false when the run was
## already paid (or the bundle is empty), so a re-shown summary cannot double-pay.
func claim_run_reward(run_id: String) -> bool:
	return reward_ledger.claim(run_id)


## Applies a bundle to the meta wallet and XP, logs it and emits currency changes.
func grant_bundle(bundle: RewardBundle, source: StringName = &"reward") -> bool:
	if bundle == null or bundle.is_empty():
		return false
	bundle.apply_to(wallet, player)
	wallet_log.append({
		"source": String(source),
		"bundle": bundle.to_dict(),
	})
	if wallet_log.size() > 50:
		wallet_log.remove_at(0)
	for kind in [&"coins", &"gems", &"stones"]:
		EventBus.currency_changed.emit(kind, get_balance(kind))
	return true


## Increments the "Next wave" skip counter used by TapGuard (first 3 need a hold).
func record_next_wave_use() -> void:
	player["next_wave_uses"] = int(player.get("next_wave_uses", 0)) + 1


func get_next_wave_uses() -> int:
	return int(player.get("next_wave_uses", 0))
