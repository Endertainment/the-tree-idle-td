## M4a persistence proof — buy a workshop level, simulate a restart, verify it.
##
## Run: godot --headless --path . --script res://tools/persistence_proof.gd
## Uses isolated user://m4a_proof_*.json paths, so the real save is never touched.
## Exits 0 when the workshop level, coins and modifier survive the reload.
extends SceneTree

const SaveServiceScript := preload("res://scripts/autoload/save_service.gd")
const PROOF_PATH := "user://m4a_proof_save.json"
const PROOF_BAK := "user://m4a_proof_save.bak.json"
const PROOF_TMP := "user://m4a_proof_save.tmp.json"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== M4a persistence proof ==")
	# In --script mode the deferred App boot may not have run yet; make the
	# service wiring explicit so SaveService has a document provider.
	var app := root.get_node_or_null("App")
	if app != null and not bool(app.call(&"is_initialized")):
		app.call(&"init_services")
	var save_service := root.get_node_or_null("SaveService")
	var game_state := root.get_node_or_null("GameState")
	var wallet_service := root.get_node_or_null("WalletService")
	var workshop_service := root.get_node_or_null("WorkshopService")
	var unlock_service := root.get_node_or_null("UnlockService")
	var modifier_service := root.get_node_or_null("ModifierService")
	if save_service == null or game_state == null or wallet_service == null or workshop_service == null:
		_fail("autoload services are missing")
		_finish(0)
		return

	var original_state: Dictionary = game_state.call(&"to_dict")
	var original_paths := [
		str(save_service.get("save_path")),
		str(save_service.get("backup_path")),
		str(save_service.get("temp_path")),
	]
	save_service.set("save_path", PROOF_PATH)
	save_service.set("backup_path", PROOF_BAK)
	save_service.set("temp_path", PROOF_TMP)
	save_service.call(&"clear")

	# 1) Fresh profile, 500 coins, buy one Tree Damage workshop level.
	_reset_profile(game_state, wallet_service, workshop_service, unlock_service)
	wallet_service.call(&"add_currency", &"coins", 500, &"proof_grant")
	var xp_bundle := RewardBundle.new()
	xp_bundle.xp = 262
	wallet_service.call(&"add_bundle", xp_bundle, &"proof_xp")
	var level_service := root.get_node_or_null("LevelService")
	_check(level_service != null and int(level_service.call(&"get_level")) == 3, "262 xp put the profile at level 3")
	_check(bool(unlock_service.call(&"is_unlocked", &"speed_1_5")), "speed 1.5x unlocked at level 3")
	_check(not bool(unlock_service.call(&"is_unlocked", &"speed_2")), "speed 2x still locked at level 3")
	_check(not bool(unlock_service.call(&"is_unlocked", &"unit_slot_2")), "unit slot 2 still locked at level 3")
	var buy: Variant = workshop_service.call(&"try_buy", &"tree_damage")
	_check(buy != null and bool(buy.call(&"is_ok")), "workshop tree_damage bought")
	_check(int(workshop_service.call(&"level_of", &"tree_damage")) == 1, "level is 1 before restart")
	_check(int(wallet_service.call(&"get_balance", &"coins")) == 450, "coins 500 - 50 = 450")
	_check(bool(save_service.call(&"flush")), "save flush succeeded")

	# 2) Inspect the on-disk document: v2, checksum, workshop section.
	var text := FileAccess.get_file_as_string(PROOF_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("save file is not JSON")
		_finish(0, save_service, game_state, original_state, original_paths)
		return
	var disk: Dictionary = parsed as Dictionary
	_check(int(disk.get("schema_version", 0)) == 2, "on-disk schema_version is 2")
	_check(str(disk.get("checksum", "")).begins_with("sha256:"), "on-disk checksum is sha256")
	var disk_workshop: Dictionary = disk.get("workshop", {})
	_check(int(disk_workshop.get("tree_damage", 0)) == 1, "disk workshop.tree_damage is 1")

	# 3) Simulate a restart: a brand-new SaveService reads the same files.
	var loader: Node = SaveServiceScript.new()
	loader.set("save_path", PROOF_PATH)
	loader.set("backup_path", PROOF_BAK)
	loader.set("temp_path", PROOF_TMP)
	var reloaded: Dictionary = loader.call(&"load")
	loader.free()
	_check(not reloaded.is_empty(), "fresh SaveService reloaded the document")
	_check(int(reloaded.get("schema_version", 0)) == 2, "reloaded schema_version is 2")

	# 4) Apply the reloaded profile to a clean runtime and re-check state + stats.
	_reset_profile(game_state, wallet_service, workshop_service, unlock_service)
	game_state.call(&"from_dict", reloaded)
	wallet_service.call(&"reset")
	workshop_service.call(&"init_service", reloaded.get("workshop", {}))
	unlock_service.call(&"refresh")
	_check(int(workshop_service.call(&"level_of", &"tree_damage")) == 1, "workshop level survived the restart")
	_check(int(wallet_service.call(&"get_balance", &"coins")) == 450, "coin balance survived the restart")
	var boosted := float(modifier_service.call(&"get_stat", &"tree_damage", 100.0))
	_check(absf(boosted - 104.0) < 0.001, "workshop +4 %% modifier restored (got %.2f)" % boosted)
	_check(bool(modifier_service.call(&"has_source", &"workshop")), "workshop source re-registered")

	_finish(0, save_service, game_state, original_state, original_paths)


func _reset_profile(
	game_state: Node,
	wallet_service: Node,
	workshop_service: Node,
	unlock_service: Node
) -> void:
	game_state.set("player", {
		"id": "", "nickname": "", "avatar_id": "avatar_01", "level": 1,
		"xp": 0, "created_at": 0, "provider": "", "provider_uid": "",
		"best_wave": 0, "next_wave_uses": 0,
	})
	game_state.set("wallet", {"coins": 0, "gems": 0, "stones": 0})
	game_state.set("unlocks", {})
	game_state.set("is_onboarded", true)
	game_state.set("stats", {
		"best_wave": 0, "runs_played": 0, "total_kills": 0,
		"total_playtime": 0, "weekly_max_wave": 0, "week_id": "",
	})
	wallet_service.call(&"reset")
	workshop_service.call(&"reset")
	unlock_service.call(&"refresh")


func _finish(
	_code: int,
	save_service: Node = null,
	game_state: Node = null,
	original_state: Dictionary = {},
	original_paths: Array = []
) -> void:
	if save_service != null:
		save_service.call(&"clear")
		if original_paths.size() == 3:
			save_service.set("save_path", original_paths[0])
			save_service.set("backup_path", original_paths[1])
			save_service.set("temp_path", original_paths[2])
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
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[ PASS ] ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	print("[ FAIL ] ", message)
