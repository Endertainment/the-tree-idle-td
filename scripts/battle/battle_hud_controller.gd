## BattleHudController — binds battle state to the BattleHUD and routes sheets.
##
## This is the M2 extraction of the HUD half of the old 540-line controller. It
## never changes run state directly: it calls BattleController APIs and renders
## the data those calls return. Boss bar binding lives here as well.
class_name BattleHudController
extends Node

var _battle: BattleController
var _hud: BattleHUD
var _build_sheet: BuildSheet
var _tower_sheet: TowerSheet
var _unit_slots: UnitSlots
var _elapsed_timer: float = 0.0


## Wires every signal once. Called by BattleController after the arena exists.
func setup(battle: BattleController, hud: BattleHUD) -> void:
	_battle = battle
	_hud = hud

	_build_sheet = BuildSheet.new()
	_build_sheet.setup(battle, hud)
	_tower_sheet = TowerSheet.new()
	_tower_sheet.setup(battle, hud)
	_unit_slots = UnitSlots.new()
	_unit_slots.setup(
		battle,
		hud,
		battle.get_unit_slots_root(),
		battle.get_unit_slot_scene(),
		battle.get_map_data()
	)
	_unit_slots.slot_pressed.connect(_on_unit_slot_pressed)

	_hud.build_requested.connect(_on_build_requested)
	_hud.next_wave_requested.connect(_on_next_wave_requested)
	_hud.dismiss_requested.connect(close_all)
	_hud.tower_upgrade_requested.connect(_on_tower_upgrade_requested)
	_hud.tower_sell_requested.connect(_on_tower_sell_requested)
	_hud.unit_place_requested.connect(_on_unit_place_requested)
	_hud.unit_upgrade_requested.connect(_on_unit_upgrade_requested)

	_battle.pedestal_pressed.connect(_on_pedestal_pressed)
	_battle.tower_pressed.connect(_on_tower_pressed)
	_battle.boss_spawned.connect(_on_boss_spawned)
	_battle.boss_hp_changed.connect(_on_boss_hp_changed)
	_battle.boss_removed.connect(_on_boss_removed)
	_battle.cash_changed.connect(_on_cash_changed)
	_battle.tree_hp_changed.connect(_on_tree_hp_changed)

	var manager := _battle.get_wave_manager()
	manager.wave_started.connect(_on_wave_started)
	manager.wave_cleared.connect(_on_wave_cleared)
	manager.prep_started.connect(_on_prep_started)
	manager.prep_skipped.connect(_on_prep_skipped)
	manager.countdown_changed.connect(_on_countdown_changed)

	_hud.set_wave(1, _battle.get_wave_table().wave_count())
	_hud.set_cash(_battle.get_cash())
	var tree := _battle.get_tree_entity()
	_hud.set_tree_hp(tree.hp, tree.max_hp)
	_hud.set_elapsed(0.0)
	_hud.hide_boss()
	_hud.hide_countdown()


func _process(delta: float) -> void:
	if _battle == null or _hud == null:
		return
	_elapsed_timer += delta
	if _elapsed_timer >= 0.25:
		_elapsed_timer = 0.0
		_hud.set_elapsed(_battle.get_elapsed())


func close_all() -> void:
	if _build_sheet == null:
		return
	_build_sheet.close()
	_tower_sheet.close()
	_unit_slots.close()
	_battle.set_sheet_open(false)


func is_boss_bar_visible() -> bool:
	return _hud != null and _hud.is_boss_bar_visible()


func get_unit_slots() -> Array[UnitSlot]:
	if _unit_slots == null:
		return []
	return _unit_slots.get_slots()


## Tooling-only preview helpers used by tools/capture_scene.gd.
func debug_open_tower_sheet(tower: Tower) -> void:
	close_all()
	_tower_sheet.open(tower)


func debug_open_build_sheet(pedestal: Pedestal) -> void:
	close_all()
	_build_sheet.open(pedestal)


func debug_open_unit_sheet(slot: UnitSlot) -> void:
	close_all()
	_unit_slots.open(slot)


# --- HUD request handlers ---------------------------------------------------------


func _on_build_requested(tower_id: StringName) -> void:
	_build_sheet.build(tower_id)


func _on_tower_upgrade_requested() -> void:
	_tower_sheet.upgrade()


func _on_tower_sell_requested() -> void:
	_tower_sheet.sell()


func _on_unit_place_requested(unit_id: StringName) -> void:
	_unit_slots.place(unit_id)


func _on_unit_upgrade_requested() -> void:
	_unit_slots.upgrade()


func _on_next_wave_requested() -> void:
	_battle.request_next_wave()


# --- arena interaction ------------------------------------------------------------


func _on_pedestal_pressed(pedestal: Pedestal) -> void:
	close_all()
	_build_sheet.open(pedestal)


func _on_tower_pressed(tower: Tower) -> void:
	close_all()
	_tower_sheet.open(tower)


func _on_unit_slot_pressed(slot: UnitSlot) -> void:
	close_all()
	_unit_slots.open(slot)


# --- battle state -----------------------------------------------------------------


func _on_cash_changed(amount: int) -> void:
	_hud.set_cash(amount)
	if _tower_sheet != null and _tower_sheet.is_open():
		_tower_sheet.refresh()
	if _unit_slots != null and _unit_slots.is_open():
		_unit_slots.refresh()


func _on_tree_hp_changed(current_hp: float, maximum: float) -> void:
	_hud.set_tree_hp(current_hp, maximum)


func _on_boss_spawned(enemy: Enemy) -> void:
	if enemy == null or enemy.data == null:
		return
	var boss_name := LocaleService.t(enemy.data.display_name_key, enemy.data.display_name)
	_hud.show_boss(boss_name, enemy.hp, enemy.max_hp, enemy.armor)
	_hud.show_banner("%s: %s" % [LocaleService.t("battle.boss_incoming", "Boss incoming"), boss_name])


func _on_boss_hp_changed(current_hp: float, max_hp: float) -> void:
	_hud.update_boss(current_hp, max_hp)


func _on_boss_removed() -> void:
	_hud.hide_boss()


# --- wave flow --------------------------------------------------------------------


func _on_wave_started(wave: int) -> void:
	_hud.set_wave(wave, _battle.get_wave_table().wave_count())
	_hud.hide_countdown()


func _on_wave_cleared(wave: int) -> void:
	var bonus := _battle.get_wave_table().clear_bonus(wave)
	_hud.show_banner("%s %d  +%d %s" % [
		LocaleService.t("battle.wave_cleared", "Wave cleared"),
		wave,
		bonus,
		LocaleService.t("battle.cash", "cash"),
	])


func _on_prep_started(next_wave: int, duration: float) -> void:
	_hud.show_countdown(duration, _battle.get_wave_table().skip_bonus(next_wave))


func _on_prep_skipped(bonus: int) -> void:
	_hud.hide_countdown()
	_hud.show_banner("%s  +%d" % [LocaleService.t("battle.early_wave", "Early wave"), bonus])


func _on_countdown_changed(seconds_left: int) -> void:
	_hud.set_countdown(seconds_left)
