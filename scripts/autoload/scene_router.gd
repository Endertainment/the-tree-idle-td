## SceneRouter — the single owner of scene changes, transitions, history and
## Android back-button handling.
##
## Every scene id maps to one path in SCENES. No other script may call
## SceneTree.change_scene_to_file(). A full-screen fade overlay is created at
## runtime so no scene embeds transition UI. A second, higher canvas layer hosts
## modal screens opened with open_overlay() (e.g. Settings from the pause menu)
## without destroying the running scene.
extends Node

const SCENES: Dictionary = {
	&"boot": "res://scenes/boot/boot.tscn",
	&"onboarding": "res://scenes/onboarding/first_launch.tscn",
	&"main_menu": "res://scenes/menu/main_menu.tscn",
	&"workshop": "res://scenes/menu/workshop.tscn",
	&"magica": "res://scenes/menu/magica.tscn",
	&"cards": "res://scenes/menu/cards.tscn",
	&"missions": "res://scenes/menu/missions.tscn",
	&"shop": "res://scenes/menu/shop.tscn",
	&"leaderboard": "res://scenes/menu/leaderboard.tscn",
	&"profile": "res://scenes/menu/profile.tscn",
	&"settings": "res://scenes/menu/settings.tscn",
	&"battle": "res://scenes/battle/battle.tscn",
}

const FADE_OUT_SECONDS := 0.15
const FADE_IN_SECONDS := 0.15

var _overlay: CanvasLayer
var _fade: ColorRect
var _overlay_layer: CanvasLayer
var _overlay_scene: Control
var _overlay_id: StringName = &""
var _current_id: StringName = &""
var _last_params: Dictionary = {}
var _history: Array[StringName] = []
var _transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "ModalScreens"
	_overlay_layer.layer = 90
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)


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
	close_overlay()
	var target: StringName = &"main_menu"
	if not _history.is_empty():
		target = _history.pop_back()
	await _transition(target, {}, false)


## Opens a screen as a modal overlay above the current scene (no history entry).
## Used by the battle pause menu so opening Settings never ends the run.
func open_overlay(scene_id: StringName, params: Dictionary = {}) -> bool:
	if _transitioning or _overlay_scene != null:
		return false
	if not SCENES.has(scene_id):
		push_error("SceneRouter: unknown overlay scene id '%s'" % scene_id)
		return false
	var packed := load(SCENES[scene_id]) as PackedScene
	if packed == null:
		push_error("SceneRouter: cannot load overlay '%s'" % SCENES[scene_id])
		return false
	_overlay_scene = packed.instantiate() as Control
	if _overlay_scene == null:
		return false
	_overlay_id = scene_id
	_last_params = params.duplicate(true)
	_overlay_layer.add_child(_overlay_scene)
	SafeArea.apply(_overlay_scene)
	var audio := get_node_or_null("/root/AudioService")
	if audio != null:
		audio.call("bind_buttons", _overlay_scene)
	return true


## True when a modal screen is open.
func has_overlay() -> bool:
	return _overlay_scene != null and is_instance_valid(_overlay_scene)


## Closes the modal screen (if any). Safe to call when none is open.
func close_overlay() -> void:
	if _overlay_scene == null:
		return
	if is_instance_valid(_overlay_scene):
		_overlay_scene.queue_free()
	_overlay_scene = null
	_overlay_id = &""


## Called by screens that own a modal/panel stack. Returns true when handled.
func handle_back_request() -> bool:
	if _transitioning:
		return true
	if has_overlay():
		close_overlay()
		return true
	# Modals are the first thing Android back/Esc must dismiss.
	for modal: Node in get_tree().get_nodes_in_group("modal"):
		if modal is Control and (modal as Control).visible:
			modal.call(&"close")
			return true
	var scene := get_tree().current_scene
	if scene != null and scene.has_method(&"handle_back_request"):
		if bool(scene.call(&"handle_back_request")):
			return true
	if _current_id == &"main_menu" or _current_id == &"boot":
		get_tree().quit()
		return true
	back()
	return true


## Returns the id of the currently displayed scene, or &"" before the first goto.
func get_current_scene_id() -> StringName:
	return _current_id


## Returns the id of the open overlay, or &"" when none.
func get_overlay_id() -> StringName:
	return _overlay_id


## Returns the parameters passed to the current scene.
func get_params() -> Dictionary:
	return _last_params.duplicate(true)


## Returns true when back() has a stored destination.
func can_go_back() -> bool:
	return not _history.is_empty()


## Returns true while a fade transition is in progress.
func is_transitioning() -> bool:
	return _transitioning


## Android hardware back and desktop Esc route through the same handler.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back_request()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		handle_back_request()


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

	close_overlay()
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
	var current := get_tree().current_scene
	if current is Control:
		SafeArea.apply(current as Control)

	if FADE_IN_SECONDS > 0.0:
		var fade_in := create_tween()
		fade_in.tween_property(_fade, "color:a", 0.0, FADE_IN_SECONDS)
		await fade_in.finished
	else:
		_fade.color.a = 0.0

	_fade.visible = false
	_transitioning = false
