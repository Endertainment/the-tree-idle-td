## OnboardingScreen — first launch: language → nickname + avatar → Play (spec 13.2).
##
## Two pages in one scene. The profile is written once, `is_onboarded` becomes
## true and SaveService flushes immediately. Boot routes here only when the save
## says the player is not onboarded. Settings → Reset profile returns here.
class_name OnboardingScreen
extends Control

const AVATAR_COUNT := 6
const MIN_NICKNAME := 3
const MAX_NICKNAME := 16
const AVATAR_PATH := "res://assets/art/ui/menu/avatar_%02d.png"
const INPUT_TEXTURE := "res://assets/art/meta/onboarding/input_9p.png"

@onready var _back_button: Button = %BackButton
@onready var _step_label: Label = %StepLabel
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _language_page: VBoxContainer = %LanguagePage
@onready var _profile_page: VBoxContainer = %ProfilePage
@onready var _language_buttons: HBoxContainer = %LanguageButtons
@onready var _nickname_edit: LineEdit = %NicknameEdit
@onready var _error_label: Label = %ErrorLabel
@onready var _avatar_grid: GridContainer = %AvatarGrid
@onready var _continue_button: Button = %ContinueButton

var _step: int = 0
var _avatar_id: String = "avatar_01"
var _avatar_buttons: Dictionary = {}
var _language_choice: String = "uk"
var _played: bool = false


