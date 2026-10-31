## BattlePreview — showcase staging for screenshot tooling (never used in play).
##
## Kept out of BattleController so the controller stays state/flow. Everything is
## driven through the controller's public API; the parameter is untyped so this
## helper adds no class dependency back into the controller.
class_name BattlePreview
extends RefCounted

const SHOWCASE_TOWERS: Array[StringName] = [&"tower_archer", &"cannon", &"frost_spire", &"totem"]


static func stage(battle: Node) -> void:
	if bool(battle.call(&"is_finished")):
		return
	battle.call(&"add_cash", 5000)
	for index in SHOWCASE_TOWERS.size():
		battle.call(&"build_tower", battle.call(&"get_pedestal", index), SHOWCASE_TOWERS[index])
	var towers: Array = battle.call(&"get_towers")
	if not towers.is_empty():
		for _level in 4:
			battle.call(&"upgrade_tower", towers[0])
	var slots: Array = battle.call(&"get_unit_slots")
	if not slots.is_empty():
		battle.call(&"place_unit", slots[0], &"unit_archer")
	battle.call(&"debug_start_wave", 10)


static func stage_sheet(battle: Node, sheet: String) -> void:
	stage(battle)
	match sheet:
		"tower":
			var towers: Array = battle.call(&"get_towers")
			if not towers.is_empty():
				battle.call(&"debug_open_tower_sheet", towers[0])
		"build":
			battle.call(&"debug_open_build_sheet", battle.call(&"get_pedestal", 7))
		"unit":
			var slots: Array = battle.call(&"get_unit_slots")
			if not slots.is_empty():
				battle.call(&"debug_open_unit_sheet", slots[0])
		"unit_place":
			battle.call(&"debug_unlock_unit_slots")
			var all_slots: Array = battle.call(&"get_unit_slots")
			if all_slots.size() > 1:
				battle.call(&"debug_open_unit_sheet", all_slots[1])
