## MissionTemplate — one mission archetype (spec 6.6).
##
## The MissionService generates concrete daily/weekly missions from these
## templates: target and rewards scale with the player level, and the service
## stores the generated instance (target/reward included) in the save so a later
## template change cannot invalidate an in-progress mission.
class_name MissionTemplate
extends Resource

const PERIOD_DAILY := &"daily"
const PERIOD_WEEKLY := &"weekly"

const MODE_ADD := &"add"
const MODE_MAX := &"max"

@export var id: StringName = &""
## daily | weekly
@export var period: StringName = &"daily"
@export var order: int = 0
@export var title_key: String = ""
## Title with {n} replaced by the scaled target ("Clear {n} waves").
@export var title: String = ""
@export var description_key: String = ""
@export var description: String = ""
## Progress metric: waves_cleared, kills, towers_built, wave_reached, crits,
## clean_runs, cards_equipped, ads_watched.
@export var metric: StringName = &"kills"
## add = accumulate events; max = keep the highest event value (per-run records).
@export var mode: StringName = &"add"
@export var base_target: int = 10
## Extra target fraction per player level (0.12 = +12 % of the base per level).
@export var per_level: float = 0.12
@export var base_coins: int = 25
@export var base_gems: int = 0
@export var base_xp: int = 20
@export var icon: Texture2D


## Level-scaled target for this template.
func target_for(level: int) -> int:
	var safe_level := maxi(level, 1)
	return maxi(1, int(round(float(base_target) * (1.0 + per_level * float(safe_level - 1)))))


## Level-scaled coins/gems/xp rewards.
func reward_for(level: int) -> Dictionary:
	var safe_level := maxi(level, 1)
	var growth := 1.0 + 0.08 * float(safe_level - 1)
	return {
		"coins": maxi(int(round(float(base_coins) * growth)), 0),
		"gems": maxi(int(round(float(base_gems) * growth)), 0),
		"xp": maxi(int(round(float(base_xp) * growth)), 0),
	}


## Title with {n} replaced by `target`.
func title_for(target: int) -> String:
	return title.replace("{n}", str(target))
