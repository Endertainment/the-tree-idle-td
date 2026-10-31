## SettingsService — persistent user preferences (autoload).
##
## Stored in user://settings.cfg via ConfigFile. Every public setter writes once
## and emits changed(key) so live UI/audio can react immediately.
extends Node

signal changed(key: StringName)

const CONFIG_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_GAME := "game"
const SECTION_ACCESSIBILITY := "accessibility"
const SECTION_DEBUG := "debug"
const SECTION_PRIVACY := "privacy"

var config_path: String = CONFIG_PATH
const MIN_TEXT_SCALE := 1.0
const MAX_TEXT_SCALE := 1.3

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0
var language: String = "en"
var haptics: bool = true
var text_scale: float = 1.0
var shake: bool = true
var damage_numbers: bool = true
## Debug/QA only. FPS overlay and pseudo-locale are hidden in release builds.
var show_fps: bool = false
var pseudo_locale: bool = false
## Ads may not load before consent; default false in release, true in editor.
var consent_granted: bool = OS.is_debug_build()
## Desktop fake monetization (debug builds only).
var fake_monetization: bool = OS.is_debug_build()

var _initialized: bool = false


func _ready() -> void:
	language = _system_language()


## Loads settings from disk once. Safe to call more than once.
func init_service() -> void:
	if _initialized:
		return
	_initialized = true
	load_settings()


