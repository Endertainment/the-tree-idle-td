extends SceneTree
## Prints minimum sizes of a screen's layout so width overflows are diagnosable.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	root.size = Vector2i(1080, 1920)
	var path: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://scenes/menu/workshop.tscn"
	var scene := (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	await create_timer(0.5).timeout
	var sa := scene.get_node_or_null("SafeArea")
	print("viewport=", root.get_visible_rect().size, " window=", DisplayServer.window_get_size(), " content_scale=", root.content_scale_size, " mode=", root.content_scale_mode, " aspect=", root.content_scale_aspect)
	if scene is Control:
		print("root control size=", (scene as Control).size, " min=", (scene as Control).get_combined_minimum_size())
	if sa is Control:
		print("SafeArea rect=", sa.get_global_rect(), " min=", sa.get_combined_minimum_size())
		for child in sa.get_children():
			if child is Control:
				print("  ", child.name, " min=", (child as Control).get_combined_minimum_size(), " rect=", (child as Control).get_global_rect())
		var layout := sa.get_node_or_null("Layout")
		if layout:
			for child in layout.get_children():
				if child is Control:
					print("    layout/", child.name, " min=", (child as Control).get_combined_minimum_size())
	quit(0)

