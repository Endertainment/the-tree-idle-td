## ToastService — the single toast channel for every screen (autoload).
##
## One CanvasLayer, one label and one tween, fed by a pure ToastQueue: a second
## toast waits for the first to fade instead of overlapping it. Screens call
## `show_toast()` with a string already localized through LocaleService.t().
extends CanvasLayer

const DEFAULT_SECONDS := 2.0
const FADE_IN := 0.12
const FADE_OUT := 0.25

var _queue := ToastQueue.new()
var _panel: PanelContainer
var _label: Label
var _tween: Tween
var _animating: bool = false


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


## Queues a localized message. Returns immediately; the queue decides when shown.
func show_toast(message: String) -> void:
	if _queue.push(message) and not _animating:
		_play_current()


## Drops every queued message (used by debug resets and tests).
func clear_toasts() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_queue.clear()
	_animating = false
	if is_instance_valid(_panel):
		_panel.visible = false


func get_pending_count() -> int:
	return _queue.pending_count()


func get_current_toast() -> String:
	return _queue.current


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Toast"
	_panel.theme_type_variation = &"Toast"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -430.0
	_panel.offset_right = 430.0
	_panel.offset_top = -330.0
	_panel.offset_bottom = -230.0

	_label = Label.new()
	_label.name = "Label"
	_label.theme_type_variation = &"Caption"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_label)


func _play_current() -> void:
	if not _queue.is_active():
		_animating = false
		return
	_animating = true
	_label.text = _queue.current
	_panel.visible = true
	_panel.modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(DEFAULT_SECONDS)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(_on_toast_finished)


func _on_toast_finished() -> void:
	_queue.complete()
	if _queue.is_active():
		_play_current()
		return
	_animating = false
	_panel.visible = false
