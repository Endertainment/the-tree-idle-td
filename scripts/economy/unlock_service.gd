## UnlockService — the single level-gate authority (spec 6.2).
##
## Feature ids come from `res://data/progression/levels.tres`; the UI/gameplay ask
## is_unlocked(id), never compare levels. Debug grants (QA only) live in
## GameState.unlocks and are still refused in release builds. Newly available
## features are queued so the menu can show a toast after the next level-up.
extends Node

const TABLE_PATH := "res://data/progression/levels.tres"

const DISPLAY_NAMES: Dictionary = {
	&"battle": ["unlock.battle", "Battle"],
	&"workshop": ["unlock.workshop", "Workshop"],
	&"settings": ["unlock.settings", "Settings"],
	&"cards": ["unlock.cards", "Cards"],
	&"card_slot_1": ["unlock.card_slot_1", "Card slot 1"],
	&"magica": ["unlock.magica", "Magica"],
	&"speed_1_5": ["unlock.speed_1_5", "Speed 1.5x"],
	&"unit_slot_2": ["unlock.unit_slot_2", "Unit slot 2"],
	&"missions": ["unlock.missions", "Missions"],
	&"card_slot_2": ["unlock.card_slot_2", "Card slot 2"],
	&"shop": ["unlock.shop", "Shop"],
	&"leaderboard": ["unlock.leaderboard", "Leaderboard"],
	&"tower_specialization": ["unlock.tower_specialization", "Tower specialization"],
	&"speed_2": ["unlock.speed_2", "Speed 2x"],
	&"unit_slot_3": ["unlock.unit_slot_3", "Unit slot 3"],
	&"unit_slot_4": ["unlock.unit_slot_4", "Unit slot 4"],
	&"tournament": ["unlock.tournament", "Tournament"],
	&"card_slot_3": ["unlock.card_slot_3", "Card slot 3"],
	&"card_slot_4": ["unlock.card_slot_4", "Card slot 4"],
	&"prestige": ["unlock.prestige", "Prestige"],
}

var _model: ProgressionModel
var _pending: Array[StringName] = []
var _last_level: int = 1


func _ready() -> void:
	init_service()


## Loads the unlock table and syncs to the current player level.
func init_service() -> void:
	var table := load(TABLE_PATH) as LevelProgression
	if table == null:
		push_error("UnlockService: cannot load %s" % TABLE_PATH)
		table = LevelProgression.new()
	_model = ProgressionModel.new(table)
	_last_level = LevelService.get_level()
	_model.set_level(_last_level)
	_pending.clear()


func is_unlocked(unlock_id: StringName) -> bool:
	if GameState.has_extra_unlock(unlock_id):
		return true
	return _model != null and _model.is_unlocked(unlock_id)


## Lowest level that unlocks `unlock_id`, or 0 when the id is unknown.
func level_required(unlock_id: StringName) -> int:
	return _model.level_for(unlock_id) if _model != null else 0


## All feature ids unlocked at the current level, including debug grants.
func get_all_unlocked() -> Array[StringName]:
	var result: Array[StringName] = []
	if _model != null:
		result = _model.all_unlocked(LevelService.get_level())
	for extra: String in GameState.unlocks.keys():
		var id := StringName(extra)
		if bool(GameState.unlocks[extra]) and not result.has(id):
			result.append(id)
	return result


## Called by LevelService after each level gain. Publishes new unlock ids.
func on_level_up(new_level: int) -> void:
	if _model == null:
		return
	var newly := _model.newly_unlocked(_last_level, new_level)
	_model.set_level(new_level)
	_last_level = new_level
	for unlock_id: StringName in newly:
		_pending.append(unlock_id)
		EventBus.unlocked.emit(unlock_id)


## Drains the toast queue (the menu shows one message per session).
func take_pending_unlocks() -> Array[StringName]:
	var pending := _pending.duplicate()
	_pending.clear()
	return pending


## Localized human name for an unlock id.
func display_name(unlock_id: StringName) -> String:
	var entry: Array = DISPLAY_NAMES.get(unlock_id, [])
	if entry.is_empty():
		return String(unlock_id).capitalize()
	return LocaleService.t(str(entry[0]), str(entry[1]))


## QA-only grant. Still refused in release builds (spec: debug unlock stays debug).
func grant_debug_unlock(unlock_id: StringName) -> bool:
	if not App.is_debug_build():
		return false
	GameState.grant_extra_unlock(unlock_id)
	SaveService.request_save()
	EventBus.unlocked.emit(unlock_id)
	_pending.append(unlock_id)
	return true


## Debug/tooling: resyncs the cached level from GameState.
func refresh() -> void:
	if _model == null:
		return
	_last_level = LevelService.get_level()
	_model.set_level(_last_level)
