## MetaWallet — pure persistent-currency logic (coins, gems, stones), spec 6.1.
##
## Holds a reference to the profile's `wallet` dictionary so GameState stays the
## storage owner while WalletService (autoload) is the only mutation path. Every
## accepted mutation appends to a bounded transaction log; rejected ones do not.
## No autoload access: unit tests instantiate it directly.
class_name MetaWallet
extends RefCounted

const MAX_LOG_ENTRIES := 50
const CURRENCIES: Array[StringName] = [&"coins", &"gems", &"stones"]


var _balances: Dictionary
var _log: Array[Dictionary] = []


func _init(balances: Dictionary) -> void:
	_balances = balances


## Rebinds to a new wallet dictionary (profiles/tests replace the dictionary).
func bind(balances: Dictionary) -> void:
	_balances = balances


func get_balances() -> Dictionary:
	return _balances


func get_balance(kind: StringName) -> int:
	return maxi(int(_balances.get(String(kind), 0)), 0)


## Adds `amount` from a legitimate source. Rejects unknown currencies and
## non-positive amounts so a reward path can never subtract by mistake.
func add(kind: StringName, amount: int, reason: StringName = &"grant", at_unix: int = 0) -> SpendResult:
	if not CURRENCIES.has(kind):
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "wallet.unknown_currency", amount, 0)
	if amount <= 0:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "wallet.invalid_amount", amount, get_balance(kind))
	var key := String(kind)
	var balance := get_balance(kind) + amount
	_balances[key] = balance
	_record(kind, amount, reason, balance, at_unix)
	return SpendResult.success(amount, balance)


## Atomically spends `amount`. The balance can never go negative.
func try_spend(kind: StringName, amount: int, reason: StringName = &"spend", at_unix: int = 0) -> SpendResult:
	if not CURRENCIES.has(kind):
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "wallet.unknown_currency", amount, 0)
	if amount <= 0:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "wallet.invalid_amount", amount, get_balance(kind))
	var current := get_balance(kind)
	if current < amount:
		return SpendResult.failure(
			SpendResult.Code.INSUFFICIENT_FUNDS, "wallet.not_enough_%s" % kind, amount, current
		)
	var balance := current - amount
	_balances[String(kind)] = balance
	_record(kind, -amount, reason, balance, at_unix)
	return SpendResult.success(amount, balance)


## Applies every positive field of a RewardBundle to the wallet. Returns the list
## of currencies that actually changed, so the caller can emit one signal each.
func add_bundle(bundle: RewardBundle, reason: StringName = &"reward", at_unix: int = 0) -> Array[StringName]:
	var changed: Array[StringName] = []
	if bundle == null:
		return changed
	for kind: StringName in CURRENCIES:
		var amount := 0
		match kind:
			&"coins":
				amount = bundle.coins
			&"gems":
				amount = bundle.gems
			&"stones":
				amount = bundle.stones
		if amount > 0 and add(kind, amount, reason, at_unix).is_ok():
			changed.append(kind)
	return changed


func get_log() -> Array[Dictionary]:
	return _log.duplicate(true)


func clear_log() -> void:
	_log.clear()


func _record(kind: StringName, delta: int, reason: StringName, balance: int, at_unix: int) -> void:
	_log.append({
		"kind": String(kind),
		"delta": delta,
		"balance": balance,
		"reason": String(reason),
		"at": at_unix,
	})
	if _log.size() > MAX_LOG_ENTRIES:
		_log.remove_at(0)
