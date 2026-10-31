## ApiResult — typed result of one API call (spec 8.4).
##
## `ok` is true only for a 2xx response with a JSON object body. `error_code`
## is the server's `detail.code` for 4xx/5xx, or a transport code
## (`network_error`, `timeout`, `cancelled`, `queued_offline`).
class_name ApiResult
extends RefCounted

var ok: bool = false
var status: int = 0
var data: Dictionary = {}
var error_code: StringName = &""
var message: String = ""
var retryable: bool = false
var queued: bool = false


static func success(status_code: int, body: Dictionary) -> ApiResult:
	var result := ApiResult.new()
	result.ok = true
	result.status = status_code
	result.data = body
	return result


static func failure(
	status_code: int, code: StringName, detail: String = "", can_retry: bool = false
) -> ApiResult:
	var result := ApiResult.new()
	result.ok = false
	result.status = status_code
	result.error_code = code
	result.message = detail
	result.retryable = can_retry
	return result


## Conflict (revision/idempotency) responses carry the server copy in `detail`.
func is_conflict() -> bool:
	return status == 409


func conflict_detail() -> Dictionary:
	var detail: Variant = data.get("detail", {})
	return detail as Dictionary if detail is Dictionary else {}


func server_save() -> Dictionary:
	var detail := conflict_detail()
	var server: Variant = detail.get("server", {})
	return server as Dictionary if server is Dictionary else {}


func describe() -> String:
	if ok:
		return "ok(%d)" % status
	return "%s(%d): %s" % [String(error_code), status, message]
