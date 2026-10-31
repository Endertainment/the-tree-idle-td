## MagicaModel — pure research state for the 12 Magica nodes (spec 6.4).
##
## Owns prerequisites, the single active research, offline completion and cancel
## refunds. Nothing here touches the wallet or ModifierService; MagicaService buys
## the node, records the result here and publishes completed effects.
class_name MagicaModel
extends RefCounted

const CANCEL_REFUND := 0.5

var _nodes: Array[MagicaNode] = []
var _research: Dictionary = {}
var _completed: Array[StringName] = []
var _pending: StringName = &""


## Replaces the node pool and restores a saved state dictionary.
func setup(nodes: Array[MagicaNode], state: Dictionary = {}) -> void:
	_nodes = nodes
	_research = {}
	_completed.clear()
	_pending = &""

	var stored_research: Variant = state.get("research", {})
	if stored_research is Dictionary and not (stored_research as Dictionary).is_empty():
		var research := stored_research as Dictionary
		var research_id := StringName(str(research.get("node_id", "")))
		if get_node_by_id(research_id) != null:
			_research = {
				"node_id": String(research_id),
				"started_at": int(research.get("started_at", 0)),
				"ends_at": int(research.get("ends_at", 0)),
			}

	var stored_completed: Variant = state.get("completed", [])
	if stored_completed is Array:
		for entry: Variant in stored_completed as Array:
			var completed_id := StringName(str(entry))
			if get_node_by_id(completed_id) != null and not _completed.has(completed_id):
				_completed.append(completed_id)

	var stored_pending := StringName(str(state.get("pending_claim", "")))
	if stored_pending != &"" and get_node_by_id(stored_pending) != null and not _completed.has(stored_pending):
		_pending = stored_pending


func get_nodes() -> Array[MagicaNode]:
	return _nodes


func nodes_in_branch(branch: StringName) -> Array[MagicaNode]:
	var result: Array[MagicaNode] = []
	for node: MagicaNode in _nodes:
		if node.branch == branch:
			result.append(node)
	return result


func get_node_by_id(node_id: StringName) -> MagicaNode:
	for node: MagicaNode in _nodes:
		if node.id == node_id:
			return node
	return null


func is_completed(node_id: StringName) -> bool:
	return _completed.has(node_id)


func completed_ids() -> Array[StringName]:
	return _completed.duplicate()


func get_research() -> Dictionary:
	return _research.duplicate()


func has_active_research() -> bool:
	return not _research.is_empty()


func active_node_id() -> StringName:
	return StringName(str(_research.get("node_id", "")))


func get_pending_claim() -> StringName:
	return _pending


func has_pending_claim() -> bool:
	return _pending != &""


## Missing prerequisites for `node_id` (empty when ready).
func missing_prerequisites(node_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var node := get_node_by_id(node_id)
	if node == null:
		return result
	for requirement: StringName in node.requires:
		if not is_completed(requirement):
			result.append(requirement)
	return result


## A node can start when it is known, not completed/pending, all prerequisites are
## completed and no other research is running.
func is_available(node_id: StringName) -> bool:
	var node := get_node_by_id(node_id)
	if node == null or is_completed(node_id) or _pending == node_id:
		return false
	if not _research.is_empty():
		return false
	return missing_prerequisites(node_id).is_empty()


## Reason code for a node that cannot start (`""` when available).
func block_reason(node_id: StringName) -> String:
	var node := get_node_by_id(node_id)
	if node == null:
		return "unknown"
	if is_completed(node_id):
		return "completed"
	if _pending == node_id:
		return "claim"
	if not _research.is_empty():
		return "busy"
	if not missing_prerequisites(node_id).is_empty():
		return "prerequisites"
	return ""


## Starts research. `speed` divides the authored duration (1.3 = +30 % faster).
## Returns {ok, node, started_at, ends_at, duration} or {ok=false, reason}.
func start(node_id: StringName, now_unix: int, speed: float = 1.0) -> Dictionary:
	var node := get_node_by_id(node_id)
	if node == null or not is_available(node_id):
		return {"ok": false, "reason": block_reason(node_id)}
	var duration := maxi(1, int(round(float(node.duration_seconds) / maxf(speed, 0.1))))
	_research = {
		"node_id": String(node_id),
		"started_at": now_unix,
		"ends_at": now_unix + duration,
	}
	return {
		"ok": true,
		"node": node,
		"started_at": now_unix,
		"ends_at": now_unix + duration,
		"duration": duration,
	}


## Marks research finished when `now_unix` reached the stored end timestamp. The
## result becomes claimable (a badge), and the effect is applied on claim().
func reconcile(now_unix: int) -> bool:
	if _research.is_empty():
		return false
	var ends_at := int(_research.get("ends_at", 0))
	if now_unix < ends_at:
		return false
	_pending = StringName(str(_research.get("node_id", "")))
	_research = {}
	return true


## Rewarded speed-up: moves the finish line earlier by `seconds` (never before
## now). Completes the research when the new end is reached immediately.
func speed_up(now_unix: int, seconds: int) -> bool:
	if _research.is_empty():
		return false
	var ends_at := int(_research.get("ends_at", 0))
	_research["ends_at"] = maxi(ends_at - maxi(seconds, 0), now_unix)
	reconcile(now_unix)
	return true


## Claims the pending research into `completed`. Returns the node id or &"".
func claim() -> StringName:
	if _pending == &"":
		return &""
	var claimed := _pending
	_pending = &""
	if not _completed.has(claimed):
		_completed.append(claimed)
	return claimed


## Cancels the active research and returns the 50 % refund per currency.
func cancel() -> Dictionary:
	if _research.is_empty():
		return {}
	var node := get_node_by_id(StringName(str(_research.get("node_id", ""))))
	_research = {}
	if node == null:
		return {}
	return {
		"coins": int(floor(float(node.coin_cost) * CANCEL_REFUND)),
		"gems": int(floor(float(node.gem_cost) * CANCEL_REFUND)),
	}


## Seconds left on the active research (0 when idle).
func remaining_seconds(now_unix: int) -> int:
	if _research.is_empty():
		return 0
	return maxi(int(_research.get("ends_at", 0)) - now_unix, 0)


## 0..1 completion of the active research.
func progress(now_unix: int) -> float:
	if _research.is_empty():
		return 0.0
	var started := int(_research.get("started_at", 0))
	var ends := int(_research.get("ends_at", started + 1))
	var total := maxi(ends - started, 1)
	return clampf(float(now_unix - started) / float(total), 0.0, 1.0)


## ModifierService source entries for one completed node.
func node_entries(node_id: StringName) -> Dictionary:
	var node := get_node_by_id(node_id)
	if node == null:
		return {}
	return ModifierBuilder.entries_from(node.effects)


## Save-shaped state (research, completed and the M4b pending-claim extra).
func to_state() -> Dictionary:
	var completed: Array[String] = []
	for node_id: StringName in _completed:
		completed.append(String(node_id))
	return {
		"research": _research.duplicate(true),
		"completed": completed,
		"pending_claim": String(_pending),
	}
