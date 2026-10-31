## Balance simulator — plays real battle scenes for three meta profiles (M8).
##
## Run:
##   godot --headless --path . --script res://tools/simulate_run.gd \
##       -- --profile=new --runs=10 [--seed=1] [--speed=16] [--verbose]
##
## Profiles (spec 4.8 / 6.2):
##   new  first launch: level 1, no workshop, no cards, one unit slot
##   mid  ~3 h player: level 12, workshop 8 levels on the combat tracks,
##        two rare cards, all level-gated unit slots
##   max  endgame: level 20, every workshop track at 30, four cards at max
##        level (the data pool has one legendary + epics; see BALANCE.md),
##        Fourth Branch (all four unit slots)
##
## Each run instantiates the real battle scene and uses a greedy but competent
## bot: fill all pedestals, place units, then buy the cheapest affordable upgrade
## across towers, units and tree tracks. Prep breaks are skipped for the bonus.
## Prints one line per run and a distribution summary; exits non-zero when the
## profile median misses the §4.8 target band.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const REAL_TIMEOUT := 900.0
const BUY_INTERVAL := 0.15
const BUYS_PER_TICK := 4
const SAMPLE_INTERVAL := 0.05

const TOWER_ORDER: Array[StringName] = [
	&"tower_archer", &"tower_archer", &"tower_archer", &"tower_archer",
	&"cannon", &"tower_archer", &"frost_spire", &"tower_archer",
]
const UNIT_ORDER: Array[StringName] = [&"unit_archer", &"unit_mage", &"unit_druid", &"unit_archer"]
const TRACK_ORDER: Array[StringName] = [
	&"tree_attack_speed", &"tree_crit_chance", &"tree_crit_damage",
	&"tree_damage", &"tree_range", &"tree_regen",
]
## Global tracks buff towers and units too; the tree-only tracks are bought only
## with a large cash surplus (a competent player spends on coverage first).
const GLOBAL_TRACKS: Array[StringName] = [
	&"tree_attack_speed", &"tree_crit_chance", &"tree_crit_damage",
]
const TREE_ONLY_TRACKS: Array[StringName] = [&"tree_damage", &"tree_range", &"tree_regen"]
const TREE_SURPLUS := 4000

## Profile definitions. Workshop ids are the `data/workshop/*.tres` ids.
const PROFILES := {
	"new": {
		"level": 1,
		"workshop": {},
		"cards": [],
		"unit_slot_bonus": 0.0,
		"target_min": 8,
		"target_max": 12,
	},
	"mid": {
		"level": 12,
		"workshop": {
			"tree_damage": 8, "tower_damage": 8, "unit_damage": 8,
			"attack_speed": 8, "crit_chance": 8, "crit_damage": 8,
			"tree_max_hp": 8, "damage_reduction": 8,
			"leak_damage_reduction": 8, "starting_cash": 8,
			"cash_gain": 8, "wave_clear_bonus": 8, "in_run_discount": 8,
		},
		"cards": [
			{"id": "sharpened_tips", "level": 1},
			{"id": "overgrowth", "level": 1},
		],
		"unit_slot_bonus": 0.0,
		"target_min": 25,
		"target_max": 35,
	},
	"max": {
		"level": 20,
		"workshop": "all_30",
		"cards": [
			{"id": "ancient_pact", "level": 5},
			{"id": "swift_winds", "level": 5},
			{"id": "overgrowth", "level": 5},
			{"id": "guardian_bond", "level": 5},
		],
		"unit_slot_bonus": 1.0,
		"target_min": 45,
		"target_max": 999,
	},
}

var _temp_save := "user://m8_sim_save.json"
var _profile_name := "new"
var _runs := 10
var _start_seed := 1
var _sim_speed := 16.0
var _verbose := false
var _event_bus: Node
var _tick := 0
var _cleared_runs: Array[int] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		var text := str(arg)
		if text.begins_with("--profile="):
			_profile_name = text.trim_prefix("--profile=")
		elif text.begins_with("--runs="):
			_runs = maxi(int(text.trim_prefix("--runs=")), 1)
		elif text.begins_with("--seed="):
			_start_seed = maxi(int(text.trim_prefix("--seed=")), 1)
		elif text.begins_with("--speed="):
			_sim_speed = clampf(float(text.trim_prefix("--speed=")), 1.0, 32.0)
		elif text == "--verbose":
			_verbose = true
	if not PROFILES.has(_profile_name):
		print("[simulate] unknown profile '%s' (use new|mid|max)" % _profile_name)
		quit(2)
		return
	_temp_save = "user://m8_sim_%s_save.json" % _profile_name
	# Point SaveService at a scratch file before App.init_services() runs, so the
	# simulator never reads or writes the player's real save.
	var early_save := root.get_node_or_null("SaveService")
	if early_save != null:
		early_save.set("save_path", _temp_save)
		early_save.set("backup_path", _temp_save + ".bak")
		early_save.set("temp_path", _temp_save + ".tmp")
		early_save.call(&"clear")
	_run_all.call_deferred()


