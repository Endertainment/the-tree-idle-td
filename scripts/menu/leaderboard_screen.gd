## LeaderboardScreen — weekly / all-time / tournament cohort table (spec 13.11).
##
## All data comes through LeaderboardService (LocalBackendStub in M5b). The screen
## only renders, keeps the selected tab, shows the offline banner with the cached
## timestamp, pins the player's row at the bottom and explains the empty state.
extends Control

const TABS: Array[StringName] = [&"weekly", &"all_time", &"tournament"]
const TAB_LABELS: Dictionary = {
	&"weekly": ["leaderboard.tab.weekly", "Weekly"],
	&"all_time": ["leaderboard.tab.all_time", "All-time"],
	&"tournament": ["leaderboard.tab.tournament", "Tournament"],
}
const MEDALS: Dictionary = {
	1: "res://assets/art/meta/leaderboard/medal_1.png",
	2: "res://assets/art/meta/leaderboard/medal_2.png",
	3: "res://assets/art/meta/leaderboard/medal_3.png",
}
const AVATAR_DIR := "res://assets/art/ui/menu/"
const STONE_ICON := "res://assets/art/ui/icons/icon_stone.png"

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _refresh_button: Button = %RefreshButton
@onready var _tabs: HBoxContainer = %Tabs
@onready var _offline_label: Label = %OfflineLabel
@onready var _tournament_panel: PanelContainer = %TournamentPanel
@onready var _cohort_label: Label = %CohortLabel
@onready var _tournament_detail: Label = %TournamentDetail
@onready var _eligibility_label: Label = %EligibilityLabel
@onready var _loading_label: Label = %LoadingLabel
@onready var _reward_panel: PanelContainer = %RewardPanel
@onready var _reward_title: Label = %RewardTitle
@onready var _tier_rows: VBoxContainer = %TierRows
@onready var _rows: VBoxContainer = %Rows
@onready var _empty_label: Label = %EmptyLabel
@onready var _own_rank: Label = %OwnRank
@onready var _own_avatar: TextureRect = %OwnAvatar
@onready var _own_caption: Label = %OwnCaption
@onready var _own_nickname: Label = %OwnNickname
@onready var _own_wave: Label = %OwnWave
@onready var _own_panel: PanelContainer = %OwnPanel
@onready var _nav: MenuNav = %NavBar

var _active_tab: StringName = &"weekly"
var _tab_buttons: Dictionary = {}
var _preview: bool = false
var _loading: bool = false


func _ready() -> void:
	_localize()
	_build_tabs()
	_back_button.pressed.connect(_on_back_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	LeaderboardService.refresh_failed.connect(_on_refresh_failed)
	_refresh_content()
	AudioBus.bind_buttons(self)


func _exit_tree() -> void:
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)
	if LeaderboardService.refresh_failed.is_connected(_on_refresh_failed):
		LeaderboardService.refresh_failed.disconnect(_on_refresh_failed)


func _on_refresh_failed(_board: StringName, _reason: StringName) -> void:
	ToastService.show_toast(
		LocaleService.t("leaderboard.refresh_failed", "Could not refresh. Showing cached results.")
	)


func _on_language_changed(_code: String) -> void:
	_localize()
	_refresh_tabs()
	_refresh_reward_tiers()
	_refresh_content()


func _localize() -> void:
	_title_label.text = LocaleService.t("leaderboard.title", "Leaderboard")
	_back_button.text = LocaleService.t("common.back", "Back")
	_refresh_button.text = LocaleService.t("leaderboard.refresh", "Refresh")
	_loading_label.text = LocaleService.t("leaderboard.loading", "Loading…")
	_empty_label.text = LocaleService.t(
		"leaderboard.empty",
		"No runs yet. Play your first battle to enter the leaderboard."
	)
	_own_caption.text = LocaleService.t("leaderboard.own_rank", "Your rank")
	_reward_title.text = LocaleService.t("leaderboard.reward_tiers", "Reward tiers")
	_nav.setup(&"")
	if not LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.connect(_on_language_changed)


