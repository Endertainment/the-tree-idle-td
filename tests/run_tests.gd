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


func _initialize() -> void:
	print("== The Tree: M0+M4a tests ==")
	var core: RefCounted = TestCore.new()
	var battle: RefCounted = TestBattle.new()
	var economy: RefCounted = TestEconomy.new()
	var meta: RefCounted = TestMeta.new()
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
