## MissionModel — pure daily/weekly mission state (spec 6.6).
##
## Generates a deterministic subset from the authored templates for each mission
## cycle, tracks event progress, enforces claim-once and rerolls everything when the
## 04:00 / Monday-04:00 boundary is crossed. MissionService owns the wallet, card
## pack and save calls; this model stays headless-testable.
class_name MissionModel
extends RefCounted

const DAILY_COUNT := 3
const WEEKLY_COUNT := 5
const DAILY_BONUS_COINS := 30
const DAILY_BONUS_GEMS := 2
const WEEKLY_BONUS_COINS := 250
const WEEKLY_BONUS_GEMS := 10

var _templates: Array[MissionTemplate] = []
var _level: int = 1
var _day_id: String = ""
var _week_id: String = ""
var _daily: Array[Dictionary] = []
var _weekly: Array[Dictionary] = []
var _daily_bonus_claimed: bool = false
var _weekly_bonus_claimed: bool = false


## Restores `state` and rerolls expired cycles. Returns true when anything changed.
func setup(
	templates: Array[MissionTemplate],
	state: Dictionary,
	level: int,
	now_unix: int,
	offset_minutes: int
) -> bool:
	_templates = templates
	_level = maxi(level, 1)
	_day_id = str(state.get("day_id", ""))
	_week_id = str(state.get("week_id", ""))
	_daily = _parse_missions(state.get("daily", []), &"daily")
	_weekly = _parse_missions(state.get("weekly", []), &"weekly")
	_daily_bonus_claimed = bool(state.get("daily_bonus_claimed", false))
	_weekly_bonus_claimed = bool(state.get("weekly_bonus_claimed", false))
	return ensure_cycle(now_unix, offset_minutes)


## Rerolls any cycle whose id no longer matches the local reset boundary.
func ensure_cycle(now_unix: int, offset_minutes: int) -> bool:
	var changed := false
	var today := MissionSchedule.day_id(now_unix, offset_minutes)
	if _day_id != today:
		_day_id = today
		_daily = _generate(&"daily", MissionSchedule.day_index(now_unix, offset_minutes), DAILY_COUNT)
		_daily_bonus_claimed = false
		changed = true
	var this_week := MissionSchedule.week_id(now_unix, offset_minutes)
	if _week_id != this_week:
		_week_id = this_week
		_weekly = _generate(&"weekly", MissionSchedule.week_index(now_unix, offset_minutes), WEEKLY_COUNT)
		_weekly_bonus_claimed = false
		changed = true
	return changed


func get_daily() -> Array[Dictionary]:
	return _daily


func get_weekly() -> Array[Dictionary]:
	return _weekly


func get_missions(period: StringName) -> Array[Dictionary]:
	return _daily if period == MissionTemplate.PERIOD_DAILY else _weekly


func get_day_id() -> String:
	return _day_id


func get_week_id() -> String:
	return _week_id


func get_mission(mission_id: String) -> Dictionary:
	for row: Dictionary in _daily:
		if str(row.get("id", "")) == mission_id:
			return row
	for row: Dictionary in _weekly:
		if str(row.get("id", "")) == mission_id:
			return row
	return {}


## Applies a battle event to every matching mission. `mode` is `add` (accumulate)
## or `max` (keep the highest single-run value). Returns true when progress moved.
func track(metric: StringName, amount: int, mode: StringName = &"add") -> bool:
	var changed := false
	for row: Dictionary in _daily:
		if _track_row(row, metric, amount, mode):
			changed = true
	for row: Dictionary in _weekly:
		if _track_row(row, metric, amount, mode):
			changed = true
	return changed


func _track_row(row: Dictionary, metric: StringName, amount: int, mode: StringName) -> bool:
	if bool(row.get("claimed", false)):
		return false
	if StringName(str(row.get("metric", ""))) != metric:
		return false
	var target := maxi(int(row.get("target", 1)), 1)
	var progress := int(row.get("progress", 0))
	var next := progress
	if mode == &"max":
		next = maxi(progress, amount)
	else:
		next = progress + maxi(amount, 0)
	next = clampi(next, 0, target)
	if next == progress:
		return false
	row["progress"] = next
	return true


## Direct progress setter used by tests and the screenshot preview.
func set_progress(mission_id: String, progress: int) -> bool:
	var row := get_mission(mission_id)
	if row.is_empty():
		return false
	row["progress"] = clampi(progress, 0, maxi(int(row.get("target", 1)), 1))
	return true


func claimable_count(period: StringName) -> int:
	var count := 0
	for row: Dictionary in get_missions(period):
		if can_claim(row):
			count += 1
	return count


func claimed_count(period: StringName) -> int:
	var count := 0
	for row: Dictionary in get_missions(period):
		if bool(row.get("claimed", false)):
			count += 1
	return count


func all_claimed(period: StringName) -> bool:
	var rows := get_missions(period)
	return not rows.is_empty() and claimed_count(period) == rows.size()


func can_claim(row: Dictionary) -> bool:
	return not bool(row.get("claimed", false)) \
		and int(row.get("progress", 0)) >= int(row.get("target", 1))


