## CardCollection — pure owned/equipped/shards state for the 12 cards (spec 6.5).
##
## Duplicates become shards and upgrade the card automatically while enough shards
## remain. CardService wraps this with persistence, drop rolls and the aggregated
## ModifierService source; the model itself has no autoload access.
class_name CardCollection
extends RefCounted

const MAX_LEVEL := 5
const DUPLICATE_SHARDS := 20
const MAX_SLOTS := 5

var _cards: Array[CardData] = []
## id (String) -> {"level": int, "shards": int}
var _owned: Dictionary = {}
## Slot -> id (String) or null. Always MAX_SLOTS long internally.
var _equipped: Array = []


## Replaces the card pool and restores a saved state dictionary.
func setup(cards: Array[CardData], state: Dictionary = {}) -> void:
	_cards = cards
	_owned.clear()
	_equipped = [null, null, null, null, null]

	var stored_owned: Variant = state.get("owned", [])
	if stored_owned is Array:
		for entry: Variant in stored_owned as Array:
			if not (entry is Dictionary):
				continue
			var row := entry as Dictionary
			var card_id := StringName(str(row.get("id", "")))
			if get_card(card_id) == null:
				continue
			var level := clampi(int(row.get("level", 1)), 1, MAX_LEVEL)
			var shards := maxi(int(row.get("shards", 0)), 0)
			_owned[String(card_id)] = {"level": level, "shards": shards}

	var stored_equipped: Variant = state.get("equipped", [])
	if stored_equipped is Array:
		var entries := stored_equipped as Array
		for index in mini(entries.size(), MAX_SLOTS):
			var raw: Variant = entries[index]
			if raw == null:
				continue
			var equipped_id := StringName(str(raw))
			if get_card(equipped_id) == null or not is_owned(equipped_id):
				continue
			_equipped[index] = String(equipped_id)


func get_cards() -> Array[CardData]:
	return _cards


func get_card(card_id: StringName) -> CardData:
	for card: CardData in _cards:
		if card.id == card_id:
			return card
	return null


func is_owned(card_id: StringName) -> bool:
	return _owned.has(String(card_id))


func level_of(card_id: StringName) -> int:
	var row: Dictionary = _owned.get(String(card_id), {})
	return int(row.get("level", 0))


func shards_of(card_id: StringName) -> int:
	var row: Dictionary = _owned.get(String(card_id), {})
	return int(row.get("shards", 0))


func owned_count() -> int:
	return _owned.size()


## Data rows in card-pool order, for the collection grid.
func owned_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: CardData in _cards:
		if not is_owned(card.id):
			continue
		result.append({
			"data": card,
			"id": card.id,
			"level": level_of(card.id),
			"shards": shards_of(card.id),
		})
	return result


## Shards needed for the next level (0 at max).
func shard_cost(card_id: StringName) -> int:
	var card := get_card(card_id)
	if card == null:
		return 0
	return card.shard_cost(level_of(card_id))


func can_upgrade(card_id: StringName) -> bool:
	if not is_owned(card_id):
		return false
	var level := level_of(card_id)
	if level >= MAX_LEVEL:
		return false
	return shards_of(card_id) >= shard_cost(card_id)


## Spends shards for one level. Returns true when the level increased.
func upgrade(card_id: StringName) -> bool:
	if not can_upgrade(card_id):
		return false
	var key := String(card_id)
	var row: Dictionary = _owned[key]
	row["shards"] = int(row.get("shards", 0)) - shard_cost(card_id)
	row["level"] = mini(int(row.get("level", 1)) + 1, MAX_LEVEL)
	_owned[key] = row
	return true


## Grants a card: new cards start at level 1, duplicates become shards and
## auto-upgrade while affordable. Returns {new, upgraded, shards}.
func grant(card_id: StringName) -> Dictionary:
	if get_card(card_id) == null:
		return {"new": false, "upgraded": 0, "shards": 0}
	if not is_owned(card_id):
		_owned[String(card_id)] = {"level": 1, "shards": 0}
		return {"new": true, "upgraded": 0, "shards": 0}
	var key := String(card_id)
	var row: Dictionary = _owned[key]
	row["shards"] = int(row.get("shards", 0)) + DUPLICATE_SHARDS
	_owned[key] = row
	var upgrades := 0
	while can_upgrade(card_id):
		if not upgrade(card_id):
			break
		upgrades += 1
	return {"new": false, "upgraded": upgrades, "shards": shards_of(card_id)}


func equipped_ids() -> Array[String]:
	var result: Array[String] = []
	for index in MAX_SLOTS:
		var card_id: Variant = _equipped[index]
		if card_id != null:
			result.append(str(card_id))
	return result


func equipped_count() -> int:
	return equipped_ids().size()


func slot_card(slot: int) -> StringName:
	if slot < 0 or slot >= MAX_SLOTS:
		return &""
	var card_id: Variant = _equipped[slot]
	return StringName(str(card_id)) if card_id != null else &""


## Slot of `card_id`, or -1 when not equipped.
func slot_of(card_id: StringName) -> int:
	for index in MAX_SLOTS:
		if str(_equipped[index]) == String(card_id):
			return index
	return -1


## Equips a card into `slot` (or the first empty slot when slot < 0). `slot_count`
## is the number of slots the profile has unlocked. Returns true on success.
func equip(card_id: StringName, slot: int = -1, slot_count: int = 1) -> bool:
	if not is_owned(card_id) or slot_count <= 0:
		return false
	var safe_count := clampi(slot_count, 1, MAX_SLOTS)
	var target := slot
	if target < 0:
		target = -1
		for index in safe_count:
			if _equipped[index] == null:
				target = index
				break
		if target < 0:
			return false
	if target < 0 or target >= safe_count:
		return false
	var previous_slot := slot_of(card_id)
	if previous_slot >= 0 and previous_slot != target:
		_equipped[previous_slot] = null
	_equipped[target] = String(card_id)
	return true


func unequip(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS or _equipped[slot] == null:
		return false
	_equipped[slot] = null
	return true


## Aggregated ModifierService entries for the current loadout.
func effect_entries() -> Dictionary:
	var entries: Dictionary = {}
	for index in MAX_SLOTS:
		var card_id := slot_card(index)
		if card_id == &"":
			continue
		var card := get_card(card_id)
		if card == null:
			continue
		var scale := CardData.effect_scale(level_of(card_id))
		for effect: ModifierData in card.effects:
			ModifierBuilder.add_effect(entries, effect, scale)
	return entries


## Save-shaped state. Keeps the historical 4 slots until the Deep Roots slot is
## used, so v2 documents written before M4b stay byte-compatible.
func to_state() -> Dictionary:
	var owned: Array[Dictionary] = []
	for card: CardData in _cards:
		if not is_owned(card.id):
			continue
		owned.append({
			"id": String(card.id),
			"level": level_of(card.id),
			"shards": shards_of(card.id),
		})
	var equipped: Array = []
	for index in MAX_SLOTS:
		var card_id: Variant = _equipped[index]
		equipped.append(null if card_id == null else str(card_id))
	while equipped.size() > 4 and equipped[equipped.size() - 1] == null:
		equipped.pop_back()
	return {"owned": owned, "equipped": equipped}
