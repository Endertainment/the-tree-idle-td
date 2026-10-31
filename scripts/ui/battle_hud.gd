## BattleHUD — the battle overlay (M3: upgrade panel, speed, pause, next wave).
##
## Presentation only: it renders data passed in and emits requests; the
## BattleHudController decides. M2 added the boss bar, tower/unit sheets; M3 adds
## the generated UpgradePanel host, the 1x/1.5x/2x segmented speed control with
## lock popup, the pause overlay and the next-wave hold guard. The upgrade rows
## themselves live in UpgradePanel/UpgradeRow.
class_name BattleHUD
extends CanvasLayer

signal build_requested(tower_id: StringName)
signal next_wave_requested
signal dismiss_requested
signal tower_upgrade_requested
signal tower_sell_requested
signal unit_place_requested(unit_id: StringName)
signal unit_upgrade_requested
signal speed_requested(speed: float)
signal debug_unlock_requested(unlock_id: StringName)
signal pause_requested
signal resume_requested
signal restart_requested
signal abandon_requested
signal upgrade_open_requested
signal upgrade_closed

const LOW_HP_RATIO := 0.3
const HP_FILL_NORMAL := preload("res://assets/art/battle/hud/tree_hp_fill.png")
const HP_FILL_LOW := preload("res://assets/art/battle/hud/tree_hp_fill_low.png")
const LOCK_ICON := preload("res://assets/art/ui/icons/icon_lock.png")
const DELTA_COLOR := Color(0.55, 0.95, 0.45, 1.0)
const WARN_COLOR := Color(1.0, 0.58, 0.45, 1.0)
const STAT_LABEL_WIDTH := 250.0

@onready var _wave_label: Label = %WaveLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _cash_pill: CurrencyPill = %CashPill
@onready var _gems_pill: CurrencyPill = %GemsPill
@onready var _speed_1x: Button = %Speed1x
@onready var _speed_15x: Button = %Speed15x
@onready var _speed_2x: Button = %Speed2x
@onready var _pause_button: Button = %PauseButton
@onready var _boss_bar: PanelContainer = %BossBar
@onready var _boss_name: Label = %BossName
@onready var _boss_hp_label: Label = %BossHpLabel
@onready var _boss_armor: Label = %BossArmor
@onready var _boss_hp_bar: TextureProgressBar = %BossHpBar
@onready var _countdown_box: VBoxContainer = %CountdownBox
@onready var _countdown_label: Label = %CountdownLabel
@onready var _next_wave_button: Button = %NextWaveButton
@onready var _banner: PanelContainer = %Banner
@onready var _banner_label: Label = %BannerLabel
@onready var _hp_bar: TextureProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _build_sheet: Control = %BuildSheet
@onready var _build_scrim: ColorRect = %BuildScrim
@onready var _build_rows: VBoxContainer = %BuildRows
@onready var _build_close: Button = %BuildClose
@onready var _build_title: Label = %BuildTitle
@onready var _tower_sheet: Control = %TowerSheet
@onready var _tower_scrim: ColorRect = %TowerScrim
@onready var _tower_title: Label = %TowerTitle
@onready var _tower_stats: VBoxContainer = %TowerStats
@onready var _tower_reason: Label = %TowerReason
@onready var _tower_upgrade: Button = %TowerUpgradeButton
@onready var _tower_sell: Button = %TowerSellButton
@onready var _tower_close: Button = %TowerClose
@onready var _unit_sheet: Control = %UnitSheet
@onready var _unit_scrim: ColorRect = %UnitScrim
@onready var _unit_title: Label = %UnitTitle
@onready var _unit_rows: VBoxContainer = %UnitRows
@onready var _unit_reason: Label = %UnitReason
@onready var _unit_upgrade: Button = %UnitUpgradeButton
@onready var _unit_close: Button = %UnitClose
@onready var _upgrade_panel: UpgradePanel = %UpgradePanel
@onready var _pause_menu: PauseMenu = %PauseOverlay
@onready var _lock_modal: Modal = %LockModal

