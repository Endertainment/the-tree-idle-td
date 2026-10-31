## BattleController — owns one battle run: arena, economy, waves, defeat/summary.
##
## State machine: prepare -> wave -> result. All timing is driven by BattleClock's
## scaled delta; all damage is resolved by DamageResolver; scene changes go
## through SceneRouter (from RunSummary). No balance literals live here: numbers
## come from MapData, WaveTable, EnemyData, TowerData and TreeData.
class_name BattleController
extends Node2D

const COLLAPSE_SECONDS := 1.2

@export var map_data: MapData
@export var wave_table: WaveTable
@export var tree_data: TreeData
@export var enemy_resources: Array[EnemyData] = []
@export var tower_resources: Array[TowerData] = []
@export var enemy_scene: PackedScene
@export var tower_scene: PackedScene
@export var pedestal_scene: PackedScene
@export var projectile_scene: PackedScene
@export var run_summary_scene: PackedScene
@export var unit_slot_texture: Texture2D

@onready var _background: Sprite2D = $Arena/Background
@onready var _lanes_root: Node2D = $Arena/Lanes
@onready var _pedestals_root: Node2D = $Arena/Pedestals
@onready var _unit_slots_root: Node2D = $Arena/UnitSlots
@onready var _towers_root: Node2D = $Arena/Towers
@onready var _tree: TreeEntity = $Tree
@onready var _enemies_root: Node2D = $Enemies
@onready var _projectiles_root: Node2D = $Projectiles
@onready var _clock: BattleClock = $BattleClock
@onready var _hud: BattleHUD = $BattleHUD

var _lane_north: Path2D
var _lane_south: Path2D
var _pedestals: Array[Pedestal] = []
var _enemy_lookup: Dictionary = {}
var _tower_lookup: Dictionary = {}
var _run_rng: RandomNumberGenerator
var _wave_manager: WaveManager
var _spawner: Spawner
var _projectile_pool: Array[Projectile] = []
var _active_enemies: Array[Enemy] = []
var _selected_pedestal: Pedestal
var _next_enemy_uid: int = 1
var _spawned_total: int = 0
var _kills: int = 0
var _leaks: int = 0
var _cleared_waves: int = 0
var _elapsed: float = 0.0
var _hud_timer: float = 0.0
var _finished: bool = false


