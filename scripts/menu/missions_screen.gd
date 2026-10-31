## MissionsScreen — daily/weekly missions with progress and claim state (spec 13.9).
##
## Presentation only: MissionService generates the cycle, tracks battle events,
## grants rewards through WalletService and rerolls at 04:00 / Monday 04:00.
## The screen ticks the reset countdowns once per second.
extends Control

const ROW_ICON := "res://assets/art/meta/missions/mission_icon.png"
const COIN_ICON := "res://assets/art/ui/icons/icon_coin.png"
const GEM_ICON := "res://assets/art/ui/icons/icon_gem.png"
const XP_ICON := "res://assets/art/ui/icons/icon_star.png"

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _claim_all_button: Button = %ClaimAllButton
@onready var _daily_countdown: Label = %DailyCountdown
@onready var _weekly_countdown: Label = %WeeklyCountdown
@onready var _daily_rows: VBoxContainer = %DailyRows
@onready var _weekly_rows: VBoxContainer = %WeeklyRows
@onready var _daily_bonus: Label = %DailyBonusLabel
@onready var _weekly_bonus: Label = %WeeklyBonusLabel
@onready var _reset_note: Label = %ResetNote
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _nav: MenuNav = %MenuNav

var _tick: float = 0.0
var _toast_tween: Tween
var _preview_model: MissionModel
var _preview_state: Dictionary = {}
var _templates_by_id: Dictionary = {}


func _ready() -> void:
	for template: MissionTemplate in MissionTemplateTable.load_table().templates:
		_templates_by_id[String(template.id)] = template
	_localize()
	_back_button.pressed.connect(_on_back_pressed)
	_claim_all_button.pressed.connect(_on_claim_all_pressed)
	MissionService.missions_changed.connect(_refresh)
	LocaleService.language_changed.connect(_on_language_changed)
	_toast.visible = false
	_refresh()
	set_process(true)


func _exit_tree() -> void:
	if MissionService.missions_changed.is_connected(_refresh):
		MissionService.missions_changed.disconnect(_refresh)
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_localize()
	_refresh()


## Mission rows persist the English title for save stability; render the key.
func _localized_mission_title(row: Dictionary) -> String:
	var template: MissionTemplate = _templates_by_id.get(str(row.get("template_id", row.get("id", ""))), null)
	if template == null:
		return str(row.get("title", ""))
	var target := maxi(int(row.get("target", 1)), 1)
	return LocaleService.t(template.title_key, template.title).replace("{n}", str(target))


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	if _preview_state.is_empty():
		MissionService.ensure_cycle()
	_refresh_countdowns()


func _localize() -> void:
	_title_label.text = LocaleService.t("missions.title", "Missions")
	_back_button.text = LocaleService.t("common.back", "Back")
	_claim_all_button.text = LocaleService.t("missions.claim_all", "Claim all")
	_reset_note.text = LocaleService.t(
		"missions.reset_note",
		"Daily missions reset at 04:00 local time; weekly missions reset Monday 04:00."
	)
	_nav.setup(&"missions")


func _model() -> MissionModel:
	if _preview_state.is_empty():
		return MissionService.get_model()
	if _preview_model == null:
		_preview_model = MissionModel.new()
		_preview_model.setup(
			MissionTemplateTable.load_table().templates,
			_preview_state,
			8,
			TimeService.now_unix(),
			MissionSchedule.system_offset_minutes()
		)
	return _preview_model


func _refresh() -> void:
	var model := _model()
	_rebuild_section(_daily_rows, model.get_daily())
	_rebuild_section(_weekly_rows, model.get_weekly())
	_refresh_bonus_labels(model)
	_refresh_countdowns()
	var claimable := model.claimable_count(&"daily") + model.claimable_count(&"weekly")
	_claim_all_button.visible = claimable >= 2
	_claim_all_button.disabled = claimable < 2
	AudioBus.bind_buttons(self)


