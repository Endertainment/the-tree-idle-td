## Headless test runner for Milestone 0.
##
## Usage:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 when every test passes, 1 otherwise.
extends SceneTree

const TestCore := preload("res://tests/test_core.gd")


func _initialize() -> void:
	print("== The Tree: M0 tests ==")
	var suite: RefCounted = TestCore.new()
	var cases: Array[Dictionary] = [
		{"name": "art manifest paths exist", "callable": Callable(suite, "test_manifest_paths")},
		{"name": "SaveService round-trip", "callable": Callable(suite, "test_save_roundtrip")},
		{"name": "cost curve monotonic", "callable": Callable(suite, "test_cost_curve")},
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
