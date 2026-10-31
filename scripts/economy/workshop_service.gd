## WorkshopService — permanent coin upgrades (spec 6.3), the live singleton.
##
## Owns the WorkshopModel (24 data tracks, cost curve, level cap) and is the only
## path that spends coins on it: the wallet transaction happens in WalletService,
## then the level is recorded and the aggregated effects are published to
## ModifierService as one source id. Battle code reads ModifierService only.
extends Node

const SOURCE_ID := &"workshop"

var _model: WorkshopModel


func _ready() -> void:
	init_service()


## Loads tracks and restores saved levels. Called by App after GameState.
func init_service(saved_levels: Dictionary = {}) -> void:
	_model = WorkshopModel.new()
	_model.setup(WorkshopModel.load_tracks(), saved_levels)
	_apply_modifiers()


func get_model() -> WorkshopModel:
	return _model


func get_tracks() -> Array[WorkshopTrack]:
	return _model.get_tracks()


func get_tracks_in(category: StringName) -> Array[WorkshopTrack]:
	return _model.get_tracks_in(category)


func get_track(track_id: StringName) -> WorkshopTrack:
	return _model.get_track(track_id)


func level_of(track_id: StringName) -> int:
	return _model.level_of(track_id)


## Next-level coin cost, or 0 when maxed/unknown.
func cost_of(track_id: StringName) -> int:
	return _model.cost_of(track_id)


func total_of(track_id: StringName) -> float:
	return _model.total_of(track_id)


func is_maxed(track_id: StringName) -> bool:
	return _model.is_maxed(track_id)


func can_buy(track_id: StringName) -> SpendResult:
	return _model.can_buy(track_id, WalletService.get_balance(&"coins"))


## Buys one level: eligibility -> coin spend -> level record -> modifiers.
func try_buy(track_id: StringName) -> SpendResult:
	var check := can_buy(track_id)
	if not check.is_ok():
		return check
	var spent := WalletService.try_spend(&"coins", check.amount, &"workshop")
	if not spent.is_ok():
		return spent
	if not _model.record_purchase(track_id):
		WalletService.add_currency(&"coins", check.amount, &"workshop_refund")
		return SpendResult.failure(SpendResult.Code.MAX_LEVEL, "workshop.max_level", check.amount, spent.balance)
	_apply_modifiers()
	SaveService.request_save()
	return spent


func to_dict() -> Dictionary:
	return _model.get_levels()


## Debug/tooling: resets every level to 0 and removes the modifier source.
func reset() -> void:
	if _model == null:
		return
	_model.setup(WorkshopModel.load_tracks())
	_apply_modifiers()


func _apply_modifiers() -> void:
	var entries := _model.modifier_entries()
	if entries.is_empty():
		ModifierService.remove_source(SOURCE_ID)
	else:
		ModifierService.add_source(SOURCE_ID, entries)
