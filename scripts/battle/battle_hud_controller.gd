## BattleHudController — binds battle state to the BattleHUD and routes sheets.
##
## This is the M2 extraction of the HUD half of the old 540-line controller. It
## never changes run state directly: it calls BattleController APIs and renders
## the data those calls return. M3 adds the upgrade-panel purchase handler, speed
## lock state, pause routing and the affordability dot.
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
	_hud.upgrade_open_requested.connect(_on_upgrade_open_requested)
	_hud.upgrade_closed.connect(_on_upgrade_closed)
	_hud.speed_requested.connect(_on_speed_requested)
	_hud.debug_unlock_requested.connect(_on_debug_unlock_requested)
	_hud.pause_requested.connect(_on_pause_requested)
	_hud.resume_requested.connect(_on_resume_requested)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.abandon_requested.connect(_on_abandon_requested)
	_hud.set_upgrade_purchase_handler(_purchase_upgrade)
	_hud.set_upgrade_open_handler(_open_tower_row)

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
	_hud.set_gems(GameState.get_balance(&"gems"))
	var tree := _battle.get_tree_entity()
	_hud.set_tree_hp(tree.hp, tree.max_hp)
	_hud.set_elapsed(0.0)
	_hud.hide_boss()
	_hud.hide_countdown()
	refresh_speed_control()
	_hud.set_next_wave_uses(_battle.get_next_wave_uses())
	refresh_upgrade_availability()


func _process(delta: float) -> void:
	if _battle == null or _hud == null:
		return
	_elapsed_timer += delta
	if _elapsed_timer >= 0.25:
		_elapsed_timer = 0.0
		_hud.set_elapsed(_battle.get_elapsed())


## Android back / Esc while a run is active: never leaves without confirm.
func handle_back_request() -> bool:
	if _battle == null or _hud == null or _battle.is_finished():
		return false
	if _hud.is_pause_open():
		_hud.hide_pause()
		_battle.set_paused(false)
		return true
	_on_pause_requested()
	return true


func close_all() -> void:
	if _build_sheet == null:
		return
	_build_sheet.close()
	_tower_sheet.close()
	_unit_slots.close()
	_hud.hide_upgrade_panel()
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


## Opens the generated upgrade sheet (Tree tab) for the HUD/tools.
func open_upgrade_panel(tab: StringName = &"tree") -> void:
	if _battle == null or _battle.is_finished():
		return
	close_all()
	_hud.show_upgrade_panel(_battle.upgrade_rows(), tab)
	_battle.set_sheet_open(true)


