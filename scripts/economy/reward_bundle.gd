## RewardBundle — one typed payload for every reward source (spec 6.1).
##
## Run summary, missions, ads and IAP all build a bundle and hand it to the meta
## wallet path, so there is exactly one UI animation and one idempotency guard.
## apply_to() mutates plain dictionaries, which keeps the class pure and testable
## without autoloads; GameState passes its own wallet/player dictionaries.
class_name RewardBundle
extends RefCounted

var coins: int = 0
var gems: int = 0
var stones: int = 0
var cash: int = 0
var xp: int = 0
var cards: int = 0


## Builds the run-end bundle from the run rewards table.
static func for_run(waves_cleared: int, boss_waves: int = 0, is_new_best: bool = false) -> RewardBundle:
	var rewards := RunRewards.compute(waves_cleared, boss_waves, is_new_best)
	var bundle := RewardBundle.new()
	bundle.coins = int(rewards["coins"])
	bundle.gems = int(rewards["gems"])
	bundle.xp = int(rewards["xp"])
	return bundle


## Coins-only bundle for the rewarded "Double coins" button.
static func coins_only(amount: int) -> RewardBundle:
	var bundle := RewardBundle.new()
	bundle.coins = maxi(amount, 0)
	return bundle


static func from_dict(data: Dictionary) -> RewardBundle:
	var bundle := RewardBundle.new()
	bundle.coins = int(data.get("coins", 0))
	bundle.gems = int(data.get("gems", 0))
	bundle.stones = int(data.get("stones", 0))
	bundle.cash = int(data.get("cash", 0))
	bundle.xp = int(data.get("xp", 0))
	bundle.cards = int(data.get("cards", 0))
	return bundle


func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"gems": gems,
		"stones": stones,
		"cash": cash,
		"xp": xp,
		"cards": cards,
	}


func is_empty() -> bool:
	return coins <= 0 and gems <= 0 and stones <= 0 and cash <= 0 and xp <= 0 and cards <= 0


## Applies positive amounts only (spec: `amount > 0` guard everywhere).
func apply_to(wallet: Dictionary, player: Dictionary) -> void:
	if coins > 0:
		wallet["coins"] = int(wallet.get("coins", 0)) + coins
	if gems > 0:
		wallet["gems"] = int(wallet.get("gems", 0)) + gems
	if stones > 0:
		wallet["stones"] = int(wallet.get("stones", 0)) + stones
	if xp > 0:
		player["xp"] = int(player.get("xp", 0)) + xp
	# Cash is run-only and never converted; the field exists so bundles share one
	# schema, but run-end bundles leave it at 0 and it is not applied to a wallet.
