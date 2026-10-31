## UpgradePanel — generated bottom sheet with Tree / Units / Towers tabs (M3).
##
## Rows are generated from BattleController payloads; adding a Tree track is a
## data change. Hold-to-buy runs at 8/s through HoldToBuy and stops on the first
## failed SpendResult, so it cannot double-spend. The panel is presentation plus
## input repeat; every transaction goes through the controller's handler Callable.
class_name UpgradePanel
extends Control

signal closed

const TABS: Array[StringName] = [&"tree", &"units", &"towers"]
const ACTIVE_TAB_VARIATION := &"GoldButton"
const IDLE_TAB_VARIATION := &"SecondaryButton"

@onready var _scrim: ColorRect = %Scrim
@onready var _title: Label = %Title
@onready var _close_button: Button = %CloseButton
@onready var _tab_tree: Button = %TabTree
@onready var _tab_units: Button = %TabUnits
@onready var _tab_towers: Button = %TabTowers
@onready var _rows: VBoxContainer = %Rows
@onready var _empty_label: Label = %EmptyLabel

var _purchase_handler: Callable
var _open_handler: Callable
var _hold := HoldToBuy.new()
var _hold_row_id: StringName = &""
var _rows_by_id: Dictionary = {}
var _data: Dictionary = {"tree": [], "units": [], "towers": []}
var _active_tab: StringName = &"tree"


func _ready() -> void:
	visible = false
	set_process(false)
	_title.text = LocaleService.t("battle.upgrades", "Upgrades")
	_close_button.text = LocaleService.t("battle.close", "Close")
	_tab_tree.text = LocaleService.t("battle.tab_tree", "Tree")
	_tab_units.text = LocaleService.t("battle.tab_units", "Units")
	_tab_towers.text = LocaleService.t("battle.tab_towers", "Towers")
	_close_button.pressed.connect(close_panel)
	_scrim.gui_input.connect(_on_scrim_gui_input)
	_tab_tree.pressed.connect(_on_tab_pressed.bind(&"tree"))
	_tab_units.pressed.connect(_on_tab_pressed.bind(&"units"))
	_tab_towers.pressed.connect(_on_tab_pressed.bind(&"towers"))


## The controller supplies the transaction function (kind, row_id -> SpendResult).
func set_purchase_handler(handler: Callable) -> void:
	_purchase_handler = handler


## The controller supplies the tower-sheet opener (row_id -> void).
func set_open_handler(handler: Callable) -> void:
	_open_handler = handler


## Shows the panel on `active_tab` with a data snapshot for all three tabs.
func open_panel(data: Dictionary, active_tab: StringName = &"tree") -> void:
	_data = _normalize_data(data)
	_active_tab = active_tab if TABS.has(active_tab) else &"tree"
	visible = true
	set_process(true)
	_update_tab_styles()
	_render(true)


## Replaces row data without rebuilding existing row nodes (keeps a hold alive).
func set_data(data: Dictionary) -> void:
	_data = _normalize_data(data)
	if not visible:
		return
	_render(false)


func close_panel() -> void:
	_stop_hold()
	visible = false
	set_process(false)
	closed.emit()


func is_panel_open() -> bool:
	return visible


func get_active_tab() -> StringName:
	return _active_tab


## Row ids currently rendered (tests and tools assert data-driven generation).
func get_row_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for row in _rows_by_id.values():
		ids.append((row as UpgradeRow).row_id)
	return ids


func _process(delta: float) -> void:
	if not _hold.is_active():
		return
	_hold.tick(delta, _attempt_hold)


func _attempt_hold() -> SpendResult:
	var row := _rows_by_id.get(_hold_row_id) as UpgradeRow
	if row == null or not _purchase_handler.is_valid():
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "battle.unknown_upgrade", 0, 0)
	return _purchase(row.kind, row.row_id)


func _purchase(kind: StringName, row_id: StringName) -> SpendResult:
	if not _purchase_handler.is_valid():
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "battle.unknown_upgrade", 0, 0)
	var result: Variant = _purchase_handler.call(kind, row_id)
	if result is SpendResult:
		return result as SpendResult
	return SpendResult.success(0, 0)


func _on_row_buy_pressed(row_id: StringName) -> void:
	var row := _rows_by_id.get(row_id) as UpgradeRow
	if row != null:
		_purchase(row.kind, row_id)


func _on_row_hold_started(row_id: StringName) -> void:
	_stop_hold()
	_hold_row_id = row_id
	_hold.start()


func _on_row_hold_stopped() -> void:
	_stop_hold()


func _on_row_open_pressed(row_id: StringName) -> void:
	if _open_handler.is_valid():
		_open_handler.call(row_id)


func _stop_hold() -> void:
	_hold.stop()
	_hold_row_id = &""


func _on_tab_pressed(tab: StringName) -> void:
	if tab == _active_tab:
		return
	_stop_hold()
	_active_tab = tab
	_update_tab_styles()
	_render(true)


func _update_tab_styles() -> void:
	var tabs := {&"tree": _tab_tree, &"units": _tab_units, &"towers": _tab_towers}
	for tab in tabs:
		var button := tabs[tab] as Button
		button.theme_type_variation = ACTIVE_TAB_VARIATION if tab == _active_tab else IDLE_TAB_VARIATION


func _render(force_rebuild: bool) -> void:
	if force_rebuild:
		for row in _rows_by_id.values():
			(row as Node).queue_free()
		_rows_by_id.clear()
	var payloads: Array = _data.get(String(_active_tab), [])
	var seen: Dictionary = {}
	for payload in payloads:
		if not (payload is Dictionary):
			continue
		var row_data := payload as Dictionary
		var row_id: StringName = row_data.get("id", &"")
		seen[row_id] = true
		var row := _rows_by_id.get(row_id) as UpgradeRow
		if row == null:
			row = UpgradeRow.new()
			_rows.add_child(row)
			row.buy_pressed.connect(_on_row_buy_pressed)
			row.hold_started.connect(_on_row_hold_started)
			row.hold_stopped.connect(_on_row_hold_stopped)
			row.open_pressed.connect(_on_row_open_pressed)
			_rows_by_id[row_id] = row
		row.apply(row_data)
		row.visible = true
	for row_id in _rows_by_id.keys():
		if not seen.has(row_id):
			var stale := _rows_by_id[row_id] as UpgradeRow
			if stale != null:
				if stale.row_id == _hold_row_id:
					_stop_hold()
				stale.queue_free()
			_rows_by_id.erase(row_id)
	_empty_label.visible = payloads.is_empty()
	_empty_label.text = _empty_text()


func _empty_text() -> String:
	match _active_tab:
		&"units":
			return LocaleService.t("battle.no_units", "No guardian units placed yet")
		&"towers":
			return LocaleService.t("battle.no_towers", "Build a tower to upgrade it")
		_:
			return LocaleService.t("battle.no_upgrades", "No upgrades available")


func _normalize_data(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = {
		"tree": data.get("tree", []),
		"units": data.get("units", []),
		"towers": data.get("towers", []),
	}
	return normalized


func _on_scrim_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		close_panel()
