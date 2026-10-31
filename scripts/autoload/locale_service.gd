## LocaleService — language selection, locale-aware formatting and plural rules.
##
## Translations live in `localization/strings.csv` (keys,en,uk); Godot imports it
## into `strings.en.translation` / `strings.uk.translation` and project.godot
## registers both. Every visible string is a key; `t()` returns the translation
## from the active catalogue. Switching language only calls
## `TranslationServer.set_locale()` and emits `language_changed`, so screens that
## build text in code can refresh without a scene reload (static .tscn labels are
## re-translated by the engine). Pure formatting rules live in LocaleFormat.
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


## Returns true when `key` exists in the active translation catalogue.
func has_key(key: String) -> bool:
	return tr(key) != key


## Translates a key and falls back to `fallback` (then to the key) when the
## catalogue does not contain it yet. `fallback` is authoring/debug aid only;
## shipped keys must exist in strings.csv (enforced by tools/lint_locale.gd).
func t(key: String, fallback: String = "") -> String:
	var translated: String = tr(key)
	if translated == key:
		translated = fallback if not fallback.is_empty() else key
	if _pseudo_enabled():
		translated = pseudo(translated)
	return translated


## Applies the debug pseudo-locale transform (+~60 % length, marks overflow).
func pseudo(text: String) -> String:
	return LocaleFormat.pseudo(text)


## Formats an integer with locale-aware thousands separators: 12 480 / 12,480.
func format_number(value: int) -> String:
	return LocaleFormat.format_number(value, language)


## Formats `value` for an explicit language (pure helper used by unit tests).
static func format_number_for(value: int, code: String) -> String:
	return LocaleFormat.format_number(value, code)


static func group_separator_for(code: String) -> String:
	return LocaleFormat.group_separator(code)


## Formats "2h 15m" (en) or "2г 15хв" (uk); seconds below a minute.
func format_duration(seconds: int) -> String:
	return LocaleFormat.format_duration(seconds, language)


## Formats `seconds` for an explicit language (pure helper used by unit tests).
static func format_duration_for(seconds: int, code: String) -> String:
	return LocaleFormat.format_duration(seconds, code)


## Formats a countdown with days/hours/minutes (missions reset timer).
func format_countdown(seconds: int) -> String:
	return LocaleFormat.format_countdown(seconds, language)


## Formats `seconds` as a countdown for an explicit language (pure helper).
static func format_countdown_for(seconds: int, code: String) -> String:
	return LocaleFormat.format_countdown(seconds, code)


static func duration_unit_for(kind: String, code: String) -> String:
	return LocaleFormat.duration_unit(kind, code)


## Formats 0..1 as a whole percentage ("42 %").
func format_percent(ratio: float, include_sign: bool = false) -> String:
	var value := roundi(clampf(ratio, -1.0, 1.0) * 100.0)
	if include_sign:
		return "%+d %%" % value
	return "%d %%" % value


## Returns the plural word for `count` (e.g. "монети") using `.one/.few/.many`
## keys plus `.other`. Values live centrally in strings.csv.
func plural(count: int, key_base: String) -> String:
	var form := plural_form_for(count, language)
	var candidate := "%s.%s" % [key_base, form]
	var translated := tr(candidate)
	if translated == candidate and form != "other":
		translated = tr(key_base + ".other")
	if translated == candidate:
		translated = tr(key_base)
	if translated == candidate:
		return "%d" % count
	return translated


## Returns "12 480 монет" / "12,480 coins".
func plural_count(count: int, key_base: String) -> String:
	return "%s %s" % [format_number(count), plural(count, key_base)]


## Pure Ukrainian/English plural category selector (unit-testable).
static func plural_form_for(count: int, code: String) -> String:
	return LocaleFormat.plural_form(count, code)


func _pseudo_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	var settings := get_node_or_null("/root/SettingsService")
	return settings != null and bool(settings.get("pseudo_locale"))


func _normalize_language(code: String) -> String:
	var lowered := code.to_lower()
	if lowered.begins_with("uk") or lowered.begins_with("ua"):
		return "uk"
	return "en"


func _system_language() -> String:
	return _normalize_language(OS.get_locale_language())
