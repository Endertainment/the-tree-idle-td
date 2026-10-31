## Tutorial probe — verifies the three one-shot hints in a real battle/summary.
## Run: godot --headless --path . --script res://tools/tutorial_probe.gd
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var app := root.get_node_or_null("App")
	var guard := 0
	while app != null and not bool(app.call(&"is_initialized")) and guard < 120:
		await process_frame
		guard += 1
	var tutorial := root.get_node_or_null("TutorialService")
	var game_state := root.get_node_or_null("GameState")
	if tutorial == null or game_state == null:
		print("[tutorial] FAIL: services missing")
		quit(1)
		return
	tutorial.call(&"reset")
	var save_service := root.get_node_or_null("SaveService")
	if save_service != null:
		save_service.set("save_path", "user://m8_tutorial_probe.json")
		save_service.set("backup_path", "user://m8_tutorial_probe.bak.json")
		save_service.set("temp_path", "user://m8_tutorial_probe.tmp.json")
		save_service.call(&"clear")

	var battle: Node = (load(BATTLE_SCENE) as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame
	var clock: Variant = battle.call(&"get_clock")
	clock.call(&"set_speed", 8.0)
	var hud: Node = battle.get_node_or_null("BattleHUD")
	var found: Node = null
	for _tick in 40:
		await create_timer(0.1).timeout
		for child in hud.get_children():
			if child.get_script() != null and String(child.get_script().resource_path).ends_with("tutorial_hint.gd"):
				found = child
				break
		if found != null and bool(found.call(&"is_showing")):
			break
	if found == null:
		print("[tutorial] FAIL: hint node was never created")
		battle.queue_free()
		quit(1)
		return
	print("[tutorial] hint visible=%s text='%s'" % [
		str(bool(found.call(&"is_showing"))), str(found.call(&"get_hint_text")),
	])
	print("[tutorial] shown ids after wave 1: %s" % str(tutorial.call(&"shown_ids")))
	var ok := bool(found.call(&"is_showing")) and not str(found.call(&"get_hint_text")).is_empty()
	found.call(&"dismiss")
	battle.queue_free()
	await process_frame
	await process_frame
	var audio := root.get_node_or_null("AudioService")
	if audio != null:
		audio.call(&"release_all")
	await create_timer(0.2).timeout
	await process_frame
	if save_service != null:
		save_service.call(&"clear")
	print("[tutorial] %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
