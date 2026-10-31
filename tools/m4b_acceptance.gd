## M4 acceptance proof — the five M4b acceptance criteria that need the live services.
##
## Run: godot --headless --path . --script res://tools/m4b_acceptance.gd
## Uses isolated user://m4b_proof_* save files and restores the real profile at the end.
## Covers: research completing while "closed" + surviving a restart, workshop DPS,
## card equip/unequip aggregation + Deep Roots slot, mission claim-once and 04:00
## reroll, offline income claim, and corrupt-main -> .bak recovery.
extends SceneTree

const SaveServiceScript := preload("res://scripts/autoload/save_service.gd")
const TREE_DATA_PATH := "res://data/tree/tree_base.tres"
const PROOF_PATH := "user://m4b_proof_save.json"
const PROOF_BAK := "user://m4b_proof_save.bak.json"
const PROOF_TMP := "user://m4b_proof_save.tmp.json"
const T0 := 1_790_000_000

var _failures := 0
var _save_service: Node
var _game_state: Node
var _wallet: Node
var _workshop: Node
var _magica: Node
var _cards: Node
var _missions: Node
var _offline: Node
var _modifiers: Node
var _time: Node
var _level: Node
var _unlock: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== M4 acceptance proof ==")
	var app := root.get_node_or_null("App")
	if app != null and not bool(app.call(&"is_initialized")):
		app.call(&"init_services")

	_save_service = root.get_node_or_null("SaveService")
	_game_state = root.get_node_or_null("GameState")
	_wallet = root.get_node_or_null("WalletService")
	_workshop = root.get_node_or_null("WorkshopService")
	_magica = root.get_node_or_null("MagicaService")
	_cards = root.get_node_or_null("CardService")
	_missions = root.get_node_or_null("MissionService")
	_offline = root.get_node_or_null("OfflineService")
	_modifiers = root.get_node_or_null("ModifierService")
	_time = root.get_node_or_null("TimeService")
	_level = root.get_node_or_null("LevelService")
	_unlock = root.get_node_or_null("UnlockService")
	if _save_service == null or _game_state == null or _wallet == null or _magica == null \
			or _cards == null or _missions == null or _offline == null or _time == null:
		_fail("autoload services are missing")
		_finish()
		return

	var original_state: Dictionary = _game_state.call(&"to_dict")
	var original_paths := [
		str(_save_service.get("save_path")),
		str(_save_service.get("backup_path")),
		str(_save_service.get("temp_path")),
	]
	_save_service.set("save_path", PROOF_PATH)
	_save_service.set("backup_path", PROOF_BAK)
	_save_service.set("temp_path", PROOF_TMP)
	_save_service.call(&"clear")
	_time.call(&"set_now_override", T0)

	_test_research_offline(PROOF_PATH, PROOF_BAK, PROOF_TMP)
	_test_workshop_dps()
	_test_cards()
	_test_missions()
	_test_offline()
	_test_corrupt_save()

	_time.call(&"set_now_override", -1)
	_restore_profile(original_state)
	_save_service.call(&"clear")
	_save_service.set("save_path", original_paths[0])
	_save_service.set("backup_path", original_paths[1])
	_save_service.set("temp_path", original_paths[2])
	print("== %s ==" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)


func _test_research_offline(path: String, backup: String, temp: String) -> void:
	print("[ proof ] research completes while closed and survives restart")
	_reset_profile()
	_wallet.call(&"add_currency", &"coins", 5000, &"proof_grant")
	var start: Variant = _magica.call(&"try_start", &"quickened_roots_1")
	_check(start != null and bool(start.call(&"is_ok")), "research started with 5000 coins")
	_check(int(_magica.call(&"remaining_seconds")) == 1800, "quickened_roots_1 is a 30 min timer")
	_time.call(&"set_now_override", T0 + 1801)
	_check(bool(_magica.call(&"reconcile")), "research completed after the timestamp delta while closed")
	_check(bool(_magica.call(&"has_pending_claim")), "completion became a claimable badge")
	_check(_magica.call(&"pending_claim_id") == &"quickened_roots_1", "badge points at the finished node")

	# Simulated app restart: the service reloads the same save state.
	_magica.call(&"init_service", _game_state.get("magica"))
	_check(bool(_magica.call(&"has_pending_claim")), "pending claim survived the restart")
	_check(not bool(_magica.call(&"has_active_research")), "the timer did not restart")
	var claimed: Variant = _magica.call(&"claim")
	_check(claimed == &"quickened_roots_1", "claim moved the node into completed")
	var speed := float(_modifiers.call(&"get_stat", &"magica_speed", 1.0))
	_check(absf(speed - 1.10) < 0.001, "completed node published +10 % research speed")
	_check(bool(_save_service.call(&"flush")), "save flush succeeded")

	var loader: Node = SaveServiceScript.new()
	loader.set("save_path", path)
	loader.set("backup_path", backup)
	loader.set("temp_path", temp)
	var reloaded: Dictionary = loader.call(&"load")
	loader.free()
	var magica_section: Dictionary = reloaded.get("magica", {})
	var completed: Array = magica_section.get("completed", [])
	_check(completed.has("quickened_roots_1"), "completed research persisted to disk")
	_check(str(magica_section.get("pending_claim", "")) == "", "no duplicate pending claim on disk")


