## Headless test runner for Milestones 0-4a.
##
## Usage:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 when every test passes, 1 otherwise.
extends SceneTree

const TestCore := preload("res://tests/test_core.gd")
const TestBattle := preload("res://tests/test_battle.gd")
const TestEconomy := preload("res://tests/test_economy.gd")
const TestMeta := preload("res://tests/test_meta.gd")
const TestM4b := preload("res://tests/test_m4b.gd")
const TestM5a := preload("res://tests/test_m5a.gd")
const TestM5b := preload("res://tests/test_m5b.gd")
const TestM6 := preload("res://tests/test_m6.gd")
const TestM7 := preload("res://tests/test_m7.gd")
const TestM8 := preload("res://tests/test_m8.gd")


func _initialize() -> void:
	print("== The Tree: M0+M4b tests ==")
	var core: RefCounted = TestCore.new()
	var battle: RefCounted = TestBattle.new()
	var economy: RefCounted = TestEconomy.new()
	var meta: RefCounted = TestMeta.new()
	var m4b: RefCounted = TestM4b.new()
	var m5a: RefCounted = TestM5a.new()
	var m5b: RefCounted = TestM5b.new()
	var m6: RefCounted = TestM6.new()
	var m7: RefCounted = TestM7.new()
	var m8: RefCounted = TestM8.new()
	var cases: Array[Dictionary] = [
		{"name": "art manifest paths exist", "callable": Callable(core, "test_manifest_paths")},
		{"name": "SaveService round-trip", "callable": Callable(core, "test_save_roundtrip")},
		{"name": "cost curve monotonic", "callable": Callable(core, "test_cost_curve")},
		{"name": "damage resolver armor floor", "callable": Callable(battle, "test_damage_armor_floor")},
		{"name": "damage resolver crit path", "callable": Callable(battle, "test_damage_crit")},
		{"name": "damage true damage and multipliers", "callable": Callable(battle, "test_damage_true_and_multipliers")},
		{"name": "splash falloff", "callable": Callable(battle, "test_splash_falloff")},
		{"name": "status slow refresh", "callable": Callable(battle, "test_status_refresh")},
		{"name": "targeting modes", "callable": Callable(battle, "test_targeting_modes")},
		{"name": "tower behavior registry", "callable": Callable(battle, "test_tower_behavior_registry")},
		{"name": "unit slot unlocking", "callable": Callable(battle, "test_unit_slot_unlocking")},
		{"name": "tower and unit data match spec", "callable": Callable(battle, "test_tower_and_unit_data")},
		{"name": "wave table integrity and boss cadence", "callable": Callable(battle, "test_wave_table_integrity")},
		{"name": "map lanes and pedestal clearance", "callable": Callable(battle, "test_map_layout")},
		{"name": "run summary cash math", "callable": Callable(battle, "test_summary_cash_math")},
		{"name": "wallet transactions and reasons", "callable": Callable(economy, "test_wallet_transactions")},
		{"name": "hold-to-buy over-buy guard", "callable": Callable(economy, "test_hold_to_buy_over_buy_guard")},
		{"name": "tree upgrade cost curves", "callable": Callable(economy, "test_upgrade_track_curves")},
		{"name": "tree DPS delta after damage upgrade", "callable": Callable(economy, "test_tree_dps_after_damage_upgrade")},
		{"name": "reward bundle idempotency", "callable": Callable(economy, "test_reward_bundle_idempotency")},
		{"name": "speed multiplier math", "callable": Callable(economy, "test_speed_multiplier_math")},
		{"name": "next-wave tap guard", "callable": Callable(economy, "test_tap_guard")},
		{"name": "save v1 to v2 migration", "callable": Callable(meta, "test_save_v1_migration")},
		{"name": "corrupt save falls back to backup", "callable": Callable(meta, "test_corrupt_save_falls_back_to_backup")},
		{"name": "meta wallet never negative", "callable": Callable(meta, "test_wallet_never_negative")},
		{"name": "workshop cost curve and cap", "callable": Callable(meta, "test_workshop_cost_curve_and_cap")},
		{"name": "unlock gating at levels 3/4/10/12", "callable": Callable(meta, "test_unlock_gating_levels")},
		{"name": "modifier stacking and caps", "callable": Callable(meta, "test_modifier_stacking_and_caps")},
		{"name": "workshop bonus reaches battle DPS", "callable": Callable(meta, "test_workshop_bonus_reaches_battle_dps")},
		{"name": "magica prerequisites and one research", "callable": Callable(m4b, "test_magica_prerequisites_and_research")},
		{"name": "magica cancel refund and speed", "callable": Callable(m4b, "test_magica_cancel_refund_and_speed")},
		{"name": "magica offline completion survives restart", "callable": Callable(m4b, "test_magica_offline_completion_survives_restart")},
		{"name": "card equip/unequip restores stats", "callable": Callable(m4b, "test_card_equip_unequip_restores_stats")},
		{"name": "card duplicate shards and upgrade curve", "callable": Callable(m4b, "test_card_upgrade_and_duplicates")},
		{"name": "card slot limits", "callable": Callable(m4b, "test_card_slot_limits")},
		{"name": "mission 04:00 boundary", "callable": Callable(m4b, "test_mission_schedule_0400_boundary")},
		{"name": "missions claim once and reroll", "callable": Callable(m4b, "test_missions_claim_once_and_reset")},
		{"name": "mission completion bonus once", "callable": Callable(m4b, "test_mission_completion_bonus_once")},
		{"name": "offline income caps", "callable": Callable(m4b, "test_offline_income_caps")},
		{"name": "locale key lint", "callable": Callable(m5a, "test_locale_key_lint")},
		{"name": "en/uk translation catalogues", "callable": Callable(m5a, "test_translation_catalogues_load")},
		{"name": "ukrainian plural rules", "callable": Callable(m5a, "test_ukrainian_plural_rules")},
		{"name": "number and duration formatting", "callable": Callable(m5a, "test_number_and_duration_formatting")},
		{"name": "pseudo-locale transform", "callable": Callable(m5a, "test_pseudo_locale")},
		{"name": "settings persistence", "callable": Callable(m5a, "test_settings_persistence")},
		{"name": "nickname validation and uuid", "callable": Callable(m5a, "test_nickname_validation")},
		{"name": "audio bus volume mapping", "callable": Callable(m5a, "test_audio_bus_volume_mapping")},
		{"name": "shop product catalog integrity", "callable": Callable(m5b, "test_shop_catalog_integrity")},
		{"name": "leaderboard sorting and own rank", "callable": Callable(m5b, "test_leaderboard_sorting_and_own_rank")},
		{"name": "profile stats aggregation", "callable": Callable(m5b, "test_profile_stats_aggregation")},
		{"name": "toast queue", "callable": Callable(m5b, "test_toast_queue")},
		{"name": "ad placement caps", "callable": Callable(m6, "test_ad_placement_caps")},
		{"name": "interstitial cadence", "callable": Callable(m6, "test_interstitial_cadence")},
		{"name": "reward once guard", "callable": Callable(m6, "test_reward_once_guard")},
		{"name": "IAP catalog resource", "callable": Callable(m6, "test_iap_catalog_resource")},
		{"name": "monetization config", "callable": Callable(m6, "test_monetization_config")},
		{"name": "billing reason mapping", "callable": Callable(m6, "test_billing_reason_mapping")},
		{"name": "speed boost persistence", "callable": Callable(m6, "test_speed_boost_persistence")},
		{"name": "M6 locale keys", "callable": Callable(m6, "test_m6_locale_keys")},
		{"name": "analytics privacy sanitize", "callable": Callable(m6, "test_analytics_privacy_sanitize")},
		{"name": "API retry backoff schedule", "callable": Callable(m7, "test_api_backoff_schedule")},
		{"name": "API URL building", "callable": Callable(m7, "test_api_url_building")},
		{"name": "ApiResult typed contract", "callable": Callable(m7, "test_api_result_typed")},
		{"name": "offline API queue persistence", "callable": Callable(m7, "test_api_queue_persistence")},
		{"name": "save sync revision policy", "callable": Callable(m7, "test_save_sync_policy")},
		{"name": "save sync three-way merge", "callable": Callable(m7, "test_save_sync_three_way_merge")},
		{"name": "remote config merge and TTL", "callable": Callable(m7, "test_remote_config_merge_and_ttl")},
		{"name": "leaderboard server row mapping", "callable": Callable(m7, "test_leaderboard_backend_mapping")},
		{"name": "M7 env and remote defaults resources", "callable": Callable(m7, "test_env_and_remote_defaults_resources")},
		{"name": "ApiClient owns HTTPRequest", "callable": Callable(m7, "test_only_api_client_owns_http_request")},
		{"name": "tutorial hints one-shot and persistent", "callable": Callable(m8, "test_tutorial_one_shot_and_persistence")},
		{"name": "tutorial locale catalogues", "callable": Callable(m8, "test_tutorial_locale_catalogues")},
		{"name": "tutorial hint control", "callable": Callable(m8, "test_tutorial_hint_control")},
		{"name": "release wave curve", "callable": Callable(m8, "test_release_wave_curve")},
	]

	var failures := 0
	for test_case: Dictionary in cases:
		var test_name := str(test_case["name"])
		var test_callable := test_case["callable"] as Callable
		print("[ RUN  ] ", test_name)
		var passed := bool(test_callable.call())
		if passed:
			print("[ PASS ] ", test_name)
		else:
			failures += 1
			print("[ FAIL ] ", test_name)

	var total := cases.size()
	print("== %d/%d passed, %d failed ==" % [total - failures, total, failures])
	quit(1 if failures > 0 else 0)
