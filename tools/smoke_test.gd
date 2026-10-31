extends SceneTree
## M0+M1 smoke test: theme integrity + scene instantiation.
##
## Run: godot --headless --path . --script res://tools/smoke_test.gd
## Exit code 0 = all checks passed.

const REQUIRED_BUTTON_VARIATIONS := ["PrimaryButton", "SecondaryButton", "GoldButton", "IconButton"]
const REQUIRED_PANEL_VARIATIONS := ["PanelGreen", "PanelDark", "ListRow", "Chip", "CurrencyPill"]
const SCENES := [
	["res://scenes/boot/boot.tscn", 2],
	["res://scenes/menu/main_menu.tscn", 2],
	["res://scenes/battle/battle.tscn", 40],
	["res://scenes/battle/battle_hud.tscn", 25],
	["res://scenes/battle/run_summary.tscn", 10],
	["res://scenes/battle/entities/enemy.tscn", 4],
	["res://scenes/battle/entities/tree.tscn", 3],
	["res://scenes/battle/entities/pedestal.tscn", 5],
	["res://scenes/battle/entities/tower.tscn", 3],
	["res://scenes/battle/entities/projectile.tscn", 2],
	["res://ui/components/primary_button.tscn", 1],
	["res://ui/components/panel.tscn", 1],
	["res://ui/components/currency_pill.tscn", 1],
	["res://ui/components/modal.tscn", 2],
]

var failures := 0


func _initialize() -> void:
	print("== The Tree: M0+M1 smoke test ==")
	_check_theme()
	_check_scenes()
	print("== %s ==" % ("OK" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)


func _check_theme() -> void:
	var theme := load("res://ui/theme/main_theme.tres") as Theme
	if theme == null:
		_fail("theme does not load")
		return

	var button_vars := theme.get_type_variation_list("Button")
	for v in REQUIRED_BUTTON_VARIATIONS:
		if not button_vars.has(v):
			_fail("theme missing Button variation: %s" % v)

	var panel_vars := theme.get_type_variation_list("PanelContainer")
	for v in REQUIRED_PANEL_VARIATIONS:
		if not panel_vars.has(v) and not button_vars.has(v):
			_fail("theme missing PanelContainer variation: %s" % v)

	var checked := 0
	for type_name in ["PrimaryButton", "PanelGreen", "PanelDark", "ListRow", "Chip", "CurrencyPill"]:
		for state in ["normal", "panel", "pressed"]:
			var sb := theme.get_stylebox(state, type_name)
			if sb is StyleBoxTexture:
				var tex: Texture2D = (sb as StyleBoxTexture).texture
				checked += 1
				if tex == null:
					_fail("%s/%s has null texture" % [type_name, state])
				elif not FileAccess.file_exists(tex.resource_path):
					_fail("%s/%s texture missing on disk: %s" % [type_name, state, tex.resource_path])
	if checked == 0:
		_fail("no StyleBoxTexture found in the theme")
	else:
		_pass("%d stylebox textures resolved" % checked)


func _check_scenes() -> void:
	for entry in SCENES:
		var path: String = entry[0]
		var min_nodes: int = entry[1]
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("scene does not load: %s" % path)
			continue
		var inst := packed.instantiate()
		if inst == null:
			_fail("scene does not instantiate: %s" % path)
			continue
		root.add_child(inst)
		var count := _count_nodes(inst)
		inst.queue_free()
		if count < min_nodes:
			_fail("scene looks empty (%d nodes, expected >= %d): %s" % [count, min_nodes, path])
		else:
			_pass("%s (%d nodes)" % [path.get_file(), count])


func _count_nodes(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count_nodes(child)
	return n


func _pass(msg: String) -> void:
	print("[ PASS ] ", msg)


func _fail(msg: String) -> void:
	failures += 1
	print("[ FAIL ] ", msg)
