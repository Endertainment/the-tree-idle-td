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
	if window.y <= 0:
		return 0.0
	# Safe area is in screen coordinates; the window may be offset (multi-monitor).
	var window_rect := Rect2i(DisplayServer.window_get_position(), window)
	var top_px := maxi(safe.position.y - window_rect.position.y, 0)
	if top_px <= 0:
		return 0.0
	# Guard against a bogus reading turning into a half-screen margin.
	top_px = mini(top_px, int(window.y * 0.25))
	var tree := Engine.get_main_loop() as SceneTree
	var viewport_height := 1920.0
	if tree != null and tree.root != null:
		viewport_height = tree.root.get_visible_rect().size.y
	return float(top_px) / float(window.y) * viewport_height


