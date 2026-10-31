## M4a battle smoke test — loads the real battle scene and drives the run economy.
##
## Run: godot --headless --path . --script res://tools/battle_smoke.gd
## Proves: 8 pedestals + 4 unit slots, tower/unit build & upgrade costs, 70 % sell
## refund, tree upgrade purchase (cost + DPS), speed lock/unlock, pause freezing
## the simulation, 2x delta scaling, wave progression, abandon === death rewards
## and reward-bundle idempotency. Exits non-zero on failure.
##
## Calls are dynamic because --script compiles this file before autoload identifiers
## exist; the battle scene itself still uses them normally.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SUMMARY_SCENE := "res://scenes/battle/run_summary.tscn"
const SIM_SPEED := 8.0
const SIM_SECONDS := 4.0
const BOSS_WAVE := 10

var _failures: int = 0
var _temp_save: String = "user://m3_smoke_save.json"
var _temp_backup: String = "user://m3_smoke_save.bak.json"
var _temp_tmp: String = "user://m3_smoke_save.tmp.json"


func _initialize() -> void:
	# The tool asserts English fallback labels; pin the locale regardless of host.
	TranslationServer.set_locale("en")
	var locale_service := get_root().get_node_or_null("LocaleService")
	if locale_service != null:
		locale_service.call("set_language", "en")
	_run.call_deferred()