func _test_workshop_dps() -> void:
	print("[ proof ] workshop purchase changes starting DPS")
	_reset_profile()
	_wallet.call(&"add_currency", &"coins", 500, &"proof_grant")
	var tree := load(TREE_DATA_PATH) as TreeData
	if tree == null:
		_fail("cannot load tree data")
		return
	var fresh := TreeUpgrades.tree_dps_from_stats(
		tree.damage, tree.attack_interval, tree.crit_chance, tree.crit_multiplier
	)
	var buy: Variant = _workshop.call(&"try_buy", &"tree_damage")
	_check(buy != null and bool(buy.call(&"is_ok")), "workshop tree_damage level bought")
	var damage := float(_modifiers.call(&"get_stat", &"tree_damage", tree.damage))
	var boosted := TreeUpgrades.tree_dps_from_stats(
		damage, tree.attack_interval, tree.crit_chance, tree.crit_multiplier
	)
	_check(boosted > fresh, "starting DPS increased (%.2f -> %.2f)" % [fresh, boosted])
	_check(absf(boosted / fresh - 1.04) < 0.001, "one tree_damage level is exactly +4 % DPS")


func _test_cards() -> void:
	print("[ proof ] card equip changes aggregated stats; unequip restores")
	_reset_profile()
	_game_state.get("player")["level"] = 2
	_level.call(&"init_service")
	_unlock.call(&"init_service")
	_cards.call(&"grant_card", &"greed")
	_check(int(_cards.call(&"slot_count")) == 1, "level 2 unlocks exactly one card slot")
	_check(bool(_cards.call(&"equip", &"greed", 0)), "greed equipped")
	var cash := float(_modifiers.call(&"get_stat", &"cash_gain", 1.0))
	_check(absf(cash - 1.20) < 0.001, "greed added +20 % cash to the aggregated stat")
	_check(bool(_cards.call(&"unequip", 0)), "greed unequipped")
	cash = float(_modifiers.call(&"get_stat", &"cash_gain", 1.0))
	_check(absf(cash - 1.0) < 0.001, "unequip restored the base stat")

	# Deep Roots adds the fifth slot on top of the level-20 fourth slot.
	_game_state.get("player")["level"] = 20
	_level.call(&"init_service")
	_unlock.call(&"init_service")
	_magica.call(&"init_service", {"research": {}, "completed": ["deep_roots"], "pending_claim": ""})
	_check(int(_cards.call(&"slot_count")) == 5, "Deep Roots grants the 5th card slot (got %d)" % int(_cards.call(&"slot_count")))


func _test_missions() -> void:
	print("[ proof ] missions claim once, all-3 bonus and 04:00 reroll")
	_reset_profile()
	var model: Variant = _missions.call(&"get_model")
	var daily: Array = model.call(&"get_daily")
	var weekly: Array = model.call(&"get_weekly")
	_check(daily.size() == 3 and weekly.size() == 5, "3 daily + 5 weekly missions generated")
	var first: Dictionary = daily[0]
	var target := int(first.get("target", 0))
	model.call(&"set_progress", str(first["id"]), target)
	var claim_one: Dictionary = _missions.call(&"claim", str(first["id"]))
	_check(bool(claim_one.get("ok", false)), "completed mission claimed")
	var claim_two: Dictionary = _missions.call(&"claim", str(first["id"]))
	_check(not bool(claim_two.get("ok", true)), "claiming the same mission twice is impossible")

	var coins_before := int(_wallet.call(&"get_balance", &"coins"))
	var gems_before := int(_wallet.call(&"get_balance", &"gems"))
	for row: Dictionary in model.call(&"get_daily"):
		if not bool(row.get("claimed", false)):
			model.call(&"set_progress", str(row["id"]), int(row["target"]))
			_missions.call(&"claim", str(row["id"]))
	_check(bool(model.call(&"is_bonus_claimed", &"daily")), "all-3 completion bonus was granted")
	_check(int(_wallet.call(&"get_balance", &"coins")) - coins_before >= 30, "daily bonus paid 30 coins")
	_check(int(_wallet.call(&"get_balance", &"gems")) - gems_before >= 2, "daily bonus paid 2 gems")

	var saved_state: Dictionary = _game_state.get("missions")
	var old_day := str(_missions.call(&"get_day_id"))
	_time.call(&"set_now_override", T0 + 2 * 86400)
	_missions.call(&"init_service", saved_state)
	_check(str(_missions.call(&"get_day_id")) != old_day, "crossed 04:00 rerolled the mission day")
	var rerolled: Variant = _missions.call(&"get_model")
	_check(int(rerolled.call(&"claimed_count", &"daily")) == 0, "reroll cleared daily claim state")
	var old_claim: Dictionary = _missions.call(&"claim", str(first["id"]))
	_check(not bool(old_claim.get("ok", true)), "an expired/old mission id cannot be claimed")
	_time.call(&"set_now_override", T0)


