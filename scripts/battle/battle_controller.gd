## BattleController — owns one battle run: arena, economy, waves and run flow.
##
## M2 split: HUD binding lives in BattleHudController, sheets in BuildSheet /
## TowerSheet / UnitSlots / UpgradePanel, the enemy pool in EnemyManager,
## projectile + hit resolution in CombatSystem and screenshot staging in
## BattlePreview. M3 adds the RunWallet transaction API (single cash mutation
## point), Tree upgrade tracks and the pause/speed/abandon flow. This script keeps
## state and flow only: cash transactions, build/upgrade/sell, aura ticking, boss
## tracking and run end.
##
## All damage goes through DamageResolver; all numbers come from resources. Scene
## collaborators are addressed through public APIs, never `get_node("../../")`.
class_name BattleController
extends Node2D

signal cash_changed(amount: int)
signal tree_hp_changed(current_hp: float, maximum: float)
signal pedestal_pressed(pedestal: Pedestal)
signal tower_pressed(tower: Tower)
signal boss_spawned(enemy: Enemy)
signal boss_hp_changed(current_hp: float, max_hp: float)
signal boss_removed

const COLLAPSE_SECONDS := 1.2
const AURA_INTERVAL := 0.1
## Ranged enemies (ported roster) fire along the lane; these sprites are the
## readable in-flight part of that attack. Fixed pool, never freed mid-run.
const ENEMY_SHOT_POOL := 8
const ENEMY_SHOT_MIN_DURATION := 0.12
const FX_DEATH_TEXTURE := preload("res://assets/art/battle/fx/fx_death.png")
const RUN_UPGRADE_SOURCE := &"run_tree_upgrades"
const DESIGN_SIZE := Vector2(1080.0, 1920.0)

## The battlefield is authored in a 1080x1920 design space. Tall phones (2.2:1)
## get extra vertical space that the arena art does not cover on its own, which
## used to leave a grey band under the field. Wrap every world node in a `World`
## container, centre the design area in the real viewport, and stretch the
## background beyond the design rect so the screen is always covered.
var _world: Node2D


func _fit_world_to_viewport() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	move_child(_world, 0)
	for node in [$Arena, $Tree, $Enemies, $Projectiles, $FX, $DamageNumbers, $RangeIndicator]:
		(node as Node2D).reparent(_world, false)
	_apply_world_transform()
	get_viewport().size_changed.connect(_apply_world_transform)


func _apply_world_transform() -> void:
	if _world == null:
		return
	var viewport_size := get_viewport_rect().size
	var fit := viewport_size.x / DESIGN_SIZE.x
	_world.scale = Vector2(fit, fit)
	_world.position = Vector2(0.0, (viewport_size.y - DESIGN_SIZE.y * fit) * 0.5)
	if _background != null:
		# Cover, not contain: the background must reach every screen edge.
		var cover := maxf(
			viewport_size.x / (DESIGN_SIZE.x * fit),
			viewport_size.y / (DESIGN_SIZE.y * fit)
		)
		_background.scale = Vector2(cover, cover)

@export var map_data: MapData
@export var wave_table: WaveTable
@export var tree_data: TreeData
@export var enemy_resources: Array[EnemyData] = []
@export var tower_resources: Array[TowerData] = []
@export var unit_resources: Array[UnitData] = []
## Optional explicit track list; empty means "load every .tres from the upgrades
## directory", which keeps adding a track data-only.
@export var upgrade_tracks: Array[UpgradeTrack] = []
@export var enemy_scene: PackedScene
@export var tower_scene: PackedScene
@export var unit_scene: PackedScene
@export var pedestal_scene: PackedScene
@export var unit_slot_scene: PackedScene
@export var projectile_scene: PackedScene
@export var run_summary_scene: PackedScene

@onready var _background: Sprite2D = $Arena/Background
@onready var _lanes_root: Node2D = $Arena/Lanes
@onready var _pedestals_root: Node2D = $Arena/Pedestals
@onready var _unit_slots_root: Node2D = $Arena/UnitSlots
@onready var _towers_root: Node2D = $Arena/Towers
@onready var _units_root: Node2D = $Arena/Units
@onready var _tree: TreeEntity = $Tree
@onready var _enemies_root: Node2D = $Enemies
@onready var _projectiles_root: Node2D = $Projectiles
@onready var _fx: FxPool = $FX
@onready var _damage_numbers: DamageNumbers = $DamageNumbers
@onready var _range_indicator: RangeIndicator = $RangeIndicator
@onready var _clock: BattleClock = $BattleClock
@onready var _hud: BattleHUD = $BattleHUD
@onready var _hud_controller: Node = $BattleHudController

var _arena: BattleArena
var _enemy_lookup: Dictionary = {}
var _tower_lookup: Dictionary = {}
var _unit_lookup: Dictionary = {}
var _run_rng: RandomNumberGenerator
var _wave_manager: WaveManager
var _spawner: Spawner
var _aura_system: AuraSystem
var _enemy_manager: EnemyManager
var _combat: CombatSystem
var _target_index: SpatialHash
var _wallet: RunWallet
var _upgrades: TreeUpgrades
var _debug_overlay: DebugOverlay
var _summary: RunSummary
var _towers: Array[Tower] = []
var _units: Array[Unit] = []
var _unit_slots: Array[UnitSlot] = []
var _active_boss: Enemy
var _kills: int = 0
var _leaks: int = 0
var _run_towers_built: int = 0
var _cleared_waves: int = 0
var _elapsed: float = 0.0
var _aura_timer: float = 0.0
var _finished: bool = false
var _paused: bool = false
var _sheet_open: bool = false
var _app_paused: bool = false
var _shake_left: float = 0.0
var _shake_strength: float = 0.0
var _last_tree_hp: float = -1.0
## In-flight ranged-enemy projectiles: {sprite, active, from, to, duration,
## elapsed, damage_pct}. One dict per pooled sprite, reused forever.
var _enemy_shots: Array[Dictionary] = []
var _ranged_shots_fired: int = 0
var _ranged_hits_landed: int = 0