func _ready() -> void:
	if not _validate_content():
		return
	var run_seed := _fresh_seed()
	RunState.reset(run_seed)
	_run_rng = RngService.new_run_rng(run_seed)
	RunState.cash = wave_table.starting_cash

	_build_arena()
	_build_tree()
	_build_projectile_pool()
	_build_systems()
	_connect_hud()

	_hud.set_wave(1, wave_table.wave_count())
	_hud.set_cash(RunState.cash)
	_hud.set_tree_hp(_tree.hp, _tree.max_hp)
	_hud.set_elapsed(0.0)
	EventBus.run_started.emit()
	_wave_manager.start()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	var dt := _clock.scaled(delta)
	_elapsed += dt
	_wave_manager.tick(dt)
	_hud_timer += dt
	if _hud_timer >= 0.25:
		_hud_timer = 0.0
		_hud.set_elapsed(_elapsed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		if _selected_pedestal != null:
			_close_sheet()


# --- public API (HUD and tests) ------------------------------------------------


func get_clock() -> BattleClock:
	return _clock


func get_tree_entity() -> TreeEntity:
	return _tree


func get_wave_manager() -> WaveManager:
	return _wave_manager


func get_cash() -> int:
	return RunState.cash


func get_kills() -> int:
	return _kills


func get_spawned_count() -> int:
	return _spawned_total


func get_cleared_waves() -> int:
	return _cleared_waves


func get_tower_count() -> int:
	return _towers_root.get_child_count()


func get_pedestal_count() -> int:
	return _pedestals.size()


func get_pedestal(index: int) -> Pedestal:
	if index < 0 or index >= _pedestals.size():
		return null
	return _pedestals[index]


func get_active_enemy_count() -> int:
	var count := 0
	for enemy in _active_enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			count += 1
	return count


func is_finished() -> bool:
	return _finished


## Adds in-run cash and notifies the HUD. `amount` may be negative.
func add_cash(amount: int) -> void:
	RunState.cash = maxi(RunState.cash + amount, 0)
	EventBus.run_cash_changed.emit(RunState.cash)
	_hud.set_cash(RunState.cash)


## Spends cash atomically; returns false (and changes nothing) when unaffordable.
func spend_cash(amount: int) -> bool:
	if amount < 0 or RunState.cash < amount:
		return false
	RunState.cash -= amount
	EventBus.run_cash_changed.emit(RunState.cash)
	_hud.set_cash(RunState.cash)
	return true


## Builds a tower on a free pedestal. Public so the smoke test can drive a build.
func build_tower(pedestal: Pedestal, tower_id: StringName) -> bool:
	if _finished or pedestal == null or not pedestal.is_buildable():
		return false
	var data: TowerData = _tower_lookup.get(tower_id, null)
	if data == null or not spend_cash(data.build_cost):
		return false
	var tower := tower_scene.instantiate() as Tower
	_towers_root.add_child(tower)
	tower.global_position = pedestal.global_position
	tower.setup(data, _clock)
	tower.shot_requested.connect(_on_tower_shot.bind(data.id))
	pedestal.mark_occupied(tower)
	return true


# --- arena construction ----------------------------------------------------------


func _build_arena() -> void:
	_background.texture = map_data.background
	_background.position = map_data.arena_size * 0.5
	_lane_north = _create_lane(&"LaneNorth", map_data.lane_north_points)
	_lane_south = _create_lane(&"LaneSouth", map_data.lane_south_points)
	_create_pedestals()
	_create_unit_slots()


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


func _create_unit_slots() -> void:
	for slot_position in map_data.unit_slot_positions:
		var slot := Sprite2D.new()
		slot.texture = unit_slot_texture
		slot.position = slot_position
		slot.modulate = Color(1.0, 1.0, 1.0, 0.75)
		_unit_slots_root.add_child(slot)


func _build_tree() -> void:
	_tree.setup(tree_data, _clock, _run_rng)
	_tree.defeated.connect(_on_tree_defeated)
	_tree.hp_changed.connect(_on_tree_hp_changed)
	_tree.shot_requested.connect(_on_tree_shot)


func _build_projectile_pool() -> void:
	for i in 12:
		_create_projectile()


func _build_systems() -> void:
	for data in enemy_resources:
		if data != null:
			_enemy_lookup[data.id] = data
	for data in tower_resources:
		if data != null:
			_tower_lookup[data.id] = data

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
	_wave_manager.prep_started.connect(_on_prep_started)
	_wave_manager.prep_skipped.connect(_on_prep_skipped)
	_wave_manager.countdown_changed.connect(_hud.set_countdown)
	_wave_manager.table_finished.connect(_on_table_finished)


func _connect_hud() -> void:
	_hud.build_requested.connect(_on_build_requested)
	_hud.next_wave_requested.connect(_on_next_wave_requested)
	_hud.dismiss_requested.connect(_close_sheet)


# --- spawning and combat ---------------------------------------------------------


func _on_spawn_requested(
	enemy_id: StringName,
	lane_id: StringName,
	hp_multiplier: float,
	speed_multiplier: float,
	cash_multiplier: float
) -> void:
	var data: EnemyData = _enemy_lookup.get(enemy_id, null)
	if data == null:
		push_error("BattleController: unknown enemy id '%s'" % enemy_id)
		return
	var lane := _lane_north if lane_id == &"north" else _lane_south
	var enemy := enemy_scene.instantiate() as Enemy
	_enemies_root.add_child(enemy)
	var lateral := _run_rng.randf_range(-14.0, 14.0)
	enemy.setup(data, lane, hp_multiplier, speed_multiplier, cash_multiplier, lateral, _clock, _next_enemy_uid)
	_next_enemy_uid += 1
	enemy.died.connect(_on_enemy_died)
	enemy.leaked.connect(_on_enemy_leaked)
	_active_enemies.append(enemy)
	_spawned_total += 1
	_wave_manager.on_enemy_spawned()


func _on_tree_shot(
	origin: Vector2,
	target: Enemy,
	speed: float,
	damage: float,
	crit_chance: float,
	crit_multiplier: float,
	texture: Texture2D
) -> void:
	_fire_projectile(origin, target, speed, damage, crit_chance, crit_multiplier, texture, &"tree")


func _on_tower_shot(
	origin: Vector2,
	target: Enemy,
	speed: float,
	damage: float,
	crit_chance: float,
	crit_multiplier: float,
	texture: Texture2D,
	source_id: StringName
) -> void:
	_fire_projectile(origin, target, speed, damage, crit_chance, crit_multiplier, texture, source_id)


func _fire_projectile(
	origin: Vector2,
	target: Enemy,
	speed: float,
	damage: float,
	crit_chance: float,
	crit_multiplier: float,
	texture: Texture2D,
	source_id: StringName
) -> void:
	if target == null or not is_instance_valid(target):
		return
	var projectile := _get_projectile()
	projectile.launch(
		origin, target, speed, damage, crit_chance, crit_multiplier,
		texture, _clock, _run_rng, source_id, true
	)


func _get_projectile() -> Projectile:
	for projectile in _projectile_pool:
		if not projectile.active:
			return projectile
	return _create_projectile()


func _create_projectile() -> Projectile:
	var projectile := projectile_scene.instantiate() as Projectile
	_projectiles_root.add_child(projectile)
	projectile.expired.connect(_on_projectile_expired)
	_projectile_pool.append(projectile)
	return projectile


func _on_projectile_expired(_projectile: Projectile) -> void:
	pass


func _on_enemy_died(enemy: Enemy) -> void:
	_kills += 1
	add_cash(enemy.cash_value())
	_remove_enemy(enemy)
	_wave_manager.on_enemy_removed()


func _on_enemy_leaked(enemy: Enemy) -> void:
	_leaks += 1
	_tree.receive_leak(enemy.leak_damage_pct)
	_remove_enemy(enemy)
	_wave_manager.on_enemy_removed()


func _remove_enemy(enemy: Enemy) -> void:
	_active_enemies.erase(enemy)


# --- wave HUD callbacks -----------------------------------------------------------


func _on_wave_started(wave: int) -> void:
	RunState.wave = wave
	_hud.set_wave(wave, wave_table.wave_count())
	_hud.hide_countdown()


func _on_wave_cleared(wave: int) -> void:
	_cleared_waves = wave
	var bonus := wave_table.clear_bonus(wave)
	add_cash(bonus)
	EventBus.wave_cleared.emit(wave)
	var text := LocaleService.t("battle.wave_cleared", "Wave %d cleared") % wave
	_hud.show_banner("%s  +%d" % [text, bonus])


func _on_prep_started(next_wave: int, duration: float) -> void:
	_hud.show_countdown(duration, wave_table.skip_bonus(next_wave))


func _on_prep_skipped(bonus: int) -> void:
	add_cash(bonus)
	_hud.hide_countdown()
	_hud.show_banner(LocaleService.t("battle.early_wave", "Early wave") + "  +%d" % bonus)


func _on_next_wave_requested() -> void:
	_wave_manager.skip_prep()


func _on_table_finished() -> void:
	_finish_run()


# --- build sheet -----------------------------------------------------------------


func _on_pedestal_pressed(pedestal: Pedestal) -> void:
	if _finished:
		return
	if _selected_pedestal == pedestal:
		_close_sheet()
		return
	_close_sheet()
	_selected_pedestal = pedestal
	pedestal.select()
	_hud.show_build_sheet(_build_options())
	_clock.set_paused(true)


func _on_build_requested(tower_id: StringName) -> void:
	if _selected_pedestal == null:
		return
	if build_tower(_selected_pedestal, tower_id):
		_close_sheet()


func _build_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for data in tower_resources:
		if data == null:
			continue
		var affordable := RunState.cash >= data.build_cost
		options.append({
			"data": data,
			"affordable": affordable,
			"reason": "" if affordable else LocaleService.t("battle.not_enough_cash", "Not enough cash"),
		})
	return options


func _close_sheet() -> void:
	if _selected_pedestal != null:
		_selected_pedestal.deselect()
		_selected_pedestal = null
	_hud.hide_build_sheet()
	_clock.set_paused(false)


# --- run end ----------------------------------------------------------------------


func _on_tree_defeated() -> void:
	_finish_run()


func _on_tree_hp_changed(current_hp: float, maximum: float) -> void:
	_hud.set_tree_hp(current_hp, maximum)


func _finish_run() -> void:
	if _finished:
		return
	_finished = true
	_close_sheet()
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


# --- helpers ------------------------------------------------------------------------


func _validate_content() -> bool:
	if map_data == null or wave_table == null or tree_data == null:
		push_error("BattleController: map_data, wave_table and tree_data are required")
		return false
	var required: Array[PackedScene] = [enemy_scene, tower_scene, pedestal_scene, projectile_scene, run_summary_scene]
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