func _test_offline() -> void:
	print("[ proof ] offline income computes and claims through the wallet")
	_reset_profile()
	_game_state.get("player")["last_seen_at"] = T0 - 3 * 3600
	var before := int(_wallet.call(&"get_balance", &"coins"))
	_offline.call(&"init_service", {})
	var pending: Dictionary = _offline.call(&"get_pending")
	_check(int(pending.get("coins", 0)) == 108, "3 h away at 0.01 coins/s = 108 coins (got %d)" % int(pending.get("coins", 0)))
	var claimed := int(_offline.call(&"claim"))
	_check(claimed == 108, "offline claim returned 108 coins")
	_check(int(_wallet.call(&"get_balance", &"coins")) == before + 108, "offline coins landed in the wallet")
	_check(int(_offline.call(&"claim")) == 0, "offline claim is once per pending modal")


func _test_corrupt_save() -> void:
	print("[ proof ] corrupt main save falls back to .bak")
	_save_service.call(&"clear")
	_save_service.call(&"save", {"player": {"id": "first"}, "wallet": {"coins": 111, "gems": 1, "stones": 0}})
	_save_service.call(&"save", {"player": {"id": "second"}, "wallet": {"coins": 222, "gems": 2, "stones": 0}})
	var main_text := FileAccess.get_file_as_string(PROOF_PATH)
	var parsed: Variant = JSON.parse_string(main_text)
	if not (parsed is Dictionary):
		_fail("saved proof file is not JSON")
		return
	var tampered: Dictionary = parsed as Dictionary
	tampered["wallet"] = {"coins": 999999, "gems": 2, "stones": 0}
	var file := FileAccess.open(PROOF_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(tampered))
	file.close()
	var recovered: Dictionary = _save_service.call(&"load")
	var wallet: Dictionary = recovered.get("wallet", {})
	_check(int(wallet.get("coins", 0)) == 111, "tampered checksum loaded the previous write (.bak)")
	_check(bool(_save_service.get("recovered_from_backup")), "recovered_from_backup was set")


func _reset_profile() -> void:
	_time.call(&"set_now_override", T0)
	_game_state.set("player", {
		"id": "", "nickname": "", "avatar_id": "avatar_01", "level": 1,
		"xp": 0, "created_at": 0, "provider": "", "provider_uid": "",
		"best_wave": 0, "next_wave_uses": 0, "last_seen_at": 0,
	})
	_game_state.set("wallet", {"coins": 0, "gems": 0, "stones": 0})
	_game_state.set("stats", {
		"best_wave": 0, "runs_played": 0, "total_kills": 0,
		"total_playtime": 0, "weekly_max_wave": 0, "week_id": "",
	})
	_game_state.set("magica", {"research": {}, "completed": [], "pending_claim": ""})
	_game_state.set("cards", {"owned": [], "equipped": [null, null, null, null]})
	_game_state.set("missions", {
		"day_id": "", "daily": [], "week_id": "", "weekly": [],
		"daily_bonus_claimed": false, "weekly_bonus_claimed": false,
	})
	_game_state.set("unlocks", {})
	_game_state.set("is_onboarded", true)
	_wallet.call(&"reset")
	_level.call(&"init_service")
	_unlock.call(&"init_service")
	_workshop.call(&"reset")
	_magica.call(&"reset")
	_cards.set(&"drops_enabled", false)
	_cards.call(&"reset")
	_missions.call(&"reset")


func _restore_profile(original: Dictionary) -> void:
	if original.is_empty():
		return
	_game_state.call(&"from_dict", original)
	_wallet.call(&"reset")
	_level.call(&"init_service")
	_unlock.call(&"init_service")
	_workshop.call(&"init_service", original.get("workshop", {}))
	_magica.call(&"init_service", original.get("magica", {}))
	_cards.set(&"drops_enabled", true)
	_cards.call(&"init_service", original.get("cards", {}))
	_missions.call(&"init_service", original.get("missions", {}))
	_offline.call(&"init_service", original)


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
	quit(1 if _failures > 0 else 0)