func _ready() -> void:
	if not _validate_content():
		return
	_fit_world_to_viewport()
	var run_seed := _fresh_seed()
	RunState.reset(run_seed)
	_run_rng = RngService.new_run_rng(run_seed)
	_wallet = RunWallet.new(_starting_cash())
	_upgrades = TreeUpgrades.new()
	_upgrades.setup(_resolve_upgrade_tracks())
	_apply_run_modifiers()
	_sync_cash()

	_target_index = SpatialHash.new(160.0)
	_aura_system = AuraSystem.new()
	_arena = BattleArena.new()
	_arena.build(
		map_data,
		_background,
		_lanes_root,
		_pedestals_root,
		pedestal_scene,
		_on_pedestal_pressed
	)
	_build_tree()
	_build_systems()
	_hud_controller.call(&"setup", self, _hud)
	EventBus.card_dropped.connect(_on_card_dropped)
	EventBus.second_wind_used.connect(_on_second_wind_used)
	if App.is_debug_build():
		_debug_overlay = DebugOverlay.new()
		_debug_overlay.name = "DebugOverlay"
		add_child(_debug_overlay)
		_debug_overlay.setup(self)
	_grant_free_archer()
	AdsService.start_run(RunState.run_id)
	EventBus.run_started.emit()
	_wave_manager.start()


func _exit_tree() -> void:
	# Run-scoped sources must not leak into the menu or the next run.
	ModifierService.remove_source(RUN_UPGRADE_SOURCE)


func _physics_process(delta: float) -> void:
	_update_shake(delta)
	if _finished:
		return
	var dt := _clock.scaled(delta)
	if dt <= 0.0:
		return
	_target_index.rebuild(_enemy_manager.get_active())
	_elapsed += dt
	_tick_enemy_shots(dt)
	_wave_manager.tick(dt)
	_aura_timer += dt
	if _aura_timer >= AURA_INTERVAL:
		_aura_timer = 0.0
		_refresh_auras()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_hud_controller.call(&"close_all")


# --- public API (HUD, collaborators, tests and tools) ---------------------------


## Android back / Esc is owned by the HUD (pause + confirm), never a silent exit.
func handle_back_request() -> bool:
	if _finished or _hud_controller == null:
		return false
	return bool(_hud_controller.call(&"handle_back_request"))


func get_clock() -> BattleClock:
	return _clock


func get_hud() -> BattleHUD:
	return _hud


func get_tree_entity() -> TreeEntity:
	return _tree


func get_wave_manager() -> WaveManager:
	return _wave_manager


func get_wave_table() -> WaveTable:
	return wave_table


func get_map_data() -> MapData:
	return map_data


func get_unit_slots_root() -> Node2D:
	return _unit_slots_root


func get_unit_slot_scene() -> PackedScene:
	return unit_slot_scene


func get_cash() -> int:
	return _wallet.get_cash()


func get_wallet() -> RunWallet:
	return _wallet


func get_tree_upgrades() -> TreeUpgrades:
	return _upgrades


func get_run_id() -> String:
	return RunState.run_id


## The run summary node once the run has ended (null before that).
func get_run_summary() -> RunSummary:
	return _summary


func get_boss_waves_cleared() -> int:
	if wave_table == null or wave_table.boss_every <= 0:
		return 0
	return _cleared_waves / wave_table.boss_every


func get_kills() -> int:
	return _kills


func get_leaks() -> int:
	return _leaks


func get_elapsed() -> float:
	return _elapsed


func get_spawned_count() -> int:
	return _enemy_manager.get_spawned_total() if _enemy_manager != null else 0


func get_projectile_count() -> int:
	return _combat.get_active_count() if _combat != null else 0


## Snapshot used by the F3 debug overlay; cheap and allocation-light per frame.
func get_debug_snapshot() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"enemies": get_active_enemy_count(),
		"projectiles": get_projectile_count(),
		"cash": get_cash(),
		"speed": get_sim_speed(),
		"wave": RunState.wave,
		"cleared": _cleared_waves,
		"kills": _kills,
		"paused": _paused,
		"finished": _finished,
		"upgrades": _upgrades.get_levels() if _upgrades != null else {},
	}


func get_cleared_waves() -> int:
	return _cleared_waves


func get_tower_count() -> int:
	return _towers.size()


func get_unit_count() -> int:
	return _units.size()


func get_pedestal_count() -> int:
	return _arena.pedestals.size()


func get_pedestal(index: int) -> Pedestal:
	return _arena.get_pedestal(index)


func get_towers() -> Array[Tower]:
	return _towers


func get_units() -> Array[Unit]:
	return _units


func get_tower_data(tower_id: StringName) -> TowerData:
	return _tower_lookup.get(tower_id, null) as TowerData


func get_unit_data(unit_id: StringName) -> UnitData:
	return _unit_lookup.get(unit_id, null) as UnitData


func get_enemy_data(enemy_id: StringName) -> EnemyData:
	return _enemy_lookup.get(enemy_id, null) as EnemyData


func get_active_enemy_count() -> int:
	return _enemy_manager.get_active_count() if _enemy_manager != null else 0


func get_active_boss() -> Enemy:
	if _active_boss != null and is_instance_valid(_active_boss) and _active_boss.is_alive():
		return _active_boss
	return null


func get_slowed_enemy_count() -> int:
	var count := 0
	if _enemy_manager == null:
		return count
	for enemy in _enemy_manager.get_active():
		if is_instance_valid(enemy) and enemy.is_alive() and enemy.is_slowed():
			count += 1
	return count


func get_damage_number_count() -> int:
	return _damage_numbers.active_count()


func is_finished() -> bool:
	return _finished


func is_boss_bar_visible() -> bool:
	return bool(_hud_controller.call(&"is_boss_bar_visible"))


