## ApiQueue — persisted offline operation queue (spec 8.4).
##
## Pure data model plus JSON file persistence, so the queue survives a restart
## and can be tested without a socket. Operations are retried at most
## MAX_ATTEMPTS times and de-duplicated by idempotency key.
class_name ApiQueue
extends RefCounted

const MAX_OPS := 100
const MAX_ATTEMPTS := 5

var ops: Array[Dictionary] = []


## Builds a queue entry for a mutating call.
static func make_op(
	method: StringName,
	path: String,
	body: Dictionary,
	idempotency_key: String,
	now_unix: int
) -> Dictionary:
	return {
		"method": String(method).to_upper(),
		"path": path,
		"body": body.duplicate(true),
		"idempotency_key": idempotency_key,
		"attempts": 0,
		"created_at": now_unix,
	}


## Adds an operation. Returns false when the key is already queued or full.
func enqueue(op: Dictionary) -> bool:
	if not _is_valid(op):
		return false
	var key := str(op.get("idempotency_key", ""))
	if not key.is_empty():
		for existing: Dictionary in ops:
			if str(existing.get("idempotency_key", "")) == key:
				return false
	if ops.size() >= MAX_OPS:
		return false
	ops.append(_normalize(op))
	return true


func size() -> int:
	return ops.size()


func is_empty() -> bool:
	return ops.is_empty()


func peek() -> Dictionary:
	return {} if ops.is_empty() else ops[0].duplicate(true)


func pop_front() -> Dictionary:
	if ops.is_empty():
		return {}
	return ops.pop_front()


## Records a failed attempt. Returns true while the op should be retried,
## false when it was dropped after MAX_ATTEMPTS.
func mark_failure(op: Dictionary) -> bool:
	var key := str(op.get("idempotency_key", ""))
	var index := -1
	for i in ops.size():
		if str(ops[i].get("idempotency_key", "")) == key and key != "":
			index = i
			break
	if index < 0:
		return false
	var attempts := int(ops[index].get("attempts", 0)) + 1
	ops[index]["attempts"] = attempts
	if attempts >= MAX_ATTEMPTS:
		ops.remove_at(index)
		return false
	return true


func clear() -> void:
	ops.clear()


func to_array() -> Array:
	return ops.duplicate(true)


## Restores operations from decoded JSON (array or {"ops": [...]}).
func from_array(data: Variant) -> void:
	ops.clear()
	var source: Array = []
	if data is Array:
		source = data
	elif data is Dictionary and (data as Dictionary).get("ops", null) is Array:
		source = (data as Dictionary)["ops"]
	for entry: Variant in source:
		if entry is Dictionary and _is_valid(entry as Dictionary):
			ops.append(_normalize(entry as Dictionary))
			if ops.size() >= MAX_OPS:
				break


func save_to_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("ApiQueue: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify({"ops": ops}, "\t"))
	file.close()
	return true


func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return false
	from_array(parsed)
	return true


func _is_valid(op: Dictionary) -> bool:
	var method := str(op.get("method", "")).to_upper()
	var path := str(op.get("path", ""))
	return (
		["POST", "PUT", "PATCH", "DELETE"].has(method)
		and path.begins_with("/")
		and (op.get("body", {}) is Dictionary)
	)


func _normalize(op: Dictionary) -> Dictionary:
	return {
		"method": str(op.get("method", "POST")).to_upper(),
		"path": str(op.get("path", "/")),
		"body": (op.get("body", {}) as Dictionary).duplicate(true),
		"idempotency_key": str(op.get("idempotency_key", "")),
		"attempts": clampi(int(op.get("attempts", 0)), 0, MAX_ATTEMPTS),
		"created_at": int(op.get("created_at", 0)),
	}
