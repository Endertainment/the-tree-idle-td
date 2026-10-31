## SettingsScreen — audio, game, account, legal and about (spec 13.12).
##
## Every control applies live: volumes hit AudioService through
## SettingsService.changed, the language switch only changes the translation
## locale, and text scale re-duplicates the theme without reloading the scene.
## The screen can be pushed as a scene (gear on the main menu) or opened as a
## modal overlay from the battle pause menu; back handles both.
extends Control

const MAX_SLIDER_WIDTH := 520

@onready var _back_button: Button = %BackButton
@onready var _title: Label = %TitleLabel
@onready var _audio_rows: VBoxContainer = %AudioRows
@onready var _game_rows: VBoxContainer = %GameRows
@onready var _account_rows: VBoxContainer = %AccountRows
@onready var _legal_rows: VBoxContainer = %LegalRows
@onready var _about_rows: VBoxContainer = %AboutRows
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _legal_modal: Modal = %LegalModal
@onready var _reset_modal: Modal = %ResetModal

var _toast_tween: Tween
var _fps_label: Label


func _ready() -> void:
	_localize()
	_back_button.pressed.connect(_on_back_pressed)
	LocaleService.language_changed.connect(_on_language_changed)
	_toast.visible = false
	_legal_modal.confirmed.connect(func() -> void: pass)
	_reset_modal.confirmed.connect(_on_reset_confirmed)
	_build_fps_label()
	_rebuild()
	set_process(true)


func _exit_tree() -> void:
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _process(_delta: float) -> void:
	if _fps_label == null or not _fps_label.visible:
		return
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _localize() -> void:
	_title.text = LocaleService.t("settings.title", "Settings")
	_back_button.text = LocaleService.t("common.back", "Back")


func _on_language_changed(_code: String) -> void:
	_localize()
	_rebuild()


func _on_back_pressed() -> void:
	SaveService.request_save()
	if SceneRouter.has_overlay():
		SceneRouter.close_overlay()
	else:
		SceneRouter.back()


func _rebuild() -> void:
	_clear(_audio_rows)
	_clear(_game_rows)
	_clear(_account_rows)
	_clear(_legal_rows)
	_clear(_about_rows)
	_build_audio()
	_build_game()
	_build_account()
	_build_legal()
	_build_about()
	AudioBus.bind_buttons(self)


func _clear(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


# --- rows ----------------------------------------------------------------------

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Body"
	label.modulate = Color(1.0, 0.83, 0.45, 1.0)
	return label


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 96)
	row.add_theme_constant_override("separation", 16)
	return row


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Body"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _option_button(text: String, active: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 88)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"GoldButton" if active else &"SecondaryButton"
	button.pressed.connect(callback)
	return button


func _value_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Caption"
	label.custom_minimum_size = Vector2(120, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


# --- audio ---------------------------------------------------------------------

func _build_audio() -> void:
	_add_volume_row(&"music", "settings.music", SettingsService.music_volume)
	_add_volume_row(&"sfx", "settings.sfx", SettingsService.sfx_volume)
	_add_volume_row(&"ui", "settings.ui", SettingsService.ui_volume)


func _add_volume_row(bus: StringName, key: String, value: float) -> void:
	var row := _row()
	row.add_child(_row_label(LocaleService.t(key, String(bus).capitalize())))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 56)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	var percent := _value_label("%d %%" % roundi(value * 100.0))
	slider.value_changed.connect(func(new_value: float) -> void:
		SettingsService.set_volume(bus, new_value)
		percent.text = "%d %%" % roundi(new_value * 100.0)
	)
	row.add_child(slider)
	row.add_child(percent)
	_audio_rows.add_child(row)


func _style_slider(slider: HSlider) -> void:
	var track_texture := load("res://assets/art/ui/common/slider_track.png") as Texture2D
	var fill_texture := load("res://assets/art/ui/common/slider_fill.png") as Texture2D
	var knob_texture := load("res://assets/art/ui/common/slider_knob.png") as Texture2D
	if track_texture != null:
		var track := StyleBoxTexture.new()
		track.texture = track_texture
		track.modulate_color = Color(0.92, 0.97, 0.88, 1.0)
		slider.add_theme_stylebox_override("slider", track)
	if fill_texture != null:
		var fill := StyleBoxTexture.new()
		fill.texture = fill_texture
		fill.modulate_color = Color(1.0, 0.85, 0.4, 1.0)
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	if knob_texture != null:
		slider.add_theme_icon_override("grabber", knob_texture)
		slider.add_theme_icon_override("grabber_highlight", knob_texture)


# --- game ----------------------------------------------------------------------

func _build_game() -> void:
	_add_language_row()
	_add_text_scale_row()
	_add_toggle_row(&"shake", "settings.shake", SettingsService.shake)
	_add_toggle_row(&"haptics", "settings.haptics", SettingsService.haptics)
	_add_toggle_row(&"damage_numbers", "settings.damage_numbers", SettingsService.damage_numbers)
	if OS.is_debug_build():
		_add_toggle_row(&"show_fps", "settings.fps", SettingsService.show_fps)
		_add_toggle_row(&"pseudo_locale", "settings.pseudo_locale", SettingsService.pseudo_locale)


func _add_language_row() -> void:
	var row := _row()
	row.add_child(_row_label(LocaleService.t("settings.language", "Language")))
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 12)
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for code: String in ["uk", "en"]:
		var key := "settings.language.%s" % code
		var button := _option_button(LocaleService.t(key, code.to_upper()), LocaleService.language == code,
			func() -> void: _set_language(code))
		button.custom_minimum_size = Vector2(230, 88)
		group.add_child(button)
	row.add_child(group)
	_game_rows.add_child(row)


