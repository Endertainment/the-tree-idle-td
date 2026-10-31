## Performance probe — 120 enemies + 8 towers + 4 units on the real battle scene.
##
## Run windowed (needs rendering monitors):
##   godot --path . --script res://tools/perf_probe.gd
## Prints measured FPS (vsync off), draw calls, active entity counts and exits
## non-zero below the M2 floor of 55 FPS. Numbers are reported, never guessed.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const ENEMY_COUNT := 120
const WARMUP_SECONDS := 1.0
const MEASURE_SECONDS := 5.0
const FPS_FLOOR := 55.0

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== M2 perf probe: %d enemies, 8 towers, 4 units ==" % ENEMY_COUNT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.set("player", {"level": 12, "xp": 0, "best_wave": 0})
		game_state.set("wallet", {"coins": 0, "gems": 150, "stones": 0})
		var wallet_service := root.get_node_or_null("WalletService")
		var workshop_service := root.get_node_or_null("WorkshopService")
		var unlock_service := root.get_node_or_null("UnlockService")
		if wallet_service != null:
			wallet_service.call(&"reset")
		if workshop_service != null:
			workshop_service.call(&"reset")
		if unlock_service != null:
			unlock_service.call(&"refresh")

	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		_fail("cannot load battle scene")
		_finish()
		return
	var battle: Node = packed.instantiate()
	root.add_child(battle)
	await process_frame

	battle.call(&"add_cash", 6000)
	var tower_ids: Array[StringName] = [&"tower_archer", &"cannon", &"frost_spire", &"totem"]
	for index in 8:
		var pedestal: Variant = battle.call(&"get_pedestal", index)
		battle.call(&"build_tower", pedestal, tower_ids[index % tower_ids.size()])

	var slots: Array = battle.call(&"get_unit_slots")
	battle.call(&"debug_unlock_unit_slots")
	var unit_ids: Array[StringName] = [&"unit_archer", &"unit_mage", &"unit_druid", &"unit_archer"]
	for index in mini(slots.size(), 4):
		battle.call(&"place_unit", slots[index], unit_ids[index])

	for _index in ENEMY_COUNT:
		battle.call(&"debug_spawn_enemy", &"grunt", &"north" if _index % 2 == 0 else &"south")
	var clock: Variant = battle.call(&"get_clock")
	clock.call(&"set_speed", 1.0)

	# Warm up: let the first frames, auras and projectiles settle.
	var warmup := 0.0
	while warmup < WARMUP_SECONDS:
		await process_frame
		warmup += 1.0 / 60.0

	var frames := 0
	var elapsed := 0.0
	var draw_calls_peak := 0
	var enemies_peak := 0
	var start_usec := Time.get_ticks_usec()
	while elapsed < MEASURE_SECONDS:
		await process_frame
		frames += 1
		elapsed = float(Time.get_ticks_usec() - start_usec) / 1_000_000.0
		draw_calls_peak = maxi(
			draw_calls_peak,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		)
		enemies_peak = maxi(enemies_peak, int(battle.call(&"get_active_enemy_count")))

	var fps := float(frames) / maxf(elapsed, 0.001)
	print("  measured FPS      : %.1f  (%d frames / %.2f s, vsync off)" % [fps, frames, elapsed])
	print("  draw calls (peak) : %d" % draw_calls_peak)
	print("  enemies (peak)    : %d" % enemies_peak)
	print("  towers            : %d" % int(battle.call(&"get_tower_count")))
	print("  units             : %d" % int(battle.call(&"get_unit_count")))
	print("  process FPS       : %.1f" % Engine.get_frames_per_second())
	_check(fps >= FPS_FLOOR, "FPS %.1f >= %.0f" % [fps, FPS_FLOOR])
	_check(enemies_peak >= ENEMY_COUNT, "enemy load reached %d" % enemies_peak)
	_check(int(battle.call(&"get_tower_count")) == 8, "8 towers alive")
	_check(int(battle.call(&"get_unit_count")) == 4, "4 units alive")

	battle.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[ PASS ] ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	print("[ FAIL ] ", message)


func _finish() -> void:
	print("== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
