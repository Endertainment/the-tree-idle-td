## M4a tests: save v2 migration/recovery, persistent wallet, workshop curves and
## caps, unlock gating and ModifierService stacking.
##
## Pure logic only: SaveService/ModifierService are instantiated from their
## scripts and no autoload globals are touched (the suite runs headless).
extends RefCounted

const TREE_DATA_PATH := "res://data/tree/tree_base.tres"
const LEVELS_PATH := "res://data/progression/levels.tres"
const SaveServiceScript := preload("res://scripts/autoload/save_service.gd")
const ModifierServiceScript := preload("res://scripts/autoload/modifier_service.gd")


func test_save_v1_migration() -> bool:
	var v1 := {
		"schema_version": 1,
		"player": {
			"id": "legacy", "nickname": "Vova", "avatar_id": "elf_01",
			"level": 7, "xp": 320, "best_wave": 18, "next_wave_uses": 3,
		},
		"wallet": {"coins": 12480, "gems": 350, "stones": 0},
		"unlocks": {"speed_1_5": true, "speed_2": false},
		"is_onboarded": true,
		"applied_rewards": ["run-1"],
		"wallet_log": [{"source": "old"}],
	}
	var v2 := SaveServiceScript.migrate_v1_to_v2(v1)
	if int(v2.get("schema_version", 0)) != 2:
		print("  migrated schema_version is not 2: ", v2.get("schema_version"))
		return false
	if int(v1.get("schema_version", 0)) != 1:
		print("  migration must be pure (input mutated)")
		return false
	var stats: Dictionary = v2.get("stats", {})
	if int(stats.get("best_wave", 0)) != 18:
		print("  v1 player.best_wave must move to stats.best_wave: ", stats)
		return false
	var wallet: Dictionary = v2.get("wallet", {})
	if int(wallet.get("coins", 0)) != 12480 or int(wallet.get("gems", 0)) != 350:
		print("  wallet was not preserved: ", wallet)
		return false
	var unlocks: Array = v2.get("unlocks", [])
	if unlocks.size() != 1 or str(unlocks[0]) != "speed_1_5":
		print("  v1 unlock flags must become a true-only array: ", unlocks)
		return false
	var cards: Dictionary = v2.get("cards", {})
	if (cards.get("equipped", []) as Array).size() != 4:
		print("  v2 cards must default to 4 empty equip slots: ", cards)
		return false
	for key in ["player", "stats", "workshop", "magica", "missions", "settings", "shop", "ads"]:
		if not v2.has(key):
			print("  missing v2 section: ", key)
			return false
	if not bool(v2.get("is_onboarded", false)) or (v2.get("applied_rewards", []) as Array).size() != 1:
		print("  local extras (onboarded/ledger) must survive migration")
		return false
	if (v2.get("player", {}) as Dictionary).has("best_wave"):
		print("  v2 player should not duplicate best_wave (stats owns it)")
		return false
	var migrated := SaveServiceScript.migrate(v1)
	if int(migrated.get("schema_version", 0)) != 2 or int((migrated.get("stats", {}) as Dictionary).get("best_wave", 0)) != 18:
		print("  migrate() must route v1 -> v2")
		return false
	print("  v1 -> v2 migration is pure and fills all 11 sections")
	return true


