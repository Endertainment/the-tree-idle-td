## Ranged-enemy probe — proves the ported archers actually shoot the Tree.
##
## Run: godot --headless --path . --script res://tools/ranged_probe.gd
##
## Boots the real battle scene, jumps to wave 9 (one thrower) and waits for the
## first shot. A load-only test cannot prove this: the data can be authored and
## the signal never emitted, or the enemy can be killed before it stops.
## Exits non-zero on failure.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const WAVE := 9
const SIM_SPEED := 8.0
const MAX_SECONDS := 45.0
const STEP := 0.05

var _failures: int = 0
var _temp_save: String = "user://ranged_probe_save.json"


func _initialize() -> void:
	TranslationServer.set_locale("en")
	_run.call_deferred()


func _run() -> void:
	print("== ranged probe: wave %d, %.0fx ==" % [WAVE, SIM_SPEED])
	var save_service := root.get_node_or_null("SaveService")
	if save_service != null:
		save_service.set("save_path", _temp_save)
		save_service.call(&"clear")

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

	var tree: Variant = battle.call(&"get_tree_entity")
	var clock: Variant = battle.call(&"get_clock")
	if tree == null or clock == null:
		_fail("battle has no tree entity or clock")
		_finish()
		return

	var hp_before := float(tree.get("hp"))
	battle.call(&"debug_start_wave", WAVE)
	clock.call(&"set_speed", SIM_SPEED)

	var waited := 0.0
	while waited < MAX_SECONDS and int(battle.call(&"ranged_shots_fired")) == 0:
		await create_timer(STEP).timeout
		waited += STEP

	var shots := int(battle.call(&"ranged_shots_fired"))
	_check(shots > 0, "a ranged enemy fired (%.0fs)" % waited)

	waited = 0.0
	while waited < 10.0 and int(battle.call(&"ranged_hits_landed")) == 0:
		await create_timer(STEP).timeout
		waited += STEP
	var hits := int(battle.call(&"ranged_hits_landed"))
	_check(hits > 0, "the shot landed on the Tree (%.1fs after the first shot)" % waited)
	_check(
		float(tree.get("hp")) < hp_before,
		"Tree HP dropped (%.0f -> %.0f)" % [hp_before, float(tree.get("hp"))]
	)

	battle.queue_free()
	await process_frame
	_finish()


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
	# Release the battle music stream before the audio server shuts down,
	# otherwise the run ends with "resources still in use" ERROR lines.
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
