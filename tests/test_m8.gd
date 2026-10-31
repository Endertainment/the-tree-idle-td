## M8 tests — tutorial hints, the release wave curve and the release preset.
extends RefCounted


func _autoload(name: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(name)


func test_tutorial_one_shot_and_persistence() -> bool:
	var game_state := _autoload("GameState")
	var tutorial := _autoload("TutorialService")
	if game_state == null or tutorial == null:
		print("  GameState/TutorialService autoload is missing")
		return false
	var original: Dictionary = game_state.tutorial.duplicate(true)
	game_state.tutorial = {"shown": {}}
	# The test runner executes before App's deferred boot; WorkshopService owns a
	# section of build_save_document(), so initialise it exactly once.
	var workshop := _autoload("WorkshopService")
	if workshop != null and workshop.call(&"get_model") == null:
		workshop.call(&"init_service")
	if not tutorial.should_show(&"first_build"):
		print("  a fresh profile should show the build hint")
		game_state.tutorial = original
		return false
	if not tutorial.take(&"first_build", false):
		print("  take() should return true for an unseen hint")
		game_state.tutorial = original
		return false
	if tutorial.should_show(&"first_build"):
		print("  a shown hint must not repeat")
		game_state.tutorial = original
		return false
	if tutorial.text(&"first_build").is_empty():
		print("  hint text must resolve through LocaleService")
		game_state.tutorial = original
		return false
	var document: Dictionary = game_state.build_save_document()
	if not document.has("tutorial"):
		print("  the save document must carry the tutorial section")
		game_state.tutorial = original
		return false
	game_state.tutorial = {"shown": {}}
	game_state.from_dict(document)
	if tutorial.should_show(&"first_build"):
		print("  the tutorial flag did not survive a save round-trip")
		game_state.tutorial = original
		return false
	game_state.tutorial = original
	tutorial.reset()
	print("  3 hints, one-shot flags persist in the save document")
	return true


func test_tutorial_locale_catalogues() -> bool:
	var text := FileAccess.get_file_as_string("res://localization/strings.csv")
	if text.is_empty():
		print("  could not read localization/strings.csv")
		return false
	var found := 0
	for line in text.split("\n"):
		if not line.begins_with("tutorial."):
			continue
		var cells := line.split(",")
		if cells.size() < 3 or cells[1].strip_edges().is_empty() or cells[2].strip_edges().is_empty():
			print("  tutorial key is missing en/uk copy: ", line)
			return false
		found += 1
	if found < 4:
		print("  expected 4 tutorial keys, found ", found)
		return false
	print("  %d tutorial keys with en + uk copy" % found)
	return true


func test_tutorial_hint_control() -> bool:
	# Loaded at call time: a preload would compile TutorialHint before the
	# autoload globals exist in the headless test runner.
	var script: GDScript = load("res://scripts/ui/tutorial_hint.gd")
	var hint: Control = script.new()
	Engine.get_main_loop().root.add_child(hint)
	hint.show_hint("test tip", 0.0)
	if not hint.is_showing() or hint.get_hint_text() != "test tip":
		print("  TutorialHint did not show its text")
		hint.free()
		return false
	hint.dismiss()
	if hint.is_showing():
		print("  dismiss() must hide the hint")
		hint.free()
		return false
	hint.free()
	print("  dismissible non-modal hint control builds and hides")
	return true


func test_release_wave_curve() -> bool:
	var table := load("res://data/waves/wave_table_m2.tres") as WaveTable
	if table == null or table.waves.size() != 60:
		print("  the release table must have 60 waves")
		return false
	var wave_9 := table.get_wave(9)
	var wave_10 := table.get_wave(10)
	if wave_10.hp_multiplier / wave_9.hp_multiplier < 1.7:
		print("  wave 10 must be the difficulty step (ratio %.2f)" % [
			wave_10.hp_multiplier / wave_9.hp_multiplier
		])
		return false
	var wave_40 := table.get_wave(40)
	var wave_60 := table.get_wave(60)
	if wave_60.hp_multiplier / wave_40.hp_multiplier < 10.0:
		print("  late waves must accelerate (x%.1f by wave 60)" % [
			wave_60.hp_multiplier / wave_40.hp_multiplier
		])
		return false
	if table.get_wave(60).is_boss == false or table.get_wave(50).is_boss == false:
		print("  boss cadence must continue through wave 60")
		return false
	print("  60 waves, wave-10 step and late acceleration present")
	return true
