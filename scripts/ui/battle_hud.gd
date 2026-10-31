## BattleHUD — the M1 battle overlay: wave/timer/cash, tree HP, build sheet,
## prep countdown, wave banner and the placeholder Upgrade button.
##
## Presentation only: the HUD never mutates run state. It emits requests and the
## BattleController decides; display values arrive through set_*() calls.
class_name BattleHUD
extends CanvasLayer

signal build_requested(tower_id: StringName)
signal next_wave_requested
signal dismiss_requested

const LOW_HP_RATIO := 0.3
const HP_FILL_NORMAL := preload("res://assets/art/battle/hud/tree_hp_fill.png")
const HP_FILL_LOW := preload("res://assets/art/battle/hud/tree_hp_fill_low.png")

@onready var _wave_label: Label = %WaveLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _cash_pill: CurrencyPill = %CashPill
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

var _banner_tween: Tween


func _ready() -> void:
	_countdown_box.visible = false
	_banner.visible = false
	_build_sheet.visible = false
	_upgrade_button.text = LocaleService.t("battle.upgrade", "Upgrade")
	_build_title.text = LocaleService.t("battle.build_title", "Build tower")
	_build_close.text = LocaleService.t("battle.close", "Close")
	_next_wave_button.text = LocaleService.t("battle.next_wave", "Next wave")

	_next_wave_button.pressed.connect(_on_next_wave_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_build_close.pressed.connect(_on_dismiss_pressed)
	_build_scrim.gui_input.connect(_on_scrim_gui_input)


## Updates the wave counter; `total` 0 renders a bare "Wave N".
func set_wave(wave: int, total: int) -> void:
	var caption := LocaleService.t("battle.wave", "Wave")
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
	_hp_label.text = "%s: %d%%" % [LocaleService.t("battle.hp", "HP"), int(round(ratio * 100.0))]
	if ratio < LOW_HP_RATIO:
		_hp_bar.texture_progress = HP_FILL_LOW
		_hp_label.modulate = Color(1.0, 0.42, 0.38, 1.0)
	else:
		_hp_bar.texture_progress = HP_FILL_NORMAL
		_hp_label.modulate = Color.WHITE


## Shows the inter-wave countdown and the "Next wave" bonus button.
func show_countdown(duration: float, skip_bonus: int) -> void:
	_countdown_box.visible = true
	_next_wave_button.text = "%s  +%d" % [LocaleService.t("battle.next_wave", "Next wave"), skip_bonus]
	set_countdown(int(ceil(duration)))


func set_countdown(seconds_left: int) -> void:
	if not _countdown_box.visible:
		return
	_countdown_label.text = "%s %d" % [LocaleService.t("battle.next_wave_in", "Next wave in"), maxi(seconds_left, 0)]


func hide_countdown() -> void:
	_countdown_box.visible = false


## Shows a 0.6 s-style wave banner and fades it out.
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


## Opens the bottom build sheet with one card per available tower.
func show_build_sheet(options: Array[Dictionary]) -> void:
	_rebuild_rows(options)
	_build_sheet.visible = true


func hide_build_sheet() -> void:
	_build_sheet.visible = false


func is_sheet_open() -> bool:
	return _build_sheet.visible


func _rebuild_rows(options: Array[Dictionary]) -> void:
	for child in _build_rows.get_children():
		child.queue_free()
	for option in options:
		var data := option.get("data") as TowerData
		if data == null:
			continue
		_build_rows.add_child(_create_tower_row(data, bool(option.get("affordable", false)), str(option.get("reason", ""))))


func _create_tower_row(data: TowerData, affordable: bool, reason: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = &"ListRow"
	row.custom_minimum_size = Vector2(0, 128)

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
	name_label.text = LocaleService.t(data.display_name_key, "Archer Tower")
	info.add_child(name_label)

	var stats := Label.new()
	stats.theme_type_variation = &"Caption"
	stats.text = "%d %s  ·  %.2f s  ·  %d %s" % [
		int(round(data.damage)), LocaleService.t("battle.damage", "damage"),
		data.attack_interval, int(round(data.range)), LocaleService.t("battle.range", "range")
	]
	info.add_child(stats)

	if not reason.is_empty():
		var reason_label := Label.new()
		reason_label.theme_type_variation = &"Caption"
		reason_label.text = reason
		reason_label.modulate = Color(1.0, 0.55, 0.45, 1.0)
		info.add_child(reason_label)

	var build_button := Button.new()
	build_button.theme_type_variation = &"PrimaryButton"
	build_button.custom_minimum_size = Vector2(220, 96)
	build_button.text = "%s %d" % [LocaleService.t("battle.build", "Build"), data.build_cost]
	build_button.disabled = not affordable
	build_button.pressed.connect(_on_build_row_pressed.bind(data.id))
	layout.add_child(build_button)
	return row


func _on_build_row_pressed(tower_id: StringName) -> void:
	build_requested.emit(tower_id)


func _on_next_wave_pressed() -> void:
	next_wave_requested.emit()


func _on_upgrade_pressed() -> void:
	_upgrade_modal.open(
		LocaleService.t("battle.upgrades", "Upgrades"),
		LocaleService.t("battle.upgrades_soon", "Tree upgrades arrive in M3"),
		LocaleService.t("common.ok", "OK"),
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