## Adds in-run cash from a legitimate source and notifies the HUD.
## `amount` must be positive; spending uses try_spend_cash().
func add_cash(amount: int, reason: StringName = &"grant") -> void:
	_wallet.add(amount, reason)
	_sync_cash()


## Starting cash after the workshop "Starting Cash" track.
func _starting_cash() -> int:
	var base := float(wave_table.starting_cash)
	return maxi(int(round(ModifierService.get_stat(&"starting_cash", base))), 1)


## In-run price after the "In-Run Discount" track (no-op at level 0).
func _price(base_cost: int) -> int:
	var discount := clampf(ModifierService.get_stat(&"in_run_discount", 0.0), 0.0, 0.8)
	return maxi(1, int(round(float(base_cost) * (1.0 - discount))))


## Cash reward after the "Cash Gain" track (refunds are not scaled).
func _cash_reward(base_amount: int) -> int:
	var gain := maxf(ModifierService.get_stat(&"cash_gain", 1.0), 0.0)
	return int(round(float(base_amount) * gain))


## Wave-clear cash: table bonus + "Wave Clear Bonus" track, then Cash Gain.
func _wave_clear_cash(wave: int) -> int:
	var flat := int(round(ModifierService.get_stat(&"wave_clear_bonus", 0.0)))
	return _cash_reward(wave_table.clear_bonus(wave) + flat)


## Spends cash atomically and returns the typed result. The only spend path.
func try_spend_cash(amount: int, reason: StringName) -> SpendResult:
	var result := _wallet.try_spend(amount, reason)
	if result.is_ok():
		_sync_cash()
	return result


## Mirrors the wallet balance into RunState and notifies listeners. Cash is changed
## only through RunWallet, so this is the single sync point.
func _sync_cash() -> void:
	RunState.cash = _wallet.get_cash()
	EventBus.run_cash_changed.emit(RunState.cash)
	cash_changed.emit(RunState.cash)


## Builds a tower on a free pedestal. Public so tools/tests can drive a build.
func build_tower(pedestal: Pedestal, tower_id: StringName) -> bool:
	if _finished or pedestal == null or not pedestal.is_buildable():
		return false
	var data := _tower_lookup.get(tower_id, null) as TowerData
	if data == null or not try_spend_cash(_price(data.build_cost), &"build_tower").is_ok():
		AudioBus.play_ui(&"ui_error")
		return false
	if not _place_tower(pedestal, data):
		add_cash(_price(data.build_cost), &"refund_tower")
		return false
	return true


## Instantiates and registers one tower without a cash transaction.
func _place_tower(pedestal: Pedestal, data: TowerData) -> bool:
	if pedestal == null or data == null or not pedestal.is_buildable():
		return false
	var tower := tower_scene.instantiate() as Tower
	_towers_root.add_child(tower)
	tower.global_position = pedestal.global_position
	tower.setup(data, _clock, _target_index)
	tower.shot_requested.connect(_on_shot_requested)
	tower.pressed.connect(_on_tower_pressed)
	pedestal.mark_occupied(tower)
	_towers.append(tower)
	_run_towers_built += 1
	_refresh_auras()
	EventBus.tower_built.emit(data.id, _run_towers_built)
	return true


## Ancient Memory: the first free pedestal starts with an Archer Tower.
func _grant_free_archer() -> void:
	if ModifierService.get_stat(&"free_archer_voucher", 0.0) < 1.0:
		return
	var data := _tower_lookup.get(&"tower_archer", null) as TowerData
	if data == null:
		return
	for pedestal: Pedestal in _arena.pedestals:
		if pedestal != null and pedestal.is_buildable():
			_place_tower(pedestal, data)
			return


## Upgrades a built tower one level (cash checked here, level in Tower).
func upgrade_tower(tower: Tower) -> bool:
	if _finished or tower == null or not is_instance_valid(tower) or not tower.can_upgrade():
		return false
	var cost := _price(tower.upgrade_cost())
	if not try_spend_cash(cost, &"upgrade_tower").is_ok():
		AudioBus.play_ui(&"ui_error")
		return false
	if not tower.upgrade():
		add_cash(cost, &"refund_tower")
		return false
	AudioBus.play_sfx_id(&"upgrade_buy")
	_refresh_auras()
	_refresh_upgrade_panel()
	return true


## Sells a tower for its data refund and frees its pedestal.
func sell_tower(tower: Tower) -> int:
	if _finished or tower == null or not is_instance_valid(tower):
		return 0
	var refund := tower.sell_value()
	var pedestal := _pedestal_for_tower(tower)
	_towers.erase(tower)
	tower.queue_free()
	if pedestal != null:
		pedestal.clear()
	add_cash(refund, &"sell_tower")
	AudioBus.play_ui(&"tower_sell")
	_refresh_auras()
	_refresh_upgrade_panel()
	return refund


## All buildable tower types with affordability, for the build sheet.
func build_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for data in tower_resources:
		if data == null:
			continue
		options.append({
			"data": data,
			"affordable": _wallet.can_afford(_price(data.build_cost)),
			"cost": _price(data.build_cost),
		})
	return options


## Places a guardian unit on a free, unlocked canopy slot.
func place_unit(slot: UnitSlot, unit_id: StringName) -> bool:
	if _finished or slot == null or not slot.is_unlocked() or not slot.is_empty():
		return false
	var data := _unit_lookup.get(unit_id, null) as UnitData
	if data == null or not try_spend_cash(_price(data.placement_cost), &"place_unit").is_ok():
		return false
	var unit := unit_scene.instantiate() as Unit
	_units_root.add_child(unit)
	unit.global_position = slot.global_position
	unit.setup(data, _clock, _target_index, slot.index)
	unit.shot_requested.connect(_on_shot_requested)
	slot.mark_occupied(unit)
	_units.append(unit)
	return true


