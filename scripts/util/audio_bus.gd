## AudioBus — autoload-independent façade for AudioService.
##
## Scene scripts and headless tools call these static helpers instead of the
## AudioService autoload identifier, so a scene still compiles when a tool loads
## it before/without autoload registration.
class_name AudioBus
extends RefCounted


static func _service() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null("AudioService")


static func call_method(method: StringName, args: Array = []) -> Variant:
	var service := _service()
	if service == null:
		return null
	return service.callv(method, args)


static func play_ui(sound: StringName = &"ui_click") -> void:
	call_method(&"play_ui", [sound])


static func play_sfx_id(sound: StringName, pitch_variation: float = 0.05) -> void:
	call_method(&"play_sfx_id", [sound, pitch_variation])


static func play_sfx(stream: AudioStream, pitch_variation: float = 0.05) -> void:
	call_method(&"play_sfx", [stream, pitch_variation])


static func set_modal_open(open: bool) -> void:
	call_method(&"set_modal_open", [open])


static func bind_buttons(root: Node) -> void:
	call_method(&"bind_buttons", [root])
