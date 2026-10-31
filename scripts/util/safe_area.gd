## DisplayCutout — converts the Android display cutout into canvas units.
##
## Godot reports the safe area in physical pixels; the game runs in a 1080-wide
## canvas, so every inset has to be divided by the display scale. Used by the
## menu shell and the battle HUD to keep content clear of the camera hole.
class_name DisplayCutout
extends RefCounted


## Vertical inset (canvas units) that must be added below the top screen edge.
static func top_inset() -> float:
	if not DisplayServer.has_method("get_display_safe_area"):
		return 0.0
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var window: Vector2i = DisplayServer.window_get_size()
	if window.y <= 0 or safe.position.y <= 0:
		return 0.0
	var viewport := Engine.get_main_loop() as SceneTree
	var viewport_height := 1920.0
	if viewport != null and viewport.root != null:
		viewport_height = viewport.root.get_visible_rect().size.y
	return float(safe.position.y) / float(window.y) * viewport_height