## Upgrades a placed unit one level (cash checked here, level in Unit).
func upgrade_unit(unit: Unit) -> bool:
	if _finished or unit == null or not is_instance_valid(unit) or not unit.can_upgrade():
		return false
	var cost := _price(unit.upgrade_cost())
	if not try_spend_cash(cost, &"upgrade_unit").is_ok():
		return false
	if not unit.upgrade():
		add_cash(cost, &"refund_unit")
		return false
	_refresh_upgrade_panel()
	return true


## Placement options for the unit sheet (all unit types + affordability).
func unit_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for data in unit_resources:
		if data == null:
			continue
		options.append({
			"data": data,
			"affordable": _wallet.can_afford(_price(data.placement_cost)),
			"cost": _price(data.placement_cost),
		})
	return options


## Called by UnitSlots once it has instantiated the slot nodes.
func register_unit_slots(slots: Array[UnitSlot]) -> void:
	_unit_slots = slots


## Tooling helper: unlocks every canopy slot (perf probe, preview capture).
## Never called by gameplay flow; workshop/level gates stay enforced for players.
func debug_unlock_unit_slots() -> void:
	for slot in _unit_slots:
		if is_instance_valid(slot):
			slot.set_unlocked(true)


func get_unit_slots() -> Array[UnitSlot]:
	return _unit_slots


# --- tree upgrades ---------------------------------------------------------------


## Purchases one Tree upgrade level: eligibility check, wallet transaction, then
## the level record. Returns the typed result so hold-to-buy can stop cleanly.
func try_buy_tree_upgrade(track_id: StringName) -> SpendResult:
	if _finished:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "battle.run_over", 0, get_cash())
	var check := _upgrades.can_buy(track_id, _wallet)
	if not check.is_ok():
		return check
	var result := try_spend_cash(_price(check.amount), &"tree_upgrade")
	if not result.is_ok():
		AudioBus.play_ui(&"ui_error")
		return result
	AudioBus.play_sfx_id(&"upgrade_buy")
	_upgrades.record_purchase(track_id)
	_apply_run_modifiers()
	_tree.play_level_up()
	_refresh_upgrade_panel()
	return result


## Purchases one unit upgrade by panel row id (used by the Units tab).
func try_buy_unit_upgrade(row_id: StringName) -> SpendResult:
	var unit := _unit_for_row(row_id)
	if unit == null:
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "battle.unknown_upgrade", 0, get_cash())
	if not unit.can_upgrade():
		return SpendResult.failure(SpendResult.Code.MAX_LEVEL, "battle.max_level", 0, get_cash())
	var cost := _price(unit.upgrade_cost())
	var result := try_spend_cash(cost, &"upgrade_unit")
	if not result.is_ok():
		AudioBus.play_ui(&"ui_error")
		return result
	AudioBus.play_sfx_id(&"upgrade_buy")
	if not unit.upgrade():
		add_cash(cost, &"refund_unit")
		return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "battle.unknown_upgrade", cost, get_cash())
	_refresh_upgrade_panel()
	return result


## Routes one UpgradePanel purchase attempt. `kind` is tree/unit; towers open a sheet.
func buy_upgrade_row(kind: StringName, row_id: StringName) -> SpendResult:
	match kind:
		&"tree":
			return try_buy_tree_upgrade(row_id)
		&"unit":
			return try_buy_unit_upgrade(row_id)
		_:
			return SpendResult.failure(SpendResult.Code.INVALID_AMOUNT, "battle.unknown_upgrade", 0, get_cash())


## Opens the tower sheet for an UpgradePanel tower row.
func open_tower_row(row_id: StringName) -> void:
	var index := int(String(row_id).trim_prefix("tower_"))
	if index < 0 or index >= _towers.size():
		return
	_hud_controller.call(&"open_tower_sheet_for", _towers[index])


## True when any Tree/unit/tower upgrade is currently affordable (notification dot).
func has_affordable_upgrade() -> bool:
	if _finished:
		return false
	for track in _upgrades.get_tracks():
		if _upgrades.can_buy(track.id, _wallet).is_ok():
			return true
	for unit in _units:
		if unit.can_upgrade() and _wallet.can_afford(_price(unit.upgrade_cost())):
			return true
	for tower in _towers:
		if tower.can_upgrade() and _wallet.can_afford(_price(tower.upgrade_cost())):
			return true
	return false


## Row payloads for the three UpgradePanel tabs, generated from data.
func upgrade_rows() -> Dictionary:
	return {
		"tree": tree_upgrade_rows(),
		"units": unit_upgrade_rows(),
		"towers": tower_upgrade_rows(),
	}


func tree_upgrade_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for track in _upgrades.get_tracks():
		var level := _upgrades.get_level(track.id)
		var maxed := _upgrades.is_maxed(track.id)
		var check := _upgrades.can_buy(track.id, _wallet)
		var price := _price(check.amount)
		rows.append({
			"id": track.id,
			"kind": &"tree",
			"action": &"buy",
			"icon": track.icon,
			"name": LocaleService.t(track.name_key, track.name),
			"level_text": "%s %d / %d" % [LocaleService.t("battle.level_short", "Lv"), level, track.max_level],
			"current_text": track.format_value(track.value_at(level)),
			"next_text": track.format_value(track.next_value(level)),
			"delta_text": "+%s" % track.format_value(track.delta_at(level)),
			"cost": price,
			"cost_text": LocaleService.format_number(price),
			"maxed": maxed,
			"affordable": not maxed and _wallet.can_afford(price),
			"reason": _row_reason(check),
			"hold": true,
		})
	return rows


