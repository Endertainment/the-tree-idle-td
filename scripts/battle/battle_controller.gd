## BattleController — owns one battle run: arena, entities, economy and run flow.
##
## M2 split: HUD binding lives in BattleHudController, the three bottom sheets in
## BuildSheet / TowerSheet / UnitSlots. This script keeps state and flow only:
## spawning (pooled enemies), wave progression, cash transactions, tower/unit
## build+upgrade+sell, aura ticking, damage application and run end.
##
## All damage still goes through DamageResolver; all numbers come from resources.
## Scene collaborators are addressed through small public APIs, never node paths
## like `get_node("../../")`.
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
const STARTING_PROJECTILES := 16
const FX_DEATH_TEXTURE := preload("res://assets/art/battle/fx/fx_death.png")
const FX_HIT_TEXTURE := preload("res://assets/art/battle/fx/fx_hit.png")

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

var _lane_north: Path2D
var _lane_south: Path2D
var _pedestals: Array[Pedestal] = []
var _enemy_lookup: Dictionary = {}
var _tower_lookup: Dictionary = {}
var _unit_lookup: Dictionary = {}
var _run_rng: RandomNumberGenerator
var _wave_manager: WaveManager
var _spawner: Spawner
var _aura_system: AuraSystem
var _target_index: SpatialHash
var _projectile_pool: Array[Projectile] = []
var _active_enemies: Array[Enemy] = []
var _enemy_pool: Array[Enemy] = []
var _towers: Array[Tower] = []
var _units: Array[Unit] = []
var _unit_slots: Array[UnitSlot] = []
var _active_boss: Enemy
var _next_enemy_uid: int = 1
var _spawned_total: int = 0
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
	_build_arena()
	_build_tree()
	_build_projectile_pool()
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
	_target_index.rebuild(_active_enemies)
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
	return _spawned_total


func get_cleared_waves() -> int:
	return _cleared_waves


func get_tower_count() -> int:
	return _towers.size()


func get_unit_count() -> int:
	return _units.size()


func get_pedestal_count() -> int:
	return _pedestals.size()


func get_pedestal(index: int) -> Pedestal:
	if index < 0 or index >= _pedestals.size():
		return null
	return _pedestals[index]


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
	return _active_enemies.size()


func get_active_boss() -> Enemy:
	if _active_boss != null and is_instance_valid(_active_boss) and _active_boss.is_alive():
		return _active_boss
	return null


func get_slowed_enemy_count() -> int:
	var count := 0
	for enemy in _active_enemies:
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


## Debug/tooling helper: unlocks every canopy slot (perf probe, preview capture).
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
	_on_spawn_requested(enemy_id, lane_id, 1.0, 1.0, 1.0, 1.0)


## Builds a showcase board for the preview screenshot (tools only).
func stage_preview() -> void:
	if _finished:
		return
	add_cash(5000)
	var showcase: Array[StringName] = [&"tower_archer", &"cannon", &"frost_spire", &"totem"]
	for index in showcase.size():
		if index < _pedestals.size():
			build_tower(_pedestals[index], showcase[index])
	if not _towers.is_empty():
		for _level in 4:
			upgrade_tower(_towers[0])
	var slots := get_unit_slots()
	if not slots.is_empty():
		place_unit(slots[0], &"unit_archer")
	debug_start_wave(10)


## Stages combat and opens one bottom sheet, for HUD preview screenshots.
func stage_sheet_preview(sheet: String) -> void:
	stage_preview()
	match sheet:
		"tower":
			if not _towers.is_empty():
				_hud_controller.call(&"debug_open_tower_sheet", _towers[0])
		"build":
			if _pedestals.size() > 7:
				_hud_controller.call(&"debug_open_build_sheet", _pedestals[7])
		"unit":
			var slots := get_unit_slots()
			if not slots.is_empty():
				_hud_controller.call(&"debug_open_unit_sheet", slots[0])
		"unit_place":
			debug_unlock_unit_slots()
			var all_slots := get_unit_slots()
			if all_slots.size() > 1:
				_hud_controller.call(&"debug_open_unit_sheet", all_slots[1])


# --- arena construction ----------------------------------------------------------


func _build_arena() -> void:
	_background.texture = map_data.background
	_background.position = map_data.arena_size * 0.5
	_lane_north = _create_lane(&"LaneNorth", map_data.lane_north_points)
	_lane_south = _create_lane(&"LaneSouth", map_data.lane_south_points)
	_create_pedestals()


