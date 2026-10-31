## UnitSlots — owns the four canopy slots and the unit placement/upgrade flow.
##
## Slot nodes are created from MapData anchors and SlotRequirement data; unlock
## checks go through UnitSlotRules (pure). This collaborator renders through
## BattleHUD and performs transactions through BattleController.
class_name UnitSlots
extends RefCounted

signal slot_pressed(slot: UnitSlot)

var _battle: BattleController
var _hud: BattleHUD
var _slots: Array[UnitSlot] = []
var _selected: UnitSlot
var _placement_mode: bool = false


func setup(
	battle: BattleController,
	hud: BattleHUD,
	root: Node2D,
	slot_scene: PackedScene,
	map: MapData
) -> void:
	_battle = battle
	_hud = hud
	if root == null or slot_scene == null or map == null:
		return
	for index in map.unit_slot_positions.size():
		var slot := slot_scene.instantiate() as UnitSlot
		root.add_child(slot)
		slot.position = map.unit_slot_positions[index]
		slot.setup(index, map.slot_requirement(index), _is_unlocked(map.slot_requirement(index)))
		slot.pressed.connect(_on_slot_input)
		_slots.append(slot)
	_battle.register_unit_slots(_slots)


func get_slots() -> Array[UnitSlot]:
	return _slots


## Called by BattleHudController after it closes any other sheet.
func open(slot: UnitSlot) -> void:
	if _battle == null or _battle.is_finished() or slot == null:
		return
	if not slot.is_unlocked():
		var hint := slot.lock_hint()
		_hud.show_banner("%s: %s" % [LocaleService.t("battle.slot_locked", "Locked"), hint])
		return
	close()
	_selected = slot
	slot.select()
	if slot.is_occupied() and is_instance_valid(slot.unit):
		_placement_mode = false
		_hud.show_unit_sheet(_unit_info(slot.unit))
	else:
		_placement_mode = true
		_hud.show_unit_sheet(_placement_info())
	_battle.set_sheet_open(true)


## Places `unit_id` on the selected empty slot.
func place(unit_id: StringName) -> bool:
	if not _placement_mode or _selected == null:
		return false
	if _battle.place_unit(_selected, unit_id):
		close()
		return true
	return false


## Upgrades the unit on the selected occupied slot.
func upgrade() -> bool:
	if _placement_mode or _selected == null or _selected.unit == null:
		return false
	if not _battle.upgrade_unit(_selected.unit):
		refresh()
		return false
	_hud.show_unit_sheet(_unit_info(_selected.unit))
	return true


func refresh() -> void:
	if _selected == null:
		return
	if _placement_mode:
		_hud.show_unit_sheet(_placement_info())
	elif _selected.unit != null:
		_hud.show_unit_sheet(_unit_info(_selected.unit))


func close() -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.deselect()
	_selected = null
	_placement_mode = false
	if _hud != null:
		_hud.hide_unit_sheet()
	if _battle != null:
		_battle.set_sheet_open(false)


func is_open() -> bool:
	return _selected != null


func _on_slot_input(slot: UnitSlot) -> void:
	slot_pressed.emit(slot)


func _placement_info() -> Dictionary:
	return {
		"mode": "place",
		"options": _battle.unit_options(),
	}


func _unit_info(unit: Unit) -> Dictionary:
	var data := unit.data
	var maxed := not unit.can_upgrade()
	var cost := unit.upgrade_cost()
	return {
		"mode": "upgrade",
		"name_key": data.display_name_key,
		"name": data.display_name,
		"level": unit.level,
		"max_level": data.levels.max_level if data.levels != null else 10,
		"damage": unit.damage_at(unit.level),
		"next_damage": unit.damage_at(unit.level + 1) if not maxed else unit.damage_at(unit.level),
		"interval": unit.interval_at(unit.level),
		"next_interval": unit.interval_at(unit.level + 1) if not maxed else unit.interval_at(unit.level),
		"range": unit.range_at(unit.level),
		"next_range": unit.range_at(unit.level + 1) if not maxed else unit.range_at(unit.level),
		"splash_radius": data.splash_radius,
		"slow_pct": data.status_on_hit.slow_pct if data.status_on_hit != null else 0.0,
		"upgrade_cost": cost,
		"maxed": maxed,
		"affordable": _battle.get_cash() >= cost and not maxed,
	}


func _is_unlocked(requirement: SlotRequirement) -> bool:
	if requirement == null:
		return true
	var level := int(GameState.player.get("level", 1))
	var gems := GameState.get_balance(&"gems")
	# The map's `third_branch` flag is the Magica "Fourth Branch" node (unit slot 3);
	# cards such as Guardian Bond can add the same bonus stat.
	var workshop_flags: Dictionary = {
		"third_branch": ModifierService.get_stat(&"unit_slot_bonus", 0.0) >= 1.0,
	}
	return UnitSlotRules.meets_requirement(requirement, level, gems, workshop_flags)
