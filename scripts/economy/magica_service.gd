## MagicaService — the live research singleton (spec 6.4).
##
## One active research at a time, timestamps in UTC unix seconds, offline
## completion on boot/focus (the result becomes a claimable badge), a 50 % cancel
## refund and completed effects published to ModifierService as per-node sources.
## The wallet is only touched through WalletService.
extends Node

signal magica_changed
signal research_completed(node_id: StringName)

const SOURCE_PREFIX := &"magica:"
const SPEED_UP_SECONDS := 30 * 60

var _model: MagicaModel


func _ready() -> void:
	init_service(GameState.magica)


## Loads nodes and restores the saved research state. Safe to call again from App.
func init_service(saved_state: Dictionary = {}) -> void:
	_model = MagicaModel.new()
	_model.setup(MagicaNode.load_all(), saved_state)
	_sync_state()
	_apply_modifiers()
	reconcile(false)


func get_model() -> MagicaModel:
	_ensure_model()
	return _model


func get_nodes() -> Array[MagicaNode]:
	_ensure_model()
	return _model.get_nodes()


func nodes_in_branch(branch: StringName) -> Array[MagicaNode]:
	_ensure_model()
	return _model.nodes_in_branch(branch)


func get_node_by_id(node_id: StringName) -> MagicaNode:
	_ensure_model()
	return _model.get_node_by_id(node_id)


func is_completed(node_id: StringName) -> bool:
	_ensure_model()
	return _model.is_completed(node_id)


func is_available(node_id: StringName) -> bool:
	_ensure_model()
	return _model.is_available(node_id)


func missing_prerequisites(node_id: StringName) -> Array[StringName]:
	_ensure_model()
	return _model.missing_prerequisites(node_id)


func has_active_research() -> bool:
	_ensure_model()
	return _model.has_active_research()


func active_node_id() -> StringName:
	_ensure_model()
	return _model.active_node_id()


func has_pending_claim() -> bool:
	_ensure_model()
	return _model.has_pending_claim()


func pending_claim_id() -> StringName:
	_ensure_model()
	return _model.get_pending_claim()


func remaining_seconds() -> int:
	_ensure_model()
	return _model.remaining_seconds(TimeService.now_unix())


func progress() -> float:
	_ensure_model()
	return _model.progress(TimeService.now_unix())


func get_state() -> Dictionary:
	_ensure_model()
	return _model.to_state()


## Starts research: eligibility -> wallet spend -> model record -> save.
func try_start(node_id: StringName) -> SpendResult:
	_ensure_model()
	var node := _model.get_node_by_id(node_id)
	if node == null:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "magica.unknown_node", 0, WalletService.get_balance(&"coins"))
	if not _model.is_available(node_id):
		var reason := _model.block_reason(node_id)
		if reason == "completed":
			return SpendResult.failure(SpendResult.Code.MAX_LEVEL, "magica.completed", 0, WalletService.get_balance(&"coins"))
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "magica.%s" % reason, 0, WalletService.get_balance(&"coins"))

	if node.coin_cost > 0:
		var coin_result := WalletService.try_spend(&"coins", node.coin_cost, &"magica")
		if not coin_result.is_ok():
			return coin_result
	if node.gem_cost > 0:
		var gem_result := WalletService.try_spend(&"gems", node.gem_cost, &"magica")
		if not gem_result.is_ok():
			if node.coin_cost > 0:
				WalletService.add_currency(&"coins", node.coin_cost, &"magica_refund")
			return gem_result

	var speed := maxf(ModifierService.get_stat(&"magica_speed", 1.0), 0.1)
	var started := _model.start(node_id, TimeService.now_unix(), speed)
	if not bool(started.get("ok", false)):
		if node.coin_cost > 0:
			WalletService.add_currency(&"coins", node.coin_cost, &"magica_refund")
		if node.gem_cost > 0:
			WalletService.add_currency(&"gems", node.gem_cost, &"magica_refund")
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "magica.busy", 0, WalletService.get_balance(&"coins"))

	_sync_state()
	SaveService.request_save()
	magica_changed.emit()
	return SpendResult.success(node.coin_cost, WalletService.get_balance(&"coins"))


## Cancels research, refunding 50 % of each spent currency.
func cancel() -> Dictionary:
	_ensure_model()
	var refund := _model.cancel()
	if refund.is_empty():
		return {}
	if int(refund.get("coins", 0)) > 0:
		WalletService.add_currency(&"coins", int(refund["coins"]), &"magica_cancel")
	if int(refund.get("gems", 0)) > 0:
		WalletService.add_currency(&"gems", int(refund["gems"]), &"magica_cancel")
	_sync_state()
	SaveService.request_save()
	magica_changed.emit()
	return refund


## Claims a finished research; its effects become active immediately.
func claim() -> StringName:
	_ensure_model()
	var claimed := _model.claim()
	if claimed == &"":
		return &""
	_sync_state()
	_apply_modifiers()
	SaveService.request_save()
	magica_changed.emit()
	return claimed


## Boot/focus/UI tick: completes research whose UTC end timestamp has passed.
## Returns true when the state changed (the caller may save).
func reconcile(save: bool = true) -> bool:
	_ensure_model()
	if not _model.reconcile(TimeService.now_unix()):
		return false
	_sync_state()
	if save:
		SaveService.request_save()
	magica_changed.emit()
	research_completed.emit(_model.get_pending_claim())
	return true


## Rewarded-ad speed-up. Real ads arrive with M6; this stub refuses cleanly.
func speed_up(_seconds: int = SPEED_UP_SECONDS) -> bool:
	return false


## True when `stat` receives a nonzero modifier from any completed node.
func has_effect(stat: StringName) -> bool:
	_ensure_model()
	for node_id: StringName in _model.completed_ids():
		var node := _model.get_node_by_id(node_id)
		if node == null:
			continue
		for effect: ModifierData in node.effects:
			if effect != null and effect.stat == stat:
				return true
	return false


func to_dict() -> Dictionary:
	_ensure_model()
	return _model.to_state()


## Debug/tooling reset.
func reset() -> void:
	_model = MagicaModel.new()
	_model.setup(MagicaNode.load_all(), {})
	_sync_state()
	_apply_modifiers()
	magica_changed.emit()


func _ensure_model() -> void:
	if _model == null:
		init_service(GameState.magica)


func _sync_state() -> void:
	if _model == null:
		return
	GameState.magica = _model.to_state()


func _apply_modifiers() -> void:
	if _model == null:
		return
	ModifierService.remove_sources_with_prefix(SOURCE_PREFIX)
	for node_id: StringName in _model.completed_ids():
		var entries := _model.node_entries(node_id)
		if entries.is_empty():
			continue
		ModifierService.add_source(StringName(String(SOURCE_PREFIX) + String(node_id)), entries)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			reconcile()
