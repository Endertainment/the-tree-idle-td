## EnemyManager — pooled enemy lifecycle for one battle run.
##
## Moved out of BattleController in the M2 close-out split: it owns the enemy
## pool, spawning (lane choice, lateral jitter, boss signal) and retirement, and
## forwards hit/HP facts upward. Damage formulas stay in DamageResolver and cash
## in the controller.
class_name EnemyManager
extends Node

signal enemy_spawned(enemy: Enemy)
signal enemy_died(enemy: Enemy)
signal enemy_leaked(enemy: Enemy)
signal enemy_hit(enemy: Enemy, amount: float, is_crit: bool, source_id: StringName)
signal enemy_hp_changed(enemy: Enemy, current_hp: float, max_hp: float)
signal boss_spawned(enemy: Enemy)
## A ranged enemy fired; the controller owns the projectile and the Tree damage.
signal enemy_shot(enemy: Enemy)

var _root: Node2D
var _scene: PackedScene
var _clock: BattleClock
var _target_index: SpatialHash
var _rng: RandomNumberGenerator
var _lane_north: Path2D
var _lane_south: Path2D
var _tree_target: Node2D
var _pool: Array[Enemy] = []
var _active: Array[Enemy] = []
var _next_uid: int = 1
var _spawned_total: int = 0


func setup(
	root: Node2D,
	scene: PackedScene,
	clock: BattleClock,
	target_index: SpatialHash,
	rng: RandomNumberGenerator,
	lane_north: Path2D,
	lane_south: Path2D,
	tree_target: Node2D = null
) -> void:
	_root = root
	_scene = scene
	_clock = clock
	_target_index = target_index
	_rng = rng
	_lane_north = lane_north
	_lane_south = lane_south
	_tree_target = tree_target


## Spawns `data` on `lane_id` with already-combined HP scaling.
func spawn(
	data: EnemyData,
	lane_id: StringName,
	hp_multiplier: float,
	speed_multiplier: float,
	cash_multiplier: float
) -> Enemy:
	if data == null or _root == null:
		return null
	var lane := _lane_north if lane_id == &"north" else _lane_south
	var enemy := _acquire()
	var lateral := _rng.randf_range(-14.0, 14.0)
	enemy.setup(
		data,
		lane,
		hp_multiplier,
		speed_multiplier,
		cash_multiplier,
		lateral,
		_clock,
		_next_uid,
		_tree_target
	)
	_next_uid += 1
	_active.append(enemy)
	_spawned_total += 1
	enemy_spawned.emit(enemy)
	if data.is_boss:
		boss_spawned.emit(enemy)
	return enemy


func get_active() -> Array[Enemy]:
	return _active


func get_active_count() -> int:
	return _active.size()


func get_spawned_total() -> int:
	return _spawned_total


func _acquire() -> Enemy:
	for enemy in _pool:
		if is_instance_valid(enemy) and enemy.is_pooled():
			return enemy
	var created := _scene.instantiate() as Enemy
	_root.add_child(created)
	created.died.connect(_on_died)
	created.leaked.connect(_on_leaked)
	created.hit_taken.connect(_on_hit)
	created.hp_changed.connect(_on_hp_changed.bind(created))
	created.ranged_shot.connect(_on_ranged_shot)
	_pool.append(created)
	return created


func _release(enemy: Enemy) -> void:
	_active.erase(enemy)
	enemy.release()


func _on_died(enemy: Enemy) -> void:
	enemy_died.emit(enemy)
	_release(enemy)


func _on_leaked(enemy: Enemy) -> void:
	enemy_leaked.emit(enemy)
	_release(enemy)


func _on_hit(enemy: Enemy, amount: float, is_crit: bool, source_id: StringName) -> void:
	enemy_hit.emit(enemy, amount, is_crit, source_id)


func _on_hp_changed(current_hp: float, max_hp: float, enemy: Enemy) -> void:
	enemy_hp_changed.emit(enemy, current_hp, max_hp)


func _on_ranged_shot(enemy: Enemy) -> void:
	enemy_shot.emit(enemy)