func test_corrupt_save_falls_back_to_backup() -> bool:
	var service: Node = _temp_service()
	if service == null:
		return false
	var first := {"player": {"id": "first", "level": 2}, "wallet": {"coins": 111, "gems": 1, "stones": 0}}
	var second := {"player": {"id": "second", "level": 3}, "wallet": {"coins": 222, "gems": 2, "stones": 0}}
	if not service.call(&"save", first) or not service.call(&"save", second):
		print("  setup writes failed")
		_cleanup(service)
		return false

	# A valid JSON file with a tampered payload must fail the checksum and use .bak.
	var main_path := str(service.get("save_path"))
	var text := FileAccess.get_file_as_string(main_path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		print("  saved file is not JSON")
		_cleanup(service)
		return false
	var tampered: Dictionary = parsed as Dictionary
	tampered["wallet"] = {"coins": 999999, "gems": 2, "stones": 0}
	var file := FileAccess.open(main_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(tampered))
	file.close()

	var recovered: Dictionary = service.call(&"load")
	if int((recovered.get("wallet", {}) as Dictionary).get("coins", 0)) != 111:
		print("  checksum failure must load the previous write (.bak): ", recovered.get("wallet"))
		_cleanup(service)
		return false
	if not bool(service.get("recovered_from_backup")):
		print("  recovered_from_backup flag was not set")
		_cleanup(service)
		return false

	# Both files broken -> {} and no crash.
	var backup_path := str(service.get("backup_path"))
	for path: String in [main_path, backup_path]:
		var broken := FileAccess.open(path, FileAccess.WRITE)
		broken.store_string("{not json")
		broken.close()
	var empty: Dictionary = service.call(&"load")
	if not empty.is_empty():
		print("  both-corrupt load must return {}")
		_cleanup(service)
		return false
	_cleanup(service)
	print("  tampered main -> .bak recovery (111 coins), both corrupt -> empty")
	return true


func test_wallet_never_negative() -> bool:
	var balances := {"coins": 0, "gems": 0, "stones": 0}
	var wallet := MetaWallet.new(balances)
	if not wallet.add(&"coins", 10, &"test").is_ok():
		print("  add(10) failed")
		return false
	var refused := wallet.try_spend(&"coins", 30, &"test")
	if refused.is_ok() or refused.code != SpendResult.Code.INSUFFICIENT_FUNDS or wallet.get_balance(&"coins") != 10:
		print("  over-spend must fail and keep the balance: ", wallet.get_balance(&"coins"))
		return false
	if not wallet.try_spend(&"coins", 4, &"test").is_ok() or wallet.get_balance(&"coins") != 6:
		print("  spend 4 from 10 should leave 6: ", wallet.get_balance(&"coins"))
		return false
	if wallet.try_spend(&"coins", 7, &"test").is_ok() or wallet.get_balance(&"coins") < 0:
		print("  balance went negative")
		return false
	if wallet.add(&"coins", 0, &"test").is_ok() or wallet.add(&"coins", -5, &"test").is_ok():
		print("  non-positive adds must be rejected")
		return false
	if wallet.add(&"gold", 5, &"test").is_ok():
		print("  unknown currency must be rejected")
		return false
	for _index in 60:
		wallet.add(&"gems", 1, &"loop")
	if wallet.get_log().size() != MetaWallet.MAX_LOG_ENTRIES:
		print("  log must be bounded at %d, got %d" % [MetaWallet.MAX_LOG_ENTRIES, wallet.get_log().size()])
		return false
	var entry: Dictionary = wallet.get_log()[-1]
	for key in ["kind", "delta", "balance", "reason", "at"]:
		if not entry.has(key):
			print("  log entry is missing ", key)
			return false
	var bundle := RewardBundle.new()
	bundle.coins = 25
	bundle.gems = 3
	bundle.xp = 40
	var changed := wallet.add_bundle(bundle, &"bundle")
	if changed.size() != 2 or wallet.get_balance(&"coins") != 31 or wallet.get_balance(&"gems") != 63:
		print("  bundle apply changed wrong currencies: ", changed)
		return false
	print("  no negative balance, bounded 50-entry log, bundle grants verified")
	return true


func test_workshop_cost_curve_and_cap() -> bool:
	var tracks := WorkshopModel.load_tracks()
	if tracks.size() != 24:
		print("  expected 24 workshop tracks, got ", tracks.size())
		return false
	var expected := {
		&"tree_damage": ["attack", 50, 0.04, 0.0],
		&"unit_damage": ["attack", 60, 0.04, 0.0],
		&"tower_damage": ["attack", 70, 0.04, 0.0],
		&"crit_chance": ["attack", 80, 0.004, 0.25],
		&"crit_damage": ["attack", 80, 0.05, 0.0],
		&"attack_speed": ["attack", 120, 0.015, 0.0],
		&"tree_max_hp": ["defense", 50, 0.05, 0.0],
		&"tree_regen": ["defense", 90, 0.0004, 0.0],
		&"damage_reduction": ["defense", 100, 0.005, 0.6],
		&"starting_cash": ["defense", 70, 6.0, 0.0],
		&"start_shield": ["defense", 150, 40.0, 0.0],
		&"leak_damage_reduction": ["defense", 140, 0.005, 0.4],
		&"cash_gain": ["utility", 60, 0.03, 0.0],
		&"coin_gain": ["utility", 90, 0.03, 0.0],
		&"xp_gain": ["utility", 80, 0.03, 0.0],
		&"in_run_discount": ["utility", 110, 0.008, 0.4],
		&"wave_clear_bonus": ["utility", 75, 4.0, 0.0],
		&"offline_cap_minutes": ["utility", 120, 20.0, 0.0],
		&"offline_coin_rate": ["environment", 100, 0.05, 0.0],
		&"ad_reward_bonus": ["environment", 90, 0.04, 0.0],
		&"mission_reward_bonus": ["environment", 90, 0.04, 0.0],
		&"magica_speed": ["environment", 130, 0.02, 0.0],
		&"free_daily_gems": ["environment", 200, 0.1, 5.0],
		&"card_drop_chance": ["environment", 160, 0.005, 0.15],
	}
	for track in tracks:
		if not expected.has(track.id):
			print("  unexpected workshop track ", track.id)
			return false
		var want: Array = expected[track.id]
		if track.category != StringName(want[0]) or track.base_cost != int(want[1]):
			print("  category/cost mismatch for ", track.id)
			return false
		if not is_equal_approx(track.effect_per_level, float(want[2])) or not is_equal_approx(track.cap, float(want[3])):
			print("  effect/cap mismatch for ", track.id)
			return false
		if track.max_level != 50 or not is_equal_approx(track.cost_growth, 1.18):
			print("  max level / growth must be 50 / 1.18 for ", track.id)
			return false
	for category: StringName in WorkshopModel.CATEGORIES:
		var count := 0
		for track in tracks:
			if track.category == category:
				count += 1
		if count != 6:
			print("  category %s has %d tracks, expected 6" % [category, count])
			return false

	var model := WorkshopModel.new()
	model.setup(tracks)
	var damage := model.get_track(&"tree_damage")
	if damage.cost_at(0) != 50 or damage.cost_at(1) % 5 != 0:
		print("  first cost must be base and every cost rounded to 5")
		return false
	if damage.cost_at(1) != 60:
		print("  50 * 1.18 rounded to 5 should be 60, got ", damage.cost_at(1))
		return false
	var previous := 0
	for level in range(0, 50):
		var cost := damage.cost_at(level)
		if cost <= previous or cost % 5 != 0:
			print("  cost curve not strictly increasing/rounded at level %d: %d" % [level, cost])
			return false
		previous = cost
	model.set_level(&"tree_damage", 50)
	if not model.is_maxed(&"tree_damage") or model.cost_of(&"tree_damage") != 0:
		print("  level 50 must be maxed with no price")
		return false
	var maxed := model.can_buy(&"tree_damage", 999999999)
	if maxed.is_ok() or maxed.code != SpendResult.Code.MAX_LEVEL:
		print("  buying past 50 must fail with MAX_LEVEL")
		return false
	var drop := model.get_track(&"card_drop_chance")
	if not is_equal_approx(drop.total_at(30), 0.15) or not is_equal_approx(drop.total_at(50), 0.15):
		print("  card drop chance must cap at 15 %%: ", drop.total_at(50))
		return false
	var gems := model.get_track(&"free_daily_gems")
	if not is_equal_approx(gems.total_at(50), 5.0):
		print("  free daily gems must cap at 5: ", gems.total_at(50))
		return false
	model.set_level(&"tree_damage", 10)
	var entries := model.modifier_entries()
	if not entries.has("tree_damage") or not is_equal_approx(float(entries["tree_damage"]["mul"]), 0.4):
		print("  tree damage 10 levels must declare a +40 %% multiplier: ", entries.get("tree_damage"))
		return false
	print("  24 tracks, 4x6 categories, 1.18/round-5 curve, caps at 50/15 %%/5 gems")
	return true


func test_unlock_gating_levels() -> bool:
	var table := load(LEVELS_PATH) as LevelProgression
	if table == null:
		print("  cannot load ", LEVELS_PATH)
		return false
	var model := ProgressionModel.new(table)
	var checks := [
		[1, &"battle", true], [1, &"speed_1_5", false],
		[3, &"speed_1_5", true], [3, &"magica", true],
		[3, &"unit_slot_2", false], [3, &"speed_2", false],
		[4, &"unit_slot_2", true], [4, &"missions", true],
		[4, &"speed_2", false],
		[10, &"speed_2", true], [10, &"unit_slot_4", false],
		[12, &"unit_slot_4", true], [12, &"tournament", true],
		[12, &"card_slot_3", false],
	]
	for entry: Array in checks:
		var level := int(entry[0])
		var unlock_id := StringName(entry[1])
		var want := bool(entry[2])
		if model.is_unlocked(unlock_id, level) != want:
			print("  unlock %s at level %d expected %s" % [unlock_id, level, want])
			return false
	var newly := model.newly_unlocked(1, 4)
	for required: StringName in [&"cards", &"speed_1_5", &"unit_slot_2", &"missions"]:
		if not newly.has(required):
			print("  level 1->4 missed ", required, ": ", newly)
			return false
	if model.level_for(&"speed_2") != 10 or model.level_for(&"unknown") != 0:
		print("  level_for() returned the wrong gate")
		return false
	print("  gates at levels 3/4/10/12 and unknown ids verified")
	return true


func test_modifier_stacking_and_caps() -> bool:
	var modifiers: Node = ModifierServiceScript.new()
	modifiers.call(&"add_source", &"workshop", {"tree_damage": {"mul": 0.4}})
	modifiers.call(&"add_source", &"cards", {"tree_damage": {"mul": 0.25}})
	var damaged := float(modifiers.call(&"get_stat", &"tree_damage", 100.0))
	if absf(damaged - 175.0) > 0.001:
		print("  multiplicative sources must stack: 100 * 1.4 * 1.25 = 175, got ", damaged)
		modifiers.free()
		return false
	modifiers.call(&"add_source", &"crit", {"crit_chance": {"add": 0.2}})
	modifiers.call(&"add_source", &"card_crit", {"crit_chance": {"add": 0.5}})
	var crit := float(modifiers.call(&"get_stat_clamped", &"crit_chance", 0.05, 0.0, 0.6))
	if not is_equal_approx(crit, 0.6):
		print("  crit chance must clamp at 60 %%, got ", crit)
		modifiers.free()
		return false
	modifiers.call(&"add_source", &"dr_a", {"damage_reduction": {"add": 0.5}})
	modifiers.call(&"add_source", &"dr_b", {"damage_reduction": {"add": 0.2}})
	var reduction := float(modifiers.call(&"get_stat_clamped", &"damage_reduction", 0.0, 0.0, 0.6))
	if not is_equal_approx(reduction, 0.6):
		print("  damage reduction must clamp at 60 %%, got ", reduction)
		modifiers.free()
		return false
	modifiers.call(&"remove_source", &"cards")
	if absf(float(modifiers.call(&"get_stat", &"tree_damage", 100.0)) - 140.0) > 0.001:
		print("  removing a source must remove exactly its contribution")
		modifiers.free()
		return false
	modifiers.call(&"remove_source", &"does_not_exist")
	modifiers.free()
	print("  add/mul stacking, crit + reduction caps and idempotent removal verified")
	return true


func test_workshop_bonus_reaches_battle_dps() -> bool:
	var tree := load(TREE_DATA_PATH) as TreeData
	if tree == null:
		print("  cannot load ", TREE_DATA_PATH)
		return false
	var model := WorkshopModel.new()
	model.setup(WorkshopModel.load_tracks(), {"tree_damage": 10})
	var modifiers: Node = ModifierServiceScript.new()
	modifiers.call(&"add_source", &"workshop", model.modifier_entries())

	var fresh := TreeUpgrades.tree_dps_from_stats(
		tree.damage, tree.attack_interval, tree.crit_chance, tree.crit_multiplier
	)
	var boosted_damage := float(modifiers.call(&"get_stat", &"tree_damage", tree.damage))
	var boosted_interval := tree.attack_interval / maxf(float(modifiers.call(&"get_stat", &"attack_speed", 1.0)), 0.01)
	var boosted_crit := float(modifiers.call(&"get_stat", &"crit_chance", tree.crit_chance))
	var boosted_multiplier := float(modifiers.call(&"get_stat", &"crit_damage", tree.crit_multiplier))
	var boosted := TreeUpgrades.tree_dps_from_stats(
		boosted_damage, boosted_interval, boosted_crit, boosted_multiplier
	)
	if boosted <= fresh * 1.3:
		print("  tree_damage 10 must raise starting DPS by ~40 %%, got %.2f -> %.2f" % [fresh, boosted])
		modifiers.free()
		return false
	if not is_equal_approx(boosted / fresh, 1.4):
		print("  expected exactly +40 %% DPS for 10 damage levels, ratio %.4f" % (boosted / fresh))
		modifiers.free()
		return false

	var cash_mods: Node = ModifierServiceScript.new()
	var cash_model := WorkshopModel.new()
	cash_model.setup(WorkshopModel.load_tracks(), {"starting_cash": 10, "start_shield": 2, "damage_reduction": 10})
	cash_mods.call(&"add_source", &"workshop", cash_model.modifier_entries())
	var start_cash := float(cash_mods.call(&"get_stat", &"starting_cash", 120.0))
	var shield := float(cash_mods.call(&"get_stat", &"start_shield", 0.0))
	var dr := float(cash_mods.call(&"get_stat", &"damage_reduction", 0.0))
	if not is_equal_approx(start_cash, 180.0) or not is_equal_approx(shield, 80.0) or not is_equal_approx(dr, 0.05):
		print("  starting cash/shield/reduction did not reach ModifierService: ", start_cash, " ", shield, " ", dr)
		cash_mods.free()
		modifiers.free()
		return false
	cash_mods.free()
	modifiers.free()
	print("  tree_damage 10: DPS %.2f -> %.2f (+40 %%), cash/shield/reduction wired" % [fresh, boosted])
	return true


func _temp_service() -> Node:
	var service: Node = SaveServiceScript.new()
	if service == null:
		print("  cannot instantiate SaveService")
		return null
	var suffix := str(Time.get_ticks_usec())
	service.set("save_path", "user://m4a_test_%s.json" % suffix)
	service.set("backup_path", "user://m4a_test_%s.bak.json" % suffix)
	service.set("temp_path", "user://m4a_test_%s.tmp.json" % suffix)
	service.call(&"clear")
	return service


func _cleanup(service: Node) -> void:
	service.call(&"clear")
	service.free()
