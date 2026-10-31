## TowerSheet — upgrade/sell flow for one selected tower.
##
## Builds a plain stat dictionary for BattleHUD (presentation) and performs the
## cash transactions through BattleController. Range circle highlighting is owned
## by the controller's RangeIndicator.
class_name TowerSheet
extends RefCounted

var _battle: BattleController
var _hud: BattleHUD
var _tower: Tower


func setup(battle: BattleController, hud: BattleHUD) -> void:
	_battle = battle
	_hud = hud


func open(tower: Tower) -> void:
	if _battle == null or _battle.is_finished() or tower == null:
		return
	close()
	_tower = tower
	_hud.show_tower_sheet(build_info())
	_battle.show_range_indicator(tower.global_position, tower.effective_range())
	_battle.set_sheet_open(true)


func upgrade() -> bool:
	if _tower == null:
		return false
	if not _battle.upgrade_tower(_tower):
		refresh()
		return false
	refresh()
	return true


func sell() -> int:
	if _tower == null:
		return 0
	var refund := _battle.sell_tower(_tower)
	close()
	if refund > 0:
		_hud.show_banner("%s  +%d" % [LocaleService.t("battle.sold", "Sold"), refund])
	return refund


## Re-renders the sheet after cash or level changes.
func refresh() -> void:
	if _tower == null or not is_instance_valid(_tower):
		return
	_hud.show_tower_sheet(build_info())
	_battle.show_range_indicator(_tower.global_position, _tower.effective_range())


func close() -> void:
	_tower = null
	if _hud != null:
		_hud.hide_tower_sheet()
	if _battle != null:
		_battle.hide_range_indicator()
		_battle.set_sheet_open(false)


func is_open() -> bool:
	return _tower != null


func build_info() -> Dictionary:
	var data := _tower.data
	var maxed := not _tower.can_upgrade()
	var cost := _tower.upgrade_cost()
	var aura := _tower.aura_values()
	return {
		"name_key": data.display_name_key,
		"name": data.display_name,
		"level": _tower.level,
		"max_level": data.levels.max_level if data.levels != null else 10,
		"damage": _tower.damage_at(_tower.level),
		"next_damage": _tower.damage_at(_tower.level + 1) if not maxed else _tower.damage_at(_tower.level),
		"interval": _tower.interval_at(_tower.level),
		"next_interval": _tower.interval_at(_tower.level + 1) if not maxed else _tower.interval_at(_tower.level),
		"range": _tower.range_at(_tower.level),
		"next_range": _tower.range_at(_tower.level + 1) if not maxed else _tower.range_at(_tower.level),
		"splash_radius": data.splash_radius,
		"slow_pct": data.status_on_hit.slow_pct if data.status_on_hit != null else 0.0,
		"is_aura": data.has_aura(),
		"aura_radius": float(aura["radius"]),
		"aura_damage": float(aura["damage"]),
		"aura_speed": float(aura["speed"]),
		"upgrade_cost": cost,
		"maxed": maxed,
		"affordable": _battle.get_cash() >= cost and not maxed,
		"sell_value": _tower.sell_value(),
	}
