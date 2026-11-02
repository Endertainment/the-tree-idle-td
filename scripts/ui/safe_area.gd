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
	# `get_display_safe_area()` is in *screen* coordinates. On a multi-monitor
	# setup the window can start at x=1920, which used to turn the left inset
	# into 1920 px and push the whole screen off-canvas. Compare against the
	# window rectangle instead of the screen origin.
	var window_rect := Rect2i(DisplayServer.window_get_position(), window_size)
	var safe := DisplayServer.get_display_safe_area().intersection(window_rect)
	if safe.size.x <= 0 or safe.size.y <= 0:
		return
	var left := maxi(safe.position.x - window_rect.position.x, 0)
	var top := maxi(safe.position.y - window_rect.position.y, 0)
	var right := maxi(window_rect.end.x - safe.end.x, 0)
	var bottom := maxi(window_rect.end.y - safe.end.y, 0)
	# A sane cutout is a fraction of the screen; anything larger is a bad reading.
	var max_h := int(window_size.x * 0.25)
	var max_v := int(window_size.y * 0.25)
	left = mini(left, max_h)
	right = mini(right, max_h)
	top = mini(top, max_v)
	bottom = mini(bottom, max_v)
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
