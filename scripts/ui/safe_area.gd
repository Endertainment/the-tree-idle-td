## SafeArea — applies display cutout/status-bar insets to a screen.
##
## Every screen has a `SafeArea` MarginContainer between the full-bleed background
## and the content. Insets are added to that container's margins; when a scene has
## no such node the root Control is shrunk instead. Desktop returns a full-rect safe
## area, so this is a no-op there. Called by SceneRouter, never per frame.
class_name SafeArea
extends RefCounted


static func apply(root: Control) -> void:
	if root == null or not root.is_inside_tree():
		return
	if root.has_meta("safe_area_applied"):
		return
	root.set_meta("safe_area_applied", true)
	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var left := maxi(safe.position.x, 0)
	var top := maxi(safe.position.y, 0)
	var right := maxi(window_size.x - safe.end.x, 0)
	var bottom := maxi(window_size.y - safe.end.y, 0)
	if left == 0 and top == 0 and right == 0 and bottom == 0:
		return
	var viewport_size := root.get_viewport_rect().size
	var scale_x := viewport_size.x / float(window_size.x)
	var scale_y := viewport_size.y / float(window_size.y)
	var container := root.get_node_or_null("SafeArea")
	if container is MarginContainer:
		var margin := container as MarginContainer
		margin.add_theme_constant_override(
			"margin_left", margin.get_theme_constant("margin_left") + int(round(left * scale_x))
		)
		margin.add_theme_constant_override(
			"margin_top", margin.get_theme_constant("margin_top") + int(round(top * scale_y))
		)
		margin.add_theme_constant_override(
			"margin_right", margin.get_theme_constant("margin_right") + int(round(right * scale_x))
		)
		margin.add_theme_constant_override(
			"margin_bottom", margin.get_theme_constant("margin_bottom") + int(round(bottom * scale_y))
		)
		return
	root.offset_left += left * scale_x
	root.offset_top += top * scale_y
	root.offset_right -= right * scale_x
	root.offset_bottom -= bottom * scale_y