func _refresh_countdowns() -> void:
	var model := _model()
	var offset := MissionSchedule.system_offset_minutes()
	var now := TimeService.now_unix()
	_daily_countdown.text = "%s %s" % [
		LocaleService.t("missions.resets_in", "Resets in"),
		_format_countdown(model.remaining_seconds(&"daily", now, offset)),
	]
	_weekly_countdown.text = "%s %s" % [
		LocaleService.t("missions.resets_in", "Resets in"),
		_format_countdown(model.remaining_seconds(&"weekly", now, offset)),
	]


func _format_countdown(seconds: int) -> String:
	var total := maxi(seconds, 0)
	var days := total / 86400
	var hours := (total % 86400) / 3600
	var minutes := (total % 3600) / 60
	if days > 0:
		return LocaleService.format_countdown(seconds)
	if hours > 0:
		return LocaleService.format_countdown(seconds)
	return LocaleService.format_countdown(seconds)


func _rebuild_section(container: VBoxContainer, rows: Array[Dictionary]) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	for row: Dictionary in rows:
		container.add_child(_mission_row(row))


func _mission_row(row: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 152)
	panel.theme_type_variation = &"ListRow"
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.texture = load(ROW_ICON) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	box.add_child(info)

	var title := Label.new()
	title.text = _localized_mission_title(row)
	title.theme_type_variation = &"Body"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 10)
	info.add_child(progress_row)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 24)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = maxf(float(row.get("target", 1)), 1.0)
	bar.value = float(row.get("progress", 0))
	bar.show_percentage = false
	progress_row.add_child(bar)
	var progress_label := Label.new()
	progress_label.theme_type_variation = &"Caption"
	progress_label.text = "%d / %d" % [int(row.get("progress", 0)), int(row.get("target", 0))]
	progress_row.add_child(progress_label)

	box.add_child(_rewards_box(row))

	var claim := Button.new()
	claim.custom_minimum_size = Vector2(200, 92)
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claim.focus_mode = Control.FOCUS_NONE
	var claimed := bool(row.get("claimed", false))
	var complete := int(row.get("progress", 0)) >= int(row.get("target", 1))
	if claimed:
		claim.text = LocaleService.t("missions.claimed", "Claimed")
		claim.theme_type_variation = &"SecondaryButton"
		claim.disabled = true
	elif complete:
		claim.text = LocaleService.t("missions.claim", "Claim")
		claim.theme_type_variation = &"GoldButton"
		claim.pressed.connect(_on_claim_pressed.bind(str(row.get("id", ""))))
	else:
		claim.text = LocaleService.t("missions.in_progress", "In progress")
		claim.theme_type_variation = &"SecondaryButton"
		claim.disabled = true
	box.add_child(claim)
	return panel


func _rewards_box(row: Dictionary) -> HBoxContainer:
	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 8)
	rewards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_add_reward(rewards, COIN_ICON, int(row.get("reward_coins", 0)))
	_add_reward(rewards, GEM_ICON, int(row.get("reward_gems", 0)))
	_add_reward(rewards, XP_ICON, int(row.get("reward_xp", 0)))
	return rewards


func _add_reward(parent: HBoxContainer, icon_path: String, amount: int) -> void:
	if amount <= 0:
		return
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 2)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.texture = load(icon_path) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.add_child(icon)
	var label := Label.new()
	label.text = str(amount)
	label.theme_type_variation = &"Caption"
	chip.add_child(label)
	parent.add_child(chip)


func _refresh_bonus_labels(model: MissionModel) -> void:
	_daily_bonus.text = _bonus_text(model, &"daily")
	_weekly_bonus.text = _bonus_text(model, &"weekly")