func _build_tabs() -> void:
	for tab: StringName in TABS:
		var button := Button.new()
		button.name = "Tab%s" % String(tab).capitalize()
		button.custom_minimum_size = Vector2(0, 86)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"SecondaryButton"
		button.pressed.connect(_on_tab_pressed.bind(tab))
		_tabs.add_child(button)
		_tab_buttons[tab] = button
	_refresh_tabs()


func _refresh_tabs() -> void:
	for tab: StringName in _tab_buttons.keys():
		var button: Button = _tab_buttons[tab]
		var active := tab == _active_tab
		button.theme_type_variation = &"GoldButton" if active else &"SecondaryButton"
		button.modulate = Color.WHITE if active else Color(0.8, 0.84, 0.78, 1.0)
		var entry: Array = TAB_LABELS[tab]
		button.text = LocaleService.t(str(entry[0]), str(entry[1]))


func _on_tab_pressed(tab: StringName) -> void:
	if tab == _active_tab or _loading:
		return
	_active_tab = tab
	AudioBus.play_ui(&"ui_toggle")
	_refresh_tabs()
	_refresh_content()


func _refresh_content() -> void:
	var tournament := _active_tab == &"tournament"
	_tournament_panel.visible = tournament
	_reward_panel.visible = tournament
	if tournament:
		_refresh_tournament()
		_refresh_reward_tiers()
	var has_runs := _preview or LeaderboardService.has_player_runs()
	var show_empty := not has_runs and not tournament
	_empty_label.visible = show_empty
	_rows.visible = not show_empty
	_own_panel.visible = has_runs or tournament
	if not show_empty:
		_rebuild_rows(LeaderboardService.get_entries(_active_tab))
	_refresh_offline_banner()
	_refresh_own()
	AudioBus.bind_buttons(self)


func _refresh_offline_banner() -> void:
	if not LeaderboardService.is_offline():
		_offline_label.visible = false
		return
	_offline_label.visible = true
	var updated := LeaderboardService.get_last_updated(_active_tab)
	var stamp := LocaleService.t("leaderboard.never", "Never")
	if updated > 0:
		stamp = Time.get_time_string_from_unix_time(updated)
	_offline_label.text = "%s · %s" % [
		LocaleService.t("leaderboard.offline", "Offline · showing cached results"),
		LocaleService.t("leaderboard.updated", "Updated %s") % stamp,
	]


func _refresh_tournament() -> void:
	var info := LeaderboardService.get_tournament_info()
	_cohort_label.text = LocaleService.t("leaderboard.cohort", "Cohort %s") % str(info.get("cohort_id", ""))
	var ends := LocaleService.format_duration(maxi(int(info.get("ends_at", 0)) - TimeService.now_unix(), 0))
	_tournament_detail.text = "%s · %s" % [
		LocaleService.t("leaderboard.ends", "Ends in %s") % ends,
		LocaleService.t("leaderboard.tournament_note", "The tournament groups 50 players."),
	]
	if bool(info.get("eligible", false)):
		_eligibility_label.text = LocaleService.t("leaderboard.eligible", "You are in this cohort")
		_eligibility_label.modulate = Color(0.55, 0.9, 0.4, 1.0)
	else:
		_eligibility_label.text = LocaleService.t(
			"leaderboard.not_eligible", "Reach player level %d to join"
		) % int(info.get("requirement_level", 12))
		_eligibility_label.modulate = Color(1.0, 0.78, 0.24, 1.0)


func _refresh_reward_tiers() -> void:
	for child: Node in _tier_rows.get_children():
		_tier_rows.remove_child(child)
		child.queue_free()
	for tier: Dictionary in LeaderboardService.get_reward_tiers():
		_tier_rows.add_child(_tier_row(tier))


func _tier_row(tier: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = _tier_label(int(tier.get("percentile", 100)))
	label.theme_type_variation = &"Caption"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.texture = load(STONE_ICON) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var amount := Label.new()
	amount.text = LocaleService.format_number(int(tier.get("stones", 0)))
	amount.theme_type_variation = &"Body"
	amount.add_theme_color_override("font_color", Color(1.0, 0.78, 0.24, 1.0))
	amount.custom_minimum_size = Vector2(70, 0)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)
	return row


