extends SceneTree
## Temporary capture helper: renders a scene to a PNG so a visual review is possible.
## Run: godot --path . --script res://tools/capture_scene.gd -- <scene_path> <out_path> [sheet]
## Scenes that expose `stage_preview()` (the battle) are staged before capture so
## the screenshot shows combat with towers, a unit and a boss instead of prep.
## `sheet` (tower|build|unit) additionally opens one bottom sheet.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://scenes/menu/main_menu.tscn"
	var out_path: String = args[1] if args.size() > 1 else "res://docs/_shot_menu.png"
	var sheet: String = args[2] if args.size() > 2 else ""
	var locale: String = args[3] if args.size() > 3 else ""
	var pseudo: bool = args.size() > 4 and args[4] == "pseudo"
	var text_scale: float = float(args[5]) if args.size() > 5 else 0.0
	var settings := get_root().get_node_or_null("SettingsService")
	# Finish the boot sequence before applying capture-only settings: App defers
	# init_services(), and its settings/locale load would otherwise overwrite the
	# requested language and refresh the staged preview after stage_preview().
	var app := get_root().get_node_or_null("App")
	if app != null:
		app.call("init_services")
	if pseudo and settings != null:
		settings.set("pseudo_locale", true)
	if text_scale > 0.0 and settings != null:
		settings.set("text_scale", text_scale)
		settings.call("apply_text_scale", get_root())
	if not locale.is_empty():
		settings.set("language", locale)
		TranslationServer.set_locale(locale)
		var locale_service := get_root().get_node_or_null("LocaleService")
		if locale_service != null:
			locale_service.call("set_language", locale)

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("cannot load %s" % scene_path)
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	root.size = Vector2i(1080, 1920)
	var instance := packed.instantiate()
	root.add_child(instance)
	await create_timer(0.2).timeout
	if instance.has_method("stage_sheet_preview") and not sheet.is_empty():
		instance.call("stage_sheet_preview", sheet)
	elif instance.has_method("stage_preview"):
		instance.call("stage_preview")
	if pseudo:
		_apply_pseudo(instance)
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


## Pseudo-locale layout stress: engine-translated static labels are doubled here,
## while strings already produced by LocaleService.t() arrive with the marker.
func _apply_pseudo(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit:
		var holder := node as Control
		var text: String = str(holder.get("text"))
		if not text.is_empty() and not text.ends_with("\u2026"):
			if text.contains(".") and not text.contains(" "):
				var locale_service := get_root().get_node_or_null("LocaleService")
				if locale_service != null:
					holder.set("text", locale_service.call("t", text))
			else:
				holder.set("text", LocaleFormat.pseudo(text))
	for child: Node in node.get_children():
		_apply_pseudo(child)