func _bonus_text(model: MissionModel, period: StringName) -> String:
	if model.is_bonus_claimed(period):
		return LocaleService.t("missions.bonus_claimed", "Completion bonus claimed")
	var reward := model.bonus_reward(period)
	var text := LocaleService.t("missions.bonus", "All complete: %s, %s") % [
		LocaleService.plural_count(int(reward.get("coins", 0)), "plural.coins"),
		LocaleService.plural_count(int(reward.get("gems", 0)), "plural.gems"),
	]
	if bool(reward.get("card_pack", false)):
		text += LocaleService.t("missions.bonus_card_pack", ", +1 card pack")
	return text


func _on_claim_pressed(mission_id: String) -> void:
	if _preview_state.is_empty():
		var result := MissionService.claim(mission_id)
		if bool(result.get("ok", false)):
			AudioBus.play_ui(&"ui_claim")
			_fly_coins(int(result.get("coins", 0)))
			_show_toast(LocaleService.t("missions.claimed_toast", "Mission claimed"))
		else:
			AudioBus.play_ui(&"ui_error")
			_show_toast(LocaleService.t("missions.not_complete", "Mission is not complete"))
	else:
		AudioBus.play_ui(&"ui_claim")
		_show_toast(LocaleService.t("missions.claimed_toast", "Mission claimed"))
	_refresh()


func _on_claim_all_pressed() -> void:
	if _preview_state.is_empty():
		var claimed := MissionService.claim_all()
		if claimed > 0:
			AudioBus.play_ui(&"ui_claim")
			_fly_coins(claimed * 40)
		_show_toast(LocaleService.t("missions.claim_all_toast", "Claimed %d missions") % claimed)
	else:
		_show_toast(LocaleService.t("missions.claim_all_toast", "Claimed %d missions") % 0)
	_refresh()


## Coin fly: pooled-looking tweened coin icons travel from the row area to the
## top-right currency corner. Purely cosmetic; grants already happened above.
func _fly_coins(amount: int) -> void:
	var viewport := get_viewport_rect().size
	var destination := Vector2(viewport.x - 150.0, 120.0)
	var origin := Vector2(viewport.x * 0.72, viewport.y * 0.58)
	var count := clampi(3 + amount / 80, 3, 9)
	for index in count:
		var coin := TextureRect.new()
		coin.texture = load(COIN_ICON) as Texture2D
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2(46, 46)
		coin.size = Vector2(46, 46)
		coin.position = origin + Vector2(float(index % 3) * 26.0 - 26.0, float(index / 3) * 22.0)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.z_index = 40
		add_child(coin)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(coin, "position", destination, 0.65).set_delay(index * 0.055).set_ease(
			Tween.EASE_IN
		).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(coin, "modulate:a", 0.0, 0.2).set_delay(0.5 + index * 0.055)
		tween.chain().tween_callback(coin.queue_free)


func _on_back_pressed() -> void:
	SaveService.request_save()
	SceneRouter.back()


func _on_shop_pressed() -> void:
	SceneRouter.goto(&"shop")


func _show_toast(message: String) -> void:
	ToastService.show_toast(message)


## Tooling-only populated state for docs/preview captures.
func stage_preview() -> void:
	_preview_state = {"day_id": "", "daily": [], "week_id": "", "weekly": []}
	_preview_model = MissionModel.new()
	_preview_model.setup(
		MissionTemplateTable.load_table().templates,
		_preview_state,
		8,
		TimeService.now_unix(),
		MissionSchedule.system_offset_minutes()
	)
	var daily := _preview_model.get_daily()
	if daily.size() >= 2:
		_preview_model.set_progress(str(daily[0]["id"]), int(daily[0]["target"]))
		_preview_model.set_progress(str(daily[1]["id"]), int(daily[1]["target"]) * 2 / 3)
		_preview_model.claim(str(daily[0]["id"]))
	var weekly := _preview_model.get_weekly()
	if weekly.size() >= 3:
		_preview_model.set_progress(str(weekly[0]["id"]), int(weekly[0]["target"]) * 3 / 4)
		_preview_model.set_progress(str(weekly[1]["id"]), int(weekly[1]["target"]) / 2)
	_preview_state = _preview_model.to_state()
	_refresh()