## Replaces current values with on-disk values (or defaults on first launch).
func load_settings() -> void:
	var config := ConfigFile.new()
	var error: Error = config.load(config_path)
	if error != OK:
		_apply_defaults()
		return

	master_volume = clampf(float(config.get_value(SECTION_AUDIO, "master", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value(SECTION_AUDIO, "music", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION_AUDIO, "sfx", 1.0)), 0.0, 1.0)
	ui_volume = clampf(float(config.get_value(SECTION_AUDIO, "ui", 1.0)), 0.0, 1.0)
	language = _normalize_language(str(config.get_value(SECTION_GAME, "language", _system_language())))
	text_scale = clampf(float(config.get_value(SECTION_GAME, "text_scale", 1.0)), MIN_TEXT_SCALE, MAX_TEXT_SCALE)
	haptics = bool(config.get_value(SECTION_ACCESSIBILITY, "haptics", true))
	shake = bool(config.get_value(SECTION_ACCESSIBILITY, "shake", true))
	damage_numbers = bool(config.get_value(SECTION_GAME, "damage_numbers", true))
	show_fps = bool(config.get_value(SECTION_DEBUG, "show_fps", false))
	pseudo_locale = bool(config.get_value(SECTION_DEBUG, "pseudo_locale", false))
	consent_granted = bool(config.get_value(SECTION_PRIVACY, "consent_granted", OS.is_debug_build()))
	fake_monetization = bool(config.get_value(SECTION_DEBUG, "fake_monetization", OS.is_debug_build()))


## Writes current values to user://settings.cfg.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, "master", master_volume)
	config.set_value(SECTION_AUDIO, "music", music_volume)
	config.set_value(SECTION_AUDIO, "sfx", sfx_volume)
	config.set_value(SECTION_AUDIO, "ui", ui_volume)
	config.set_value(SECTION_GAME, "language", language)
	config.set_value(SECTION_GAME, "text_scale", text_scale)
	config.set_value(SECTION_ACCESSIBILITY, "haptics", haptics)
	config.set_value(SECTION_ACCESSIBILITY, "shake", shake)
	config.set_value(SECTION_GAME, "damage_numbers", damage_numbers)
	config.set_value(SECTION_DEBUG, "show_fps", show_fps)
	config.set_value(SECTION_DEBUG, "pseudo_locale", pseudo_locale)
	config.set_value(SECTION_DEBUG, "fake_monetization", fake_monetization)
	config.set_value(SECTION_PRIVACY, "consent_granted", consent_granted)

	var error: Error = config.save(config_path)
	if error != OK:
		push_warning("SettingsService: could not save settings (error %d)" % error)


## Sets one of the four audio volumes: &"master", &"music", &"sfx", &"ui".
func set_volume(bus: StringName, linear: float) -> void:
	var value := clampf(linear, 0.0, 1.0)
	match bus:
		&"master":
			master_volume = value
		&"music":
			music_volume = value
		&"sfx":
			sfx_volume = value
		&"ui":
			ui_volume = value
		_:
			push_warning("SettingsService: unknown audio bus '%s'" % bus)
			return
	save_settings()
	changed.emit(bus)


## Sets and persists the preferred UI language ("en" or "uk").
func set_language(code: String) -> void:
	var normalized := _normalize_language(code)
	if normalized == language:
		return
	language = normalized
	save_settings()
	changed.emit(&"language")


## Sets and persists a boolean accessibility flag (&"haptics" or &"shake").
func set_flag(key: StringName, enabled: bool) -> void:
	match key:
		&"haptics":
			haptics = enabled
		&"shake":
			shake = enabled
		&"damage_numbers":
			damage_numbers = enabled
		&"show_fps":
			show_fps = enabled
		&"pseudo_locale":
			pseudo_locale = enabled
		_:
			push_warning("SettingsService: unknown flag '%s'" % key)
			return
	save_settings()
	changed.emit(key)


## Sets and persists the text scale multiplier (clamped to 1.0..1.3).
func set_text_scale(value: float) -> void:
	var normalized := clampf(value, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
	if is_equal_approx(normalized, text_scale):
		return
	text_scale = normalized
	save_settings()
	changed.emit(&"text_scale")


## Persists the ad-consent answer. AdsService gates every ad on this flag.
func set_consent_granted(granted: bool) -> void:
	if consent_granted == granted:
		return
	consent_granted = granted
	save_settings()
	changed.emit(&"consent_granted")


## Sets the debug fake-monetization switch (desktop only; no effect in release).
func set_fake_monetization(enabled: bool) -> void:
	if not OS.is_debug_build():
		return
	fake_monetization = enabled
	save_settings()
	changed.emit(&"fake_monetization")


## Applies the text scale to the live UI theme (no scene reload).
func apply_text_scale(root: Window) -> void:
	if root == null:
		return
	ThemeScaler.apply(root, text_scale)


## Returns true when a settings file already exists (first-launch check).
func has_stored_settings() -> bool:
	return FileAccess.file_exists(config_path)


## Settings payload mirrored into the v2 save document (spec 8.2).
func to_save_dict() -> Dictionary:
	return {
		"music": music_volume,
		"sfx": sfx_volume,
		"ui": ui_volume,
		"haptics": haptics,
		"language": language,
		"text_scale": text_scale,
		"shake": shake,
		"damage_numbers": damage_numbers,
	}


## Applies a settings payload from a save when no settings file exists yet.
func apply_save_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	music_volume = clampf(float(data.get("music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx", sfx_volume)), 0.0, 1.0)
	ui_volume = clampf(float(data.get("ui", ui_volume)), 0.0, 1.0)
	haptics = bool(data.get("haptics", haptics))
	language = _normalize_language(str(data.get("language", language)))
	text_scale = clampf(float(data.get("text_scale", text_scale)), MIN_TEXT_SCALE, MAX_TEXT_SCALE)
	shake = bool(data.get("shake", shake))
	damage_numbers = bool(data.get("damage_numbers", damage_numbers))


func _apply_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 1.0
	ui_volume = 1.0
	language = _system_language()
	haptics = true
	text_scale = 1.0
	shake = true
	damage_numbers = true
	show_fps = false
	pseudo_locale = false
	consent_granted = OS.is_debug_build()
	fake_monetization = OS.is_debug_build()


func _normalize_language(code: String) -> String:
	var lowered := code.to_lower()
	if lowered.begins_with("uk") or lowered.begins_with("ua"):
		return "uk"
	return "en"


func _system_language() -> String:
	return _normalize_language(OS.get_locale_language())
