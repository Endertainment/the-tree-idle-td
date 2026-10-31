## SceneRouter — the single owner of scene changes, transitions and history.
##
## Every scene id maps to one path in SCENES below. No other script may call
## SceneTree.change_scene_to_file(). A full-screen fade overlay is created at
## runtime so no scene has to embed transition UI.
extends Node

const SCENES: Dictionary = {
	&"boot": "res://scenes/boot/boot.tscn",
	&"main_menu": "res://scenes/menu/main_menu.tscn",
	&"workshop": "res://scenes/menu/workshop.tscn",
	&"battle": "res://scenes/battle/battle.tscn",
}

const FADE_OUT_SECONDS := 0.15
const FADE_IN_SECONDS := 0.15

var _overlay: CanvasLayer
var _fade: ColorRect
var _current_id: StringName = &""
var _last_params: Dictionary = {}
var _history: Array[StringName] = []
var _transitioning: bool = false


func _ready() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "SceneTransition"
	_overlay.layer = 100
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_fade)
	_fade.visible = false


## Changes to the scene registered under `scene_id`.
## `params` are stored for the next scene and exposed via get_params().
func goto(scene_id: StringName, params: Dictionary = {}) -> void:
	await _transition(scene_id, params, true)


## Reloads the current scene (run restart). Keeps the same scene id and history.
func reload(params: Dictionary = {}) -> void:
	if _current_id == &"":
		return
	await _transition(_current_id, params, false, true)


## Returns to the previous scene, or the main menu when history is empty.
func back() -> void:
	var target: StringName = &"main_menu"
	if not _history.is_empty():
		target = _history.pop_back()
	await _transition(target, {}, false)


## Returns the id of the currently displayed scene, or &"" before the first goto.
func get_current_scene_id() -> StringName:
	return _current_id


## Returns the parameters passed to the current scene.
func get_params() -> Dictionary:
	return _last_params.duplicate(true)


## Returns true when back() has a stored destination.
func can_go_back() -> bool:
	return not _history.is_empty()


## Returns true while a fade transition is in progress.
func is_transitioning() -> bool:
	return _transitioning


func _transition(
	scene_id: StringName,
	params: Dictionary,
	push_history: bool,
	allow_same: bool = false
) -> void:
	if _transitioning:
		return
	if not SCENES.has(scene_id):
		push_error("SceneRouter: unknown scene id '%s'" % scene_id)
		return
	if scene_id == _current_id and not allow_same:
		return

	_transitioning = true
	_last_params = params.duplicate(true)
	_fade.visible = true
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)

	if FADE_OUT_SECONDS > 0.0:
		var fade_out := create_tween()
		fade_out.tween_property(_fade, "color:a", 1.0, FADE_OUT_SECONDS)
		await fade_out.finished
	else:
		_fade.color.a = 1.0

	if push_history and _current_id != &"":
		_history.append(_current_id)
	_current_id = scene_id

	var error: Error = get_tree().change_scene_to_file(SCENES[scene_id])
	if error != OK:
		push_error("SceneRouter: failed to load '%s' (error %d)" % [SCENES[scene_id], error])
		_fade.visible = false
		_transitioning = false
		return

	EventBus.scene_changed.emit(scene_id)
	await get_tree().process_frame

	if FADE_IN_SECONDS > 0.0:
		var fade_in := create_tween()
		fade_in.tween_property(_fade, "color:a", 0.0, FADE_IN_SECONDS)
		await fade_in.finished
	else:
		_fade.color.a = 0.0

	_fade.visible = false
	_transitioning = false
