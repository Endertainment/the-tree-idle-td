## CardService — collection, loadout and drop singleton (spec 6.5).
##
## Owns the pure CardCollection, equips cards into 1-5 unlocked slots, rolls card
## drops on wave clears (8 % base + the workshop `card_drop_chance` track) and
## publishes the loadout as one `&"cards"` ModifierService source. Duplicates become
## shards and auto-upgrade.
extends Node

signal cards_changed
signal card_dropped(card_id: StringName)

const SOURCE_ID := &"cards"
const BASE_DROP_CHANCE := 0.08
const RARITY_WEIGHTS: Dictionary = {
	&"common": 60.0,
	&"rare": 25.0,
	&"epic": 12.0,
	&"legendary": 3.0,
}

var _collection: CardCollection
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Tools disable drops to isolate a simulation.
var drops_enabled: bool = true


func _ready() -> void:
	_rng.randomize()
	init_service(GameState.cards)
	EventBus.wave_cleared.connect(_on_wave_cleared)


func init_service(saved_state: Dictionary = {}) -> void:
	_collection = CardCollection.new()
	_collection.setup(CardData.load_all(), saved_state)
	_sync_state()
	_apply_modifiers()


func get_cards() -> Array[CardData]:
	_ensure_collection()
	return _collection.get_cards()


func get_card(card_id: StringName) -> CardData:
	_ensure_collection()
	return _collection.get_card(card_id)


func is_owned(card_id: StringName) -> bool:
	_ensure_collection()
	return _collection.is_owned(card_id)


func level_of(card_id: StringName) -> int:
	_ensure_collection()
	return _collection.level_of(card_id)


func shards_of(card_id: StringName) -> int:
	_ensure_collection()
	return _collection.shards_of(card_id)


func shard_cost(card_id: StringName) -> int:
	_ensure_collection()
	return _collection.shard_cost(card_id)


func can_upgrade(card_id: StringName) -> bool:
	_ensure_collection()
	return _collection.can_upgrade(card_id)


func owned_entries() -> Array[Dictionary]:
	_ensure_collection()
	return _collection.owned_entries()


func owned_count() -> int:
	_ensure_collection()
	return _collection.owned_count()


func equipped_count() -> int:
	_ensure_collection()
	return _collection.equipped_count()


func equipped_ids() -> Array[String]:
	_ensure_collection()
	return _collection.equipped_ids()


func slot_card(slot: int) -> StringName:
	_ensure_collection()
	return _collection.slot_card(slot)


## Number of unlocked equip slots: level gates 2/5/15/20 plus Deep Roots.
func slot_count() -> int:
	_ensure_collection()
	var base := 0
	for index in range(1, 5):
		if UnlockService.is_unlocked(StringName("card_slot_%d" % index)):
			base += 1
	var bonus := int(round(maxf(ModifierService.get_stat(&"card_slot_bonus", 0.0), 0.0)))
	return clampi(base + bonus, 0, CardCollection.MAX_SLOTS)


## Spends shards for one card level.
func try_upgrade(card_id: StringName) -> bool:
	_ensure_collection()
	if not _collection.upgrade(card_id):
		return false
	_sync_state()
	_apply_modifiers()
	SaveService.request_save()
	cards_changed.emit()
	return true


## Grants a card or duplicate shards. Returns {new, upgraded, shards}.
func grant_card(card_id: StringName) -> Dictionary:
	_ensure_collection()
	var result := _collection.grant(card_id)
	_sync_state()
	_apply_modifiers()
	SaveService.request_save()
	cards_changed.emit()
	return result


## Picks a random card (rarity-weighted) and grants it. Returns the card id.
func grant_random_card(prefer_new: bool = true) -> StringName:
	_ensure_collection()
	var cards := _collection.get_cards()
	if cards.is_empty():
		return &""
	var pool: Array[CardData] = cards
	if prefer_new:
		var missing: Array[CardData] = []
		for card: CardData in cards:
			if not _collection.is_owned(card.id):
				missing.append(card)
		if not missing.is_empty():
			pool = missing
	var chosen := _pick_weighted(pool)
	if chosen == null:
		return &""
	grant_card(chosen.id)
	card_dropped.emit(chosen.id)
	return chosen.id


func equip(card_id: StringName, slot: int = -1) -> bool:
	_ensure_collection()
	if not _collection.equip(card_id, slot, slot_count()):
		return false
	_sync_state()
	_apply_modifiers()
	SaveService.request_save()
	cards_changed.emit()
	_track_equipped_missions()
	return true


func unequip(slot: int) -> bool:
	_ensure_collection()
	if not _collection.unequip(slot):
		return false
	_sync_state()
	_apply_modifiers()
	SaveService.request_save()
	cards_changed.emit()
	_track_equipped_missions()
	return true


## Slot of an equipped card, or -1.
func slot_of(card_id: StringName) -> int:
	_ensure_collection()
	return _collection.slot_of(card_id)


func get_state() -> Dictionary:
	_ensure_collection()
	return _collection.to_state()


## Debug/tooling reset.
func reset() -> void:
	_collection = CardCollection.new()
	_collection.setup(CardData.load_all(), {})
	_sync_state()
	_apply_modifiers()
	cards_changed.emit()


## Rolls one card drop for the cleared wave (called from EventBus).
func roll_drop() -> StringName:
	if not drops_enabled or _collection == null:
		return &""
	var chance := clampf(
		BASE_DROP_CHANCE + maxf(ModifierService.get_stat(&"card_drop_chance", 0.0), 0.0),
		0.0,
		0.5
	)
	if _rng.randf() > chance:
		return &""
	return grant_random_card()


func _on_wave_cleared(_wave: int) -> void:
	roll_drop()


func _pick_weighted(pool: Array[CardData]) -> CardData:
	if pool.is_empty():
		return null
	var total := 0.0
	for card: CardData in pool:
		total += float(RARITY_WEIGHTS.get(card.rarity, 1.0))
	var roll := _rng.randf() * total
	for card: CardData in pool:
		roll -= float(RARITY_WEIGHTS.get(card.rarity, 1.0))
		if roll <= 0.0:
			return card
	return pool[pool.size() - 1]


func _track_equipped_missions() -> void:
	if _collection == null:
		return
	var mission_service := get_node_or_null("/root/MissionService")
	if mission_service != null:
		mission_service.call(&"track_event", &"cards_equipped", _collection.equipped_count(), &"max")


func _ensure_collection() -> void:
	if _collection == null:
		init_service(GameState.cards)


func _sync_state() -> void:
	if _collection == null:
		return
	GameState.cards = _collection.to_state()


func _apply_modifiers() -> void:
	if _collection == null:
		return
	var entries := _collection.effect_entries()
	if entries.is_empty():
		ModifierService.remove_source(SOURCE_ID)
	else:
		ModifierService.add_source(SOURCE_ID, entries)
