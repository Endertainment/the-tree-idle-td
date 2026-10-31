## M5a tests: translation catalogue/lint, Ukrainian plurals, locale number and
## duration formatting, settings persistence, nickname validation and the audio
## bus volume mapping. Pure logic + temp files; no autoload globals are mutated.
extends RefCounted

const LocaleFormatScript := preload("res://scripts/util/locale_format.gd")
const ProfileRulesScript := preload("res://scripts/util/profile_rules.gd")
const AudioMathScript := preload("res://scripts/util/audio_math.gd")
const SettingsServiceScript := preload("res://scripts/autoload/settings_service.gd")
const LocaleLintScript := preload("res://tools/locale_lint.gd")
const TEST_SETTINGS_PATH := "user://test_settings_m5a.cfg"
const EN_TRANSLATION := "res://localization/strings.en.translation"
const UK_TRANSLATION := "res://localization/strings.uk.translation"


func test_locale_key_lint() -> bool:
	var result: Dictionary = LocaleLintScript.scan("res://")
	var errors: PackedStringArray = result.get("errors", PackedStringArray())
	if not errors.is_empty():
		for error: String in errors:
			print("  ", error)
		return false
	if int(result.get("keys", 0)) < 400:
		print("  expected a full catalogue, got ", result.get("keys", 0))
		return false
	print("  %d keys, all used keys present, no unused keys" % int(result.get("keys", 0)))
	return true


func test_translation_catalogues_load() -> bool:
	var en := load(EN_TRANSLATION) as Translation
	var uk := load(UK_TRANSLATION) as Translation
	if en == null or uk == null:
		print("  translation resources are missing")
		return false
	var samples := [
		"menu.battle", "tree_upgrade.damage", "settings.title",
		"onboarding.title", "plural.coins.many", "menu.nav.workshop",
	]
	for key: String in samples:
		if en.get_message(key).is_empty() or uk.get_message(key).is_empty():
			print("  missing translation: ", key)
			return false
	if uk.get_message("menu.battle") != "Бій":
		print("  uk menu.battle = ", uk.get_message("menu.battle"))
		return false
	if uk.get_message("settings.title") != "Налаштування":
		print("  uk settings.title = ", uk.get_message("settings.title"))
		return false
	print("  en/uk catalogues load and contain the spec key families")
	return true


func test_ukrainian_plural_rules() -> bool:
	var expected := {
		1: "one", 2: "few", 3: "few", 4: "few", 5: "many", 10: "many",
		11: "many", 12: "many", 14: "many", 21: "one", 22: "few",
		25: "many", 101: "one", 111: "many",
	}
	for count: int in expected.keys():
		var form := LocaleFormatScript.plural_form(count, "uk")
		if form != expected[count]:
			print("  uk plural %d -> %s (expected %s)" % [count, form, expected[count]])
			return false
	if LocaleFormatScript.plural_form(1, "en") != "one":
		return false
	if LocaleFormatScript.plural_form(2, "en") != "other":
		return false
	var uk := load(UK_TRANSLATION) as Translation
	if uk.get_message("plural.coins.one") != "монета":
		print("  plural.coins.one = ", uk.get_message("plural.coins.one"))
		return false
	if uk.get_message("plural.coins.few") != "монети":
		return false
	if uk.get_message("plural.coins.many") != "монет":
		return false
	print("  uk one/few/many incl. the 11-14 exception verified")
	return true


func test_number_and_duration_formatting() -> bool:
	if LocaleFormatScript.format_number(12480, "uk") != "12\u00a0480":
		print("  uk number = ", LocaleFormatScript.format_number(12480, "uk"))
		return false
	if LocaleFormatScript.format_number(12480, "en") != "12,480":
		print("  en number = ", LocaleFormatScript.format_number(12480, "en"))
		return false
	if LocaleFormatScript.format_number(-1234567, "uk") != "-1\u00a0234\u00a0567":
		return false
	if LocaleFormatScript.format_duration(8100, "uk") != "2г 15хв":
		print("  uk duration = ", LocaleFormatScript.format_duration(8100, "uk"))
		return false
	if LocaleFormatScript.format_duration(8100, "en") != "2h 15m":
		return false
	if LocaleFormatScript.format_duration(59, "en") != "59s":
		return false
	if LocaleFormatScript.format_duration(59, "uk") != "59с":
		return false
	if LocaleFormatScript.format_countdown(90061, "en") != "1d 01h 01m":
		print("  countdown = ", LocaleFormatScript.format_countdown(90061, "en"))
		return false
	print("  12 480 / 12,480, 2г 15хв / 2h 15m and countdowns verified")
	return true