func _ready() -> void:
	_language_choice = LocaleService.language
	_build_language_buttons()
	_build_avatars()
	_style_nickname_edit()
	_back_button.pressed.connect(_on_back_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_nickname_edit.text_changed.connect(_on_nickname_changed)
	_nickname_edit.text_submitted.connect(_on_nickname_submitted)
	LocaleService.language_changed.connect(_on_language_changed)
	_show_step(0)
	AudioBus.bind_buttons(self)


func _exit_tree() -> void:
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


# --- public/pure API (tests) ---------------------------------------------------

## Returns an empty string when `value` is a valid nickname, else an error key.
static func validate_nickname(value: String) -> String:
	return ProfileRules.validate_nickname(value)


## Generates an RFC 4122 UUID v4 string.
static func make_uuid_v4() -> String:
	return ProfileRules.make_uuid_v4()


# --- build -------------------------------------------------------------------

func _build_language_buttons() -> void:
	for code: String in ["uk", "en"]:
		var button := Button.new()
		button.name = "Language%s" % code.to_upper()
		button.text = LocaleService.t("settings.language.%s" % code, code.to_upper())
		button.custom_minimum_size = Vector2(380, 150)
		button.theme_type_variation = &"PrimaryButton"
		button.pressed.connect(_on_language_pressed.bind(code))
		_language_buttons.add_child(button)
	_style_language_buttons()


func _style_language_buttons() -> void:
	for child: Node in _language_buttons.get_children():
		var button := child as Button
		if button == null:
			continue
		var code := button.name.to_lower().trim_prefix("language")
		var active := code == _language_choice
		button.theme_type_variation = &"GoldButton" if active else &"PrimaryButton"
		button.modulate = Color.WHITE if active else Color(0.82, 0.86, 0.8, 1.0)


func _build_avatars() -> void:
	for index in range(1, AVATAR_COUNT + 1):
		var avatar_id := "avatar_%02d" % index
		var button := Button.new()
		button.name = "Avatar%d" % index
		button.custom_minimum_size = Vector2(200, 200)
		button.expand_icon = true
		button.icon = load(AVATAR_PATH % index) as Texture2D
		button.tooltip_text = LocaleService.t("onboarding.avatar_alt", "Avatar %d") % index
		button.pressed.connect(_on_avatar_pressed.bind(avatar_id))
		_avatar_grid.add_child(button)
		_avatar_buttons[avatar_id] = button
	_style_avatars()


func _style_avatars() -> void:
	for avatar_id: String in _avatar_buttons.keys():
		var button: Button = _avatar_buttons[avatar_id]
		var active := avatar_id == _avatar_id
		button.theme_type_variation = &"GoldButton" if active else &"SecondaryButton"
		button.modulate = Color.WHITE if active else Color(0.72, 0.78, 0.72, 1.0)


func _style_nickname_edit() -> void:
	_nickname_edit.add_theme_font_size_override("font_size", 44)
	var texture := load(INPUT_TEXTURE) as Texture2D
	if texture == null:
		return
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = 28
	box.texture_margin_right = 28
	box.texture_margin_top = 20
	box.texture_margin_bottom = 20
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	_nickname_edit.add_theme_stylebox_override("normal", box)
	_nickname_edit.add_theme_stylebox_override("focus", box)


# --- pages -------------------------------------------------------------------

func _show_step(step: int) -> void:
	_step = clampi(step, 0, 1)
	_language_page.visible = _step == 0
	_profile_page.visible = _step == 1
	_back_button.visible = _step == 1
	_continue_button.text = LocaleService.t(
		"onboarding.continue" if _step == 0 else "onboarding.play",
		"Continue" if _step == 0 else "Play"
	)
	_continue_button.disabled = false
	_localize()
	if _step == 1:
		_nickname_edit.grab_focus()
		_validate_live()


func _localize() -> void:
	_title.text = LocaleService.t("onboarding.title", "Welcome to the forest")
	_subtitle.visible = _step == 0
	_subtitle.text = LocaleService.t(
		"onboarding.language_subtitle",
		"You can change it later in Settings."
	)
	_step_label.text = LocaleService.t("onboarding.step", "Step %d of 2") % (_step + 1)
	_continue_button.text = LocaleService.t(
		"onboarding.continue" if _step == 0 else "onboarding.play",
		"Continue" if _step == 0 else "Play"
	)
	_back_button.text = LocaleService.t("common.back", "Back")
	_nickname_edit.placeholder_text = LocaleService.t("onboarding.nickname", "Nickname")
	# Auto-translated labels (titles, hints) refresh through the engine; buttons
	# built in code need their text explicitly re-applied.
	for child: Node in _language_buttons.get_children():
		var button := child as Button
		if button == null:
			continue
		var code := button.name.to_lower().trim_prefix("language")
		button.text = LocaleService.t("settings.language.%s" % code, code.to_upper())
	for index in range(1, AVATAR_COUNT + 1):
		var avatar_button: Button = _avatar_buttons.get("avatar_%02d" % index, null)
		if avatar_button != null:
			avatar_button.tooltip_text = LocaleService.t("onboarding.avatar_alt", "Avatar %d") % index
	_style_language_buttons()


func _on_language_changed(_code: String) -> void:
	_language_choice = LocaleService.language
	_localize()


func _on_language_pressed(code: String) -> void:
	_language_choice = code
	SettingsService.set_language(code)
	LocaleService.set_language(code)
	_style_language_buttons()


func _on_avatar_pressed(avatar_id: String) -> void:
	_avatar_id = avatar_id
	_style_avatars()


func _on_back_pressed() -> void:
	_show_step(0)


## Android back: step 2 returns to language; step 1 never skips onboarding.
func handle_back_request() -> bool:
	if _step == 1:
		_show_step(0)
	return true


func _on_continue_pressed() -> void:
	if _step == 0:
		_show_step(1)
		return
	_on_play_pressed()


func _on_nickname_changed(_text: String) -> void:
	_validate_live()


func _on_nickname_submitted(_text: String) -> void:
	_on_play_pressed()


func _validate_live() -> void:
	var error_key := validate_nickname(_nickname_edit.text)
	var has_text := not _nickname_edit.text.strip_edges().is_empty()
	_error_label.visible = has_text and not error_key.is_empty()
	if _error_label.visible:
		_error_label.text = LocaleService.t(error_key, error_key)
	_continue_button.disabled = not error_key.is_empty() or _played


func _on_play_pressed() -> void:
	if _played:
		return
	var error_key := validate_nickname(_nickname_edit.text)
	if not error_key.is_empty():
		_error_label.visible = true
		_error_label.text = LocaleService.t(error_key, error_key)
		return
	_played = true
	_continue_button.disabled = true
	GameState.player["id"] = make_uuid_v4()
	GameState.player["nickname"] = _nickname_edit.text.strip_edges()
	GameState.player["avatar_id"] = _avatar_id
	GameState.player["created_at"] = int(Time.get_unix_time_from_system())
	GameState.is_onboarded = true
	SaveService.flush()
	SceneRouter.goto(&"main_menu")
