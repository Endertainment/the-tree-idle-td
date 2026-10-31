## BuildSheet — build-flow collaborator for the selected pedestal.
##
## Owns only the selection + transaction glue. Rendering, pause state and the
## actual tower node live in BattleHUD / BattleController.
class_name BuildSheet
extends RefCounted

var _battle: BattleController
var _hud: BattleHUD
var _selected: Pedestal


func setup(battle: BattleController, hud: BattleHUD) -> void:
	_battle = battle
	_hud = hud


func open(pedestal: Pedestal) -> void:
	if _battle == null or _battle.is_finished() or pedestal == null:
		return
	if _selected == pedestal and _hud.is_build_sheet_open():
		return
	close()
	_selected = pedestal
	pedestal.select()
	_hud.show_build_sheet(_battle.build_options())
	_battle.set_sheet_open(true)


## Builds `tower_id` on the selected pedestal; keeps the sheet open on failure.
func build(tower_id: StringName) -> bool:
	if _selected == null:
		return false
	if _battle.build_tower(_selected, tower_id):
		close()
		return true
	return false


func close() -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.deselect()
	_selected = null
	if _hud != null:
		_hud.hide_build_sheet()
	if _battle != null:
		_battle.set_sheet_open(false)


func is_open() -> bool:
	return _selected != null


func get_selected() -> Pedestal:
	return _selected
