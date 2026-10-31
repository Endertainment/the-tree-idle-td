## DebugAdOverlay — visible fake ad used on desktop/editor (spec 7.1).
##
## Shows a full-screen dim panel with a countdown so rewarded/interstitial flows
## can be exercised without an ad SDK. Built at runtime so no theme scene edits are
## needed; all strings go through LocaleService.
class_name DebugAdOverlay
extends CanvasLayer

signal finished

const SCRIM_COLOR := Color(0.02, 0.05, 0.02, 0.86)

var _remaining: float = 2.0
var _countdown: Label
var _placement_label: Label
var _rewarded: bool = true
var _done: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	set_process(true)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var scrim := ColorRect.new()
	scrim.color = SCRIM_COLOR
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 420)
	panel.theme_type_variation = &"Panel"
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title := Label.new()
	title.text = LocaleService.t("debug_ad.title", "Rewarded ad (debug)")
	title.theme_type_variation = &"H1"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	_placement_label = Label.new()
	_placement_label.theme_type_variation = &"Caption"
	_placement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_placement_label)

	_countdown = Label.new()
	_countdown.theme_type_variation = &"H1"
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_countdown)

	var note := Label.new()
	note.text = LocaleService.t("debug_ad.body", "Fake ad for debug builds. No network is used.")
	note.theme_type_variation = &"Caption"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)


## Starts the countdown. `rewarded` only changes the debug label.
func play(seconds: float, placement: StringName, rewarded: bool = true) -> void:
	_remaining = maxf(seconds, 0.0)
	_rewarded = rewarded
	if _placement_label != null:
		_placement_label.text = String(placement)
	if _countdown != null:
		_countdown.text = LocaleService.t("debug_ad.countdown", "%d s") % int(ceil(_remaining))
	if _remaining <= 0.0:
		_finish()


func _process(delta: float) -> void:
	if _done:
		return
	_remaining -= delta
	if _countdown != null:
		_countdown.text = LocaleService.t("debug_ad.countdown", "%d s") % maxi(int(ceil(_remaining)), 0)
	if _remaining <= 0.0:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	finished.emit()
	queue_free()