func open_tower_sheet_for(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	close_all()
	_tower_sheet.open(tower)


## Re-renders row values in place and updates the affordability dot.
func refresh_upgrade_panel() -> void:
	if _hud.is_upgrade_panel_open():
		_hud.update_upgrade_panel(_battle.upgrade_rows())
	refresh_upgrade_availability()


func refresh_upgrade_availability() -> void:
	if _hud != null and _battle != null:
		_hud.set_upgrade_available(_battle.has_affordable_upgrade())


## Re-applies the segmented speed state after an unlock or a speed change.
func refresh_speed_control() -> void:
	if _hud == null or _battle == null:
		return
	_hud.set_speed_state(_battle.get_sim_speed(), {
		1.5: _battle.can_use_speed(1.5),
		2.0: _battle.can_use_speed(2.0),
	})


## Tooling-only: shows the pause overlay for a screenshot capture.
func debug_open_pause() -> void:
	_on_pause_requested()


# --- HUD request handlers ---------------------------------------------------------


## Synchronous purchase used by UpgradePanel's hold-to-buy; returns SpendResult.
func _purchase_upgrade(kind: StringName, row_id: StringName) -> SpendResult:
	return _battle.buy_upgrade_row(kind, row_id)


func _open_tower_row(row_id: StringName) -> void:
	_battle.open_tower_row(row_id)


func _on_build_requested(tower_id: StringName) -> void:
	_build_sheet.build(tower_id)
	refresh_upgrade_availability()


func _on_tower_upgrade_requested() -> void:
	_tower_sheet.upgrade()


func _on_tower_sell_requested() -> void:
	_tower_sheet.sell()


func _on_unit_place_requested(unit_id: StringName) -> void:
	_unit_slots.place(unit_id)
	refresh_upgrade_availability()


func _on_unit_upgrade_requested() -> void:
	_unit_slots.upgrade()


func _on_next_wave_requested() -> void:
	if _battle.request_next_wave():
		_hud.set_next_wave_uses(_battle.get_next_wave_uses())


func _on_upgrade_open_requested() -> void:
	open_upgrade_panel()


func _on_upgrade_closed() -> void:
	_battle.set_sheet_open(false)
	refresh_upgrade_availability()


func _on_speed_requested(speed: float) -> void:
	if _battle.set_sim_speed(speed):
		refresh_speed_control()


func _on_debug_unlock_requested(unlock_id: StringName) -> void:
	if _battle.debug_unlock_speed(unlock_id):
		refresh_speed_control()
		_hud.show_banner(LocaleService.t("battle.debug_unlocked", "Speed unlocked (debug)"))


func _on_pause_requested() -> void:
	if _battle.is_finished() or _hud.is_pause_open():
		return
	close_all()
	_battle.set_paused(true)
	_hud.show_pause(_pause_stats())
	_hud.set_next_wave_uses(_battle.get_next_wave_uses())


func _on_resume_requested() -> void:
	_hud.hide_pause()
	_battle.set_paused(false)


func _on_restart_requested() -> void:
	_battle.restart_run()


func _on_abandon_requested() -> void:
	_hud.hide_pause()
	_battle.abandon_run()


func _pause_stats() -> String:
	var tree := _battle.get_tree_entity()
	return "%s %d  ·  %s %d  ·  %s %s  ·  %s %d  ·  %s %d%%" % [
		LocaleService.t("battle.wave", "Wave"), RunState.wave,
		LocaleService.t("summary.kills", "Kills"), _battle.get_kills(),
		LocaleService.t("summary.time", "Time"), TimeService.format_clock(int(_battle.get_elapsed())),
		LocaleService.t("battle.cash", "Cash"), _battle.get_cash(),
		LocaleService.t("battle.hp", "HP"), int(round(tree.hp_ratio() * 100.0)),
	]


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
	refresh_upgrade_panel()


func _on_tree_hp_changed(current_hp: float, maximum: float) -> void:
	_hud.set_tree_hp(current_hp, maximum)


func _on_boss_spawned(enemy: Enemy) -> void:
	if enemy == null or enemy.data == null:
		return
	var boss_name := LocaleService.t(enemy.data.display_name_key, enemy.data.display_name)
	EventBus.boss_spawned.emit()
	_hud.show_boss(boss_name, enemy.hp, enemy.max_hp, enemy.armor)
	_hud.show_banner("%s: %s" % [LocaleService.t("battle.boss_incoming", "Boss incoming"), boss_name])


func _on_boss_hp_changed(current_hp: float, max_hp: float) -> void:
	_hud.update_boss(current_hp, max_hp)


func _on_boss_removed() -> void:
	EventBus.boss_removed.emit()
	_hud.hide_boss()


# --- wave flow --------------------------------------------------------------------


func _on_wave_started(wave: int) -> void:
	var every: int = _battle.get_wave_table().boss_every
	EventBus.wave_started.emit(wave, every > 0 and wave % every == 0)
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
	_hud.set_next_wave_uses(_battle.get_next_wave_uses())


func _on_prep_skipped(bonus: int) -> void:
	_hud.hide_countdown()
	_hud.show_banner("%s  +%d" % [LocaleService.t("battle.early_wave", "Early wave"), bonus])


func _on_countdown_changed(seconds_left: int) -> void:
	_hud.set_countdown(seconds_left)