## Explicit keys (rather than the stub's label_key) so the locale linter sees
## every reward tier string as used in code.
func _tier_label(percentile: int) -> String:
	match percentile:
		1:
			return LocaleService.t("leaderboard.reward.top1", "Top 1 %")
		10:
			return LocaleService.t("leaderboard.reward.top10", "Top 10 %")
		25:
			return LocaleService.t("leaderboard.reward.top25", "Top 25 %")
		50:
			return LocaleService.t("leaderboard.reward.top50", "Top 50 %")
		_:
			return LocaleService.t("leaderboard.reward.participation", "Participation")


func _rebuild_rows(entries: Array[Dictionary]) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for index in entries.size():
		_rows.add_child(_rank_row(index + 1, entries[index]))


func _rank_row(rank: int, entry: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 84)
	row.theme_type_variation = &"LeaderRow"
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	row.add_child(box)

	var rank_box := HBoxContainer.new()
	rank_box.custom_minimum_size = Vector2(70, 0)
	rank_box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(rank_box)
	if rank <= 3:
		var medal := TextureRect.new()
		medal.custom_minimum_size = Vector2(52, 52)
		medal.texture = load(str(MEDALS[rank])) as Texture2D
		medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rank_box.add_child(medal)
	else:
		var rank_label := Label.new()
		rank_label.text = str(rank)
		rank_label.theme_type_variation = &"Body"
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_box.add_child(rank_label)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(56, 56)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.texture = _avatar_texture(str(entry.get("avatar_id", "")))
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(avatar)

	var name_label := Label.new()
	name_label.text = str(entry.get("nickname", ""))
	name_label.theme_type_variation = &"Body"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)

	var wave := Label.new()
	wave.text = LocaleService.format_number(int(entry.get("best_wave", 0)))
	wave.theme_type_variation = &"Body"
	wave.add_theme_color_override("font_color", Color(1.0, 0.78, 0.24, 1.0))
	wave.custom_minimum_size = Vector2(110, 0)
	wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(wave)
	return row


func _refresh_own() -> void:
	var own := LeaderboardService.get_own_entry()
	var rank := LeaderboardService.get_own_rank(_active_tab)
	_own_rank.text = ("#%d" % rank) if rank > 0 else "#—"
	var nickname := str(own.get("nickname", "")).strip_edges()
	_own_nickname.text = nickname if not nickname.is_empty() else LocaleService.t("leaderboard.you", "You")
	_own_avatar.texture = _avatar_texture(str(own.get("avatar_id", "")))
	_own_wave.text = "%s %s" % [
		LocaleService.t("leaderboard.wave", "Best wave"),
		LocaleService.format_number(int(own.get("best_wave", 0))),
	]


func _avatar_texture(avatar_id: String) -> Texture2D:
	var safe_id := avatar_id if not avatar_id.is_empty() else "avatar_01"
	var path := "%s%s.png" % [AVATAR_DIR, safe_id]
	if not ResourceLoader.exists(path):
		path = AVATAR_DIR + "avatar_01.png"
	return load(path) as Texture2D


func _on_refresh_pressed() -> void:
	if _loading:
		return
	_loading = true
	_refresh_button.disabled = true
	_loading_label.visible = true
	AudioBus.play_ui(&"ui_toggle")
	await get_tree().create_timer(0.35).timeout
	LeaderboardService.refresh(_active_tab)
	_loading_label.visible = false
	_refresh_button.disabled = false
	_loading = false
	_refresh_content()
	ToastService.show_toast(
		LocaleService.t("leaderboard.updated_toast", "Leaderboard refreshed")
	)


func _on_back_pressed() -> void:
	SceneRouter.back()


## Tooling-only populated state for docs/preview captures (never saved).
func stage_preview() -> void:
	_preview = true
	GameState.stats["best_wave"] = 18
	GameState.stats["runs_played"] = 12
	_active_tab = &"weekly"
	LeaderboardService.refresh(_active_tab)
	_refresh_tabs()
	_refresh_content()
