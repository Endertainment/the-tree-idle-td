## ConsentDialog — local consent gate used when the UMP SDK is unavailable.
##
## Spec 7.1: no ad may load before consent. The flag is persisted by
## SettingsService (default false in release, true in editor/debug). This dialog is
## built at runtime and reports {granted: bool} through the callback.
class_name ConsentDialog
extends CanvasLayer

signal answered(granted: bool)

var _callback: Callable
var _answered: bool = false


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.05, 0.02, 0.9)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 640)
	panel.theme_type_variation = &"Panel"
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)

	var title := Label.new()
	title.text = LocaleService.t("consent.title", "Ads and privacy")
	title.theme_type_variation = &"H1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	var body := Label.new()
	body.text = LocaleService.t(
		"consent.body",
		"We show optional rewarded ads to support development. Choose whether personalised ads may use your advertising ID. You can change this later in Settings."
	)
	body.theme_type_variation = &"Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	var accept := Button.new()
	accept.text = LocaleService.t("consent.accept", "Allow personalised ads")
	accept.custom_minimum_size = Vector2(0, 100)
	accept.theme_type_variation = &"PrimaryButton"
	accept.focus_mode = Control.FOCUS_NONE
	accept.pressed.connect(_answer.bind(true))
	box.add_child(accept)

	var decline := Button.new()
	decline.text = LocaleService.t("consent.decline", "Use non-personalised ads only")
	decline.custom_minimum_size = Vector2(0, 92)
	decline.theme_type_variation = &"GhostButton"
	decline.focus_mode = Control.FOCUS_NONE
	decline.pressed.connect(_answer.bind(false))
	box.add_child(decline)


## Shows the dialog. `callback` receives true when the player accepted.
func open(callback: Callable) -> void:
	_callback = callback
	if not answered.is_connected(_on_answered):
		answered.connect(_on_answered)


func _answer(granted: bool) -> void:
	if _answered:
		return
	_answered = true
	SettingsService.set_consent_granted(granted)
	answered.emit(granted)
	queue_free()


func _on_answered(granted: bool) -> void:
	if _callback.is_valid():
		_callback.call(granted)
