## WorkshopRow — one generated permanent-upgrade row (spec 13.6).
##
## Presentation only: it renders a payload from WorkshopScreen and emits the
## purchase request. Built in code because the 24 rows are data-driven. The buy
## button stays tappable when unaffordable (dimmed) so the screen can show the
## "Need N more coins" toast instead of a silently dead button.
class_name WorkshopRow
extends PanelContainer

signal buy_pressed(track_id: StringName)

const ICON_SIZE := 80.0
const ROW_HEIGHT := 148.0
const BUTTON_SIZE := Vector2(190, 92)
const DELTA_COLOR := Color(0.55, 0.95, 0.45, 1.0)
const DIM_COLOR := Color(0.72, 0.72, 0.68, 1.0)
const WARN_COLOR := Color(1.0, 0.58, 0.45, 1.0)

var track_id: StringName = &""

var _payload: Dictionary = {}
var _built: bool = false
var _icon: TextureRect
var _name_label: Label
var _level_label: Label
var _current_label: Label
var _next_label: Label
var _delta_label: Label
var _cost_label: Label
var _reason_label: Label
var _button: Button


func apply(payload: Dictionary) -> void:
	_payload = payload.duplicate()
	track_id = payload.get("id", &"")
	if not _built:
		_build()
	_icon.texture = payload.get("icon") as Texture2D
	_name_label.text = str(payload.get("name", ""))
	_level_label.text = str(payload.get("level_text", ""))
	_current_label.text = str(payload.get("current_text", ""))
	_next_label.text = str(payload.get("next_text", ""))
	_delta_label.text = str(payload.get("delta_text", ""))
	var maxed := bool(payload.get("maxed", false))
	var affordable := bool(payload.get("affordable", false))
	_delta_label.visible = not maxed and not _delta_label.text.is_empty()
	_next_label.visible = not maxed
	_reason_label.text = str(payload.get("reason", ""))
	_reason_label.visible = not _reason_label.text.is_empty()
	_cost_label.text = str(payload.get("cost_text", ""))
	_cost_label.visible = not _cost_label.text.is_empty()
	if maxed:
		_button.text = LocaleService.t("workshop.max_level", "Max level")
		_button.disabled = true
		_button.modulate = DIM_COLOR
	else:
		_button.text = LocaleService.t("workshop.buy", "Buy")
		_button.disabled = false
		_button.modulate = Color.WHITE if affordable else DIM_COLOR


## Gold flash after a successful purchase (spec 13.6: sound + value flash).
func play_purchase_flash() -> void:
	modulate = Color(1.0, 0.9, 0.45, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.35)


## Red flash + a short rotation wiggle when the player taps without enough coins.
func shake() -> void:
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "rotation", -0.012, 0.05)
	tween.tween_property(self, "rotation", 0.012, 0.08)
	tween.tween_property(self, "rotation", 0.0, 0.05)
	modulate = Color(1.0, 0.55, 0.45, 1.0)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.3)


func _build() -> void:
	_built = true
	theme_type_variation = &"PanelWorkshopListRow"
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
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
	preview.add_theme_constant_override("separation", 10)
	info.add_child(preview)

	_current_label = Label.new()
	preview.add_child(_current_label)

	var arrow := Label.new()
	arrow.theme_type_variation = &"Caption"
	arrow.text = "→"
	preview.add_child(arrow)

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
	right.custom_minimum_size = Vector2(210.0, 0.0)
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
	_button.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if track_id.is_empty():
		return
	buy_pressed.emit(track_id)
