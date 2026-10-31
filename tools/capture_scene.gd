extends SceneTree
## Temporary capture helper: renders a scene to a PNG so a headless-ish review is possible.
## Run: godot --path . --script res://tools/capture_scene.gd -- <scene_path> <out_path>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/menu/main_menu.tscn"
	var out_path: String = args[1] if args.size() > 1 else "res://docs/_shot_menu.png"

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("cannot load %s" % scene_path)
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	root.size = Vector2i(1080, 1920)
	root.add_child(packed.instantiate())
	await create_timer(1.2).timeout
	await process_frame

	var img := root.get_texture().get_image()
	if img == null:
		push_error("no viewport image")
		quit(1)
		return
	var err := img.save_png(out_path)
	print("saved %s (%dx%d) err=%d" % [out_path, img.get_width(), img.get_height(), err])
	quit(0)
