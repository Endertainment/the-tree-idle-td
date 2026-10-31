## WalletService — the only mutation point for permanent currencies (autoload).
##
## Coins, gems and stones live in `GameState.wallet`; this service wraps the pure
## MetaWallet (typed SpendResult, <=50-entry log, amount > 0 guard) and adds the
## runtime concerns: EventBus notifications, save-on-mutation and xp delegation.
## Nothing else in the game may write coins/gems/stones directly.
extends Node

var _wallet: MetaWallet


func _ready() -> void:
	init_service()


## Binds the wallet to the loaded GameState profile. Safe to call more than once.
func init_service() -> void:
	_wallet = MetaWallet.new(GameState.wallet)


## Reattaches if a tool/test replaced the wallet dictionary. Returns the wallet.
func get_wallet() -> MetaWallet:
	if _wallet == null or not is_same(_wallet.get_balances(), GameState.wallet):
		_wallet = MetaWallet.new(GameState.wallet)
	return _wallet


func get_balance(kind: StringName) -> int:
	return get_wallet().get_balance(kind)


## Grants permanent currency and notifies listeners. Saves (debounced).
func add_currency(kind: StringName, amount: int, reason: StringName = &"grant") -> SpendResult:
	var result := get_wallet().add(kind, amount, reason, TimeService.now_unix())
	if result.is_ok():
		if kind == &"coins":
			_track_coins_earned(amount)
		EventBus.currency_changed.emit(kind, result.balance)
		SaveService.request_save()
	return result


## Spec 6.1 entry point: every reward source is a RewardBundle. Returns true when
## the bundle changed the wallet or granted XP.
func add(bundle: RewardBundle, source: StringName = &"reward") -> bool:
	return add_bundle(bundle, source)


## Atomically spends permanent currency. Emits meta_purchased and saves.
func try_spend(kind: StringName, amount: int, reason: StringName = &"spend") -> SpendResult:
	var result := get_wallet().try_spend(kind, amount, reason, TimeService.now_unix())
	if result.is_ok():
		EventBus.currency_changed.emit(kind, result.balance)
		EventBus.meta_purchased.emit(kind, result.amount, reason)
		SaveService.request_save()
	return result


## Applies a RewardBundle to the wallet and XP. Returns true when anything landed.
func add_bundle(bundle: RewardBundle, source: StringName = &"reward") -> bool:
	if bundle == null:
		return false
	var changed := get_wallet().add_bundle(bundle, source, TimeService.now_unix())
	for kind: StringName in changed:
		EventBus.currency_changed.emit(kind, get_balance(kind))
	if changed.has(&"coins"):
		_track_coins_earned(bundle.coins)
	if bundle.xp > 0:
		LevelService.add_xp(bundle.xp)
	if not changed.is_empty() or bundle.xp > 0:
		SaveService.request_save()
		return true
	return false


## Last 50 accepted transactions (support/debug), newest last.
func get_log() -> Array[Dictionary]:
	return get_wallet().get_log()


## Lifetime counter used by the profile screen (old saves default to the current
## balance through ProfileStats).
func _track_coins_earned(amount: int) -> void:
	if amount <= 0:
		return
	var current := int(GameState.stats.get("coins_earned", -1))
	GameState.stats["coins_earned"] = amount if current < 0 else current + amount


## Debug/tooling reset: rebinds to the current GameState wallet dictionary.
func reset() -> void:
	_wallet = MetaWallet.new(GameState.wallet)