var _banner_tween: Tween
var _pulse_tween: Tween
var _next_wave_press_msec: int = 0
var _next_wave_uses: int = 0
var _pending_unlock_id: StringName = &""
var _upgrade_dot: TextureRect
var _unlocked_speeds: Dictionary = {}


func _ready() -> void:
	_countdown_box.visible = false
	_banner.visible = false
	_build_sheet.visible = false
	_tower_sheet.visible = false
	_unit_sheet.visible = false
	_boss_bar.visible = false
	_wave_label.visible = true
	_upgrade_dot = get_node_or_null("%UpgradeDot") as TextureRect

	_upgrade_button.text = _t("battle.upgrade", "Upgrade")
	_build_title.text = _t("battle.build_title", "Build tower")
	_build_close.text = _t("battle.close", "Close")
	_tower_close.text = _t("battle.close", "Close")
	_unit_close.text = _t("battle.close", "Close")
	_next_wave_button.text = _t("battle.next_wave", "Next wave")
	_speed_1x.text = "1x"
	_speed_15x.text = "1.5x"
	_speed_2x.text = "2x"
	_tooltip_speed(_speed_1x, _t("battle.speed_1x", "Normal speed"))
	_tooltip_speed(_speed_15x, _t("battle.speed_15x", "1.5x speed"))
	_tooltip_speed(_speed_2x, _t("battle.speed_2x", "2x speed"))
	_pause_button.tooltip_text = _t("battle.pause", "Pause")

	_next_wave_button.button_down.connect(_on_next_wave_down)
	_next_wave_button.button_up.connect(_on_next_wave_up)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_build_close.pressed.connect(_on_dismiss_pressed)
	_tower_close.pressed.connect(_on_dismiss_pressed)
	_unit_close.pressed.connect(_on_dismiss_pressed)
	_build_scrim.gui_input.connect(_on_scrim_gui_input)
	_tower_scrim.gui_input.connect(_on_scrim_gui_input)
	_unit_scrim.gui_input.connect(_on_scrim_gui_input)
	_tower_upgrade.pressed.connect(_on_tower_upgrade_pressed)
	_tower_sell.pressed.connect(_on_tower_sell_pressed)
	_unit_upgrade.pressed.connect(_on_unit_upgrade_pressed)

	_speed_1x.pressed.connect(_on_speed_pressed.bind(1.0))
	_speed_15x.pressed.connect(_on_speed_pressed.bind(1.5))
	_speed_2x.pressed.connect(_on_speed_pressed.bind(2.0))
	_pause_button.pressed.connect(_on_pause_pressed)
	_upgrade_button.resized.connect(_on_upgrade_button_resized)
	_upgrade_panel.closed.connect(_on_upgrade_panel_closed)
	_pause_menu.resume_requested.connect(_on_resume_pressed)
	_pause_menu.restart_requested.connect(_on_restart_pressed)
	_pause_menu.abandon_requested.connect(_on_abandon_pressed)
	_lock_modal.confirmed.connect(_on_lock_confirmed)
	set_speed_state(1.0, {1.5: false, 2.0: false})
	set_upgrade_available(false)


# --- top bar / tree ---------------------------------------------------------------


func set_wave(wave: int, total: int) -> void:
	var caption := _t("battle.wave", "Wave")
	if total > 0:
		_wave_label.text = "%s %d / %d" % [caption, wave, total]
	else:
		_wave_label.text = "%s %d" % [caption, wave]


func set_elapsed(seconds: float) -> void:
	_timer_label.text = TimeService.format_clock(int(seconds))


func set_cash(amount: int) -> void:
	_cash_pill.set_amount(amount)


## Gems are meta currency: shown for context, never spendable in battle.
func set_gems(amount: int) -> void:
	_gems_pill.set_amount(amount)