## Claims one mission. Returns {ok, coins, gems, xp, period, title} or {ok=false}.
func claim(mission_id: String) -> Dictionary:
	for period: StringName in [MissionTemplate.PERIOD_DAILY, MissionTemplate.PERIOD_WEEKLY]:
		for row: Dictionary in get_missions(period):
			if str(row.get("id", "")) != mission_id:
				continue
			if not can_claim(row):
				return {"ok": false, "reason": "not_complete"}
			row["claimed"] = true
			return {
				"ok": true,
				"coins": int(row.get("reward_coins", 0)),
				"gems": int(row.get("reward_gems", 0)),
				"xp": int(row.get("reward_xp", 0)),
				"period": period,
				"title": str(row.get("title", "")),
			}
	return {"ok": false, "reason": "unknown"}


## Completion bonus for all 3 dailies / all 5 weeklies, claimable once per cycle.
func bonus_pending(period: StringName) -> bool:
	if not all_claimed(period):
		return false
	return not (_daily_bonus_claimed if period == MissionTemplate.PERIOD_DAILY else _weekly_bonus_claimed)


func mark_bonus_claimed(period: StringName) -> void:
	if period == MissionTemplate.PERIOD_DAILY:
		_daily_bonus_claimed = true
	else:
		_weekly_bonus_claimed = true


func bonus_reward(period: StringName) -> Dictionary:
	if period == MissionTemplate.PERIOD_DAILY:
		return {"coins": DAILY_BONUS_COINS, "gems": DAILY_BONUS_GEMS, "xp": 0, "card_pack": false}
	return {"coins": WEEKLY_BONUS_COINS, "gems": WEEKLY_BONUS_GEMS, "xp": 0, "card_pack": true}


func is_bonus_claimed(period: StringName) -> bool:
	return _daily_bonus_claimed if period == MissionTemplate.PERIOD_DAILY else _weekly_bonus_claimed


func remaining_seconds(period: StringName, now_unix: int, offset_minutes: int) -> int:
	if period == MissionTemplate.PERIOD_DAILY:
		return MissionSchedule.seconds_until_daily_reset(now_unix, offset_minutes)
	return MissionSchedule.seconds_until_weekly_reset(now_unix, offset_minutes)


func to_state() -> Dictionary:
	return {
		"day_id": _day_id,
		"daily": _daily.duplicate(true),
		"week_id": _week_id,
		"weekly": _weekly.duplicate(true),
		"daily_bonus_claimed": _daily_bonus_claimed,
		"weekly_bonus_claimed": _weekly_bonus_claimed,
	}


func _generate(period: StringName, cycle_index: int, count: int) -> Array[Dictionary]:
	var pool: Array[MissionTemplate] = []
	for template: MissionTemplate in _templates:
		if template != null and template.period == period:
			pool.append(template)
	var result: Array[Dictionary] = []
	if pool.is_empty():
		return result
	var start := ((cycle_index % pool.size()) + pool.size()) % pool.size()
	for offset in count:
		var template := pool[(start + offset) % pool.size()]
		var target := template.target_for(_level)
		var reward := template.reward_for(_level)
		result.append({
			"id": String(template.id),
			"template_id": String(template.id),
			"title": template.title_for(target),
			"metric": String(template.metric),
			"mode": String(template.mode),
			"target": target,
			"progress": 0,
			"claimed": false,
			"reward_coins": int(reward.get("coins", 0)),
			"reward_gems": int(reward.get("gems", 0)),
			"reward_xp": int(reward.get("xp", 0)),
		})
	return result


func _parse_missions(raw: Variant, period: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (raw is Array):
		return result
	for entry: Variant in raw as Array:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = (entry as Dictionary).duplicate(true)
		var template := _template_by_id(str(row.get("template_id", row.get("id", ""))))
		if template == null:
			# A template that no longer exists: keep the row but drop it from the UI
			# by leaving the id as authored. Unknown rows are ignored by get_mission.
			continue
		row["id"] = str(template.id)
		row["template_id"] = str(template.id)
		row["title"] = str(row.get("title", template.title_for(maxi(int(row.get("target", 1)), 1))))
		row["metric"] = str(row.get("metric", template.metric))
		row["mode"] = str(row.get("mode", template.mode))
		row["target"] = maxi(int(row.get("target", template.target_for(_level))), 1)
		row["progress"] = clampi(int(row.get("progress", 0)), 0, int(row["target"]))
		row["claimed"] = bool(row.get("claimed", false))
		row["reward_coins"] = maxi(int(row.get("reward_coins", template.base_coins)), 0)
		row["reward_gems"] = maxi(int(row.get("reward_gems", template.base_gems)), 0)
		row["reward_xp"] = maxi(int(row.get("reward_xp", template.base_xp)), 0)
		result.append(row)
	if period == &"daily":
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	return result


func _template_by_id(template_id: String) -> MissionTemplate:
	for template: MissionTemplate in _templates:
		if str(template.id) == template_id:
			return template
	return null