func _create_lane(lane_name: StringName, points: PackedVector2Array) -> Path2D:
	var lane := Path2D.new()
	lane.name = lane_name
	lane.curve = CurveBuilder.build(points)
	_lanes_root.add_child(lane)
	_add_lane_visual(String(lane_name), lane.curve)
	return lane


## Draws the authored road under the tree and pedestals. Path2D itself only
## renders in the editor, so the playable lane needs an explicit Line2D.
func _add_lane_visual(lane_name: String, curve: Curve2D) -> void:
	var road := Line2D.new()
	road.name = lane_name + "Road"
	road.width = 84.0
	road.default_color = Color(0.42, 0.32, 0.20, 0.85)
	road.joint_mode = Line2D.LINE_JOINT_ROUND
	road.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road.end_cap_mode = Line2D.LINE_CAP_ROUND
	road.antialiased = true
	road.z_index = -5
	var length := curve.get_baked_length()
	var steps := maxi(int(length / 24.0), 2)
	for i in steps + 1:
		road.add_point(curve.sample_baked(length * float(i) / float(steps), true))
	_lanes_root.add_child(road)


func _create_pedestals() -> void:
	for i in map_data.pedestal_positions.size():
		var pedestal := pedestal_scene.instantiate() as Pedestal
		_pedestals_root.add_child(pedestal)
		pedestal.position = map_data.pedestal_positions[i]
		pedestal.setup(i)
		pedestal.pressed.connect(_on_pedestal_pressed)
		_pedestals.append(pedestal)


func _build_tree() -> void:
	_tree.setup(tree_data, _clock, _run_rng, _target_index)
	_tree.defeated.connect(_on_tree_defeated)
	_tree.hp_changed.connect(_on_tree_hp_changed)
	_tree.shot_requested.connect(_on_shot_requested)


func _build_projectile_pool() -> void:
	for _index in STARTING_PROJECTILES:
		_create_projectile()


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


# --- spawning and combat ---------------------------------------------------------


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
	var lane := _lane_north if lane_id == &"north" else _lane_south
	var enemy := _acquire_enemy()
	var lateral := _run_rng.randf_range(-14.0, 14.0)
	enemy.setup(
		data,
		lane,
		hp_multiplier * group_hp_multiplier,
		speed_multiplier,
		cash_multiplier,
		lateral,
		_clock,
		_next_enemy_uid
	)
	_next_enemy_uid += 1
	_active_enemies.append(enemy)
	_spawned_total += 1
	_wave_manager.on_enemy_spawned()
	if data.is_boss:
		_active_boss = enemy
		boss_spawned.emit(enemy)


func _acquire_enemy() -> Enemy:
	for enemy in _enemy_pool:
		if is_instance_valid(enemy) and enemy.is_pooled():
			return enemy
	var created := enemy_scene.instantiate() as Enemy
	_enemies_root.add_child(created)
	created.died.connect(_on_enemy_died)
	created.leaked.connect(_on_enemy_leaked)
	created.hit_taken.connect(_on_enemy_hit_taken)
	created.hp_changed.connect(_on_enemy_hp_changed.bind(created))
	_enemy_pool.append(created)
	return created


func _retire_enemy(enemy: Enemy) -> void:
	_active_enemies.erase(enemy)
	enemy.release()


func _on_enemy_died(enemy: Enemy) -> void:
	_kills += 1
	add_cash(enemy.cash_value())
	_play_death_fx(enemy)
	if enemy.data != null and enemy.data.is_boss:
		_active_boss = null
		boss_removed.emit()
	_retire_enemy(enemy)
	_wave_manager.on_enemy_removed()


func _on_enemy_leaked(enemy: Enemy) -> void:
	_leaks += 1
	_tree.receive_leak(enemy.leak_damage_pct)
	_fx.play(enemy.global_position, FX_HIT_TEXTURE, 1.0, 0.3)
	if enemy.data != null and enemy.data.is_boss:
		_active_boss = null
		boss_removed.emit()
	_retire_enemy(enemy)
	_wave_manager.on_enemy_removed()


func _on_enemy_hit_taken(enemy: Enemy, amount: float, is_crit: bool, source_id: StringName) -> void:
	if not is_instance_valid(enemy) or enemy.data == null:
		return
	EventBus.damage_dealt.emit(source_id, enemy.enemy_uid, amount, is_crit, not enemy.is_alive())
	var offset := Vector2(0.0, -78.0 * maxf(enemy.data.scale, 0.8))
	_damage_numbers.show_number(enemy.global_position + offset, amount, is_crit)