func _add_text_scale_row() -> void:
	var row := _row()
	row.add_child(_row_label(LocaleService.t("settings.text_scale", "Text size")))
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 10)
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for step: int in [100, 115, 130]:
		var scale := float(step) / 100.0
		var active := is_equal_approx(SettingsService.text_scale, scale)
		var button := _option_button(LocaleService.t("settings.text_scale.%d" % step, "%d %%" % step), active,
			func() -> void: _set_text_scale(scale))
		button.custom_minimum_size = Vector2(150, 88)
		group.add_child(button)
	row.add_child(group)
	_game_rows.add_child(row)


func _add_toggle_row(key: StringName, label_key: String, value: bool) -> void:
	var row := _row()
	row.add_child(_row_label(LocaleService.t(label_key, String(key))))
	var state_key := "settings.on" if value else "settings.off"
	var button := _option_button(
		LocaleService.t(state_key, "On" if value else "Off"),
		value,
		func() -> void: _toggle(key)
	)
	button.custom_minimum_size = Vector2(230, 88)
	row.add_child(button)
	_game_rows.add_child(row)


func _set_language(code: String) -> void:
	SettingsService.set_language(code)
	LocaleService.set_language(code)
	SaveService.request_save()


func _set_text_scale(scale: float) -> void:
	SettingsService.set_text_scale(scale)
	SettingsService.apply_text_scale(get_window())
	SaveService.request_save()
	_rebuild()


func _toggle(key: StringName) -> void:
	var current := false
	match key:
		&"shake":
			current = SettingsService.shake
		&"haptics":
			current = SettingsService.haptics
		&"damage_numbers":
			current = SettingsService.damage_numbers
		&"show_fps":
			current = SettingsService.show_fps
		&"pseudo_locale":
			current = SettingsService.pseudo_locale
	SettingsService.set_flag(key, not current)
	if key == &"show_fps":
		_build_fps_label()
		_fps_label.visible = SettingsService.show_fps
	SaveService.request_save()
	_rebuild()


# --- account -------------------------------------------------------------------

func _build_account() -> void:
	var nickname_row := _row()
	nickname_row.add_child(_row_label(LocaleService.t("settings.nickname", "Nickname")))
	var nickname := _value_label(str(GameState.player.get("nickname", "")))
	nickname.custom_minimum_size = Vector2(420, 0)
	nickname_row.add_child(nickname)
	_account_rows.add_child(nickname_row)

	var id_row := _row()
	id_row.add_child(_row_label(LocaleService.t("settings.player_id", "Player ID")))
	var player_id := _value_label(str(GameState.player.get("id", "")))
	player_id.custom_minimum_size = Vector2(420, 0)
	player_id.add_theme_font_size_override("font_size", 22)
	id_row.add_child(player_id)
	var copy := _option_button(LocaleService.t("settings.copy", "Copy"), false, _on_copy_pressed)
	copy.custom_minimum_size = Vector2(200, 88)
	id_row.add_child(copy)
	_account_rows.add_child(id_row)


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(str(GameState.player.get("id", "")))
	_show_toast(LocaleService.t("settings.copied", "Copied to clipboard"))


# --- legal / about -------------------------------------------------------------

func _build_legal() -> void:
	_add_legal_row("settings.privacy", "settings.privacy_body")
	_add_legal_row("settings.terms", "settings.terms_body")


func _add_legal_row(title_key: String, body_key: String) -> void:
	var row := _row()
	var button := _option_button(LocaleService.t(title_key, title_key), false,
		func() -> void: _open_legal(title_key, body_key))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	_legal_rows.add_child(row)


func _open_legal(title_key: String, body_key: String) -> void:
	_legal_modal.open(
		LocaleService.t(title_key, title_key),
		LocaleService.t(body_key, body_key),
		LocaleService.t("common.ok", "OK"),
		""
	)


func _build_about() -> void:
	var version_row := _row()
	version_row.add_child(_row_label(LocaleService.t("settings.version", "Version %s") % App.version_string()))
	_about_rows.add_child(version_row)
	if OS.is_debug_build():
		var reset := _option_button(LocaleService.t("settings.reset_profile", "Reset profile (debug)"), false,
			_open_reset)
		reset.theme_type_variation = &"SecondaryButton"
		reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_about_rows.add_child(reset)


func _open_reset() -> void:
	_reset_modal.open(
		LocaleService.t("settings.reset_title", "Reset profile?"),
		LocaleService.t("settings.reset_body", "All progress, cards and research will be deleted."),
		LocaleService.t("settings.reset_confirm", "Reset"),
		LocaleService.t("common.cancel", "Cancel")
	)


func _on_reset_confirmed() -> void:
	GameState.reset_profile()
	WalletService.reset()
	WorkshopService.reset()
	CardService.reset()
	MagicaService.reset()
	MissionService.reset()
	UnlockService.refresh()
	SaveService.flush()
	SceneRouter.goto(&"onboarding")


# --- FPS + toast ---------------------------------------------------------------

func _build_fps_label() -> void:
	if _fps_label != null and is_instance_valid(_fps_label):
		return
	_fps_label = Label.new()
	_fps_label.name = "FpsLabel"
	_fps_label.theme_type_variation = &"Caption"
	_fps_label.modulate = Color(0.7, 1.0, 0.7, 1.0)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.visible = OS.is_debug_build() and SettingsService.show_fps
	%Header.add_child(_fps_label)


func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.25)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)
