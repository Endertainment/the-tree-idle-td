## MissionService — daily/weekly missions driven by battle events (spec 6.6).
##
## Generates 3 daily + 5 weekly missions from `data/missions/templates.tres`, keeps
## progress in the save, claims rewards through WalletService (scaled by the
## workshop `mission_reward_bonus` track), grants the all-3/all-5 completion bonuses
## once and rerolls at the 04:00 local / Monday 04:00 boundaries.
extends Node

signal missions_changed
signal mission_claimed(mission_id: String, reward: Dictionary)

var _model: MissionModel
var _table: MissionTemplateTable
var _run_leaks: int = 0
var _run_active: bool = false


func _ready() -> void:
	init_service(GameState.missions)
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_leaked.connect(_on_enemy_leaked)
	EventBus.tower_built.connect(_on_tower_built)


## Restores saved missions and rerolls any expired cycle. Safe to call again.
func init_service(saved_state: Dictionary = {}) -> void:
	_table = MissionTemplateTable.load_table()
	_model = MissionModel.new()
	var changed := _model.setup(
		_table.templates,
		saved_state,
		LevelService.get_level(),
		TimeService.now_unix(),
		MissionSchedule.system_offset_minutes()
	)
	_sync_state()
	if changed:
		SaveService.request_save()
	missions_changed.emit()


func get_model() -> MissionModel:
	_ensure_model()
	return _model


func get_daily() -> Array[Dictionary]:
	_ensure_model()
	return _model.get_daily()


func get_weekly() -> Array[Dictionary]:
	_ensure_model()
	return _model.get_weekly()


func get_state() -> Dictionary:
	_ensure_model()
	return _model.to_state()


func claimable_count(period: StringName) -> int:
	_ensure_model()
	return _model.claimable_count(period)


func claimed_count(period: StringName) -> int:
	_ensure_model()
	return _model.claimed_count(period)


func all_claimed(period: StringName) -> bool:
	_ensure_model()
	return _model.all_claimed(period)


func remaining_seconds(period: StringName) -> int:
	_ensure_model()
	return _model.remaining_seconds(period, TimeService.now_unix(), MissionSchedule.system_offset_minutes())


func get_day_id() -> String:
	_ensure_model()
	return _model.get_day_id()


func get_week_id() -> String:
	_ensure_model()
	return _model.get_week_id()


## Tick called by the screen: rerolls cycles crossed while the app was closed.
func ensure_cycle() -> bool:
	_ensure_model()
	var changed := _model.ensure_cycle(TimeService.now_unix(), MissionSchedule.system_offset_minutes())
	if changed:
		_sync_state()
		SaveService.request_save()
		missions_changed.emit()
	return changed


## Public event entry point (battle, cards and the future M6 ads all use it).
func track_event(metric: StringName, amount: int, mode: StringName = &"add") -> bool:
	_ensure_model()
	if not _model.track(metric, amount, mode):
		return false
	_sync_state()
	SaveService.request_save()
	missions_changed.emit()
	return true


## Claims one completed mission and applies its reward. Returns the claim result.
func claim(mission_id: String) -> Dictionary:
	_ensure_model()
	ensure_cycle()
	var result := _model.claim(mission_id)
	if not bool(result.get("ok", false)):
		return result
	var bundle := _bundle_for(
		int(result.get("coins", 0)),
		int(result.get("gems", 0)),
		int(result.get("xp", 0))
	)
	GameState.grant_bundle(bundle, &"mission")
	var bonus := _grant_completion_bonus(StringName(str(result.get("period", ""))))
	_sync_state()
	SaveService.request_save()
	mission_claimed.emit(mission_id, result)
	missions_changed.emit()
	if not bonus.is_empty():
		result["bonus"] = bonus
	return result


## Claims every completed mission. Returns the number claimed.
func claim_all() -> int:
	_ensure_model()
	var claimed := 0
	for period: StringName in [MissionTemplate.PERIOD_DAILY, MissionTemplate.PERIOD_WEEKLY]:
		var ids: Array[String] = []
		for row: Dictionary in _model.get_missions(period):
			if _model.can_claim(row):
				ids.append(str(row.get("id", "")))
		for mission_id: String in ids:
			var result := claim(mission_id)
			if bool(result.get("ok", false)):
				claimed += 1
	return claimed


## Records one rewarded-ad view for the M6 ad bridge and the weekly mission.
func record_rewarded_ad() -> void:
	track_event(&"ads_watched", 1, &"add")


## Debug/tooling reset.
func reset() -> void:
	_model = MissionModel.new()
	_model.setup(
		MissionTemplateTable.load_table().templates,
		{},
		LevelService.get_level(),
		TimeService.now_unix(),
		MissionSchedule.system_offset_minutes()
	)
	_sync_state()
	missions_changed.emit()


func _ensure_model() -> void:
	if _model == null:
		init_service(GameState.missions)


func _sync_state() -> void:
	if _model == null:
		return
	GameState.missions = _model.to_state()


func _bundle_for(coins: int, gems: int, xp: int) -> RewardBundle:
	var multiplier := maxf(ModifierService.get_stat(&"mission_reward_bonus", 1.0), 0.0)
	var bundle := RewardBundle.new()
	bundle.coins = maxi(int(round(float(coins) * multiplier)), 0)
	bundle.gems = maxi(int(round(float(gems) * multiplier)), 0)
	bundle.xp = maxi(xp, 0)
	return bundle


## Grants the all-3 / all-5 bonus exactly once per cycle. Returns a summary
## dictionary ({period, coins, gems, card_pack}) or {} when nothing was due.
func _grant_completion_bonus(period: StringName) -> Dictionary:
	if period == &"" or not _model.bonus_pending(period):
		return {}
	var reward := _model.bonus_reward(period)
	var bundle := _bundle_for(
		int(reward.get("coins", 0)),
		int(reward.get("gems", 0)),
		int(reward.get("xp", 0))
	)
	GameState.grant_bundle(bundle, &"mission_bonus")
	var card_pack := bool(reward.get("card_pack", false))
	if card_pack:
		var card_service := get_node_or_null("/root/CardService")
		if card_service != null:
			card_service.call(&"grant_random_card", true)
	_model.mark_bonus_claimed(period)
	_sync_state()
	return {
		"period": period,
		"coins": bundle.coins,
		"gems": bundle.gems,
		"card_pack": card_pack,
	}


# --- battle event bridge ----------------------------------------------------------


func _on_run_started() -> void:
	_run_leaks = 0
	_run_active = true


func _on_run_ended(waves: int) -> void:
	if not _run_active:
		return
	_run_active = false
	track_event(&"wave_reached", maxi(waves, 0), &"max")
	if _run_leaks == 0:
		track_event(&"clean_runs", 1, &"add")


func _on_wave_cleared(wave: int) -> void:
	track_event(&"waves_cleared", 1, &"add")
	track_event(&"wave_reached", wave, &"max")


func _on_damage_dealt(_source_id: StringName, target_id: int, _amount: float, is_crit: bool, _is_kill: bool) -> void:
	if is_crit and target_id > 0:
		track_event(&"crits", 1, &"add")


func _on_enemy_killed(_enemy_id: StringName, _is_boss: bool) -> void:
	track_event(&"kills", 1, &"add")


func _on_enemy_leaked(_enemy_id: StringName) -> void:
	_run_leaks += 1


func _on_tower_built(_tower_id: StringName, run_count: int) -> void:
	track_event(&"towers_built", run_count, &"max")