func unit_upgrade_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for unit in _units:
		if unit == null or not is_instance_valid(unit) or unit.data == null:
			continue
		var maxed := not unit.can_upgrade()
		var cost := _price(unit.upgrade_cost())
		var affordable := not maxed and _wallet.can_afford(cost)
		rows.append({
			"id": _unit_row_id(unit),
			"kind": &"unit",
			"action": &"buy",
			"icon": unit.data.icon,
			"name": LocaleService.t(unit.data.display_name_key, unit.data.display_name),
			"level_text": "%s %d / %d" % [
				LocaleService.t("battle.level_short", "Lv"),
				unit.level,
				unit.data.levels.max_level if unit.data.levels != null else 10,
			],
			"current_text": _format_damage(unit.damage_at(unit.level)),
			"next_text": _format_damage(unit.damage_at(unit.level + 1)),
			"delta_text": "+%s %s" % [
				_format_damage(unit.damage_at(unit.level + 1) - unit.damage_at(unit.level)),
				LocaleService.t("battle.damage", "damage"),
			],
			"cost": cost,
			"cost_text": LocaleService.format_number(cost),
			"maxed": maxed,
			"affordable": affordable,
			"reason": _row_reason_for(maxed, affordable),
			"hold": true,
		})
	return rows


func tower_upgrade_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index in _towers.size():
		var tower := _towers[index]
		if tower == null or not is_instance_valid(tower) or tower.data == null:
			continue
		rows.append({
			"id": StringName("tower_%d" % index),
			"kind": &"tower",
			"action": &"open",
			"icon": tower.data.icon,
			"name": LocaleService.t(tower.data.display_name_key, tower.data.display_name),
			"level_text": "%s %d / %d" % [
				LocaleService.t("battle.level_short", "Lv"),
				tower.level,
				tower.data.levels.max_level if tower.data.levels != null else 10,
			],
			"current_text": _format_damage(tower.damage_at(tower.level)),
			"next_text": _format_damage(tower.damage_at(tower.level + 1)),
			"delta_text": "",
			"cost": _price(tower.upgrade_cost()),
			"cost_text": "",
			"maxed": not tower.can_upgrade(),
			"affordable": true,
			"reason": "",
			"hold": false,
		})
	return rows


func _row_reason(result: SpendResult) -> String:
	if result.is_ok():
		return ""
	return LocaleService.t(result.reason_key, result.reason_key)


func _row_reason_for(maxed: bool, affordable: bool) -> String:
	if maxed:
		return LocaleService.t("battle.max_level", "Max level")
	if not affordable:
		return LocaleService.t("battle.not_enough_cash", "Not enough cash")
	return ""


func _format_damage(value: float) -> String:
	return str(int(roundf(value)))


func _unit_row_id(unit: Unit) -> StringName:
	return StringName("unit_slot_%d" % unit.slot_index)


func _unit_for_row(row_id: StringName) -> Unit:
	for unit in _units:
		if unit != null and is_instance_valid(unit) and _unit_row_id(unit) == row_id:
			return unit
	return null


func _resolve_upgrade_tracks() -> Array[UpgradeTrack]:
	if not upgrade_tracks.is_empty():
		return upgrade_tracks
	return TreeUpgrades.load_tracks()


## Publishes the in-run Tree tracks as one ModifierService source. Meta sources
## (workshop/cards) are registered elsewhere; the entities only read the
## aggregated value, so no stat is calculated in two places.
func _apply_run_modifiers() -> void:
	var bonuses := _upgrades.get_bonuses()
	var source: Dictionary = {}
	for key: Variant in bonuses.keys():
		var value := float(bonuses[key])
		if value <= 0.0:
			continue
		match String(key):
			"damage":
				source["tree_damage"] = {"mul": value}
			"attack_speed":
				source["attack_speed"] = {"mul": value}
			"crit_chance":
				source["crit_chance"] = {"add": value}
			"crit_damage":
				source["crit_damage"] = {"add": value}
			"range":
				source["tree_range"] = {"mul": value}
			"regen":
				source["tree_regen"] = {"add": value}
	ModifierService.add_source(RUN_UPGRADE_SOURCE, source)


# --- speed, pause and run control ------------------------------------------------


## True when the player may select `speed` (UnlockService gates; debug grants are
## persisted separately and only accepted in debug builds).
func can_use_speed(speed: float) -> bool:
	if speed <= 1.0:
		return true
	if speed >= 2.0:
		return UnlockService.is_unlocked(&"speed_2") or GameState.has_speed_boost(&"speed_2")
	if UnlockService.is_unlocked(&"speed_1_5"):
		return true
	return GameState.has_speed_boost(&"speed_1_5")


## Changes the battle simulation speed. Returns false when the speed is locked.
func set_sim_speed(speed: float) -> bool:
	if _finished or not can_use_speed(speed):
		return false
	_clock.set_speed(speed)
	return true


func get_sim_speed() -> float:
	return _clock.get_speed()


## Debug-only feature unlock (pause settings, debug builds only).
func debug_unlock_speed(unlock_id: StringName) -> bool:
	if not App.is_debug_build():
		return false
	var granted := UnlockService.grant_debug_unlock(unlock_id)
	if granted:
		_hud_controller.call(&"refresh_speed_control")
	return granted


## Freezes/resumes the battle simulation without pausing the SceneTree, so HUD
## tweens, the pause overlay and input stay responsive (spec 13.4).
func set_paused(value: bool) -> void:
	if _finished:
		return
	_paused = value
	if value:
		_clock.set_paused(true)
	elif not _sheet_open and not _app_paused:
		_clock.set_paused(false)


## App lifecycle: a backgrounded battle freezes the simulation; resume only when no
## menu/sheet is open. AudioService and SaveService handle their own pause hooks.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_app_paused = true
			if not _finished:
				_clock.set_paused(true)
		NOTIFICATION_APPLICATION_RESUMED:
			_app_paused = false
			if not _finished and not _paused and not _sheet_open:
				_clock.set_paused(false)


func is_paused() -> bool:
	return _paused


func get_next_wave_uses() -> int:
	return GameState.get_next_wave_uses()


## Restarts the run from a fresh scene (pause overlay Restart, after confirm).
func restart_run() -> void:
	SceneRouter.reload()


