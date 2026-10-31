## GameState — the player's persistent meta profile (autoload).
##
## Runtime model only: no disk access. App loads SaveService data at boot and
## hands it to from_dict(); to_dict() is exactly the payload SaveService writes.
extends Node

var player: Dictionary = {
	"id": "",
	"nickname": "",
	"avatar_id": "avatar_01",
	"level": 1,
	"xp": 0,
}

var wallet: Dictionary = {
	"coins": 0,
	"gems": 0,
	"stones": 0,
}

var is_onboarded: bool = false


## Serialises the profile into a plain dictionary.
func to_dict() -> Dictionary:
	return {
		"player": player.duplicate(true),
		"wallet": wallet.duplicate(true),
		"is_onboarded": is_onboarded,
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

	is_onboarded = bool(data.get("is_onboarded", is_onboarded))


## Returns a wallet balance with a safe int conversion.
func get_balance(kind: StringName) -> int:
	return int(wallet.get(String(kind), 0))


## Applies a wallet balance and notifies listeners.
func set_balance(kind: StringName, amount: int) -> void:
	var key := String(kind)
	if not wallet.has(key):
		push_warning("GameState: unknown currency '%s'" % key)
		return
	wallet[key] = maxi(amount, 0)
	EventBus.currency_changed.emit(kind, int(wallet[key]))
