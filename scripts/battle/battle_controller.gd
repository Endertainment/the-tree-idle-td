## BattleController — owns one battle run: arena, economy, waves and run flow.
##
## M2 split: HUD binding lives in BattleHudController, sheets in BuildSheet /
## TowerSheet / UnitSlots, the enemy pool in EnemyManager, projectile + hit
## resolution in CombatSystem and screenshot staging in BattlePreview. This script
## keeps state and flow only: cash transactions, build/upgrade/sell, aura ticking,
## boss tracking and run end.
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
const FX_DEATH_TEXTURE := preload("res://assets/art/battle/fx/fx_death.png")

@export var map_data: MapData
@export var wave_table: WaveTable
@export var tree_data: TreeData
@export var enemy_resources: Array[EnemyData] = []
@export var tower_resources: Array[TowerData] = []
@export var unit_resources: Array[UnitData] = []
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
var _towers: Array[Tower] = []
var _units: Array[Unit] = []
var _unit_slots: Array[UnitSlot] = []
var _active_boss: Enemy
var _kills: int = 0
var _leaks: int = 0
var _cleared_waves: int = 0
var _elapsed: float = 0.0
var _aura_timer: float = 0.0
var _finished: bool = false


func _ready() -> void:
	if not _validate_content():
		return
	var run_seed := _fresh_seed()
	RunState.reset(run_seed)
	_run_rng = RngService.new_run_rng(run_seed)
	RunState.cash = wave_table.starting_cash

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
	EventBus.run_started.emit()
	_wave_manager.start()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	var dt := _clock.scaled(delta)
	if dt <= 0.0:
		return
	_target_index.rebuild(_enemy_manager.get_active())
	_elapsed += dt
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
	return RunState.cash


func get_kills() -> int:
	return _kills


func get_leaks() -> int:
	return _leaks


func get_elapsed() -> float:
	return _elapsed


func get_spawned_count() -> int:
	return _enemy_manager.get_spawned_total() if _enemy_manager != null else 0


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


## Adds in-run cash and notifies the HUD. `amount` may be negative.
func add_cash(amount: int) -> void:
	RunState.cash = maxi(RunState.cash + amount, 0)
	EventBus.run_cash_changed.emit(RunState.cash)
	cash_changed.emit(RunState.cash)


## Spends cash atomically; returns false (and changes nothing) when unaffordable.
func spend_cash(amount: int) -> bool:
	if amount < 0 or RunState.cash < amount:
		return false
	RunState.cash -= amount
	EventBus.run_cash_changed.emit(RunState.cash)
	cash_changed.emit(RunState.cash)
	return true


## Builds a tower on a free pedestal. Public so tools/tests can drive a build.
func build_tower(pedestal: Pedestal, tower_id: StringName) -> bool:
	if _finished or pedestal == null or not pedestal.is_buildable():
		return false
	var data := _tower_lookup.get(tower_id, null) as TowerData
	if data == null or not spend_cash(data.build_cost):
		return false
	var tower := tower_scene.instantiate() as Tower
	_towers_root.add_child(tower)
	tower.global_position = pedestal.global_position
	tower.setup(data, _clock, _target_index)
	tower.shot_requested.connect(_on_shot_requested)
	tower.pressed.connect(_on_tower_pressed)
	pedestal.mark_occupied(tower)
	_towers.append(tower)
	_refresh_auras()
	return true


## Upgrades a built tower one level (cash checked here, level in Tower).
func upgrade_tower(tower: Tower) -> bool:
	if _finished or tower == null or not is_instance_valid(tower) or not tower.can_upgrade():
		return false
	var cost := tower.upgrade_cost()
	if not spend_cash(cost):
		return false
	if not tower.upgrade():
		add_cash(cost)
		return false
	_refresh_auras()
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
	add_cash(refund)
	_refresh_auras()
	return refund


