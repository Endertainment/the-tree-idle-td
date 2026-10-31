## TutorialHint — a small dismissible tip used by the three first-run hints.
##
## Built entirely in code so it can be attached to any CanvasLayer (battle HUD,
## run summary) without touching those scenes. The panel and label ignore mouse
## input, so the hint never blocks the game; only the dismiss button is clickable.
class_name TutorialHint
extends PanelContainer

signal dismissed

const AUTO_HIDE_SECONDS := 9.0
const WIDTH := 760.0
const BOTTOM_MARGIN := 230.0

var _label: Label
var _close: Button
var _timer: Timer
var _tween: Tween
var _hint_text: String = ""
var _built: bool = false


func _ready() -> void:
	_build()


## Builds the tip UI once. show_hint() also calls this so a test (or a caller
## that shows a hint in the same frame it adds the node) never sees null children.
func _build() -> void:
	if _built:
		return
	_built = true
	theme_type_variation = &"PanelGreen"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	visible = false
	custom_minimum_size = Vector2(WIDTH, 0.0)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = -BOTTOM_MARGIN - 150.0
	offset_bottom = -BOTTOM_MARGIN

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("font_size", 34)
	row.add_child(_label)

	_close = Button.new()
	_close.custom_minimum_size = Vector2(120, 96)
	_close.add_theme_font_size_override("font_size", 30)
	_close.pressed.connect(dismiss)
	row.add_child(_close)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(dismiss)
	add_child(_timer)


## Shows the hint with `text`; auto-hides after `seconds` (0 = only by button).
func show_hint(text: String, seconds: float = AUTO_HIDE_SECONDS) -> void:
	_build()
	_hint_text = text
	_label.text = text
	_close.text = LocaleService.t("tutorial.dismiss", "Got it")
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	if seconds > 0.0:
		_timer.start(seconds)


## Hides the hint and emits `dismissed` once (timer and button share this path).
func dismiss() -> void:
	if not visible or _timer == null:
		return
	_timer.stop()
	visible = false
	dismissed.emit()


func get_hint_text() -> String:
	return _hint_text


func is_showing() -> bool:
	return visible