func _run_all() -> void:
	# App.init_services() is deferred; it loads the (empty) temp save and would
	# otherwise overwrite the profile modifiers after _apply_profile().
	var app := root.get_node_or_null("App")
	var guard := 0
	while app != null and not bool(app.call(&"is_initialized")) and guard < 120:
		await process_frame
		guard += 1
	print("== balance simulation: profile=%s runs=%d seeds=%d..%d speed=%.0fx ==" % [
		_profile_name, _runs, _start_seed, _start_seed + _runs - 1, _sim_speed,
	])
	var game_state := root.get_node_or_null("GameState")
	var save_service := root.get_node_or_null("SaveService")
	_event_bus = root.get_node_or_null("EventBus")
	var original: Dictionary = game_state.call(&"to_dict") if game_state != null else {}
	if save_service != null:
		save_service.set("save_path", _temp_save)
		save_service.set("backup_path", _temp_save + ".bak")
		save_service.set("temp_path", _temp_save + ".tmp")
		save_service.call(&"clear")

	for index in _runs:
		var run_seed := _start_seed + index
		var cleared := await _play_one(run_seed)
		_cleared_runs.append(cleared)
		if save_service != null:
			save_service.call(&"clear")
		_reset_all_services(game_state)
		await process_frame

	var stats := _summary()
	_print_summary(stats)
	if game_state != null and not original.is_empty():
		game_state.call(&"from_dict", original)
		_restore_services(original)
	_cleanup_audio()
	await create_timer(0.2).timeout
	await process_frame
	if save_service != null:
		save_service.call(&"clear")
	quit(0 if stats["in_target"] else 1)