func set_tree_hp(current_hp: float, maximum: float) -> void:
	var ratio := 0.0 if maximum <= 0.0 else clampf(current_hp / maximum, 0.0, 1.0)
	_hp_bar.value = ratio * 100.0
	_hp_label.text = "%s: %d%%" % [_t("battle.hp", "HP"), int(round(ratio * 100.0))]
	if ratio < LOW_HP_RATIO:
		_hp_bar.texture_progress = HP_FILL_LOW
		_hp_label.modulate = Color(1.0, 0.42, 0.38, 1.0)
	else:
		_hp_bar.texture_progress = HP_FILL_NORMAL
		_hp_label.modulate = Color.WHITE


# --- boss bar ---------------------------------------------------------------------


## Shows the boss bar and hides the wave label (boss bar replaces it).
func show_boss(boss_name: String, current_hp: float, max_hp: float, armor: float) -> void:
	_boss_name.text = boss_name
	_boss_armor.text = "%s %d" % [_t("battle.armor", "Armor"), int(round(armor))]
	_boss_hp_bar.max_value = maxf(max_hp, 1.0)
	_boss_hp_bar.value = current_hp
	update_boss(current_hp, max_hp)
	_wave_label.visible = false
	_boss_bar.visible = true


func update_boss(current_hp: float, max_hp: float) -> void:
	var ratio := 0.0 if max_hp <= 0.0 else clampf(current_hp / max_hp, 0.0, 1.0)
	_boss_hp_bar.max_value = maxf(max_hp, 1.0)
	_boss_hp_bar.value = current_hp
	_boss_hp_label.text = "%d%%" % int(round(ratio * 100.0))


func hide_boss() -> void:
	_boss_bar.visible = false
	_wave_label.visible = true


func is_boss_bar_visible() -> bool:
	return _boss_bar.visible


# --- countdown / banner -----------------------------------------------------------


func show_countdown(duration: float, skip_bonus: int) -> void:
	_countdown_box.visible = true
	_next_wave_button.text = "%s  +%d" % [_t("battle.next_wave", "Next wave"), skip_bonus]
	set_countdown(int(ceil(duration)))


func set_countdown(seconds_left: int) -> void:
	if not _countdown_box.visible:
		return
	_countdown_label.text = "%s %d" % [_t("battle.next_wave_in", "Next wave in"), maxi(seconds_left, 0)]


func hide_countdown() -> void:
	_countdown_box.visible = false


func show_banner(text: String) -> void:
	_banner_label.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.4)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)


# --- build sheet ------------------------------------------------------------------


func show_build_sheet(options: Array[Dictionary]) -> void:
	_rebuild_build_rows(options)
	_build_sheet.visible = true


func hide_build_sheet() -> void:
	_build_sheet.visible = false


func is_build_sheet_open() -> bool:
	return _build_sheet.visible


func _rebuild_build_rows(options: Array[Dictionary]) -> void:
	_clear(_build_rows)
	for option in options:
		var data := option.get("data") as TowerData
		if data == null:
			continue
		_build_rows.add_child(_create_build_row(data, bool(option.get("affordable", false))))


