extends SceneTree
## Layout audit: prints the real global rectangles of the header, first content
## block and navigation bar for every menu screen, so "different margins" can be
## compared as numbers instead of screenshots.

const SCREENS := [
	"res://scenes/menu/main_menu.tscn",
	"res://scenes/menu/workshop.tscn",
	"res://scenes/menu/cards.tscn",
	"res://scenes/menu/missions.tscn",
	"res://scenes/menu/shop.tscn",
	"res://scenes/menu/profile.tscn",
	"res://scenes/menu/leaderboard.tscn",
	"res://scenes/menu/magica.tscn",
	"res://scenes/menu/settings.tscn",
]

var _index := 0
var _current: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	root.size = Vector2i(1080, 1920)
	await create_timer(0.3).timeout
	await _next()


func _next() -> void:
	if _index >= SCREENS.size():
		quit(0)
		return
	var path: String = SCREENS[_index]
	_index += 1
	var scene := (load(path) as PackedScene).instantiate() as Control
	_current = scene
	root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.35).timeout
	_report(path, scene)
	scene.queue_free()
	await create_timer(0.15).timeout
	_next()


func _report(path: String, scene: Control) -> void:
	var name_part := path.get_file()
	var safe := scene.get_node_or_null("SafeArea") as MarginContainer
	if safe == null:
		print("%-22s NO SafeArea" % name_part)
		return
	var margins := "%d/%d/%d/%d" % [
		safe.get_theme_constant("margin_left"),
		safe.get_theme_constant("margin_top"),
		safe.get_theme_constant("margin_right"),
		safe.get_theme_constant("margin_bottom"),
	]
	var layout := safe.get_node_or_null("Layout") as VBoxContainer
	var separation := -1
	if layout != null:
		separation = layout.get_theme_constant("separation")
	var header_rect := Rect2()
	var header_name := "-"
	var first_rect := Rect2()
	var first_name := "-"
	var nav_rect := Rect2()
	if layout != null:
		var children := layout.get_children()
		for child in children:
			var control := child as Control
			if control == null or not control.visible:
				continue
			if header_name == "-":
				header_name = String(control.name)
				header_rect = control.get_global_rect()
				continue
			if String(control.name).contains("Nav"):
				nav_rect = control.get_global_rect()
			elif first_name == "-":
				first_name = String(control.name)
				first_rect = control.get_global_rect()
	print("%-16s safe=%-11s sep=%-3d header=%-10s x=%.0f y=%.0f w=%.0f h=%.0f | first=%-10s y=%.0f | nav y=%.0f h=%.0f" % [
		name_part, margins, separation,
		header_name, header_rect.position.x, header_rect.position.y, header_rect.size.x, header_rect.size.y,
		first_name, first_rect.position.y,
		nav_rect.position.y, nav_rect.size.y,
	])
