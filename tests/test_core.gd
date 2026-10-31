## M0 test suite. Exactly three checks: art manifest, save round-trip, cost curve.
extends RefCounted

const MANIFEST_PATH := "res://docs/art_manifest.json"
const ART_ROOT := "res://assets/art/"
const SaveServiceScript := preload("res://scripts/autoload/save_service.gd")
const CostCurveScript := preload("res://scripts/util/cost_curve.gd")


## Every path in docs/art_manifest.json must resolve under assets/art/.
func test_manifest_paths() -> bool:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if text.is_empty():
		print("  manifest is missing or empty: ", MANIFEST_PATH)
		return false

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array):
		print("  manifest is not a JSON array")
		return false

	var entries := parsed as Array
	if entries.is_empty():
		print("  manifest has no entries")
		return false

	var missing: Array[String] = []
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var relative_path := str(entry.get("path", ""))
		if relative_path.is_empty():
			missing.append("<entry without path>")
			continue
		if not FileAccess.file_exists(ART_ROOT + relative_path):
			missing.append(relative_path)

	if not missing.is_empty():
		print("  %d missing file(s), first: %s" % [missing.size(), ", ".join(missing.slice(0, 5))])
		return false

	print("  %d manifest paths exist" % entries.size())
	return true


## SaveService must return exactly what was written (plus metadata fields).
func test_save_roundtrip() -> bool:
	var service: Node = SaveServiceScript.new()
	var suffix := str(Time.get_ticks_usec())
	service.save_path = "user://m0_test_%s.json" % suffix
	service.backup_path = "user://m0_test_%s.bak.json" % suffix
	service.temp_path = "user://m0_test_%s.tmp.json" % suffix
	service.clear()

	var original := {
		"player": {"id": "test_player", "nickname": "Tester", "avatar_id": "avatar_01", "level": 3, "xp": 120},
		"wallet": {"coins": 12480, "gems": 350, "stones": 0},
		"is_onboarded": true,
	}
	var wrote_ok: bool = service.save(original)
	if not wrote_ok:
		print("  save() returned false")
		service.clear()
		service.free()
		return false
	if not service.has_save():
		print("  has_save() is false after a successful write")
		service.clear()
		service.free()
		return false

	var loaded: Dictionary = service.load()
	service.clear()
	service.free()

	if loaded.is_empty():
		print("  load() returned an empty dictionary")
		return false
	if int(loaded.get("schema_version", 0)) != SaveServiceScript.SCHEMA_VERSION:
		print("  schema_version is wrong: ", loaded.get("schema_version"))
		return false
	if not loaded.has("saved_at") or int(loaded.get("saved_at", 0)) <= 0:
		print("  saved_at is missing or invalid")
		return false

	var player: Dictionary = loaded.get("player", {}) as Dictionary
	var wallet: Dictionary = loaded.get("wallet", {}) as Dictionary
	if String(player.get("id", "")) != "test_player" or int(player.get("level", 0)) != 3:
		print("  player payload changed: ", player)
		return false
	if int(wallet.get("coins", 0)) != 12480 or int(wallet.get("gems", 0)) != 350:
		print("  wallet payload changed: ", wallet)
		return false
	if not bool(loaded.get("is_onboarded", false)):
		print("  is_onboarded was not preserved")
		return false

	print("  wrote and reloaded save_v1 payload (%d keys)" % loaded.size())
	return true


## CostCurve.cost_at() must be an integer and strictly increasing for levels 1..50.
func test_cost_curve() -> bool:
	var previous := 0
	for level in range(1, 51):
		var cost: int = CostCurveScript.cost_at(60, 1.55, level)
		if typeof(cost) != TYPE_INT:
			print("  level %d cost is not an int" % level)
			return false
		if cost <= previous:
			print("  cost is not strictly increasing at level %d: %d <= %d" % [level, cost, previous])
			return false
		previous = cost
	print("  levels 1..50 are strictly increasing, level 50 = %d" % previous)
	return true