## Ends the run early. Rewards use the same cleared-wave math as a defeat, so
## abandoning at wave N pays exactly what dying at wave N pays (acceptance M3).
func abandon_run() -> void:
	if _finished:
		return
	_finish_run(true)


func set_sheet_open(open: bool) -> void:
	_sheet_open = open
	if _finished:
		return
	if open:
		_clock.set_paused(true)
	elif not _paused and not _app_paused:
		_clock.set_paused(false)


## Skips the prep break. Returns false when there is no prep to skip.
func request_next_wave() -> bool:
	if _finished or _paused:
		return false
	var bonus := _wave_manager.skip_prep()
	if bonus < 0:
		return false
	GameState.record_next_wave_use()
	return true


## Re-renders the upgrade panel and its notification dot (safe when closed).
func _refresh_upgrade_panel() -> void:
	if _hud_controller != null and _hud_controller.has_method("refresh_upgrade_panel"):
		_hud_controller.call(&"refresh_upgrade_panel")


func show_range_indicator(center: Vector2, radius: float) -> void:
	_range_indicator.show_at(center, radius)


func hide_range_indicator() -> void:
	_range_indicator.hide_indicator()


## Skips to a specific authored wave (tools, tests, preview capture).
func debug_start_wave(wave_number: int) -> void:
	if _finished:
		return
	_hud_controller.call(&"close_all")
	_wave_manager.debug_start_wave(wave_number)


## Spawns one enemy outside the wave schedule (performance probe).
func debug_spawn_enemy(enemy_id: StringName, lane_id: StringName = &"north") -> void:
	var data := _enemy_lookup.get(enemy_id, null) as EnemyData
	if data == null:
		return
	_enemy_manager.spawn(data, lane_id, 1.0, 1.0, 1.0)


## Builds the preview board for the screenshot tool (see BattlePreview).
func stage_preview() -> void:
	BattlePreview.stage(self)


## Stages combat and opens one bottom sheet, for HUD preview screenshots.
func stage_sheet_preview(sheet: String) -> void:
	BattlePreview.stage_sheet(self, sheet)


## Tooling-only wrappers used by BattlePreview (capture_scene calls these).
func debug_open_tower_sheet(tower: Tower) -> void:
	_hud_controller.call(&"debug_open_tower_sheet", tower)


func debug_open_build_sheet(pedestal: Pedestal) -> void:
	_hud_controller.call(&"debug_open_build_sheet", pedestal)


func debug_open_unit_sheet(slot: UnitSlot) -> void:
	_hud_controller.call(&"debug_open_unit_sheet", slot)


## Tooling-only: opens the upgrade panel (screenshot captures use it).
func debug_open_upgrade_panel(tab: StringName = &"tree") -> void:
	_hud_controller.call(&"open_upgrade_panel", tab)


## Tooling-only: shows the pause overlay for a screenshot capture.
func debug_open_pause() -> void:
	_hud_controller.call(&"debug_open_pause")


# --- arena construction ----------------------------------------------------------


func _build_tree() -> void:
	_tree.setup(tree_data, _clock, _run_rng, _target_index)
	_tree.defeated.connect(_on_tree_defeated)
	_tree.hp_changed.connect(_on_tree_hp_changed)
	_tree.shot_requested.connect(_on_shot_requested)


func _build_systems() -> void:
	for data in enemy_resources:
		if data != null:
			_enemy_lookup[data.id] = data
	for data in tower_resources:
		if data != null:
			_tower_lookup[data.id] = data
	for data in unit_resources:
		if data != null:
			_unit_lookup[data.id] = data

	_enemy_manager = EnemyManager.new()
	_enemy_manager.name = "EnemyManager"
	add_child(_enemy_manager)
	_enemy_manager.setup(
		_enemies_root,
		enemy_scene,
		_clock,
		_target_index,
		_run_rng,
		_arena.lane_north,
		_arena.lane_south
	)
	_enemy_manager.enemy_died.connect(_on_enemy_died)
	_enemy_manager.enemy_leaked.connect(_on_enemy_leaked)
	_enemy_manager.enemy_hit.connect(_on_enemy_hit_taken)
	_enemy_manager.enemy_hp_changed.connect(_on_enemy_hp_changed)
	_enemy_manager.boss_spawned.connect(_on_boss_spawned)
	_enemy_manager.enemy_shot.connect(_on_enemy_shot)
	_build_enemy_shot_pool()

	_combat = CombatSystem.new()
	_combat.name = "CombatSystem"
	add_child(_combat)
	_combat.setup(_projectiles_root, projectile_scene, _clock, _run_rng, _target_index, _fx)

	_spawner = Spawner.new()
	_spawner.name = "Spawner"
	add_child(_spawner)
	_spawner.spawn_requested.connect(_on_spawn_requested)
	_spawner.count_multiplier = maxf(ModifierService.get_stat(&"enemies_per_wave", 1.0), 0.1)

	_wave_manager = WaveManager.new()
	_wave_manager.name = "WaveManager"
	add_child(_wave_manager)
	_wave_manager.setup(wave_table, _spawner)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_cleared.connect(_on_wave_cleared)
	_wave_manager.prep_skipped.connect(_on_prep_skipped)
	_wave_manager.table_finished.connect(_on_table_finished)


# --- spawning and combat callbacks ------------------------------------------------


func _on_spawn_requested(
	enemy_id: StringName,
	lane_id: StringName,
	hp_multiplier: float,
	speed_multiplier: float,
	cash_multiplier: float,
	group_hp_multiplier: float
) -> void:
	var data := _enemy_lookup.get(enemy_id, null) as EnemyData
	if data == null:
		push_error("BattleController: unknown enemy id '%s'" % enemy_id)
		return
	_enemy_manager.spawn(
		data,
		lane_id,
		hp_multiplier * group_hp_multiplier,
		speed_multiplier,
		cash_multiplier
	)
	_wave_manager.on_enemy_spawned()


