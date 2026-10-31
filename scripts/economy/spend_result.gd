## SpendResult — typed outcome of one run-cash transaction.
##
## Every purchase path returns one of these instead of a bare bool, so the UI can
## show a reason and a test can assert why a purchase failed. Pure data: no
## autoload access, safe to construct from headless unit tests.
class_name SpendResult
extends RefCounted

enum Code {
	OK,
	INSUFFICIENT_FUNDS,
	INVALID_AMOUNT,
	MAX_LEVEL,
}

## Machine code used by callers and tests.
var code: Code = Code.OK
## Amount the transaction asked to spend (0 for a free or failed lookup).
var amount: int = 0
## Balance after the transaction (unchanged on failure).
var balance: int = 0
## Localisation key for the disabled-row reason ("" on success).
var reason_key: String = ""


func is_ok() -> bool:
	return code == Code.OK


static func success(p_amount: int, p_balance: int) -> SpendResult:
	var result := SpendResult.new()
	result.code = Code.OK
	result.amount = p_amount
	result.balance = p_balance
	return result


static func failure(p_code: Code, p_reason_key: String, p_amount: int, p_balance: int) -> SpendResult:
	var result := SpendResult.new()
	result.code = p_code
	result.amount = p_amount
	result.balance = p_balance
	result.reason_key = p_reason_key
	return result
