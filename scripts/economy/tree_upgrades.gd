## TreeUpgrades — runtime levels and aggregated bonuses for the six Tree tracks.
##
## Tracks are loaded from a directory of UpgradeTrack resources, so the upgrade
## panel and the stat maths are generated from data: adding a `.tres` (with one
## stat id read by TreeEntity) adds a row with no UI code. The model never touches
## cash; BattleController performs the wallet transaction and then records the
## level here.
class_name TreeUpgrades
extends RefCounted

const DEFAULT_DIR := "res://data/tree/upgrades/"

var _tracks: Array[UpgradeTrack] = []
var _levels: Dictionary = {}


## Loads every UpgradeTrack resource in `dir_path`, ordered by `order` then id.
## Directory scanning keeps "add a track" a data-only change.
static func load_tracks(dir_path: String = DEFAULT_DIR) -> Array[UpgradeTrack]:
	var tracks: Array[UpgradeTrack] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("TreeUpgrades: cannot open '%s'" % dir_path)
		return tracks
	var files: Array[String] = []
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir() and (file.ends_with(".tres") or file.ends_with(".res")):
			files.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for resource_file in files:
		var resource: Resource = load(dir_path + resource_file)
		if resource is UpgradeTrack:
			tracks.append(resource as UpgradeTrack)
		else:
			push_warning("TreeUpgrades: '%s' is not an UpgradeTrack" % resource_file)
	tracks.sort_custom(_sort_tracks)
	return tracks


static func _sort_tracks(a: UpgradeTrack, b: UpgradeTrack) -> bool:
	if a.order == b.order:
		return String(a.id) < String(b.id)
	return a.order < b.order


## Replaces the track list and resets every level to 0 (new run).
func setup(tracks: Array[UpgradeTrack]) -> void:
	_tracks.clear()
	_levels.clear()
	for track in tracks:
		if track != null:
			_tracks.append(track)
			_levels[String(track.id)] = 0


func get_tracks() -> Array[UpgradeTrack]:
	return _tracks


func get_track(track_id: StringName) -> UpgradeTrack:
	for track in _tracks:
		if track.id == track_id:
			return track
	return null


func get_level(track_id: StringName) -> int:
	return int(_levels.get(String(track_id), 0))


func has_track(track_id: StringName) -> bool:
	return get_track(track_id) != null


## Next-level price, or 0 when maxed/unknown.
func cost_for(track_id: StringName) -> int:
	var track := get_track(track_id)
	if track == null or is_maxed(track_id):
		return 0
	return track.cost_at(get_level(track_id))


func is_maxed(track_id: StringName) -> bool:
	var track := get_track(track_id)
	if track == null:
		return true
	return track.is_maxed(get_level(track_id))


## Affordability/eligibility check that never mutates cash or levels.
func can_buy(track_id: StringName, wallet: RunWallet) -> SpendResult:
	var track := get_track(track_id)
	if track == null:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "battle.unknown_upgrade", 0, wallet.get_cash())
	if is_maxed(track_id):
		return SpendResult.failure(SpendResult.Code.MAX_LEVEL, "battle.max_level", 0, wallet.get_cash())
	var cost := track.cost_at(get_level(track_id))
	if not wallet.can_afford(cost):
		return SpendResult.failure(
			SpendResult.Code.INSUFFICIENT_FUNDS, "battle.not_enough_cash", cost, wallet.get_cash()
		)
	return SpendResult.success(cost, wallet.get_cash())


## Records one purchased level. Cash must already have been spent by the caller.
func record_purchase(track_id: StringName) -> SpendResult:
	if is_maxed(track_id):
		return SpendResult.failure(SpendResult.Code.MAX_LEVEL, "battle.max_level", 0, 0)
	_levels[String(track_id)] = get_level(track_id) + 1
	return SpendResult.success(0, 0)


## Total bonus for one stat id (fractions; crit chance in chance points fraction).
func get_bonus(stat_id: StringName) -> float:
	var total := 0.0
	for track in _tracks:
		if track.stat_id == stat_id:
			total += track.value_at(get_level(track.id))
	return total


## All aggregated bonuses keyed by stat id (String keys, TreeEntity reads these).
func get_bonuses() -> Dictionary:
	var bonuses: Dictionary = {}
	for track in _tracks:
		var key := String(track.stat_id)
		bonuses[key] = float(bonuses.get(key, 0.0)) + track.value_at(get_level(track.id))
	return bonuses


## Snapshot of levels, for the debug overlay and tests.
func get_levels() -> Dictionary:
	return _levels.duplicate()


## Expected Tree DPS from base stats plus upgrade bonuses. Shared by the DPS test
## and TreeEntity so the preview and the simulation cannot drift.
static func tree_dps(
	base_damage: float,
	base_interval: float,
	base_crit_chance: float,
	base_crit_multiplier: float,
	bonuses: Dictionary
) -> float:
	if base_interval <= 0.0:
		return 0.0
	var damage := base_damage * (1.0 + float(bonuses.get("damage", 0.0)))
	var interval := maxf(base_interval / (1.0 + float(bonuses.get("attack_speed", 0.0))), 0.01)
	var crit := clampf(base_crit_chance + float(bonuses.get("crit_chance", 0.0)), 0.0, 0.6)
	var crit_multiplier := base_crit_multiplier + float(bonuses.get("crit_damage", 0.0))
	return tree_dps_from_stats(damage, interval, crit, crit_multiplier)


## DPS from already-aggregated stats (used by tests that read ModifierService).
static func tree_dps_from_stats(
	damage: float,
	interval: float,
	crit_chance: float,
	crit_multiplier: float
) -> float:
	if interval <= 0.0:
		return 0.0
	var crit := clampf(crit_chance, 0.0, 0.6)
	return damage * (1.0 + crit * (crit_multiplier - 1.0)) / interval
