## RewardLedger — idempotency guard for run rewards, keyed by run id.
##
## A run summary can be re-shown (scene reload, retry, accidental re-setup); the
## ledger makes the bundle grant exactly once. Bounded to the last 50 ids so the
## save does not grow forever. Pure: the save payload owns persistence.
class_name RewardLedger
extends RefCounted

const MAX_ENTRIES := 50

var _run_ids: Array[String] = []


func has(run_id: String) -> bool:
	return _run_ids.has(run_id)


## Records `run_id` and returns true when it is new; false when already claimed.
func claim(run_id: String) -> bool:
	if run_id.is_empty() or _run_ids.has(run_id):
		return false
	_run_ids.append(run_id)
	if _run_ids.size() > MAX_ENTRIES:
		_run_ids.remove_at(0)
	return true


func size() -> int:
	return _run_ids.size()


func to_array() -> Array:
	return _run_ids.duplicate()


func from_array(values: Array) -> void:
	_run_ids.clear()
	for value: Variant in values:
		if _run_ids.size() >= MAX_ENTRIES:
			break
		var text := str(value)
		if not text.is_empty() and not _run_ids.has(text):
			_run_ids.append(text)
