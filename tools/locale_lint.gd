## LocaleLint — checks that every translation key used in scenes/scripts/data
## exists in localization/strings.csv and that the CSV has no unused keys.
##
## Used by tools/lint_locale.gd (CLI, non-zero exit) and by tests/run_tests.gd
## (same scan, no process exit). Pure file I/O; no autoloads required.
class_name LocaleLint
extends RefCounted

const CSV_PATH := "res://localization/strings.csv"
const KEY_PATTERN := r"^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$"
const PLACEHOLDER_PATTERN := r"%(?:\d+\$)?[0-9.]*[dsf%]|\{[a-z]+\}"

## Key prefixes that are assembled at runtime (format strings). Their suffixes
## are validated against the CSV, but they are not reported as unused keys.
const DYNAMIC_PREFIXES: Array[String] = [
	"cards.rarity.",
	"cards.filter.",
	"card.",
	"magica.",
	"mission.",
	"stat.",
	"settings.",
	"unlock.",
	"onboarding.",
	"plural.",
	"menu.nav.",
	"shop.product.",
	"shop.contents.",
	"shop.tab.",
	"shop.purchase_",
	"leaderboard.tab.",
]


## Runs the whole audit. Returns:
## { keys, used, missing: PackedStringArray, unused: PackedStringArray, errors: PackedStringArray }
static func scan(root_path: String = "res://") -> Dictionary:
	var errors: PackedStringArray = []
	var rows := _read_csv(errors)
	var keys: Dictionary = {}
	for row: Dictionary in rows:
		var key := str(row.get("key", ""))
		if key.is_empty():
			continue
		if keys.has(key):
			errors.append("duplicate key: %s" % key)
		keys[key] = true
		var en := str(row.get("en", ""))
		var uk := str(row.get("uk", ""))
		if en.strip_edges().is_empty():
			errors.append("empty en: %s" % key)
		if uk.strip_edges().is_empty():
			errors.append("empty uk: %s" % key)
		if not _matches(key, KEY_PATTERN):
			errors.append("bad key format: %s" % key)
		var en_placeholders := _placeholders(en)
		var uk_placeholders := _placeholders(uk)
		if en_placeholders != uk_placeholders:
			errors.append("placeholder mismatch %s: %s vs %s" % [key, en_placeholders, uk_placeholders])

	var used: Dictionary = {}
	_scan_dir(root_path, used, errors)

	for key: String in keys.keys():
		if used.has(key):
			continue
		if _is_dynamic(key):
			continue
		errors.append("unused key: %s" % key)

	var missing: PackedStringArray = []
	for key: String in used.keys():
		if not keys.has(key):
			missing.append(key)
			errors.append("missing key: %s" % key)

	var unused: PackedStringArray = []
	for key: String in keys.keys():
		if not used.has(key) and not _is_dynamic(key):
			unused.append(key)

	missing.sort()
	unused.sort()
	errors.sort()
	return {
		"keys": keys.size(),
		"used": used.size(),
		"missing": missing,
		"unused": unused,
		"errors": errors,
	}


static func _read_csv(errors: PackedStringArray) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		errors.append("cannot open %s" % CSV_PATH)
		return rows
	var header := file.get_csv_line()
	var key_index := header.find("keys")
	var en_index := header.find("en")
	var uk_index := header.find("uk")
	if key_index < 0 or en_index < 0 or uk_index < 0:
		errors.append("strings.csv must have keys,en,uk columns")
		return rows
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() <= maxi(key_index, maxi(en_index, uk_index)):
			continue
		if line[key_index].is_empty() and line[en_index].is_empty() and line[uk_index].is_empty():
			continue
		rows.append({
			"key": line[key_index],
			"en": line[en_index],
			"uk": line[uk_index],
		})
	file.close()
	return rows


static func _scan_dir(dir_path: String, used: Dictionary, errors: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry not in ["addons", "build"]:
				_scan_dir(path, used, errors)
		else:
			var extension := entry.get_extension()
			if extension == "gd":
				_scan_gd(path, used)
			elif extension == "tscn":
				_scan_tscn(path, used)
			elif extension == "tres":
				_scan_tres(path, used)
		entry = dir.get_next()
	dir.list_dir_end()


static func _scan_gd(path: String, used: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	for key: String in _find_all(text, r"LocaleService\.t\(\s*\"([^\"]+)\""):
		if "%" not in key:
			used[key] = true
	for key: String in _find_all(text, r"(?<![A-Za-z_.])tr\(\s*\"([^\"]+)\""):
		used[key] = true
	for key: String in _find_all(text, r"(?<![A-Za-z_.])_t\(\s*\"([^\"]+)\""):
		used[key] = true
	for base: String in _find_all(text, r"LocaleService\.plural\(\s*[^,]+,\s*\"([^\"]+)\""):
		for suffix: String in ["one", "few", "many", "other"]:
			used["%s.%s" % [base, suffix]] = true
	for key: String in _find_all(text, r"has_key\(\s*\"([^\"]+)\""):
		used[key] = true


static func _scan_tscn(path: String, used: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	for value: String in _find_all(text, r"(?m)^\s*(?:text|tooltip_text|placeholder_text)\s*=\s*\"([^\"]+)\""):
		if _matches(value, KEY_PATTERN):
			used[value] = true


static func _scan_tres(path: String, used: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	for value: String in _find_all(
		text,
		r"(?m)^\s*(?:name_key|display_name_key|description_key|title_key|effect_key|label_key)\s*=\s*\"([^\"]+)\""
	):
		used[value] = true


static func _find_all(text: String, pattern: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return result
	for match_result: RegExMatch in regex.search_all(text):
		result.append(match_result.get_string(1))
	return result


static func _placeholders(text: String) -> String:
	var regex := RegEx.new()
	if regex.compile(PLACEHOLDER_PATTERN) != OK:
		return ""
	var found: PackedStringArray = []
	for match_result: RegExMatch in regex.search_all(text):
		found.append(match_result.get_string())
	found.sort()
	return ",".join(found)


static func _matches(text: String, pattern: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return false
	return regex.search(text) != null


static func _is_dynamic(key: String) -> bool:
	for prefix: String in DYNAMIC_PREFIXES:
		if key.begins_with(prefix):
			return true
	return false
