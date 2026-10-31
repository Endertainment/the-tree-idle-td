## M2 battle smoke test — loads the real battle scene and drives combat systems.
##
## Run: godot --headless --path . --script res://tools/battle_smoke.gd
## Proves: 8 pedestals + 4 unit slots (3 locked), one of every tower builds, a
## tower reaches level 5, a guardian unit is placed and upgraded, the boss wave
## spawns, the boss bar binds, kills/slows/damage numbers happen and cash moves.
## Exits non-zero on failure. Calls are dynamic because --script compiles this
## file before autoload identifiers exist.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const SIM_SPEED := 8.0
const SIM_SECONDS := 4.0
const BOSS_WAVE := 10

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== M2 battle smoke (%.0fs real at %.0fx) ==" % [SIM_SECONDS, SIM_SPEED])
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

	var slots: Array = battle.call(&"get_unit_slots")
	_check(slots.size() == 4, "4 unit slots created (%d)" % slots.size())
	var locked := 0
	for index in slots.size():
		if not bool(slots[index].call(&"is_unlocked")):
			locked += 1
	_check(locked == 3, "slots 2-4 locked by data conditions (%d locked)" % locked)

	battle.call(&"add_cash", 5000)
	var tower_ids: Array[StringName] = [&"tower_archer", &"cannon", &"frost_spire", &"totem"]
	var built := 0
	for index in tower_ids.size():
		var pedestal: Variant = battle.call(&"get_pedestal", index)
		if bool(battle.call(&"build_tower", pedestal, tower_ids[index])):
			built += 1
	_check(built == 4, "built one of each tower type (%d/4)" % built)
	_check(int(battle.call(&"get_tower_count")) == 4, "tower nodes present (%d)" % int(battle.call(&"get_tower_count")))

	var towers: Array = battle.call(&"get_towers")
	var upgraded := 0
	for _level in 4:
		if bool(battle.call(&"upgrade_tower", towers[0])):
			upgraded += 1
	var archer_level := int(towers[0].get(&"level"))
	_check(upgraded == 4 and archer_level == 5, "archer upgraded to L5 (%d upgrades, level %d)" % [upgraded, archer_level])

	# Sell path: build a spare tower, sell it, verify the refund and the freed slot.
	var spare_ok := bool(battle.call(&"build_tower", battle.call(&"get_pedestal", 4), &"tower_archer"))
	var cash_before_sale: int = int(battle.call(&"get_cash"))
	var spare_tower: Variant = battle.call(&"get_pedestal", 4).get(&"tower")
	var refund: int = int(battle.call(&"sell_tower", spare_tower))
	var cash_after_sale: int = int(battle.call(&"get_cash"))
	_check(
		spare_ok and refund > 0 and cash_after_sale == cash_before_sale + refund
		and int(battle.call(&"get_tower_count")) == 4,
		"sell refunded %d cash (70%% of invested) and freed the pedestal" % refund
	)

	var placed_ok := bool(battle.call(&"place_unit", slots[0], &"unit_archer"))
	_check(placed_ok, "guardian unit placed on slot 1")
	_check(int(battle.call(&"get_unit_count")) == 1, "unit node present (%d)" % int(battle.call(&"get_unit_count")))
	var units: Array = battle.call(&"get_units")
	var unit_upgraded := bool(battle.call(&"upgrade_unit", units[0])) if not units.is_empty() else false
	_check(unit_upgraded, "guardian unit upgraded")

	var tree: Variant = battle.call(&"get_tree_entity")
	var hp_before: float = float(tree.get("hp"))
	var cash_before: int = int(battle.call(&"get_cash"))

	battle.call(&"debug_start_wave", BOSS_WAVE)
	clock.call(&"set_speed", SIM_SPEED)
	var wave_manager: Variant = battle.call(&"get_wave_manager")

	var max_slowed := 0
	var max_damage_numbers := 0
	var boss_seen := false
	var boss_bar_seen := false
	var boss_damaged := false
	var waited := 0.0
	var step := 0.05
	while waited < SIM_SECONDS:
		await create_timer(step).timeout
		waited += step
		max_slowed = maxi(max_slowed, int(battle.call(&"get_slowed_enemy_count")))
		max_damage_numbers = maxi(max_damage_numbers, int(battle.call(&"get_damage_number_count")))
		var boss: Variant = battle.call(&"get_active_boss")
		if boss != null:
			boss_seen = true
			if bool(battle.call(&"is_boss_bar_visible")):
				boss_bar_seen = true
			if float(boss.get("hp")) < float(boss.get("max_hp")):
				boss_damaged = true

	var wave: int = int(wave_manager.call(&"get_current_wave"))
	var kills: int = int(battle.call(&"get_kills"))
	var cash_after: int = int(battle.call(&"get_cash"))
	var spawned: int = int(battle.call(&"get_spawned_count"))

	_check(wave >= BOSS_WAVE, "boss wave %d started and advanced (current %d)" % [BOSS_WAVE, wave])
	_check(spawned > 0, "enemies spawned (%d)" % spawned)
	_check(boss_seen, "boss_troll spawned")
	_check(boss_bar_seen, "boss HP bar visible while boss alive")
	_check(boss_damaged, "boss HP bar received damage updates")
	_check(kills > 0, "kills resolved (%d)" % kills)
	_check(max_slowed > 0, "frost slow applied (%d slowed enemies at peak)" % max_slowed)
	_check(max_damage_numbers > 0, "floating damage numbers appeared (%d at peak)" % max_damage_numbers)
	_check(cash_after != cash_before or kills > 0, "cash changed (%d -> %d)" % [cash_before, cash_after])
	_check(float(tree.get("hp")) <= hp_before, "tree HP did not increase")
	_check(not bool(battle.call(&"is_finished")), "run still active")

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