func test_pseudo_locale() -> bool:
	var original := "Wave cleared"
	var pseudo: String = LocaleFormatScript.pseudo(original)
	if pseudo.length() < int(float(original.length()) * 1.3):
		print("  pseudo string is not long enough: ", pseudo)
		return false
	if not pseudo.ends_with("\u2026"):
		print("  pseudo string must end with the overflow marker")
		return false
	print("  pseudo-locale doubles vowels and adds the overflow marker")
	return true


func test_settings_persistence() -> bool:
	var first: Node = SettingsServiceScript.new()
	first.set("config_path", TEST_SETTINGS_PATH)
	first.call("set_volume", &"music", 0.42)
	first.call("set_volume", &"sfx", 0.7)
	first.call("set_language", "uk")
	first.call("set_text_scale", 1.15)
	first.call("set_flag", &"shake", false)
	first.call("set_flag", &"damage_numbers", false)
	first.call("save_settings")
	first.free()

	var second: Node = SettingsServiceScript.new()
	second.set("config_path", TEST_SETTINGS_PATH)
	second.call("load_settings")
	var ok := true
	if not is_equal_approx(float(second.get("music_volume")), 0.42):
		print("  music volume did not persist: ", second.get("music_volume"))
		ok = false
	if str(second.get("language")) != "uk":
		print("  language did not persist: ", second.get("language"))
		ok = false
	if not is_equal_approx(float(second.get("text_scale")), 1.15):
		print("  text scale did not persist: ", second.get("text_scale"))
		ok = false
	if bool(second.get("shake")) or bool(second.get("damage_numbers")):
		print("  boolean flags did not persist")
		ok = false
	second.free()
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	if ok:
		print("  volumes, language, text scale and flags survive a restart")
	return ok


func test_nickname_validation() -> bool:
	if ProfileRulesScript.validate_nickname("") != "onboarding.error.empty":
		return false
	if ProfileRulesScript.validate_nickname("ab") != "onboarding.error.short":
		return false
	if ProfileRulesScript.validate_nickname("abcdefghijklmnopq") != "onboarding.error.long":
		return false
	if ProfileRulesScript.validate_nickname("bad name") != "onboarding.error.chars":
		return false
	if ProfileRulesScript.validate_nickname("bad-name") != "onboarding.error.chars":
		return false
	if ProfileRulesScript.validate_nickname("Лісовик") != "":
		print("  cyrillic nickname must be valid")
		return false
	if ProfileRulesScript.validate_nickname("ok_name9") != "":
		return false
	if ProfileRulesScript.validate_nickname("abc") != "":
		return false
	var uuid := ProfileRulesScript.make_uuid_v4()
	var regex := RegEx.new()
	if regex.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$") != OK:
		return false
	if regex.search(uuid) == null:
		print("  uuid v4 format invalid: ", uuid)
		return false
	print("  3-16 chars, unicode letters and RFC 4122 UUID v4 verified")
	return true


func test_audio_bus_volume_mapping() -> bool:
	if not is_equal_approx(AudioMathScript.volume_to_db(1.0), 0.0):
		return false
	if not is_equal_approx(AudioMathScript.volume_to_db(0.5), -6.0206):
		print("  half volume = ", AudioMathScript.volume_to_db(0.5), " dB")
		return false
	if AudioMathScript.volume_to_db(0.0) != -80.0:
		return false
	if AudioMathScript.volume_to_db(1.5) != 0.0:
		return false
	if AudioMathScript.volume_to_db(-1.0) != -80.0:
		return false
	print("  0 -> -80 dB (mute), 0.5 -> -6.02 dB, 1.0 -> 0 dB, clamped")
	return true