func _on_enemy_hp_changed(current_hp: float, max_hp: float, enemy: Enemy) -> void:
	if enemy != _active_boss:
		return
	boss_hp_changed.emit(current_hp, max_hp)


func _play_death_fx(enemy: Enemy) -> void:
	var scale := 0.8
	if enemy.data != null:
		scale = maxf(enemy.data.scale, 0.6)
	_fx.play(enemy.global_position + Vector2(0.0, -20.0), FX_DEATH_TEXTURE, scale, 0.35)


func _on_shot_requested(origin: Vector2, target: Enemy, shot: Dictionary) -> void:
	_fire_projectile(origin, target, shot)


func _fire_projectile(origin: Vector2, target: Enemy, shot: Dictionary) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	var projectile := _get_projectile()
	projectile.launch(origin, target, shot, _clock)


func _get_projectile() -> Projectile:
	for projectile in _projectile_pool:
		if not projectile.active:
			return projectile
	return _create_projectile()


func _create_projectile() -> Projectile:
	var projectile := projectile_scene.instantiate() as Projectile
	_projectiles_root.add_child(projectile)
	projectile.hit_landed.connect(_on_projectile_hit_landed)
	_projectile_pool.append(projectile)
	return projectile


func _on_projectile_hit_landed(
	_projectile: Projectile,
	target: Enemy,
	shot: Dictionary,
	impact_position: Vector2
) -> void:
	_apply_hit(target, shot, impact_position)


## Resolves the primary hit, splash falloff and status through one code path.
## DamageResolver owns every number; this method only feeds it target stats.
func _apply_hit(primary: Enemy, shot: Dictionary, impact_position: Vector2) -> void:
	if primary == null or not is_instance_valid(primary) or not primary.is_alive():
		return
	var armor := primary.armor
	var target_multiplier := primary.data.damage_taken_multiplier if primary.data != null else 1.0
	var result := DamageResolver.resolve(
		float(shot.get("damage", 0.0)),
		float(shot.get("crit_chance", 0.0)),
		float(shot.get("crit_multiplier", 2.0)),
		_run_rng,
		armor,
		1.0,
		1.0,
		false,
		target_multiplier
	)
	primary.apply_damage(float(result["amount"]), bool(result["is_crit"]), shot.get("source_id", &""))
	_apply_status(primary, shot)

	var splash_radius := float(shot.get("splash_radius", 0.0))
	if splash_radius > 0.0:
		var min_ratio := float(shot.get("splash_min_ratio", 0.35))
		var candidates := _target_index.query_radius(impact_position, splash_radius)
		for enemy in candidates:
			if enemy == primary or not is_instance_valid(enemy) or not enemy.is_alive():
				continue
			var distance := impact_position.distance_to(enemy.global_position)
			var falloff := DamageResolver.splash_falloff(distance, splash_radius, min_ratio)
			var splash_armor := enemy.armor
			var splash_target_multiplier := enemy.data.damage_taken_multiplier if enemy.data != null else 1.0
			var splash_result := DamageResolver.resolve(
				float(shot.get("damage", 0.0)),
				float(shot.get("crit_chance", 0.0)),
				float(shot.get("crit_multiplier", 2.0)),
				_run_rng,
				splash_armor,
				1.0,
				falloff,
				false,
				splash_target_multiplier
			)
			enemy.apply_damage(
				float(splash_result["amount"]),
				bool(splash_result["is_crit"]),
				shot.get("source_id", &"")
			)
			_apply_status(enemy, shot)
		_fx.play(impact_position, FX_HIT_TEXTURE, splash_radius / 60.0, 0.25)
	else:
		_fx.play(impact_position, FX_HIT_TEXTURE, 0.45, 0.18)


func _apply_status(enemy: Enemy, shot: Dictionary) -> void:
	var slow_pct := float(shot.get("slow_pct", 0.0))
	if slow_pct <= 0.0:
		return
	enemy.apply_slow(slow_pct, float(shot.get("slow_duration", 0.0)))


func _refresh_auras() -> void:
	_aura_system.apply(_active_enemies, _towers, _tree)


# --- interaction callbacks --------------------------------------------------------


func _on_pedestal_pressed(pedestal: Pedestal) -> void:
	pedestal_pressed.emit(pedestal)


func _on_tower_pressed(tower: Tower) -> void:
	tower_pressed.emit(tower)


func _pedestal_for_tower(tower: Tower) -> Pedestal:
	for pedestal in _pedestals:
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
