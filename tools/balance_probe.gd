## Balance probe — automated run harness for the M3/M3.1 balance gate.
##
## Usage:
##   godot --headless --path . --script res://tools/balance_probe.gd -- [policy] [seed]
##   policy: fill | four | two | tree (opening heuristic)
##   seed:   integer run seed (RunState.seed), default 1
##
## It plays one run at 8x with greedy buying and prep skips, then prints the
## cleared wave, peak concurrent enemies and the damage share by source (the
## coverage proxy: how much of the damage actually comes from towers vs the Tree).
## Save/GameState/RunState are isolated. Exit 0 when cleared >= 7 (floor gate).
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SIM_SPEED := 8.0
const REAL_TIMEOUT := 300.0
const BUY_INTERVAL := 0.4
const SAMPLE_INTERVAL := 0.02

const TOWER_ORDER: Array[StringName] = [
	&"tower_archer", &"tower_archer", &"tower_archer", &"tower_archer",
	&"tower_archer", &"tower_archer", &"tower_archer", &"tower_archer",
]
const TRACK_ORDER: Array[StringName] = [
	&"tree_damage", &"tree_attack_speed", &"tree_crit_chance",
	&"tree_crit_damage", &"tree_range", &"tree_regen",
]

var _temp_save := "user://m3_balance_save.json"
var _tick := 0
var _policy := "two"
var _seed := 1
var _damage_by_source: Dictionary = {}
var _event_bus: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_policy = str(args[0])
	if args.size() > 1:
		_seed = int(args[1])
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	var save_service := root.get_node_or_null("SaveService")
	var run_state := root.get_node_or_null("RunState")
	_event_bus = root.get_node_or_null("EventBus")
	var original: Dictionary = game_state.call(&"to_dict") if game_state != null else {}
	if save_service != null:
		save_service.set("save_path", _temp_save)
		save_service.set("backup_path", _temp_save + ".bak")
		save_service.set("temp_path", _temp_save + ".tmp")
		save_service.call(&"clear")

	_reset_profile(game_state, run_state)
	var battle: Node = (load(BATTLE_SCENE) as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame

	var clock: Variant = battle.call(&"get_clock")
	clock.call(&"set_speed", SIM_SPEED)
	var wave_manager: Variant = battle.call(&"get_wave_manager")
	var tree: Variant = battle.call(&"get_tree_entity")
	_damage_by_source.clear()
	var damage_handler := func(source_id: StringName, target_id: int, amount: float, _is_crit: bool, _is_kill: bool) -> void:
		if target_id <= 0:
			return
		var key := String(source_id)
		_damage_by_source[key] = float(_damage_by_source.get(key, 0.0)) + amount
	if _event_bus != null:
		_event_bus.connect(&"damage_dealt", damage_handler)

	var real_elapsed := 0.0
	var next_buy := 0.0
	var max_wave := 0
	var last_wave := 0
	var peak_total := 0
	var wave_peaks: Dictionary = {}
	var wave_log: Array[String] = []
	while not bool(battle.call(&"is_finished")) and real_elapsed < REAL_TIMEOUT:
		await create_timer(SAMPLE_INTERVAL).timeout
		real_elapsed += SAMPLE_INTERVAL
		max_wave = maxi(max_wave, int(wave_manager.call(&"get_current_wave")))
		var active := int(battle.call(&"get_active_enemy_count"))
		peak_total = maxi(peak_total, active)
		wave_peaks[max_wave] = maxi(int(wave_peaks.get(max_wave, 0)), active)
		if not bool(battle.call(&"is_finished")) and float(wave_manager.call(&"get_prep_left")) > 0.0:
			battle.call(&"request_next_wave")
		next_buy += SAMPLE_INTERVAL
		if next_buy >= BUY_INTERVAL:
			next_buy = 0.0
			_spend(battle)
		if max_wave != last_wave:
			last_wave = max_wave
			wave_log.append("    wave %d: cash %d towers %d kills %d leaks %d hp %.0f%%" % [
				max_wave, int(battle.call(&"get_cash")), int(battle.call(&"get_tower_count")),
				int(battle.call(&"get_kills")), int(battle.call(&"get_leaks")),
				float(tree.call(&"hp_ratio")) * 100.0,
			])
		if int(battle.call(&"get_cleared_waves")) >= 30:
			break

	var cleared := int(battle.call(&"get_cleared_waves"))
	var units: Array = battle.call(&"get_units")
	var upgrades: Variant = battle.call(&"get_tree_upgrades")
	if _event_bus != null:
		_event_bus.disconnect(&"damage_dealt", damage_handler)

	print("== balance probe: policy=%s seed=%d ==" % [_policy, _seed])
	for line in wave_log:
		print(line)
	print("RESULT policy=%s seed=%d cleared=%d highest=%d peak=%d kills=%d leaks=%d towers=%d units=%d sim=%.1fs" % [
		_policy, _seed, cleared, max_wave, peak_total,
		int(battle.call(&"get_kills")), int(battle.call(&"get_leaks")),
		int(battle.call(&"get_tower_count")), units.size(),
		float(battle.call(&"get_elapsed")),
	])
	print_damage_shares()
	print("  tree tracks: %s" % _tracks_text(upgrades))
	print("  tree hp %.0f%%, finished=%s" % [
		float(tree.call(&"hp_ratio")) * 100.0, str(bool(battle.call(&"is_finished")))
	])
	print("  peak enemies per wave: %s" % _peaks_text(wave_peaks))

	battle.queue_free()
	await process_frame
	if save_service != null:
		save_service.call(&"clear")
	if game_state != null and not original.is_empty():
		game_state.call(&"from_dict", original)
		var wallet_service := game_state.get_node_or_null("/root/WalletService")
		var workshop_service := game_state.get_node_or_null("/root/WorkshopService")
		var unlock_service := game_state.get_node_or_null("/root/UnlockService")
		if wallet_service != null:
			wallet_service.call(&"reset")
		if workshop_service != null:
			workshop_service.call(&"init_service", original.get("workshop", {}))
		if unlock_service != null:
			unlock_service.call(&"refresh")
	quit(0 if cleared >= 7 else 1)


func _reset_profile(game_state: Node, run_state: Node) -> void:
	if game_state != null:
		game_state.set("player", {
			"id": "", "nickname": "", "avatar_id": "avatar_01", "level": 1,
			"xp": 0, "best_wave": 0, "next_wave_uses": 3,
		})
		game_state.set("wallet", {"coins": 0, "gems": 0, "stones": 0})
		game_state.set("unlocks", {})
		game_state.get("reward_ledger").call(&"from_array", [])
		var wallet_service := game_state.get_node_or_null("/root/WalletService")
		var workshop_service := game_state.get_node_or_null("/root/WorkshopService")
		var unlock_service := game_state.get_node_or_null("/root/UnlockService")
		if wallet_service != null:
			wallet_service.call(&"reset")
		if workshop_service != null:
			workshop_service.call(&"reset")
		if unlock_service != null:
			unlock_service.call(&"refresh")
	if run_state != null:
		run_state.set("seed", _seed)


func print_damage_shares() -> void:
	var total := 0.0
	for value in _damage_by_source.values():
		total += float(value)
	if total <= 0.0:
		print("  damage share: none")
		return
	var tree := float(_damage_by_source.get("tree", 0.0))
	var tower_total := 0.0
	var unit_total := 0.0
	var tower_parts: Array[String] = []
	for key in _damage_by_source:
		var amount := float(_damage_by_source[key])
		if String(key).begins_with("unit_"):
			unit_total += amount
		elif key != "tree":
			tower_total += amount
			tower_parts.append("%s %.0f%%" % [key, amount / total * 100.0])
	print("  damage share: tree %.0f%%  towers %.0f%%  units %.0f%%  (%s)" % [
		tree / total * 100.0, tower_total / total * 100.0, unit_total / total * 100.0,
		", ".join(tower_parts),
	])


func _tracks_text(upgrades: Variant) -> String:
	var parts: Array[String] = []
	for track_id in TRACK_ORDER:
		parts.append("%s %d" % [track_id, int(upgrades.call(&"get_level", track_id))])
	return ", ".join(parts)


func _peaks_text(wave_peaks: Dictionary) -> String:
	var parts: Array[String] = []
	for wave in wave_peaks:
		parts.append("%d:%d" % [int(wave), int(wave_peaks[wave])])
	return ", ".join(parts)


func _spend(battle: Node) -> void:
	var towers: Array = battle.call(&"get_towers")
	var opening := 2
	match _policy:
		"fill":
			opening = TOWER_ORDER.size()
		"four":
			opening = 4
		_:
			opening = 2
	# 1. Opening towers, cheapest first (archer 60).
	if towers.size() < opening:
		var pedestal: Variant = battle.call(&"get_pedestal", towers.size())
		if pedestal != null and bool(pedestal.call(&"is_buildable")):
			battle.call(&"build_tower", pedestal, TOWER_ORDER[towers.size()])
		return
	# 2. One guardian unit on the free canopy slot.
	var slots: Array = battle.call(&"get_unit_slots")
	if not slots.is_empty() and bool(slots[0].call(&"is_empty")):
		battle.call(&"place_unit", slots[0], &"unit_archer")
		return
	# 3. Bring the opening towers to level 5 (the tier/behavior breakpoint).
	var target_level := 5 if _policy == "two" else 4
	for tower in towers:
		if int(tower.get(&"level")) < target_level and bool(tower.call(&"can_upgrade")):
			if bool(battle.call(&"upgrade_tower", tower)):
				return
	# 4. Fill the remaining pedestals (not for the "tree" policy, which invests in
	#    two archers plus the Tree tracks instead of spreading thin).
	if _policy != "tree" and towers.size() < TOWER_ORDER.size():
		var next_pedestal: Variant = battle.call(&"get_pedestal", towers.size())
		if next_pedestal != null and bool(next_pedestal.call(&"is_buildable")):
			battle.call(&"build_tower", next_pedestal, TOWER_ORDER[towers.size()])
		return
	# 5. Tree tracks are the "tree" opening; every other opening spends on the
	#    cheapest tower/unit upgrade so the late waves keep scaling.
	if _policy == "tree" and _tick % 2 == 0:
		for track_id in TRACK_ORDER:
			var result: Variant = battle.call(&"try_buy_tree_upgrade", track_id)
			if result != null and bool(result.call(&"is_ok")):
				break
	else:
		var cheapest: Variant = null
		var cheapest_cost := 1 << 30
		for tower in battle.call(&"get_towers"):
			if bool(tower.call(&"can_upgrade")):
				var cost := int(tower.call(&"upgrade_cost"))
				if cost < cheapest_cost:
					cheapest_cost = cost
					cheapest = tower
		if cheapest != null:
			battle.call(&"upgrade_tower", cheapest)
	_tick += 1
	for unit in battle.call(&"get_units"):
		battle.call(&"upgrade_unit", unit)