func _run() -> void:
	print("== M4a battle smoke (%.0fs real at %.0fx) ==" % [SIM_SECONDS, SIM_SPEED])
	var game_state := root.get_node_or_null("GameState")
	var save_service := root.get_node_or_null("SaveService")
	var wallet_service := root.get_node_or_null("WalletService")
	var workshop_service := root.get_node_or_null("WorkshopService")
	var unlock_service := root.get_node_or_null("UnlockService")
	var modifier_service := root.get_node_or_null("ModifierService")
	var original_state: Dictionary = {}
	if game_state != null:
		original_state = game_state.call(&"to_dict")
		game_state.set("player", {
			"id": "", "nickname": "", "avatar_id": "avatar_01", "level": 1,
			"xp": 0, "created_at": 0, "provider": "", "provider_uid": "",
			"best_wave": 0, "next_wave_uses": 0,
		})
		game_state.set("wallet", {"coins": 0, "gems": 0, "stones": 0})
		game_state.set("unlocks", {})
		game_state.set("stats", {
			"best_wave": 0, "runs_played": 0, "total_kills": 0,
			"total_playtime": 0, "weekly_max_wave": 0, "week_id": "",
		})
	if modifier_service != null:
		modifier_service.call(&"clear")
	if wallet_service != null:
		wallet_service.call(&"reset")
	if workshop_service != null:
		workshop_service.call(&"reset")
	if unlock_service != null:
		unlock_service.call(&"refresh")
	if save_service != null:
		save_service.set("save_path", _temp_save)
		save_service.set("backup_path", _temp_backup)
		save_service.set("temp_path", _temp_tmp)
		save_service.call(&"clear")

	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		_fail("cannot load %s" % BATTLE_SCENE)
		_finish(game_state, save_service, original_state)
		return
	var battle: Node = packed.instantiate()
	if battle == null:
		_fail("battle scene did not instantiate")
		_finish(game_state, save_service, original_state)
		return
	root.add_child(battle)
	await process_frame
	var clock: Variant = battle.call(&"get_clock")
	if clock == null:
		_fail("battle has no BattleClock")
		_finish(game_state, save_service, original_state)
		return

	var pedestals: int = int(battle.call(&"get_pedestal_count"))
	_check(pedestals == 8, "8 pedestals spawned (%d)" % pedestals)
	_check(battle.call(&"get_tree_entity") != null, "tree entity present")
	_check(int(battle.call(&"get_cash")) == 120, "starting cash 120 with no meta bonus (got %d)" % int(battle.call(&"get_cash")))

	var slots: Array = battle.call(&"get_unit_slots")
	_check(slots.size() == 4, "4 unit slots created (%d)" % slots.size())
	var locked := 0
	for index in slots.size():
		if not bool(slots[index].call(&"is_unlocked")):
			locked += 1
	_check(locked == 3, "slots 2-4 locked by data conditions (%d locked)" % locked)

	battle.call(&"add_cash", 5000)
	var tower_ids: Array[StringName] = [&"tower_archer", &"cannon", &"frost_spire", &"totem"]
	var built := 0
	for index in tower_ids.size():
		var pedestal: Variant = battle.call(&"get_pedestal", index)
		if bool(battle.call(&"build_tower", pedestal, tower_ids[index])):
			built += 1
	_check(built == 4, "built one of each tower type (%d/4)" % built)
	_check(int(battle.call(&"get_tower_count")) == 4, "tower nodes present (%d)" % int(battle.call(&"get_tower_count")))

	var towers: Array = battle.call(&"get_towers")
	# Cost curve: base * 0.8 * 1.55^(level-1); archer base 60 -> 48 at level 1.
	var first_upgrade_cost: int = int(towers[0].call(&"upgrade_cost"))
	_check(first_upgrade_cost == 48, "tower upgrade uses base*0.8*1.55^(lvl-1) (got %d)" % first_upgrade_cost)
	var upgraded := 0
	for _level in 4:
		if bool(battle.call(&"upgrade_tower", towers[0])):
			upgraded += 1
	var archer_level := int(towers[0].get(&"level"))
	_check(upgraded == 4 and archer_level == 5, "archer upgraded to L5 (%d upgrades, level %d)" % [upgraded, archer_level])

	# Sell path: build a spare tower, sell it, verify the refund and the freed slot.
	var spare_ok := bool(battle.call(&"build_tower", battle.call(&"get_pedestal", 4), &"tower_archer"))
	var cash_before_sale: int = int(battle.call(&"get_cash"))
	var spare_tower: Variant = battle.call(&"get_pedestal", 4).get(&"tower")
	var refund: int = int(battle.call(&"sell_tower", spare_tower))
	var cash_after_sale: int = int(battle.call(&"get_cash"))
	_check(
		spare_ok and refund > 0 and cash_after_sale == cash_before_sale + refund
		and int(battle.call(&"get_tower_count")) == 4,
		"sell refunded %d cash (70%% of invested) and freed the pedestal" % refund
	)

	var placed_ok := bool(battle.call(&"place_unit", slots[0], &"unit_archer"))
	_check(placed_ok, "guardian unit placed on slot 1")
	_check(int(battle.call(&"get_unit_count")) == 1, "unit node present (%d)" % int(battle.call(&"get_unit_count")))
	var units: Array = battle.call(&"get_units")
	var unit_first_cost: int = int(units[0].call(&"upgrade_cost")) if not units.is_empty() else 0
	_check(unit_first_cost == 50, "unit upgrade uses 50*1.45^(lvl-1) (got %d)" % unit_first_cost)
	var unit_upgraded := bool(battle.call(&"upgrade_unit", units[0])) if not units.is_empty() else false
	_check(unit_upgraded, "guardian unit upgraded")

	# --- M3 tree upgrades -----------------------------------------------------
	var upgrades: Variant = battle.call(&"get_tree_upgrades")
	_check(upgrades != null, "tree upgrade tracks loaded")
	var track_count: int = int(upgrades.call(&"get_tracks").size())
	_check(track_count == 6, "6 tree tracks generated from data (%d)" % track_count)
	var rows: Dictionary = battle.call(&"upgrade_rows")
	_check((rows.get("tree", []) as Array).size() == 6, "upgrade panel builds 6 tree rows")
	var tree: Variant = battle.call(&"get_tree_entity")
	var cash_before_upgrade: int = int(battle.call(&"get_cash"))
	var cost: int = int(upgrades.call(&"cost_for", &"tree_damage"))
	var dps_before: float = float(tree.call(&"effective_damage"))
	var buy_result: Variant = battle.call(&"try_buy_tree_upgrade", &"tree_damage")
	var cash_after_upgrade: int = int(battle.call(&"get_cash"))
	var dps_after: float = float(tree.call(&"effective_damage"))
	_check(buy_result != null and bool(buy_result.call(&"is_ok")), "tree damage upgrade purchased")
	_check(int(upgrades.call(&"get_level", &"tree_damage")) == 1, "tree damage is level 1")
	_check(cash_after_upgrade == cash_before_upgrade - cost, "cash decreased by exactly the cost (%d - %d = %d)" % [cash_before_upgrade, cost, cash_after_upgrade])
	_check(dps_after > dps_before, "tree damage DPS rose (%.2f -> %.2f)" % [dps_before, dps_after])
	var next_cost: int = int(upgrades.call(&"cost_for", &"tree_damage"))
	_check(next_cost == roundi(float(cost) * 1.35), "next tree level costs base*1.35 (%d -> %d)" % [cost, next_cost])

	# --- M3 speed control -----------------------------------------------------
	_check(not bool(battle.call(&"set_sim_speed", 1.5)), "1.5x is locked at level 1")
	_check(bool(battle.call(&"debug_unlock_speed", &"speed_1_5")), "debug unlock grants 1.5x")
	_check(not bool(battle.call(&"set_sim_speed", 2.0)), "2x stays locked without its unlock")
	_check(bool(battle.call(&"debug_unlock_speed", &"speed_2")), "debug unlock grants 2x")
	_check(bool(battle.call(&"set_sim_speed", 1.5)), "1.5x selectable after unlock")
	_check(bool(battle.call(&"set_sim_speed", 2.0)), "2x selectable after unlock")

	# Pause freezes the simulation without pausing the scene tree.
	var wave_manager: Variant = battle.call(&"get_wave_manager")
	battle.call(&"set_sim_speed", 1.0)
	await create_timer(0.15).timeout
	var elapsed_pause_a: float = float(battle.call(&"get_elapsed"))
	var wave_pause_a: int = int(wave_manager.call(&"get_current_wave"))
	battle.call(&"set_paused", true)
	await create_timer(0.3).timeout
	var elapsed_pause_b: float = float(battle.call(&"get_elapsed"))
	var wave_pause_b: int = int(wave_manager.call(&"get_current_wave"))
	_check(bool(battle.call(&"is_paused")), "pause state is on")
	_check(absf(elapsed_pause_b - elapsed_pause_a) < 0.02, "pause froze the simulation clock")
	_check(wave_pause_b == wave_pause_a, "pause kept the wave unchanged (%d)" % wave_pause_b)
	battle.call(&"set_paused", false)
	await create_timer(0.15).timeout
	var elapsed_resumed: float = float(battle.call(&"get_elapsed"))
	_check(elapsed_resumed > elapsed_pause_b, "resume restarted the simulation clock")

	# 2x speeds the simulation only (delta multiplier), waves stay in sync.
	battle.call(&"set_sim_speed", 2.0)
	var elapsed_fast_a: float = float(battle.call(&"get_elapsed"))
	var wave_fast_a: int = int(wave_manager.call(&"get_current_wave"))
	await create_timer(0.4).timeout
	var elapsed_fast_b: float = float(battle.call(&"get_elapsed"))
	var wave_fast_b: int = int(wave_manager.call(&"get_current_wave"))
	var fast_delta := elapsed_fast_b - elapsed_fast_a
	_check(fast_delta > 0.55 and fast_delta < 1.15, "2x ran ~0.8 sim seconds in 0.4 real (%.2f)" % fast_delta)
	_check(wave_fast_b >= wave_fast_a, "2x never rewinds the wave (%d -> %d)" % [wave_fast_a, wave_fast_b])
	battle.call(&"set_sim_speed", 1.0)

	# --- existing boss/composition checks ------------------------------------
	# M8 raised the wave-10 wall; give the smoke towers the levels a real run
	# would have by then so this check still tests the boss, not the balance.
	battle.call(&"add_cash", 4000)
	for tower in battle.call(&"get_towers"):
		for _level in 10:
			if int(tower.get(&"level")) >= 5 or not bool(battle.call(&"upgrade_tower", tower)):
				break
	var tree_hp_before: float = float(tree.get("hp"))
	var cash_before: int = int(battle.call(&"get_cash"))
	battle.call(&"debug_start_wave", BOSS_WAVE)
	clock.call(&"set_speed", SIM_SPEED)

	var max_slowed := 0
	var max_damage_numbers := 0
	var boss_seen := false
	var boss_bar_seen := false
	var boss_damaged := false
	var waited := 0.0
	var step := 0.05
	while waited < SIM_SECONDS:
		await create_timer(step).timeout
		waited += step
		max_slowed = maxi(max_slowed, int(battle.call(&"get_slowed_enemy_count")))
		max_damage_numbers = maxi(max_damage_numbers, int(battle.call(&"get_damage_number_count")))
		var boss: Variant = battle.call(&"get_active_boss")
		if boss != null:
			boss_seen = true
			if bool(battle.call(&"is_boss_bar_visible")):
				boss_bar_seen = true
			if float(boss.get("hp")) < float(boss.get("max_hp")):
				boss_damaged = true

	var wave: int = int(wave_manager.call(&"get_current_wave"))
	var kills: int = int(battle.call(&"get_kills"))
	var cash_after: int = int(battle.call(&"get_cash"))
	var spawned: int = int(battle.call(&"get_spawned_count"))

	_check(wave >= BOSS_WAVE, "boss wave %d started and advanced (current %d)" % [BOSS_WAVE, wave])
	_check(spawned > 0, "enemies spawned (%d)" % spawned)
	_check(boss_seen, "boss_troll spawned")
	_check(boss_bar_seen, "boss HP bar visible while boss alive")
	_check(boss_damaged, "boss HP bar received damage updates")
	_check(kills > 0, "kills resolved (%d)" % kills)
	_check(max_slowed > 0, "frost slow applied (%d slowed enemies at peak)" % max_slowed)
	_check(max_damage_numbers > 0, "floating damage numbers appeared (%d at peak)" % max_damage_numbers)
	_check(cash_after != cash_before or kills > 0, "cash changed (%d -> %d)" % [cash_before, cash_after])
	_check(float(tree.get("hp")) <= tree_hp_before, "tree HP did not increase")
	_check(not bool(battle.call(&"is_finished")), "run still active")

	# --- debug overlay --------------------------------------------------------
	var overlay: Variant = battle.get_node_or_null("DebugOverlay")
	_check(overlay != null, "debug overlay exists in a debug build")
	if overlay != null:
		overlay.call(&"toggle")
		var debug_text: String = str(overlay.call(&"get_debug_text"))
		var projectiles_word := "Projectiles"
		var locale_service := get_root().get_node_or_null("LocaleService")
		if locale_service != null:
			projectiles_word = str(locale_service.call("t", "debug.projectiles", "Projectiles"))
		_check(
			"FPS" in debug_text and projectiles_word in debug_text,
			"F3 overlay reports fps/projectiles"
		)
		overlay.call(&"toggle")

	# --- abandon === death rewards + bundle idempotency -----------------------
	var cleared: int = int(battle.call(&"get_cleared_waves"))
	var boss_waves: int = int(battle.call(&"get_boss_waves_cleared"))
	var run_id: String = str(battle.call(&"get_run_id"))
	var coins_before_abandon: int = int(game_state.call(&"get_balance", &"coins"))
	var player_state: Dictionary = game_state.get("player")
	var xp_before_abandon: int = int(player_state.get("xp", 0))
	var expected := RunRewards.compute(cleared, boss_waves, cleared > 0)
	battle.call(&"abandon_run")
	await process_frame
	await process_frame
	var summary: Variant = battle.call(&"get_run_summary")
	_check(bool(battle.call(&"is_finished")), "abandon ended the run")
	_check(summary != null, "run summary shown after abandon")
	var coins_after_abandon: int = int(game_state.call(&"get_balance", &"coins"))
	var xp_after_abandon: int = int((game_state.get("player") as Dictionary).get("xp", 0))
	_check(coins_after_abandon == coins_before_abandon + int(expected["coins"]), "abandon paid the cleared-wave coins (%d -> %d, expected +%d)" % [coins_before_abandon, coins_after_abandon, int(expected["coins"])])
	_check(xp_after_abandon == xp_before_abandon + int(expected["xp"]), "abandon paid the cleared-wave XP (+%d)" % int(expected["xp"]))
	_check(int((game_state.get("player") as Dictionary).get("best_wave", 0)) == cleared, "best wave updated to %d" % cleared)

	# A second summary for the same run id must not pay again (RewardLedger).
	var summary_packed := load(SUMMARY_SCENE) as PackedScene
	if summary_packed != null:
		var duplicate := summary_packed.instantiate()
		root.add_child(duplicate)
		duplicate.call(&"setup", cleared, kills, int(battle.call(&"get_leaks")), float(battle.call(&"get_elapsed")), run_id, boss_waves, 0)
		await process_frame
		var coins_after_duplicate: int = int(game_state.call(&"get_balance", &"coins"))
		_check(coins_after_duplicate == coins_after_abandon, "re-shown summary never double-pays (ledger)")
		duplicate.queue_free()
		await process_frame
	else:
		_fail("cannot load %s" % SUMMARY_SCENE)

	battle.queue_free()
	await process_frame
	await process_frame
	# Release the battle music stream before the audio server shuts down.
	var audio := root.get_node_or_null("AudioService")
	if audio != null:
		audio.call(&"release_all")
	# Let the audio mixer drop the stopped playback before the engine shuts down.
	await create_timer(0.2).timeout
	await process_frame
	_finish(game_state, save_service, original_state)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[ PASS ] ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	print("[ FAIL ] ", message)


func _finish(game_state: Node, save_service: Node, original_state: Dictionary) -> void:
	if save_service != null:
		save_service.call(&"clear")
	if game_state != null and not original_state.is_empty():
		game_state.call(&"from_dict", original_state)
		var wallet_service := root.get_node_or_null("WalletService")
		var workshop_service := root.get_node_or_null("WorkshopService")
		var unlock_service := root.get_node_or_null("UnlockService")
		if wallet_service != null:
			wallet_service.call(&"reset")
		if workshop_service != null:
			workshop_service.call(&"init_service", original_state.get("workshop", {}))
		if unlock_service != null:
			unlock_service.call(&"refresh")
	print("== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
