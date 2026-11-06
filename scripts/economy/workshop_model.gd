## WorkshopModel — pure workspace state for the 24 permanent upgrade tracks.
##
## Loads WorkshopTrack resources from a directory, stores id -> level, prices the
## next level and produces the ModifierService source entries. It never touches
## the wallet: WorkshopService performs the coin transaction and then records the
## purchase here. No autoload access, so headless tests instantiate it directly.
class_name WorkshopModel
extends RefCounted

const DEFAULT_DIR := "res://data/workshop/"
const CATEGORIES: Array[StringName] = [&"attack", &"defense", &"utility", &"environment"]

var _tracks: Array[WorkshopTrack] = []
var _levels: Dictionary = {}


## Loads every WorkshopTrack in `dir_path`, ordered by category then order/id.
static func load_tracks(dir_path: String = DEFAULT_DIR) -> Array[WorkshopTrack]:
	var tracks: Array[WorkshopTrack] = []
	var files := ResourceDir.list(dir_path)
	if files.is_empty():
		push_error("No resources found in %s (exported builds use .remap)" % dir_path)
		return tracks
	files.sort()
	for resource_file in files:
		var resource: Resource = load(resource_file)
		if resource is WorkshopTrack:
			tracks.append(resource as WorkshopTrack)
		else:
			push_warning("WorkshopModel: '%s' is not a WorkshopTrack" % resource_file)
	tracks.sort_custom(_sort_tracks)
	return tracks


static func _sort_tracks(a: WorkshopTrack, b: WorkshopTrack) -> bool:
	if a.category == b.category:
		if a.order == b.order:
			return String(a.id) < String(b.id)
		return a.order < b.order
	return CATEGORIES.find(a.category) < CATEGORIES.find(b.category)


## Replaces the tracks and resets every level to 0. `saved_levels` (id -> int)
## restores a profile and is clamped to each track's max level.
func setup(tracks: Array[WorkshopTrack], saved_levels: Dictionary = {}) -> void:
	_tracks.clear()
	_levels.clear()
	for track in tracks:
		if track == null:
			continue
		_tracks.append(track)
		var saved := int(saved_levels.get(String(track.id), 0))
		_levels[String(track.id)] = clampi(saved, 0, track.max_level)


func get_tracks() -> Array[WorkshopTrack]:
	return _tracks


func get_tracks_in(category: StringName) -> Array[WorkshopTrack]:
	var result: Array[WorkshopTrack] = []
	for track in _tracks:
		if track.category == category:
			result.append(track)
	return result


func get_track(track_id: StringName) -> WorkshopTrack:
	for track in _tracks:
		if track.id == track_id:
			return track
	return null


func level_of(track_id: StringName) -> int:
	return int(_levels.get(String(track_id), 0))


func set_level(track_id: StringName, level: int) -> void:
	var track := get_track(track_id)
	if track == null:
		return
	_levels[String(track_id)] = clampi(level, 0, track.max_level)


func get_levels() -> Dictionary:
	return _levels.duplicate()


## Price of the next level, or 0 when the track is unknown or maxed.
func cost_of(track_id: StringName) -> int:
	var track := get_track(track_id)
	if track == null or is_maxed(track_id):
		return 0
	return track.cost_at(level_of(track_id))


func is_maxed(track_id: StringName) -> bool:
	var track := get_track(track_id)
	if track == null:
		return true
	return track.is_maxed(level_of(track_id))


func total_of(track_id: StringName) -> float:
	var track := get_track(track_id)
	if track == null:
		return 0.0
	return track.total_at(level_of(track_id))


## Eligibility check that never mutates the wallet or the levels.
func can_buy(track_id: StringName, coins: int) -> SpendResult:
	var track := get_track(track_id)
	if track == null:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "workshop.unknown_track", 0, coins)
	if is_maxed(track_id):
		return SpendResult.failure(SpendResult.Code.MAX_LEVEL, "workshop.max_level", 0, coins)
	var cost := track.cost_at(level_of(track_id))
	if coins < cost:
		return SpendResult.failure(SpendResult.Code.INSUFFICIENT_FUNDS, "workshop.not_enough_coins", cost, coins)
	return SpendResult.success(cost, coins)


## Records one level. Coins must already have been spent by the caller.
func record_purchase(track_id: StringName) -> bool:
	if is_maxed(track_id):
		return false
	_levels[String(track_id)] = level_of(track_id) + 1
	return true


## ModifierService source dictionary: stat id -> {add|mul: accumulated total}.
## Tracks whose accumulated total is 0 (or the track is untouched) are omitted.
func modifier_entries() -> Dictionary:
	var entries: Dictionary = {}
	for track in _tracks:
		var entry := track.modifier_entry(level_of(track.id))
		if entry.is_empty():
			continue
		entries[String(track.stat)] = entry
	return entries
