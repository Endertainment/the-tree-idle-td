## ProfileScreen — avatar, identity, level/XP and lifetime stats (spec 13.12 link).
##
## Read-only view over GameState; nickname editing stays in Settings. Numbers come
## from the pure ProfileStats aggregation, so the screen has no save logic.
extends Control

const AVATAR_DIR := "res://assets/art/ui/menu/"
const AVATAR_FALLBACK := "avatar_01"

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _avatar: TextureRect = %Avatar
@onready var _nickname: Label = %Nickname
@onready var _change_hint: Label = %ChangeHint
@onready var _player_id: Label = %PlayerId
@onready var _copy_button: Button = %CopyButton
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_label: Label = %XpLabel
@onready var _stats_title: Label = %StatsTitle
@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _leaderboard_button: Button = %LeaderboardButton
@onready var _settings_link: Button = %SettingsLinkButton
@onready var _nav: MenuNav = %NavBar


func _ready() -> void:
	_localize()
	_back_button.pressed.connect(_on_back_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_link.pressed.connect(_on_settings_pressed)
	_copy_button.pressed.connect(_on_copy_pressed)
	_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	LocaleService.language_changed.connect(_on_language_changed)
	_refresh()
	AudioBus.bind_buttons(self)


func _exit_tree() -> void:
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_localize()
	_refresh()


func _localize() -> void:
	_title_label.text = LocaleService.t("profile.title", "Profile")
	_back_button.text = LocaleService.t("common.back", "Back")
	_change_hint.text = LocaleService.t("profile.nickname_hint", "Change your nickname in Settings.")
	_copy_button.text = LocaleService.t("settings.copy", "Copy")
	_stats_title.text = LocaleService.t("profile.stats", "Lifetime stats")
	_leaderboard_button.text = LocaleService.t("profile.leaderboard", "Leaderboard")
	_settings_link.text = LocaleService.t("profile.open_settings", "Open settings")
	_settings_button.tooltip_text = LocaleService.t("menu.settings", "Settings")
	_nav.setup(&"")


func _refresh() -> void:
	var summary := ProfileStats.build(GameState.player, GameState.stats, GameState.wallet)
	var nickname := str(GameState.player.get("nickname", "")).strip_edges()
	_nickname.text = nickname if not nickname.is_empty() else LocaleService.t(
		"menu.nickname_fallback", "Tree Warden"
	)
	_avatar.texture = _avatar_texture(str(GameState.player.get("avatar_id", AVATAR_FALLBACK)))
	_player_id.text = str(GameState.player.get("id", ""))
	var level := int(summary["level"])
	_level_label.text = LocaleService.t("profile.level", "Player level %d") % level
	if level >= LevelService.MAX_LEVEL:
		_level_label.text = LocaleService.t("profile.max_level", "Max level")
		_xp_bar.max_value = 1.0
		_xp_bar.value = 1.0
		_xp_label.text = ""
	else:
		var required := int(summary["xp_required"])
		_xp_bar.max_value = float(maxi(required, 1))
		_xp_bar.value = float(int(summary["xp"]))
		_xp_label.text = LocaleService.t("profile.xp", "%d / %d XP") % [int(summary["xp"]), required]
	_rebuild_stats(summary)


func _rebuild_stats(summary: Dictionary) -> void:
	for child: Node in _stats_grid.get_children():
		_stats_grid.remove_child(child)
		child.queue_free()
	_add_stat(
		"res://assets/art/ui/icons/icon_trophy.png",
		LocaleService.t("leaderboard.wave", "Best wave"),
		LocaleService.format_number(int(summary["best_wave"]))
	)
	_add_stat(
		"res://assets/art/ui/icons/icon_play.png",
		LocaleService.t("profile.runs", "Runs"),
		LocaleService.format_number(int(summary["runs_played"]))
	)
	_add_stat(
		"res://assets/art/ui/icons/icon_sword.png",
		LocaleService.t("profile.kills", "Kills"),
		LocaleService.format_number(int(summary["total_kills"]))
	)
	_add_stat(
		"res://assets/art/ui/icons/icon_clock.png",
		LocaleService.t("profile.playtime", "Playtime"),
		LocaleService.format_duration(int(summary["total_playtime"]))
	)
	_add_stat(
		"res://assets/art/ui/icons/icon_coin.png",
		LocaleService.t("profile.coins_earned", "Coins earned"),
		LocaleService.format_number(int(summary["coins_earned"]))
	)


func _add_stat(icon_path: String, label_text: String, value: String) -> void:
	var cell := PanelContainer.new()
	cell.theme_type_variation = &"ListRow"
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	cell.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = &"Caption"
	box.add_child(label)
	var amount := Label.new()
	amount.text = value
	amount.theme_type_variation = &"Body"
	amount.add_theme_color_override("font_color", Color(1.0, 0.78, 0.24, 1.0))
	box.add_child(amount)
	_stats_grid.add_child(cell)


func _avatar_texture(avatar_id: String) -> Texture2D:
	var safe_id := avatar_id if not avatar_id.is_empty() else AVATAR_FALLBACK
	var path := AVATAR_DIR + safe_id + ".png"
	if not ResourceLoader.exists(path):
		path = AVATAR_DIR + AVATAR_FALLBACK + ".png"
	return load(path) as Texture2D


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(str(GameState.player.get("id", "")))
	AudioBus.play_ui(&"ui_toggle")
	ToastService.show_toast(LocaleService.t("settings.copied", "Copied to clipboard"))


func _on_leaderboard_pressed() -> void:
	SceneRouter.goto(&"leaderboard")


func _on_settings_pressed() -> void:
	SceneRouter.goto(&"settings")


func _on_back_pressed() -> void:
	SaveService.request_save()
	SceneRouter.back()


## Tooling-only populated state for docs/preview captures (never saved).
func stage_preview() -> void:
	GameState.player["nickname"] = "Elderwood"
	GameState.player["avatar_id"] = "avatar_04"
	GameState.player["id"] = "7a5c1e0b-2f4d-4c89-9a6e-1d3b5f7a9c20"
	GameState.player["level"] = 7
	GameState.player["xp"] = 50
	GameState.stats["best_wave"] = 18
	GameState.stats["runs_played"] = 12
	GameState.stats["total_kills"] = 340
	GameState.stats["total_playtime"] = 7200
	GameState.stats["coins_earned"] = 950
	GameState.wallet["coins"] = 12480
	GameState.wallet["gems"] = 350
	_refresh()
