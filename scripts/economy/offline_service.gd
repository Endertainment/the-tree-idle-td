## OfflineService — "while you were away" coin income (spec 6.1 + M4b).
##
## Computes the `now - last_seen_at` delta on boot, clamps it to the Offline Cap
## (8 h base + the workshop track) and stores a pending reward. The menu shows the
## Welcome back modal; claiming routes through WalletService. `last_seen_at` is
## refreshed on pause/close so the next boot measures only the time actually away.
extends Node

signal offline_ready(pending: Dictionary)
signal offline_claimed(coins: int)

var _pending: Dictionary = {}


func _ready() -> void:
	set_process(false)


## Called by App after GameState/settings/services exist. Safe to call more than once.
func init_service(_save_data: Dictionary = {}) -> void:
	_pending = {}
	var now := TimeService.now_unix()
	var last_seen := int(GameState.player.get("last_seen_at", 0))
	var rate := maxf(ModifierService.get_stat(&"offline_coin_rate", 1.0), 0.0)
	var cap_minutes := maxf(ModifierService.get_stat(&"offline_cap_minutes", 0.0), 0.0)
	var result := OfflineModel.compute(last_seen, now, rate, cap_minutes)
	if bool(result.get("eligible", false)) and int(result.get("coins", 0)) > 0:
		_pending = result
	GameState.player["last_seen_at"] = now
	SaveService.request_save()
	if has_pending():
		offline_ready.emit(_pending)


func get_pending() -> Dictionary:
	return _pending.duplicate(true)


func has_pending() -> bool:
	return not _pending.is_empty() and int(_pending.get("coins", 0)) > 0


## Claims the pending offline coins into the wallet. Returns the amount granted.
func claim() -> int:
	if not has_pending():
		_pending = {}
		return 0
	var coins := int(_pending.get("coins", 0))
	_pending = {}
	WalletService.add_currency(&"coins", coins, &"offline")
	SaveService.request_save()
	offline_claimed.emit(coins)
	return coins


## Refreshes `last_seen_at` to now (pause/close and run end).
func update_last_seen() -> void:
	GameState.player["last_seen_at"] = TimeService.now_unix()
	SaveService.request_save()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT:
			update_last_seen()
			SaveService.flush()
