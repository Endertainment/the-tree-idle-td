## LocaleService — language selection and locale-aware formatting (autoload).
##
## Translation catalogues are added in M5. Until then t() calls tr() and falls
## back to the supplied English text (or the key itself) so no screen is empty.
extends Node

signal language_changed(language: String)

const SUPPORTED_LANGUAGES: Array[String] = ["en", "uk"]

var language: String = "en"


func _ready() -> void:
	language = _system_language()
	TranslationServer.set_locale(language)


## Applies the saved language at boot. Safe to call more than once.
func init_service() -> void:
	set_language(SettingsService.language)


## Returns the current language code ("en" or "uk").
func get_language() -> String:
	return language


## Switches the active language immediately (no scene reload).
func set_language(code: String) -> void:
	var normalized := _normalize_language(code)
	var changed_language := normalized != language
	language = normalized
	TranslationServer.set_locale(language)
	if changed_language:
		language_changed.emit(language)


## Translates a key and falls back to `fallback` (then to the key) when the
## translation catalogue does not contain it yet.
func t(key: String, fallback: String = "") -> String:
	var translated: String = tr(key)
	if translated != key:
		return translated
	if not fallback.is_empty():
		return fallback
	return key


## Formats an integer with locale-aware thousands separators: 12 480 / 12,480.
func format_number(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = _group_separator() + grouped
	var sign_prefix := "-" if value < 0 else ""
	return sign_prefix + grouped


## Formats a duration as "2h 15m" / "2г 15хв" (or seconds below one minute).
func format_duration(seconds: int) -> String:
	var total := maxi(seconds, 0)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60
	if hours > 0:
		return "%d%s %d%s" % [hours, _unit("h"), minutes, _unit("m")]
	if minutes > 0:
		return "%d%s" % [minutes, _unit("m")]
	return "%d%s" % [secs, _unit("s")]


## Pluralisation stub: returns the translated key when available, otherwise
## "key (N)". Real Ukrainian plural rules arrive with the M5 translation pass.
func plural(count: int, key: String) -> String:
	var translated: String = tr(key)
	if translated != key:
		return translated
	return "%s (%d)" % [key, count]


func _group_separator() -> String:
	return "\u00a0" if language == "uk" else ","


func _unit(kind: String) -> String:
	if language == "uk":
		match kind:
			"h":
				return "\u0433"
			"m":
				return "\u0445\u0432"
			_:
				return "\u0441"
	match kind:
		"h":
			return "h"
		"m":
			return "m"
		_:
			return "s"


func _normalize_language(code: String) -> String:
	var lowered := code.to_lower()
	if lowered.begins_with("uk") or lowered.begins_with("ua"):
		return "uk"
	return "en"


func _system_language() -> String:
	return _normalize_language(OS.get_locale_language())
