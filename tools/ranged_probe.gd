## Ranged-enemy probe — proves the ported archers shoot, and measures the balance.
##
## Run: godot --headless --path . --script res://tools/ranged_probe.gd
##
## Phase 1 (balance): spawn one archetype at a time with no towers and let the
## Tree defend itself. Reports shots, battle seconds to kill and the cost in % of
## Tree HP, and fails when a lone enemy is cheaper than the counter-play or more
## expensive than its band. Phase 2 (mechanic): wave 9 carries a thrower — prove
## the shot is fired, lands, and costs HP. Exits non-zero on failure.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const WAVE := 9
const SIM_SPEED := 8.0
const MAX_SECONDS := 120.0
const STEP := 0.05
## Lifetime cost band, % of max Tree HP, per archetype (docs/ENEMY_ROSTER.md).
const COST_BANDS := {
	&"thrower": 6.0,
	&"mage": 6.0,
	&"trebuchet": 20.0,
}

var _failures: int = 0
var _temp_save: String = "user://ranged_probe_save.json"


func _initialize() -> void:
	TranslationServer.set_locale("en")
	_run.call_deferred()


func _run() -> void:
	print("== ranged probe: balance at %.0fx, then the wave-%d mechanic ==" % [SIM_SPEED, WAVE])
	var save_service := root.get_node_or_null("SaveService")
	if save_service != null:
		save_service.set("save_path", _temp_save)
		save_service.call(&"clear")

	var battle: Node = await _boot()
	if battle == null:
		await _finish()
		return
	var tree: Variant = battle.call(&"get_tree_entity")
	var clock: Variant = battle.call(&"get_clock")
	if tree == null or clock == null:
		_fail("battle has no tree entity or clock")
		await _finish()
		return
	clock.call(&"set_speed", SIM_SPEED)
	# Waves start automatically on boot; freeze them so a phase measures exactly
	# one archetype instead of a wave's worth of leaks.
	battle.call(&"debug_disable_waves")
	await create_timer(0.3).timeout

	# --- phase 1: lifetime cost with the Tree alone as counter-play -----------
	for enemy_id: StringName in COST_BANDS:
		var result: Dictionary = await _measure(battle, tree, enemy_id)
		var shots := int(result["shots"])
		var cost := float(result["cost_pct"])
		var band := float(COST_BANDS[enemy_id])
		print("  %-9s shots %d hits %d leaks %d  killed in %5.1fs  cost %.1f%% (band %.0f%%)" % [
			enemy_id, shots, int(result["hits"]), int(result["leaks"]),
			float(result["seconds"]), cost, band
		])
		_check(shots > 0, "%s fires before it dies" % enemy_id)
		_check(int(result["leaks"]) == 0, "%s never leaks (it stops at range)" % enemy_id)
		_check(cost <= band, "%s costs %.1f%% <= %.0f%% band" % [enemy_id, cost, band])
		_check(float(result["seconds"]) <= 90.0, "%s dies to the Tree within 90s" % enemy_id)

	# --- phase 2: the real mechanic on wave 9 --------------------------------
	var hp_before := float(tree.get("hp"))
	var shots_before := int(battle.call(&"ranged_shots_fired"))
	var hits_before := int(battle.call(&"ranged_hits_landed"))
	battle.call(&"debug_start_wave", WAVE)
	var waited := 0.0
	while waited < 45.0 and int(battle.call(&"ranged_shots_fired")) - shots_before == 0:
		await create_timer(STEP).timeout
		waited += STEP
	_check(int(battle.call(&"ranged_shots_fired")) - shots_before > 0,
		"wave %d thrower fired (%.0fs real)" % [WAVE, waited])

	waited = 0.0
	while waited < 10.0 and int(battle.call(&"ranged_hits_landed")) - hits_before == 0:
		await create_timer(STEP).timeout
		waited += STEP
	_check(int(battle.call(&"ranged_hits_landed")) - hits_before > 0, "the shot landed on the Tree")
	_check(float(tree.get("hp")) < hp_before, "Tree HP dropped (%.0f -> %.0f)" % [hp_before, float(tree.get("hp"))])

	battle.queue_free()
	await process_frame
	await _finish()


## Spawns one archetype with no towers and waits for the Tree to kill it.
func _measure(battle: Node, tree: Variant, enemy_id: StringName) -> Dictionary:
	# Each phase starts from a full Tree so the archetypes do not contaminate
	# each other's cost measurement.
	tree.set("hp", float(tree.get("max_hp")))
	var hp_before := float(tree.get("hp"))
	var max_hp := float(tree.get("max_hp"))
	var shots_before := int(battle.call(&"ranged_shots_fired"))
	var hits_before := int(battle.call(&"ranged_hits_landed"))
	var leaks_before := int(battle.call(&"get_leaks"))
	battle.call(&"debug_spawn_enemy", enemy_id, &"north")
	var waited := 0.0
	while waited < MAX_SECONDS and int(battle.call(&"debug_alive_count", enemy_id)) > 0:
		await create_timer(STEP).timeout
		waited += STEP
	# Let in-flight shots land before closing the phase.
	await create_timer(1.5).timeout
	var shots := int(battle.call(&"ranged_shots_fired")) - shots_before
	var hits := int(battle.call(&"ranged_hits_landed")) - hits_before
	var leaks := int(battle.call(&"get_leaks")) - leaks_before
	var cost := (hp_before - float(tree.get("hp"))) / maxf(max_hp, 1.0) * 100.0
	return {
		"shots": shots,
		"hits": hits,
		"leaks": leaks,
		"seconds": waited * SIM_SPEED,
		"cost_pct": cost,
	}


func _boot() -> Node:
	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		_fail("cannot load %s" % BATTLE_SCENE)
		return null
	var battle: Node = packed.instantiate()
	if battle == null:
		_fail("battle scene did not instantiate")
		return null
	root.add_child(battle)
	await process_frame
	return battle


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[ PASS ] %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	print("[ FAIL ] %s" % message)


func _finish() -> void:
	var save_service := root.get_node_or_null("SaveService")
	if save_service != null:
		save_service.call(&"clear")
	var audio := root.get_node_or_null("AudioService")
	if audio != null:
		audio.call(&"release_all")
	await create_timer(0.2).timeout
	await process_frame
	if _failures == 0:
		print("== PASS ==")
		quit(0)
	else:
		print("== FAIL (%d) ==" % _failures)
		quit(1)
