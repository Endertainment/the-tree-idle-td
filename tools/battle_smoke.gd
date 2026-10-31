## M1 battle smoke test — loads the real battle scene and simulates at 4x speed.
##
## Run: godot --headless --path . --script res://tools/battle_smoke.gd
## Proves: 8 pedestals spawn, archer towers build from data, the wave starts,
## enemies spawn, combat resolves (kill or leak) and cash moves. Exits non-zero
## on failure. Calls are dynamic because --script compiles this file before the
## autoload identifiers exist, so type references to gameplay classes would fail.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SIM_SPEED := 4.0
const SIM_SECONDS := 10.0
const TOWERS_TO_BUILD := 3

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== M1 battle smoke (%.0fs sim at %.0fx) ==" % [SIM_SECONDS, SIM_SPEED])
	var packed := load(BATTLE_SCENE) as PackedScene
	if packed == null:
		_fail("cannot load %s" % BATTLE_SCENE)
		_finish()
		return
	var battle: Node = packed.instantiate()
	if battle == null:
		_fail("battle scene did not instantiate")
		_finish()
		return
	root.add_child(battle)
	await process_frame

	var clock: Variant = battle.call(&"get_clock")
	if clock == null:
		_fail("battle has no BattleClock")
		_finish()
		return

	var pedestals: int = int(battle.call(&"get_pedestal_count"))
	_check(pedestals == 8, "8 pedestals spawned (%d)" % pedestals)
	_check(battle.call(&"get_tree_entity") != null, "tree entity present")

	battle.call(&"add_cash", 400)
	var built := 0
	for i in pedestals:
		if built >= TOWERS_TO_BUILD:
			break
		var pedestal: Variant = battle.call(&"get_pedestal", i)
		if bool(battle.call(&"build_tower", pedestal, &"tower_archer")):
			built += 1
	_check(built == TOWERS_TO_BUILD, "built %d/%d archer towers" % [built, TOWERS_TO_BUILD])
	_check(int(battle.call(&"get_tower_count")) == built, "tower nodes present (%d)" % int(battle.call(&"get_tower_count")))

	var cash_before: int = int(battle.call(&"get_cash"))
	var tree: Variant = battle.call(&"get_tree_entity")
	var hp_before: float = float(tree.get("hp"))
	var wave_manager: Variant = battle.call(&"get_wave_manager")
	var skipped: int = int(wave_manager.call(&"skip_prep"))
	_check(skipped > 0, "next-wave skip granted %d cash" % skipped)
	clock.call(&"set_speed", SIM_SPEED)

	var waited := 0.0
	var step := 0.05
	while waited < SIM_SECONDS / SIM_SPEED:
		await create_timer(step).timeout
		waited += step

	var spawned: int = int(battle.call(&"get_spawned_count"))
	var kills: int = int(battle.call(&"get_kills"))
	var tree_hp: float = float(tree.get("hp"))
	var cash_after: int = int(battle.call(&"get_cash"))
	var wave: int = int(wave_manager.call(&"get_current_wave"))

	_check(wave >= 1, "wave running (current wave %d)" % wave)
	_check(spawned > 0, "enemies spawned (%d)" % spawned)
	_check(kills > 0 or tree_hp < hp_before, "combat resolved (kills %d, tree HP %.0f -> %.0f)" % [kills, hp_before, tree_hp])
	_check(cash_after != cash_before, "cash changed (%d -> %d)" % [cash_before, cash_after])
	_check(not bool(battle.call(&"is_finished")), "run still active after %.0f simulated seconds" % SIM_SECONDS)

	battle.queue_free()
	await process_frame
	_finish()


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
	quit(0 if _failures == 0 else 1)