func _on_enemy_died(enemy: Enemy) -> void:
	_kills += 1
	add_cash(_cash_reward(enemy.cash_value()), &"kill")
	_play_death_fx(enemy)
	if enemy.data != null and enemy.data.is_boss:
		_active_boss = null
		boss_removed.emit()
	EventBus.enemy_killed.emit(enemy.data.id if enemy.data != null else &"", enemy.data.is_boss if enemy.data != null else false)
	_wave_manager.on_enemy_removed()


func _on_enemy_leaked(enemy: Enemy) -> void:
	_leaks += 1
	_tree.receive_leak(enemy.leak_damage_pct)
	_fx.play(enemy.global_position, CombatSystem.FX_HIT_TEXTURE, 1.0, 0.3)
	if enemy.data != null and enemy.data.is_boss:
		_active_boss = null
		boss_removed.emit()
	EventBus.enemy_leaked.emit(enemy.data.id if enemy.data != null else &"")
	_wave_manager.on_enemy_removed()


## ------------------------------------------------------------------ ranged
## Ported ranged archetypes stop short of the Tree and fire. Enemy owns the
## stop-and-shoot state; the controller owns the flight, the impact and the Tree
## damage, so Enemy stays a walker and all HP math stays in one place.

func _build_enemy_shot_pool() -> void:
	if _projectiles_root == null:
		return
	for index in ENEMY_SHOT_POOL:
		var sprite := Sprite2D.new()
		sprite.name = "EnemyShot%d" % index
		sprite.visible = false
		sprite.z_index = 3
		_projectiles_root.add_child(sprite)
		_enemy_shots.append({
			"sprite": sprite,
			"active": false,
			"from": Vector2.ZERO,
			"to": Vector2.ZERO,
			"duration": 0.0,
			"elapsed": 0.0,
			"damage_pct": 0.0,
		})


## Ranged attacks launched this run (battle_smoke and the tests read it).
func ranged_shots_fired() -> int:
	return _ranged_shots_fired


## Ranged attacks that actually landed on the Tree.
func ranged_hits_landed() -> int:
	return _ranged_hits_landed


func _on_enemy_shot(enemy: Enemy) -> void:
	if _finished or _tree == null or enemy == null or not is_instance_valid(enemy):
		return
	var data := enemy.data
	if data == null or not data.has_ranged_attack():
		return
	_ranged_shots_fired += 1
	if not data.attack_sfx.is_empty():
		AudioBus.play_sfx_id(data.attack_sfx, 0.06)
	_launch_enemy_shot(enemy.global_position, data)


func _launch_enemy_shot(origin: Vector2, data: EnemyData) -> void:
	var target := _tree.global_position
	var slot := _free_enemy_shot()
	if slot.is_empty():
		# Pool exhausted: resolve instantly so the attack still counts instead of
		# disappearing, which would silently weaken a swarm of archers.
		_apply_enemy_shot_damage(data.attack_damage_pct, target)
		return
	var sprite: Sprite2D = slot["sprite"]
	sprite.texture = data.attack_projectile
	sprite.visible = data.attack_projectile != null
	sprite.global_position = origin
	slot["active"] = true
	slot["from"] = origin
	slot["to"] = target
	slot["elapsed"] = 0.0
	slot["duration"] = maxf(
		origin.distance_to(target) / maxf(data.attack_projectile_speed, 1.0),
		ENEMY_SHOT_MIN_DURATION
	)
	slot["damage_pct"] = data.attack_damage_pct


func _tick_enemy_shots(dt: float) -> void:
	for slot in _enemy_shots:
		if not bool(slot["active"]):
			continue
		slot["elapsed"] = float(slot["elapsed"]) + dt
		var duration := maxf(float(slot["duration"]), ENEMY_SHOT_MIN_DURATION)
		var ratio := clampf(float(slot["elapsed"]) / duration, 0.0, 1.0)
		var sprite: Sprite2D = slot["sprite"]
		if is_instance_valid(sprite):
			sprite.global_position = (slot["from"] as Vector2).lerp(slot["to"] as Vector2, ratio)
		if ratio < 1.0:
			continue
		slot["active"] = false
		if is_instance_valid(sprite):
			sprite.visible = false
		_apply_enemy_shot_damage(float(slot["damage_pct"]), slot["to"] as Vector2)


func _apply_enemy_shot_damage(damage_pct: float, impact: Vector2) -> void:
	if _finished or _tree == null:
		return
	# `receive_leak` already applies the meta damage reduction, the FX and the
	# tree_hurt SFX hook, so a ranged hit costs exactly what a leak costs.
	_ranged_hits_landed += 1
	_tree.receive_leak(damage_pct)
	_fx.play(impact, CombatSystem.FX_HIT_TEXTURE, 1.0, 0.3)


func _free_enemy_shot() -> Dictionary:
	for slot in _enemy_shots:
		if not bool(slot["active"]):
			return slot
	return {}


func _on_enemy_hit_taken(enemy: Enemy, amount: float, is_crit: bool, source_id: StringName) -> void:
	if not is_instance_valid(enemy) or enemy.data == null:
		return
	EventBus.damage_dealt.emit(source_id, enemy.enemy_uid, amount, is_crit, not enemy.is_alive())
	if not SettingsService.damage_numbers:
		return
	var offset := Vector2(0.0, -78.0 * maxf(enemy.data.scale, 0.8))
	_damage_numbers.show_number(enemy.global_position + offset, amount, is_crit)


func _on_enemy_hp_changed(enemy: Enemy, current_hp: float, max_hp: float) -> void:
	if enemy != _active_boss:
		return
	boss_hp_changed.emit(current_hp, max_hp)


func _on_boss_spawned(enemy: Enemy) -> void:
	_active_boss = enemy
	boss_spawned.emit(enemy)
	_shake_screen(14.0)
	AudioService.haptic(70)


