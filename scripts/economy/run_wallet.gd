## RunWallet — the only mutation point for in-run cash.
##
## BattleController owns one wallet per run and mirrors its balance into
## RunState.cash for read-only consumers/tests. Nothing else may write cash:
## all gains go through add(), all spends through try_spend(), and both append to
## a bounded transaction log for support/debug. Cash never converts to coins.
class_name RunWallet
extends RefCounted

const MAX_LOG_ENTRIES := 50

var _cash: int = 0
var _log: Array[Dictionary] = []


func _init(starting_cash: int = 0) -> void:
	_cash = maxi(starting_cash, 0)


func get_cash() -> int:
	return _cash


func can_afford(amount: int) -> bool:
	return amount >= 0 and _cash >= amount


## Adds cash from a legitimate source (kill, wave clear, skip bonus, sell).
## Rejects non-positive amounts so a reward path can never subtract by mistake.
func add(amount: int, reason: StringName = &"grant") -> SpendResult:
	if amount <= 0:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "wallet.invalid_amount", amount, _cash)
	_cash += amount
	_record(amount, reason)
	return SpendResult.success(amount, _cash)


## Atomically spends `amount`. Returns INSUFFICIENT_FUNDS (and changes nothing)
## when the balance is too low, so hold-to-buy can stop on a typed result.
func try_spend(amount: int, reason: StringName = &"spend") -> SpendResult:
	if amount <= 0:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "wallet.invalid_amount", amount, _cash)
	if _cash < amount:
		return SpendResult.failure(SpendResult.Code.INSUFFICIENT_FUNDS, "battle.not_enough_cash", amount, _cash)
	_cash -= amount
	_record(-amount, reason)
	return SpendResult.success(amount, _cash)


## Returns the most recent transactions, newest last (bounded at 50).
func get_log() -> Array[Dictionary]:
	return _log.duplicate(true)


func _record(delta: int, reason: StringName) -> void:
	_log.append({"delta": delta, "balance": _cash, "reason": String(reason)})
	if _log.size() > MAX_LOG_ENTRIES:
		_log.remove_at(0)