## All buildable tower types with affordability, for the build sheet.
func build_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for data in tower_resources:
		if data == null:
			continue
		options.append({
			"data": data,
			"affordable": RunState.cash >= data.build_cost,
		})
	return options


## Places a guardian unit on a free, unlocked canopy slot.
func place_unit(slot: UnitSlot, unit_id: StringName) -> bool:
	if _finished or slot == null or not slot.is_unlocked() or not slot.is_empty():
		return false
	var data := _unit_lookup.get(unit_id, null) as UnitData
	if data == null or not spend_cash(data.placement_cost):
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
	var cost := unit.upgrade_cost()
	if not spend_cash(cost):
		return false
	if not unit.upgrade():
		add_cash(cost)
		return false
	return true


## Placement options for the unit sheet (all unit types + affordability).
func unit_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for data in unit_resources:
		if data == null:
			continue
		options.append({
			"data": data,
			"affordable": RunState.cash >= data.placement_cost,
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


func set_sheet_open(open: bool) -> void:
	if _finished:
		return
	_clock.set_paused(open)


func request_next_wave() -> void:
	_wave_manager.skip_prep()


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

	_combat = CombatSystem.new()
	_combat.name = "CombatSystem"
	add_child(_combat)
	_combat.setup(_projectiles_root, projectile_scene, _clock, _run_rng, _target_index, _fx)

	_spawner = Spawner.new()
	_spawner.name = "Spawner"
	add_child(_spawner)
	_spawner.spawn_requested.connect(_on_spawn_requested)

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
	add_cash(enemy.cash_value())
	_play_death_fx(enemy)
	if enemy.data != null and enemy.data.is_boss:
		_active_boss = null
		boss_removed.emit()
	_wave_manager.on_enemy_removed()


func _on_enemy_leaked(enemy: Enemy) -> void:
	_leaks += 1
	_tree.receive_leak(enemy.leak_damage_pct)
	_fx.play(enemy.global_position, CombatSystem.FX_HIT_TEXTURE, 1.0, 0.3)
	if enemy.data != null and enemy.data.is_boss:
		_active_boss = null
		boss_removed.emit()
	_wave_manager.on_enemy_removed()


func _on_enemy_hit_taken(enemy: Enemy, amount: float, is_crit: bool, source_id: StringName) -> void:
	if not is_instance_valid(enemy) or enemy.data == null:
		return
	EventBus.damage_dealt.emit(source_id, enemy.enemy_uid, amount, is_crit, not enemy.is_alive())
	var offset := Vector2(0.0, -78.0 * maxf(enemy.data.scale, 0.8))
	_damage_numbers.show_number(enemy.global_position + offset, amount, is_crit)


func _on_enemy_hp_changed(enemy: Enemy, current_hp: float, max_hp: float) -> void:
	if enemy != _active_boss:
		return
	boss_hp_changed.emit(current_hp, max_hp)


func _on_boss_spawned(enemy: Enemy) -> void:
	_active_boss = enemy
	boss_spawned.emit(enemy)


func _on_shot_requested(origin: Vector2, target: Enemy, shot: Dictionary) -> void:
	_combat.fire(origin, target, shot)


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
	add_cash(wave_table.clear_bonus(wave))
	EventBus.wave_cleared.emit(wave)


func _on_prep_skipped(bonus: int) -> void:
	add_cash(bonus)


func _on_table_finished() -> void:
	_finish_run()


# --- run end ----------------------------------------------------------------------


func _on_tree_defeated() -> void:
	_finish_run()


func _on_tree_hp_changed(current_hp: float, maximum: float) -> void:
	tree_hp_changed.emit(current_hp, maximum)


func _finish_run() -> void:
	if _finished:
		return
	_finished = true
	_hud_controller.call(&"close_all")
	_clock.set_paused(true)
	_wave_manager.stop()
	EventBus.run_ended.emit(_cleared_waves)
	var delay := 0.0
	if _tree.is_defeated():
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
	summary.setup(_cleared_waves, _kills, _leaks, _elapsed)


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