func _create_build_row(data: TowerData, affordable: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = &"ListRow"
	row.custom_minimum_size = Vector2(0, 160)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	row.add_child(layout)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.texture = data.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	layout.add_child(info)

	var name_label := Label.new()
	name_label.text = _t(data.display_name_key, data.display_name)
	info.add_child(name_label)

	var role := Label.new()
	role.theme_type_variation = &"Caption"
	role.text = _t(data.description_key, data.description)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(role)

	var stats := Label.new()
	stats.theme_type_variation = &"Caption"
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if data.is_aura_only():
		var aura_damage := 0
		var aura_speed := 0
		for modifier in data.aura_modifiers:
			if modifier == null:
				continue
			if modifier.stat == &"damage":
				aura_damage = int(round(modifier.multiplier * 100.0))
			elif modifier.stat == &"attack_speed":
				aura_speed = int(round(modifier.multiplier * 100.0))
		stats.text = "%s %d  ·  +%d%% %s / +%d%% %s" % [
			_t("battle.radius", "Radius"), int(round(data.aura_radius)),
			aura_damage, _t("battle.damage", "damage"),
			aura_speed, _t("battle.attack_speed", "attack speed"),
		]
	else:
		stats.text = "%d %s  ·  %.2f s  ·  %d %s" % [
			int(round(data.damage)), _t("battle.damage", "damage"),
			data.attack_interval, int(round(data.range)), _t("battle.range", "range"),
		]
	info.add_child(stats)

	if not affordable:
		var reason := Label.new()
		reason.theme_type_variation = &"Caption"
		reason.text = _t("battle.not_enough_cash", "Not enough cash")
		reason.modulate = WARN_COLOR
		info.add_child(reason)

	var build_button := Button.new()
	build_button.theme_type_variation = &"PrimaryButton"
	build_button.custom_minimum_size = Vector2(240, 104)
	build_button.text = "%s %d" % [_t("battle.build", "Build"), data.build_cost]
	build_button.disabled = not affordable
	build_button.pressed.connect(_on_build_row_pressed.bind(data.id))
	layout.add_child(build_button)
	return row


# --- tower sheet ------------------------------------------------------------------


func show_tower_sheet(info: Dictionary) -> void:
	_tower_title.text = "%s  Lv %d / %d" % [
		_t(str(info.get("name_key", "")), str(info.get("name", ""))),
		int(info.get("level", 1)),
		int(info.get("max_level", 10)),
	]
	_clear(_tower_stats)
	if bool(info.get("is_aura", false)):
		_add_stat_row(
			_tower_stats,
			_t("battle.aura", "Aura"),
			"+%d%% %s / +%d%% %s" % [
				int(round(float(info.get("aura_damage", 0.0)) * 100.0)),
				_t("battle.damage", "damage"),
				int(round(float(info.get("aura_speed", 0.0)) * 100.0)),
				_t("battle.attack_speed", "attack speed"),
			],
			"%d px" % int(round(float(info.get("aura_radius", 0.0))))
		)
	else:
		_add_stat_row(
			_tower_stats,
			_t("battle.damage", "Damage"),
			_format_int(info.get("damage", 0.0)),
			_format_int(info.get("next_damage", 0.0))
		)
		_add_stat_row(
			_tower_stats,
			_t("battle.interval", "Interval"),
			"%.2f s" % float(info.get("interval", 0.0)),
			"%.2f s" % float(info.get("next_interval", 0.0)),
			bool(info.get("maxed", false))
		)
		_add_stat_row(
			_tower_stats,
			_t("battle.range", "Range"),
			"%d px" % int(round(float(info.get("range", 0.0)))),
			"%d px" % int(round(float(info.get("next_range", 0.0)))),
			bool(info.get("maxed", false))
		)
		if float(info.get("splash_radius", 0.0)) > 0.0:
			_add_stat_row(
				_tower_stats,
				_t("battle.splash", "Splash"),
				"%d px" % int(round(float(info.get("splash_radius", 0.0)))),
				""
			)
		if float(info.get("slow_pct", 0.0)) > 0.0:
			_add_stat_row(
				_tower_stats,
				_t("battle.slow", "Slow"),
				"%d%% / 1.5 s" % int(round(float(info.get("slow_pct", 0.0)) * 100.0)),
				""
			)

	var maxed := bool(info.get("maxed", false))
	var affordable := bool(info.get("affordable", false))
	var cost := int(info.get("upgrade_cost", 0))
	_tower_upgrade.text = "%s  %d" % [_t("battle.upgrade", "Upgrade"), cost]
	_tower_upgrade.disabled = maxed or not affordable
	_tower_sell.text = "%s  +%d" % [_t("battle.sell", "Sell"), int(info.get("sell_value", 0))]
	_tower_reason.text = ""
	_tower_reason.modulate = WARN_COLOR
	if maxed:
		_tower_reason.text = _t("battle.max_level", "Max level")
	elif not affordable:
		_tower_reason.text = _t("battle.not_enough_cash", "Not enough cash")
	_tower_sheet.visible = true


func hide_tower_sheet() -> void:
	_tower_sheet.visible = false


func is_tower_sheet_open() -> bool:
	return _tower_sheet.visible


# --- unit sheet -------------------------------------------------------------------


func show_unit_sheet(info: Dictionary) -> void:
	_clear(_unit_rows)
	_unit_reason.text = ""
	if str(info.get("mode", "place")) == "place":
		_unit_title.text = _t("battle.place_unit", "Place unit")
		_unit_upgrade.visible = false
		var options: Array = info.get("options", [])
		for option in options:
			var option_data := option as Dictionary
			var data := option_data.get("data") as UnitData
			if data == null:
				continue
			_unit_rows.add_child(_create_unit_row(data, bool(option_data.get("affordable", false))))
	else:
		_unit_title.text = "%s  Lv %d / %d" % [
			_t(str(info.get("name_key", "")), str(info.get("name", ""))),
			int(info.get("level", 1)),
			int(info.get("max_level", 10)),
		]
		_add_stat_row(
			_unit_rows,
			_t("battle.damage", "Damage"),
			_format_int(info.get("damage", 0.0)),
			_format_int(info.get("next_damage", 0.0))
		)
		_add_stat_row(
			_unit_rows,
			_t("battle.interval", "Interval"),
			"%.2f s" % float(info.get("interval", 0.0)),
			"%.2f s" % float(info.get("next_interval", 0.0)),
			bool(info.get("maxed", false))
		)
		_add_stat_row(
			_unit_rows,
			_t("battle.range", "Range"),
			"%d px" % int(round(float(info.get("range", 0.0)))),
			"%d px" % int(round(float(info.get("next_range", 0.0)))),
			bool(info.get("maxed", false))
		)
		if float(info.get("splash_radius", 0.0)) > 0.0:
			_add_stat_row(
				_unit_rows,
				_t("battle.splash", "Splash"),
				"%d px" % int(round(float(info.get("splash_radius", 0.0)))),
				""
			)
		if float(info.get("slow_pct", 0.0)) > 0.0:
			_add_stat_row(
				_unit_rows,
				_t("battle.slow", "Slow"),
				"%d%% / 1.5 s" % int(round(float(info.get("slow_pct", 0.0)) * 100.0)),
				""
			)
		var maxed := bool(info.get("maxed", false))
		var affordable := bool(info.get("affordable", false))
		_unit_upgrade.visible = true
		_unit_upgrade.text = "%s  %d" % [_t("battle.upgrade", "Upgrade"), int(info.get("upgrade_cost", 0))]
		_unit_upgrade.disabled = maxed or not affordable
		_unit_reason.modulate = WARN_COLOR
		if maxed:
			_unit_reason.text = _t("battle.max_level", "Max level")
		elif not affordable:
			_unit_reason.text = _t("battle.not_enough_cash", "Not enough cash")
	_unit_sheet.visible = true


func hide_unit_sheet() -> void:
	_unit_sheet.visible = false


func is_unit_sheet_open() -> bool:
	return _unit_sheet.visible


func _create_unit_row(data: UnitData, affordable: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = &"ListRow"
	row.custom_minimum_size = Vector2(0, 160)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	row.add_child(layout)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.texture = data.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	layout.add_child(info)

	var name_label := Label.new()
	name_label.text = _t(data.display_name_key, data.display_name)
	info.add_child(name_label)

	var role := Label.new()
	role.theme_type_variation = &"Caption"
	role.text = _t(data.description_key, data.description)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(role)

	var stats := Label.new()
	stats.theme_type_variation = &"Caption"
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.text = "%d %s  ·  %.2f s  ·  %d %s" % [
		int(round(data.damage)), _t("battle.damage", "damage"),
		data.attack_interval, int(round(data.range)), _t("battle.range", "range"),
	]
	info.add_child(stats)

	if not affordable:
		var reason := Label.new()
		reason.theme_type_variation = &"Caption"
		reason.text = _t("battle.not_enough_cash", "Not enough cash")
		reason.modulate = WARN_COLOR
		info.add_child(reason)

	var place_button := Button.new()
	place_button.theme_type_variation = &"PrimaryButton"
	place_button.custom_minimum_size = Vector2(220, 104)
	place_button.text = "%s %d" % [_t("battle.place", "Place"), data.placement_cost]
	place_button.disabled = not affordable
	place_button.pressed.connect(_on_unit_place_pressed.bind(data.id))
	layout.add_child(place_button)
	return row


# --- speed control, pause and the upgrade panel -----------------------------------


## Highlights the active speed and marks locked segments with a lock icon.
func set_speed_state(sim_speed: float, unlocked: Dictionary) -> void:
	_unlocked_speeds = unlocked.duplicate()
	_style_speed_button(_speed_1x, true, is_equal_approx(sim_speed, 1.0))
	_style_speed_button(_speed_15x, bool(unlocked.get(1.5, false)), is_equal_approx(sim_speed, 1.5))
	_style_speed_button(_speed_2x, bool(unlocked.get(2.0, false)), is_equal_approx(sim_speed, 2.0))


func _style_speed_button(button: Button, unlocked: bool, active: bool) -> void:
	button.theme_type_variation = &"GoldButton" if active else &"SecondaryButton"
	button.icon = null if unlocked else LOCK_ICON
	button.modulate = Color.WHITE if unlocked else Color(0.74, 0.74, 0.7, 1.0)


func _on_speed_pressed(speed: float) -> void:
	if speed <= 1.0 or bool(_unlocked_speeds.get(speed, false)):
		speed_requested.emit(speed)
		return
	_pending_unlock_id = &"speed_2" if speed >= 2.0 else &"speed_1_5"
	var required := UnlockService.level_required(_pending_unlock_id)
	if required <= 0:
		required = 10 if speed >= 2.0 else 3
	var title := "%s %s" % [_t("battle.speed", "Speed"), _format_speed(speed)]
	var body := _t(
		"battle.speed_locked_body",
		"Reach player level %d to unlock this speed."
	) % required
	var debug := App.is_debug_build()
	_lock_modal.open(
		title,
		body,
		_t("battle.debug_unlock", "Debug unlock") if debug else _t("common.ok", "OK"),
		_t("common.cancel", "Cancel") if debug else ""
	)


func _on_lock_confirmed() -> void:
	if _pending_unlock_id.is_empty() or not App.is_debug_build():
		_pending_unlock_id = &""
		return
	var unlock_id := _pending_unlock_id
	_pending_unlock_id = &""
	debug_unlock_requested.emit(unlock_id)


func _format_speed(speed: float) -> String:
	if is_equal_approx(speed, roundf(speed)):
		return "%dx" % int(roundf(speed))
	return "%.1fx" % speed


func _tooltip_speed(button: Button, text: String) -> void:
	button.tooltip_text = text


func _on_upgrade_button_resized() -> void:
	_upgrade_button.pivot_offset = _upgrade_button.size * 0.5


func show_pause(stats_text: String) -> void:
	_pause_menu.open(stats_text)


func hide_pause() -> void:
	_pause_menu.close()


func is_pause_open() -> bool:
	return _pause_menu.is_open()


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_abandon_pressed() -> void:
	abandon_requested.emit()


## Opens the generated bottom sheet with a data snapshot for all three tabs.
func show_upgrade_panel(data: Dictionary, active_tab: StringName = &"tree") -> void:
	_upgrade_panel.open_panel(data, active_tab)


## Updates row values in place (keeps a hold-to-buy press alive).
func update_upgrade_panel(data: Dictionary) -> void:
	_upgrade_panel.set_data(data)


func hide_upgrade_panel() -> void:
	_upgrade_panel.close_panel()


func is_upgrade_panel_open() -> bool:
	return _upgrade_panel.is_panel_open()


func set_upgrade_purchase_handler(handler: Callable) -> void:
	_upgrade_panel.set_purchase_handler(handler)


func set_upgrade_open_handler(handler: Callable) -> void:
	_upgrade_panel.set_open_handler(handler)


## Notification dot + pulse while at least one upgrade is affordable.
func set_upgrade_available(available: bool) -> void:
	if _upgrade_dot != null:
		_upgrade_dot.visible = available
	if available:
		if _pulse_tween != null and _pulse_tween.is_valid():
			return
		_upgrade_button.pivot_offset = _upgrade_button.size * 0.5
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_upgrade_button, "scale", Vector2(1.04, 1.04), 0.5)
		_pulse_tween.tween_property(_upgrade_button, "scale", Vector2.ONE, 0.5)
	elif _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		_upgrade_button.scale = Vector2.ONE


## Number of successful "Next wave" skips (TapGuard needs the first three held).
func set_next_wave_uses(uses: int) -> void:
	_next_wave_uses = uses


func _on_next_wave_down() -> void:
	_next_wave_press_msec = Time.get_ticks_msec()


func _on_next_wave_up() -> void:
	var held := float(Time.get_ticks_msec() - _next_wave_press_msec) / 1000.0
	if TapGuard.allows(_next_wave_uses, held):
		next_wave_requested.emit()
	else:
		show_banner(_t("battle.hold_to_skip", "Hold 0.25 s to skip the wait"))


func _on_next_wave_pressed() -> void:
	next_wave_requested.emit()


# --- helpers ----------------------------------------------------------------------


func _add_stat_row(
	container: VBoxContainer,
	title: String,
	current_text: String,
	next_text: String,
	maxed: bool = false
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var title_label := Label.new()
	title_label.theme_type_variation = &"Body"
	title_label.custom_minimum_size = Vector2(STAT_LABEL_WIDTH, 0)
	title_label.text = title
	row.add_child(title_label)

	var current := Label.new()
	current.text = current_text
	row.add_child(current)

	if not next_text.is_empty():
		var arrow := Label.new()
		arrow.theme_type_variation = &"Caption"
		arrow.text = "→"
		row.add_child(arrow)
		var next := Label.new()
		next.text = "MAX" if maxed else next_text
		next.modulate = DELTA_COLOR if not maxed else Color(0.82, 0.82, 0.78, 1.0)
		row.add_child(next)

	container.add_child(row)


func _format_int(value: Variant) -> String:
	return str(int(round(float(value))))


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _t(key: String, fallback: String = "") -> String:
	return LocaleService.t(key, fallback)


func _on_build_row_pressed(tower_id: StringName) -> void:
	build_requested.emit(tower_id)


func _on_unit_place_pressed(unit_id: StringName) -> void:
	unit_place_requested.emit(unit_id)


func _on_tower_upgrade_pressed() -> void:
	tower_upgrade_requested.emit()


func _on_tower_sell_pressed() -> void:
	tower_sell_requested.emit()


func _on_unit_upgrade_pressed() -> void:
	unit_upgrade_requested.emit()


func _on_upgrade_pressed() -> void:
	upgrade_open_requested.emit()


func _on_upgrade_panel_closed() -> void:
	upgrade_closed.emit()


func _on_dismiss_pressed() -> void:
	dismiss_requested.emit()


func _on_scrim_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		dismiss_requested.emit()
