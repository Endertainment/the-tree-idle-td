## Headless test runner for Milestones 0-2.
##
## Usage:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 when every test passes, 1 otherwise.
extends SceneTree

const TestCore := preload("res://tests/test_core.gd")
const TestBattle := preload("res://tests/test_battle.gd")


func _initialize() -> void:
	print("== The Tree: M0+M2 tests ==")
	var core: RefCounted = TestCore.new()
	var battle: RefCounted = TestBattle.new()
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