func _play_one(run_seed: int) -> int:
	_reset_all_services(root.get_node_or_null("GameState"))
	_apply_profile()
	var run_state := root.get_node_or_null("RunState")
	if run_state != null:
		run_state.set("seed", run_seed)

	var battle: Node = (load(BATTLE_SCENE) as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame
	var clock: Variant = battle.call(&"get_clock")
	# Tools may exceed the HUD clamp (BattleClock.MAX_SPEED = 8) for fast sims;
	# the sim_speed field is public and this never touches gameplay code.
	clock.set("sim_speed", _sim_speed)
	var wave_manager: Variant = battle.call(&"get_wave_manager")
	var tree: Variant = battle.call(&"get_tree_entity")

	var real_elapsed := 0.0
	var next_buy := 0.0
	var max_wave := 0
	var peak := 0
	var last_wave := 0
	var damage_by_source: Dictionary = {}
	var damage_handler := func(source_id: StringName, target_id: int, amount: float, _is_crit: bool, _is_kill: bool) -> void:
		if target_id <= 0:
			return
		var key := String(source_id)
		damage_by_source[key] = float(damage_by_source.get(key, 0.0)) + amount
	if _event_bus != null:
		_event_bus.connect(&"damage_dealt", damage_handler)
	while not bool(battle.call(&"is_finished")) and real_elapsed < REAL_TIMEOUT:
		await create_timer(SAMPLE_INTERVAL).timeout
		real_elapsed += SAMPLE_INTERVAL
		max_wave = maxi(max_wave, int(wave_manager.call(&"get_current_wave")))
		peak = maxi(peak, int(battle.call(&"get_active_enemy_count")))
		if not bool(battle.call(&"is_finished")) and float(wave_manager.call(&"get_prep_left")) > 0.0:
			battle.call(&"request_next_wave")
		next_buy += SAMPLE_INTERVAL
		if next_buy >= BUY_INTERVAL:
			next_buy = 0.0
			_spend(battle)
		if _verbose and max_wave != last_wave:
			last_wave = max_wave
			print("    wave %2d: cash %6d towers %d units %d kills %d leaks %d hp %3.0f%%" % [
				max_wave, int(battle.call(&"get_cash")), int(battle.call(&"get_tower_count")),
				int(battle.call(&"get_unit_count")), int(battle.call(&"get_kills")),
				int(battle.call(&"get_leaks")), float(tree.call(&"hp_ratio")) * 100.0,
			])

	var cleared := int(battle.call(&"get_cleared_waves"))
	if _event_bus != null:
		_event_bus.disconnect(&"damage_dealt", damage_handler)
	print("  seed %d: cleared %d  highest %d  peak %d  kills %d  leaks %d  towers %d  units %d  sim %.0fs  real %.0fs" % [
		run_seed, cleared, max_wave, peak, int(battle.call(&"get_kills")),
		int(battle.call(&"get_leaks")), int(battle.call(&"get_tower_count")),
		int(battle.call(&"get_unit_count")), float(battle.call(&"get_elapsed")), real_elapsed,
	])
	if _verbose:
		var levels: Array[String] = []
		for tower in battle.call(&"get_towers"):
			levels.append("L%d/%.0f" % [int(tower.get(&"level")), float(tower.call(&"effective_damage"))])
		print("    tower levels/damage: %s" % ", ".join(levels))
		print("    damage share: %s" % _share_text(damage_by_source))
		var upgrades: Variant = battle.call(&"get_tree_upgrades")
		var track_parts: Array[String] = []
		for track_id in TRACK_ORDER:
			track_parts.append("%s %d" % [track_id, int(upgrades.call(&"get_level", track_id))])
		print("    tree tracks: %s" % ", ".join(track_parts))
	battle.queue_free()
	await process_frame
	await process_frame
	return cleared


# --- profile ------------------------------------------------------------------


func _apply_profile() -> void:
	var profile: Dictionary = PROFILES[_profile_name]
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		return
	var level := int(profile.get("level", 1))
	game_state.set("player", {
		"id": "sim", "nickname": "Sim", "avatar_id": "avatar_01", "level": level,
		"xp": 0, "best_wave": 0, "next_wave_uses": 3,
	})
	game_state.set("wallet", {"coins": 0, "gems": 0, "stones": 0})
	game_state.set("is_onboarded", true)
	game_state.get("reward_ledger").call(&"from_array", [])

	var level_service := root.get_node_or_null("LevelService")
	var unlock_service := root.get_node_or_null("UnlockService")
	if level_service != null:
		level_service.call(&"init_service")
	if unlock_service != null:
		unlock_service.call(&"refresh")

	var workshop_levels := _workshop_levels(profile)
	var workshop_service := root.get_node_or_null("WorkshopService")
	if workshop_service != null:
		workshop_service.call(&"init_service", workshop_levels)

	var card_service := root.get_node_or_null("CardService")
	if card_service != null:
		var equipped: Array = []
		var owned: Array = []
		for entry: Dictionary in profile.get("cards", []):
			owned.append({"id": str(entry["id"]), "level": int(entry["level"]), "shards": 0})
			equipped.append(str(entry["id"]))
		card_service.set(&"drops_enabled", false)
		card_service.call(&"init_service", {"owned": owned, "equipped": equipped})

	var bonus := float(profile.get("unit_slot_bonus", 0.0))
	if bonus > 0.0:
		var modifiers := root.get_node_or_null("ModifierService")
		if modifiers != null:
			modifiers.call(&"add_source", &"sim_profile", {"unit_slot_bonus": bonus})
	var probe_mods := root.get_node_or_null("ModifierService")
	if probe_mods != null:
		print("    profile %s: tower_damage %.2f attack_speed %.2f crit %.2f tree_hp %.0f cards %d" % [
			_profile_name,
			float(probe_mods.call(&"get_stat", &"tower_damage", 1.0)),
			float(probe_mods.call(&"get_stat", &"attack_speed", 1.0)),
			float(probe_mods.call(&"get_stat", &"crit_chance", 0.05)),
			float(probe_mods.call(&"get_stat", &"tree_max_hp", 1200.0)),
			int(card_service.call(&"equipped_count")) if card_service != null else -1,
		])
	_cleanup_audio()


func _workshop_levels(profile: Dictionary) -> Dictionary:
	var levels: Dictionary = {}
	if str(profile.get("workshop", "")) == "all_30":
		var workshop_service := root.get_node_or_null("WorkshopService")
		if workshop_service != null:
			for track: Variant in workshop_service.call(&"get_tracks"):
				levels[String(track.get(&"id"))] = 30
	else:
		var configured: Dictionary = profile.get("workshop", {})
		for key: Variant in configured:
			levels[str(key)] = int(configured[key])
	return levels


func _reset_all_services(game_state: Node) -> void:
	if game_state == null:
		return
	game_state.set("player", {
		"id": "", "nickname": "", "avatar_id": "avatar_01", "level": 1,
		"xp": 0, "best_wave": 0, "next_wave_uses": 0,
	})
	game_state.set("wallet", {"coins": 0, "gems": 0, "stones": 0})
	game_state.set("unlocks", {})
	game_state.set("is_onboarded", true)
	game_state.get("reward_ledger").call(&"from_array", [])
	var modifiers := root.get_node_or_null("ModifierService")
	if modifiers != null:
		modifiers.call(&"clear")
	for service_name in [
		"WalletService", "WorkshopService", "MagicaService", "CardService", "MissionService",
	]:
		var service := root.get_node_or_null(service_name)
		if service != null:
			service.call(&"reset")
	var unlock_service := root.get_node_or_null("UnlockService")
	if unlock_service != null:
		unlock_service.call(&"refresh")


func _restore_services(original: Dictionary) -> void:
	var workshop_service := root.get_node_or_null("WorkshopService")
	var wallet_service := root.get_node_or_null("WalletService")
	var unlock_service := root.get_node_or_null("UnlockService")
	if wallet_service != null:
		wallet_service.call(&"reset")
	if workshop_service != null:
		workshop_service.call(&"init_service", original.get("workshop", {}))
	if unlock_service != null:
		unlock_service.call(&"refresh")


# --- bot ----------------------------------------------------------------------


func _spend(battle: Node) -> void:
	for _purchase in BUYS_PER_TICK:
		if _buy_one(battle):
			continue
		return


func _buy_one(battle: Node) -> bool:
	var cash := int(battle.call(&"get_cash"))
	var towers: Array = battle.call(&"get_towers")
	# 1. Fill the eight pedestals, cheapest towers first.
	if towers.size() < TOWER_ORDER.size():
		var pedestal: Variant = battle.call(&"get_pedestal", towers.size())
		if pedestal != null and bool(pedestal.call(&"is_buildable")):
			var data: Variant = battle.call(&"get_tower_data", TOWER_ORDER[towers.size()])
			if data != null and cash >= int(data.get(&"build_cost")):
				return bool(battle.call(&"build_tower", pedestal, TOWER_ORDER[towers.size()]))
			return false
	# 2. Put a guardian on every unlocked, empty canopy slot once the tower line
	#    is up and upgraded; units are a supplement, not the damage core.
	var slots: Array = battle.call(&"get_unit_slots")
	if towers.size() >= TOWER_ORDER.size() and _min_tower_level(battle) >= 4:
		for slot in slots:
			if bool(slot.call(&"is_empty")) and bool(slot.call(&"is_unlocked")):
				var unit_id: StringName = UNIT_ORDER[mini(int(battle.call(&"get_unit_count")), UNIT_ORDER.size() - 1)]
				var unit_data: Variant = battle.call(&"get_unit_data", unit_id)
				if unit_data != null and cash >= maxi(int(unit_data.get(&"placement_cost")) + 150, 200):
					return bool(battle.call(&"place_unit", slot, unit_id))
				break
	# 3. Cheapest affordable global upgrade: towers and the attack-speed / crit
	#    tracks that buff every damage source. Unit upgrades come after towers max.
	var best_cost := 1 << 30
	var best: Dictionary = {}
	for tower in battle.call(&"get_towers"):
		if not bool(tower.call(&"can_upgrade")):
			continue
		var cost := int(tower.call(&"upgrade_cost"))
		if cost < best_cost:
			best_cost = cost
			best = {"kind": &"tower", "target": tower}
	for unit in battle.call(&"get_units"):
		if not bool(unit.call(&"can_upgrade")) or _min_tower_level(battle) < 10:
			continue
		var cost := int(unit.call(&"upgrade_cost"))
		if cost < best_cost:
			best_cost = cost
			best = {"kind": &"unit", "target": unit}
	for track_id in GLOBAL_TRACKS:
		var row := _tree_row(battle, track_id)
		if row.is_empty() or bool(row.get("maxed", true)) or not bool(row.get("affordable", false)):
			continue
		var cost := int(row.get("cost", 1 << 30))
		if cost < best_cost:
			best_cost = cost
			best = {"kind": &"tree", "target": track_id}
	if cash >= TREE_SURPLUS:
		for track_id in TREE_ONLY_TRACKS:
			var row := _tree_row(battle, track_id)
			if row.is_empty() or bool(row.get("maxed", true)) or not bool(row.get("affordable", false)):
				continue
			var cost := int(row.get("cost", 1 << 30))
			if cost < best_cost:
				best_cost = cost
				best = {"kind": &"tree", "target": track_id}
	if best.is_empty() or best_cost > cash:
		return false
	match String(best["kind"]):
		"tower":
			return bool(battle.call(&"upgrade_tower", best["target"]))
		"unit":
			return bool(battle.call(&"upgrade_unit", best["target"]))
		"tree":
			var result: Variant = battle.call(&"try_buy_tree_upgrade", best["target"])
			return result != null and bool(result.call(&"is_ok"))
	return false


func _tree_row(battle: Node, track_id: StringName) -> Dictionary:
	for row: Dictionary in battle.call(&"tree_upgrade_rows"):
		if StringName(str(row.get("id", ""))) == track_id:
			return row
	return {}


func _min_tower_level(battle: Node) -> int:
	var lowest := 99
	for tower in battle.call(&"get_towers"):
		lowest = mini(lowest, int(tower.get(&"level")))
	return lowest


func _share_text(damage_by_source: Dictionary) -> String:
	var total := 0.0
	for value in damage_by_source.values():
		total += float(value)
	if total <= 0.0:
		return "none"
	var tree := 0.0
	var towers := 0.0
	var units := 0.0
	for key: Variant in damage_by_source:
		var amount := float(damage_by_source[key])
		if String(key) == "tree":
			tree += amount
		elif String(key).begins_with("unit_"):
			units += amount
		else:
			towers += amount
	return "tree %.0f%%  towers %.0f%%  units %.0f%%" % [
		tree / total * 100.0, towers / total * 100.0, units / total * 100.0,
	]


# --- reporting ----------------------------------------------------------------


func _summary() -> Dictionary:
	var sorted := _cleared_runs.duplicate()
	sorted.sort()
	var count := sorted.size()
	var median := 0.0
	if count > 0 and count % 2 == 1:
		median = float(sorted[count / 2])
	elif count > 0:
		median = (float(sorted[count / 2 - 1]) + float(sorted[count / 2])) / 2.0
	var profile: Dictionary = PROFILES[_profile_name]
	var target_min := int(profile["target_min"])
	var target_max := int(profile["target_max"])
	return {
		"runs": count,
		"min": sorted[0] if count > 0 else 0,
		"max": sorted[count - 1] if count > 0 else 0,
		"median": median,
		"p10": _percentile(sorted, 0.10),
		"p90": _percentile(sorted, 0.90),
		"target_min": target_min,
		"target_max": target_max,
		"in_target": median >= float(target_min) and median <= float(target_max),
	}


func _percentile(sorted: Array[int], fraction: float) -> int:
	if sorted.is_empty():
		return 0
	var index := clampi(int(round(fraction * float(sorted.size() - 1))), 0, sorted.size() - 1)
	return sorted[index]


func _print_summary(stats: Dictionary) -> void:
	print("== %s: median %.1f  min %d  max %d  p10 %d  p90 %d  (target %d-%d) ==" % [
		_profile_name, float(stats["median"]), int(stats["min"]), int(stats["max"]),
		int(stats["p10"]), int(stats["p90"]), int(stats["target_min"]), int(stats["target_max"]),
	])
	print("   runs: %s" % str(_cleared_runs))
	print("   %s" % ("PASS" if bool(stats["in_target"]) else "FAIL: median outside target"))


func _cleanup_audio() -> void:
	var audio := root.get_node_or_null("AudioService")
	if audio != null:
		if audio.has_method(&"release_all"):
			audio.call(&"release_all")
		else:
			audio.call(&"stop_music", 0.0)
