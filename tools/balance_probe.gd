## Balance probe — automated greedy run for the M3 "wave 15+" balance gate.
##
## Run: godot --headless --path . --script res://tools/balance_probe.gd
## Not a player simulation: it buys towers/units/upgrades greedily every 0.4 s at
## 8x sim and reports the wave it dies on. Use it as a floor check for the economy,
## not as a substitute for a skilled manual run. Save/state are isolated.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SIM_SPEED := 8.0
const REAL_TIMEOUT := 240.0
const BUY_INTERVAL := 0.4

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
## Opening policy: "fill" (8 cheap towers), "four" (4 then upgrade), "two" (2 then L5).
var _policy := "four"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_policy = str(args[0])
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	var save_service := root.get_node_or_null("SaveService")
	var original: Dictionary = game_state.call(&"to_dict") if game_state != null else {}
	if game_state != null:
		game_state.set("player", {
			"id": "", "nickname": "", "avatar_id": "avatar_01", "level": 1,
			"xp": 0, "best_wave": 0, "next_wave_uses": 3,
		})
		game_state.set("wallet", {"coins": 0, "gems": 0, "stones": 0})
		game_state.set("unlocks", {})
	if save_service != null:
		save_service.set("save_path", _temp_save)
		save_service.set("backup_path", _temp_save + ".bak")
		save_service.set("temp_path", _temp_save + ".tmp")
		save_service.call(&"clear")

	var battle: Node = (load(BATTLE_SCENE) as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame
	var clock: Variant = battle.call(&"get_clock")
	clock.call(&"set_speed", SIM_SPEED)
	var wave_manager: Variant = battle.call(&"get_wave_manager")
	var tree: Variant = battle.call(&"get_tree_entity")

	var real_elapsed := 0.0
	var max_wave := 0
	var last_wave := 0
	while not bool(battle.call(&"is_finished")) and real_elapsed < REAL_TIMEOUT:
		await create_timer(BUY_INTERVAL).timeout
		real_elapsed += BUY_INTERVAL
		_spend(battle)
		# Skilled play: skip the prep break for the bonus cash whenever possible.
		if float(wave_manager.call(&"get_prep_left")) > 0.0:
			battle.call(&"request_next_wave")
		max_wave = maxi(max_wave, int(wave_manager.call(&"get_current_wave")))
		if max_wave != last_wave:
			last_wave = max_wave
			var hp_ratio: float = float(tree.call(&"hp_ratio"))
			print("  wave %d: cash %d, towers %d, kills %d, leaks %d, tree %.0f%%" % [
				max_wave, int(battle.call(&"get_cash")), int(battle.call(&"get_tower_count")),
				int(battle.call(&"get_kills")), int(battle.call(&"get_leaks")), hp_ratio * 100.0,
			])
		if int(battle.call(&"get_cleared_waves")) >= 30:
			break

	var cleared := int(battle.call(&"get_cleared_waves"))
	var units: Array = battle.call(&"get_units")
	print("== balance probe ==")
	print("sim speed %.1fx, real %.1fs, sim %.1fs" % [SIM_SPEED, real_elapsed, float(battle.call(&"get_elapsed"))])
	print("waves cleared: %d (highest started: %d)" % [cleared, max_wave])
	print("kills: %d, leaks: %d, towers: %d, units: %d" % [
		int(battle.call(&"get_kills")), int(battle.call(&"get_leaks")),
		int(battle.call(&"get_tower_count")), units.size(),
	])
	var upgrades: Variant = battle.call(&"get_tree_upgrades")
	for track_id in TRACK_ORDER:
		print("  %s Lv %d" % [track_id, int(upgrades.call(&"get_level", track_id))])
	print("finished: %s, tree HP %.0f%%" % [
		str(bool(battle.call(&"is_finished"))), float(tree.call(&"hp_ratio")) * 100.0
	])

	battle.queue_free()
	await process_frame
	if save_service != null:
		save_service.call(&"clear")
	if game_state != null and not original.is_empty():
		game_state.call(&"from_dict", original)
	quit(0 if cleared >= 15 else 1)


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
	# 5. Alternate Tree tracks and the cheapest tower/unit upgrade.
	if _tick % 2 == 0:
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