func _on_card_dropped(card_id: StringName) -> void:
	var card := CardService.get_card(card_id)
	if card == null or _hud == null:
		return
	_hud.show_banner(LocaleService.t("battle.card_found", "Card found: %s") % card.name)


func _on_second_wind_used() -> void:
	AudioBus.play_sfx_id(&"crit")
	if _hud != null:
		_hud.show_banner(LocaleService.t("battle.second_wind", "Second Wind: the Tree survives!"))


func _on_shot_requested(origin: Vector2, target: Enemy, shot: Dictionary) -> void:
	_combat.fire(origin, target, shot)
	_play_shot_sound(StringName(str(shot.get("source_id", ""))))


func _play_shot_sound(source_id: StringName) -> void:
	match source_id:
		&"tower_archer", &"unit_archer":
			AudioBus.play_sfx_id(&"shoot_arrow")
		&"tower_cannon":
			AudioBus.play_sfx_id(&"shoot_cannon")
		&"tower_frost_spire", &"unit_druid":
			AudioBus.play_sfx_id(&"shoot_frost")
		&"unit_mage":
			AudioBus.play_sfx_id(&"shoot_magic")


func _play_death_fx(enemy: Enemy) -> void:
	var scale := 0.8
	if enemy.data != null:
		scale = maxf(enemy.data.scale, 0.6)
	_fx.play(enemy.global_position + Vector2(0.0, -20.0), FX_DEATH_TEXTURE, scale, 0.35)


func _refresh_auras() -> void:
	_aura_system.apply(_enemy_manager.get_active(), _towers, _tree)


# --- interaction callbacks --------------------------------------------------------


func _on_pedestal_pressed(pedestal: Pedestal) -> void:
	pedestal_pressed.emit(pedestal)


func _on_tower_pressed(tower: Tower) -> void:
	tower_pressed.emit(tower)


func _pedestal_for_tower(tower: Tower) -> Pedestal:
	for pedestal in _arena.pedestals:
		if pedestal.tower == tower:
			return pedestal
	return null


# --- wave flow --------------------------------------------------------------------


func _on_wave_started(wave: int) -> void:
	RunState.wave = wave


func _on_wave_cleared(wave: int) -> void:
	_cleared_waves = wave
	add_cash(_wave_clear_cash(wave), &"wave_clear")
	EventBus.wave_cleared.emit(wave)


func _on_prep_skipped(bonus: int) -> void:
	add_cash(_cash_reward(bonus), &"skip_bonus")


func _on_table_finished() -> void:
	_finish_run()


# --- run end ----------------------------------------------------------------------


func _on_tree_defeated() -> void:
	_finish_run()


func _on_tree_hp_changed(current_hp: float, maximum: float) -> void:
	tree_hp_changed.emit(current_hp, maximum)
	if _last_tree_hp >= 0.0 and current_hp < _last_tree_hp:
		_shake_screen(10.0)
		AudioService.haptic(45)
	_last_tree_hp = current_hp


## Rewarded "Tree Blessing" placement: restores a percentage of max HP.
func heal_tree_percent(percent: float) -> bool:
	if _finished or _tree == null or _tree.is_defeated():
		return false
	var amount := _tree.max_hp * clampf(percent, 0.0, 100.0) / 100.0
	_tree.hp = minf(_tree.max_hp, _tree.hp + amount)
	_tree.hp_changed.emit(_tree.hp, _tree.max_hp)
	return true


## Settings → screen shake. Offset decays over 0.3 s; disabled means no offset.
func _shake_screen(strength: float) -> void:
	if not SettingsService.shake:
		return
	_shake_strength = maxf(_shake_strength, strength)
	_shake_left = maxf(_shake_left, 0.3)


func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		if position != Vector2.ZERO:
			position = Vector2.ZERO
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	var falloff := _shake_left / 0.3
	position = Vector2(
		randf_range(-_shake_strength, _shake_strength),
		randf_range(-_shake_strength, _shake_strength)
	) * falloff
	if _shake_left <= 0.0:
		position = Vector2.ZERO
		_shake_strength = 0.0


## Ends the run. `abandoned` skips the collapse animation but uses the same
## cleared-wave rewards as a defeat.
func _finish_run(abandoned: bool = false) -> void:
	if _finished:
		return
	_finished = true
	_paused = false
	_sheet_open = false
	_hud_controller.call(&"close_all")
	_clock.set_paused(true)
	_wave_manager.stop()
	EventBus.run_ended.emit(_cleared_waves)
	AudioBus.play_sfx_id(&"run_defeat")
	var delay := 0.0
	if not abandoned and _tree.is_defeated():
		_tree.play_collapse(COLLAPSE_SECONDS)
		delay = COLLAPSE_SECONDS
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	_show_summary()


func _show_summary() -> void:
	if run_summary_scene == null:
		push_error("BattleController: run_summary_scene is not assigned")
		return
	var summary := run_summary_scene.instantiate() as RunSummary
	add_child(summary)
	_summary = summary
	summary.setup(
		_cleared_waves,
		_kills,
		_leaks,
		_elapsed,
		RunState.run_id,
		get_boss_waves_cleared(),
		get_cash()
	)


# --- helpers ----------------------------------------------------------------------


func _validate_content() -> bool:
	if map_data == null or wave_table == null or tree_data == null:
		push_error("BattleController: map_data, wave_table and tree_data are required")
		return false
	var required: Array[PackedScene] = [
		enemy_scene, tower_scene, unit_scene, pedestal_scene,
		unit_slot_scene, projectile_scene, run_summary_scene,
	]
	for scene in required:
		if scene == null:
			push_error("BattleController: a required PackedScene export is not assigned")
			return false
	return true


func _fresh_seed() -> int:
	var seed_value := RunState.seed
	if seed_value == 0:
		seed_value = int(TimeService.now_unix()) ^ int(TimeService.now_msec())
	if seed_value == 0:
		seed_value = 1
	return seed_value
