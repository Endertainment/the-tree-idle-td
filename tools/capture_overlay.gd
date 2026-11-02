extends SceneTree
## Debug helper: opens a scene as the router overlay and captures it.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	root.size = Vector2i(1080, 1920)
	var battle := (load("res://scenes/battle/battle.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	await create_timer(0.6).timeout
	var router := root.get_node_or_null("SceneRouter")
	if router == null:
		push_error("no router")
		quit(1)
		return
	var ok: bool = router.call("open_overlay", &"settings")
	print("open_overlay -> ", ok)
	await create_timer(0.8).timeout
	var overlay: Node = router.get("_overlay_scene")
	if overlay is Control:
		var control := overlay as Control
		print("overlay size=", control.size, " visible=", control.visible, " children=", control.get_child_count())
		for child in control.get_children():
			if child is Control:
				print("  ", child.name, " rect=", (child as Control).get_global_rect(), " vis=", (child as Control).visible)
		print("root min=", control.get_combined_minimum_size())
		for c in control.get_children():
			if c is Control: print("  rootchild ", c.name, " min=", (c as Control).get_combined_minimum_size())
		var sa = control.get_node_or_null("SafeArea")
		if sa: print("SafeArea min=", sa.get_combined_minimum_size(), " margins L/R=", sa.get_theme_constant("margin_left"), "/", sa.get_theme_constant("margin_right"), " cms=", sa.custom_minimum_size)
		var lay = sa.get_node_or_null("Layout") if sa else null
		if lay:
			for c in lay.get_children():
				print("   child ", c.name, " min=", (c as Control).get_combined_minimum_size())
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("res://docs/preview/_overlay_settings.png")
	print("saved")
	quit(0)




