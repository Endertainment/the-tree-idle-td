## BattleHUD — the M2 battle overlay.
##
## Presentation only: it renders data passed in and emits requests; the
## BattleHudController decides. M2 adds the boss bar (replaces the wave label
## while a boss is alive), the tower sheet, the unit placement/upgrade sheet and
## the 1x speed placeholder (M3 wires real speeds).
class_name BattleHUD
extends CanvasLayer

signal build_requested(tower_id: StringName)
signal next_wave_requested
signal dismiss_requested
signal tower_upgrade_requested
signal tower_sell_requested
signal unit_place_requested(unit_id: StringName)
signal unit_upgrade_requested

const LOW_HP_RATIO := 0.3
const HP_FILL_NORMAL := preload("res://assets/art/battle/hud/tree_hp_fill.png")
const HP_FILL_LOW := preload("res://assets/art/battle/hud/tree_hp_fill_low.png")
const DELTA_COLOR := Color(0.55, 0.95, 0.45, 1.0)
const WARN_COLOR := Color(1.0, 0.58, 0.45, 1.0)
const STAT_LABEL_WIDTH := 250.0

@onready var _wave_label: Label = %WaveLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _cash_pill: CurrencyPill = %CashPill
@onready var _speed_button: Button = %SpeedButton
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
@onready var _upgrade_modal: Modal = %UpgradeModal
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

var _banner_tween: Tween


func _ready() -> void:
	_countdown_box.visible = false
	_banner.visible = false
	_build_sheet.visible = false
	_tower_sheet.visible = false
	_unit_sheet.visible = false
	_boss_bar.visible = false
	_wave_label.visible = true

	_upgrade_button.text = _t("battle.upgrade", "Upgrade")
	_build_title.text = _t("battle.build_title", "Build tower")
	_build_close.text = _t("battle.close", "Close")
	_tower_close.text = _t("battle.close", "Close")
	_unit_close.text = _t("battle.close", "Close")
	_next_wave_button.text = _t("battle.next_wave", "Next wave")
	_speed_button.text = "1x"
	_speed_button.disabled = true
	_speed_button.tooltip_text = _t("battle.speed_soon", "Speed control arrives in M3")

	_next_wave_button.pressed.connect(_on_next_wave_pressed)
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


func _on_next_wave_pressed() -> void:
	next_wave_requested.emit()


func _on_upgrade_pressed() -> void:
	_upgrade_modal.open(
		_t("battle.upgrades", "Upgrades"),
		_t("battle.upgrades_soon", "Tree upgrades arrive in M3"),
		_t("common.ok", "OK"),
		""
	)


func _on_dismiss_pressed() -> void:
	dismiss_requested.emit()


func _on_scrim_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		dismiss_requested.emit()
