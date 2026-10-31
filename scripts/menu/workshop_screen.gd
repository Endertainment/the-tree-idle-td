## WorkshopScreen — permanent coin upgrades: 4 tabs, 24 generated rows (spec 13.6).
##
## Presentation + routing only: every purchase goes through WorkshopService, and
## the screen re-renders from the service after each result. No gameplay maths and
## no direct wallet writes live here.
extends Control

const CATEGORY_IDS: Array[StringName] = [&"attack", &"defense", &"utility", &"environment"]
const PURCHASE_SFX_HOOK := "metadata/workshop_purchase_sfx"

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _coins_pill: CurrencyPill = %CoinsPill
@onready var _attack_tab: Button = %AttackTab
@onready var _defense_tab: Button = %DefenseTab
@onready var _utility_tab: Button = %UtilityTab
@onready var _environment_tab: Button = %EnvironmentTab
@onready var _rows_box: VBoxContainer = %Rows
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _nav: MenuNav = %MenuNav

var _category: StringName = &"attack"
var _rows: Dictionary = {}
var _toast_tween: Tween
## Tooling-only preview state for screenshots; never touches the real save.
var _preview_coins: int = -1
var _preview_levels: Dictionary = {}


func _ready() -> void:
	_localize()
	_attack_tab.pressed.connect(_on_tab_pressed.bind(CATEGORY_IDS[0]))
	_defense_tab.pressed.connect(_on_tab_pressed.bind(CATEGORY_IDS[1]))
	_utility_tab.pressed.connect(_on_tab_pressed.bind(CATEGORY_IDS[2]))
	_environment_tab.pressed.connect(_on_tab_pressed.bind(CATEGORY_IDS[3]))
	_back_button.pressed.connect(_on_back_pressed)
	EventBus.currency_changed.connect(_on_currency_changed)
	LocaleService.language_changed.connect(_on_language_changed)
	_toast.visible = false
	_refresh()
	select_category(_category)


func _exit_tree() -> void:
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_localize()
	_rebuild_rows()


func _localize() -> void:
	_title_label.text = LocaleService.t("workshop.title", "Workshop")
	_back_button.text = LocaleService.t("common.back", "Back")
	_hint_label.text = LocaleService.t(
		"workshop.hint",
		"Permanent upgrades. Coins are never spent inside a battle."
	)
	_attack_tab.text = LocaleService.t("workshop.category.attack", "Attack")
	_defense_tab.text = LocaleService.t("workshop.category.defense", "Defense")
	_utility_tab.text = LocaleService.t("workshop.category.utility", "Utility")
	_environment_tab.text = LocaleService.t("workshop.category.environment", "Environment")
	_nav.setup(&"workshop")


## Switches the visible category and rebuilds its rows.
func select_category(category: StringName) -> void:
	_category = category
	_style_tabs()
	_rebuild_rows()


func _on_tab_pressed(category: StringName) -> void:
	select_category(category)


func _on_back_pressed() -> void:
	SaveService.request_save()
	SceneRouter.back()


func _on_shop_pressed() -> void:
	SceneRouter.goto(&"shop")


func _refresh() -> void:
	_coins_pill.set_amount(_balance())


func _balance() -> int:
	return _preview_coins if _preview_coins >= 0 else WalletService.get_balance(&"coins")


func _level_of(track_id: StringName) -> int:
	if _preview_levels.has(String(track_id)):
		return int(_preview_levels[String(track_id)])
	return WorkshopService.level_of(track_id)


func _rebuild_rows() -> void:
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	for track in WorkshopService.get_tracks_in(_category):
		var row := WorkshopRow.new()
		row.name = "Row_%s" % track.id
		_rows_box.add_child(row)
		row.apply(_payload(track))
		row.buy_pressed.connect(_on_buy_pressed.bind(row))
		_rows[String(track.id)] = row
	AudioBus.bind_buttons(self)


func _payload(track: WorkshopTrack) -> Dictionary:
	var level := _level_of(track.id)
	var maxed := level >= track.max_level or (track.cap > 0.0 and track.total_at(level) >= track.cap)
	var cost := 0 if maxed else track.cost_at(level)
	var balance := _balance()
	var affordable := not maxed and balance >= cost
	return {
		"id": track.id,
		"icon": track.icon,
		"name": LocaleService.t(track.name_key, track.name),
		"level_text": "%s %d / %d" % [LocaleService.t("workshop.level_short", "Lv"), level, track.max_level],
		"current_text": track.format_total(level),
		"next_text": track.format_total(level + 1),
		"delta_text": "",
		"cost_text": "" if maxed else LocaleService.format_number(cost),
		"maxed": maxed,
		"affordable": affordable,
		"reason": "" if maxed or affordable else _need_more_text(cost - balance),
	}


func _on_buy_pressed(track_id: StringName, row: WorkshopRow) -> void:
	var result := WorkshopService.try_buy(track_id)
	if result.is_ok():
		AudioBus.play_ui(&"ui_purchase")
		row.play_purchase_flash()
		_refresh()
		_apply_row(track_id)
		return
	row.shake()
	AudioBus.play_ui(&"ui_error")
	_show_toast(_reason_text(result))


func _apply_row(track_id: StringName) -> void:
	var row: WorkshopRow = _rows.get(String(track_id), null)
	var track := WorkshopService.get_track(track_id)
	if row != null and track != null:
		row.apply(_payload(track))


func _reason_text(result: SpendResult) -> String:
	if result.code == SpendResult.Code.MAX_LEVEL:
		return LocaleService.t("workshop.max_level", "Max level")
	var missing := maxi(result.amount - result.balance, 0)
	return _need_more_text(missing)


func _need_more_text(missing: int) -> String:
	return LocaleService.t("workshop.need_more", "Need %d more coins") % missing


func _style_tabs() -> void:
	var pairs := {
		_attack_tab: CATEGORY_IDS[0],
		_defense_tab: CATEGORY_IDS[1],
		_utility_tab: CATEGORY_IDS[2],
		_environment_tab: CATEGORY_IDS[3],
	}
	for button: Button in pairs.keys():
		var active: bool = pairs[button] == _category
		button.theme_type_variation = &"GoldButton" if active else &"SecondaryButton"
		button.modulate = Color.WHITE if active else Color(0.82, 0.84, 0.8, 1.0)


func _on_currency_changed(kind: StringName, _amount: int) -> void:
	if kind != &"coins":
		return
	_refresh()
	for track in WorkshopService.get_tracks_in(_category):
		_apply_row(track.id)


func _show_toast(message: String) -> void:
	ToastService.show_toast(message)


## Tooling-only: a populated, affordable state for docs/preview captures.
func stage_preview() -> void:
	_preview_coins = 12480
	_preview_levels = {
		"tree_damage": 12,
		"unit_damage": 8,
		"tower_damage": 10,
		"crit_chance": 6,
		"crit_damage": 4,
		"attack_speed": 3,
	}
	_refresh()
	_rebuild_rows()
