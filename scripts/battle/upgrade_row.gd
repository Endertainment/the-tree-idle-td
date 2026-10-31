## UpgradeRow — one generated row in the upgrade panel (Tree / Units / Towers).
##
## Presentation only: it renders a payload dictionary produced by BattleController
## and emits press/hold requests. The panel owns repeat timing; the controller owns
## the transaction. Built in code because the row list is data-driven.
class_name UpgradeRow
extends PanelContainer

signal buy_pressed(row_id: StringName)
signal hold_started(row_id: StringName)
signal hold_stopped
signal open_pressed(row_id: StringName)

const ICON_SIZE := 88.0
const ROW_HEIGHT := 152.0
const BUTTON_SIZE := Vector2(210, 96)
const DELTA_COLOR := Color(0.55, 0.95, 0.45, 1.0)
const WARN_COLOR := Color(1.0, 0.58, 0.45, 1.0)

var row_id: StringName = &""
var kind: StringName = &""
var hold_enabled: bool = false

var _payload: Dictionary = {}
var _built: bool = false
var _icon: TextureRect
var _name_label: Label
var _level_label: Label
var _current_label: Label
var _arrow_label: Label
var _next_label: Label
var _delta_label: Label
var _cost_label: Label
var _reason_label: Label
var _button: Button


func apply(payload: Dictionary) -> void:
	_payload = payload.duplicate()
	row_id = payload.get("id", &"")
	kind = payload.get("kind", &"")
	hold_enabled = bool(payload.get("hold", false))
	if not _built:
		_build()
	_icon.texture = payload.get("icon") as Texture2D
	_name_label.text = str(payload.get("name", ""))
	_level_label.text = str(payload.get("level_text", ""))
	var maxed := bool(payload.get("maxed", false))
	var action: StringName = payload.get("action", &"buy")
	if action == &"open":
		_current_label.text = str(payload.get("current_text", ""))
		_next_label.text = ""
		_delta_label.text = ""
		_arrow_label.visible = false
		_next_label.visible = false
		_delta_label.visible = false
	else:
		_arrow_label.visible = true
		_next_label.visible = true
		_current_label.text = str(payload.get("current_text", ""))
		_next_label.text = str(payload.get("next_text", ""))
		_delta_label.text = str(payload.get("delta_text", ""))
		_delta_label.visible = not maxed and not _delta_label.text.is_empty()
	_reason_label.text = str(payload.get("reason", ""))
	_reason_label.visible = not _reason_label.text.is_empty()
	var cost_text := str(payload.get("cost_text", ""))
	_cost_label.text = "" if cost_text.is_empty() else "%s %s" % [
		LocaleService.t("battle.cost", "Cost"), cost_text
	]
	_cost_label.visible = not _cost_label.text.is_empty()
	var affordable := bool(payload.get("affordable", false))
	if action == &"open":
		_button.text = LocaleService.t("battle.open", "Open")
		_button.disabled = false
	elif maxed:
		_button.text = LocaleService.t("battle.max_level_short", "MAX")
		_button.disabled = true
	else:
		_button.text = LocaleService.t("battle.buy", "Buy")
		_button.disabled = not affordable


func _build() -> void:
	_built = true
	theme_type_variation = &"ListRow"
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	add_child(layout)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(_icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	layout.add_child(info)

	_name_label = Label.new()
	info.add_child(_name_label)

	_level_label = Label.new()
	_level_label.theme_type_variation = &"Caption"
	info.add_child(_level_label)

	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 12)
	info.add_child(preview)

	_current_label = Label.new()
	preview.add_child(_current_label)

	var arrow := Label.new()
	arrow.theme_type_variation = &"Caption"
	arrow.text = "→"
	preview.add_child(arrow)
	_arrow_label = arrow

	_next_label = Label.new()
	_next_label.modulate = DELTA_COLOR
	preview.add_child(_next_label)

	_delta_label = Label.new()
	_delta_label.theme_type_variation = &"Caption"
	_delta_label.modulate = DELTA_COLOR
	preview.add_child(_delta_label)

	_reason_label = Label.new()
	_reason_label.theme_type_variation = &"Caption"
	_reason_label.modulate = WARN_COLOR
	info.add_child(_reason_label)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(240.0, 0.0)
	right.add_theme_constant_override("separation", 6)
	layout.add_child(right)

	_cost_label = Label.new()
	_cost_label.theme_type_variation = &"Caption"
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_cost_label)

	_button = Button.new()
	_button.theme_type_variation = &"PrimaryButton"
	_button.custom_minimum_size = BUTTON_SIZE
	right.add_child(_button)

	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	_button.pressed.connect(_on_pressed)


func _on_button_down() -> void:
	if hold_enabled:
		hold_started.emit(row_id)


func _on_button_up() -> void:
	if hold_enabled:
		hold_stopped.emit()


func _on_pressed() -> void:
	if hold_enabled:
		return
	if _payload.get("action", &"buy") == &"open":
		open_pressed.emit(row_id)
	else:
		buy_pressed.emit(row_id)
