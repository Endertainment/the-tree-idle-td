## Boss probe — proves the airship rotation and its summon mechanic in a real run.
##
## Run: godot --headless --path . --script res://tools/boss_probe.gd
##
## Wave 10 must field the Troll Warden, wave 20 the Orc Airship, and the airship
## must drop its wyvern escort while it lives. Data alone cannot prove this: the
## summon could be authored and never ticked. Exits non-zero on failure.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const TROLL_WAVE := 10
const AIRSHIP_WAVE := 20
const SIM_SPEED := 8.0
const WATCH_SECONDS := 20.0
const STEP := 0.05

var _failures: int = 0
var _temp_save: String = "user://boss_probe_save.json"


func _initialize() -> void:
	TranslationServer.set_locale("en")
	_run.call_deferred()


func _run() -> void:
	print("== boss probe: waves %d and %d at %.0fx ==" % [TROLL_WAVE, AIRSHIP_WAVE, SIM_SPEED])
	var save_service := root.get_node_or_null("SaveService")
	if save_service != null:
		save_service.set("save_path", _temp_save)
		save_service.call(&"clear")

	var battle: Node = await _boot()
	if battle == null:
		_finish()
		return
	var clock: Variant = battle.call(&"get_clock")

	battle.call(&"debug_start_wave", TROLL_WAVE)
	clock.call(&"set_speed", SIM_SPEED)
	await create_timer(0.5).timeout
	var troll: Variant = battle.call(&"get_active_boss")
	_check(troll != null and troll.get("data").id == &"boss_troll", "wave 10 fields the Troll Warden")
	_check(int(battle.call(&"boss_summons_spawned")) == 0, "the troll summons nothing")

	battle.call(&"debug_start_wave", AIRSHIP_WAVE)
	var waited := 0.0
	var airship: Variant = null
	while waited < 5.0:
		var candidate: Variant = battle.call(&"get_active_boss")
		if candidate != null and candidate.get("data").id == &"boss_airship":
			airship = candidate
			break
		await create_timer(STEP).timeout
		waited += STEP
	_check(airship != null, "wave 20 fields the Orc Airship")

	waited = 0.0
	while waited < WATCH_SECONDS and int(battle.call(&"boss_summons_spawned")) < 1:
		await create_timer(STEP).timeout
		waited += STEP
	var summons := int(battle.call(&"boss_summons_spawned"))
	_check(summons > 0, "the airship summoned its escort (%d in %.0fs)" % [summons, waited])
	_check(int(battle.call(&"debug_alive_count", &"wyvern")) > 0, "summoned wyverns are alive")

	battle.queue_free()
	await process_frame
	_finish()


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
