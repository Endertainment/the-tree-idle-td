extends SceneTree
## Translation key audit (spec §10): fails when a key used by a scene, script or
## data resource is missing from localization/strings.csv, or when the CSV keeps
## an unused key. Also validates key format, empty cells and placeholder parity.
##
## Run: godot --headless --path . --script res://tools/lint_locale.gd
## Exit code 0 = clean, 1 = missing/unused keys or invalid rows.
const LocaleLintScript := preload("res://tools/locale_lint.gd")


func _initialize() -> void:
	var result := LocaleLintScript.scan("res://")
	var errors: PackedStringArray = result.get("errors", PackedStringArray())
	print("== locale lint ==")
	print("keys: %d, used: %d, missing: %d, unused: %d" % [
		int(result.get("keys", 0)),
		int(result.get("used", 0)),
		(result.get("missing", PackedStringArray()) as PackedStringArray).size(),
		(result.get("unused", PackedStringArray()) as PackedStringArray).size(),
	])
	for error: String in errors:
		print("[ FAIL ] ", error)
	if errors.is_empty():
		print("[ PASS ] every used key exists and every CSV key is used")
		quit(0)
	else:
		print("== %d problem(s) ==" % errors.size())
		quit(1)
