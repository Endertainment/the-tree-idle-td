## Unit — a guardian unit placed on one of the Tree's four canopy slots.
##
## Units use the same shot pipeline as towers (spatial-hash targeting, pooled
## projectiles, DamageResolver, status on hit) and are upgraded in place from the
## unit sheet. They are never sold or destroyed in the launch build.
class_name Unit
extends Node2D

signal shot_requested(origin: Vector2, target: Enemy, shot: Dictionary)
signal changed(unit: Unit)

var data: UnitData
var level: int = 1
var slot_index: int = 0

var _clock: BattleClock
var _target_index: SpatialHash
var _cooldown: float = 0.0
var _behavior: TowerBehavior

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	set_physics_process(false)


## Applies the unit profile. Must run after add_child() so @onready refs exist.
func setup(unit_data: UnitData, clock: BattleClock, target_index: SpatialHash, p_slot_index: int) -> void:
	data = unit_data
	_clock = clock
	_target_index = target_index
	slot_index = p_slot_index
	level = 1
	_refresh_behavior()
	if data.sprite_texture != null:
		_sprite.texture = data.sprite_texture
	_cooldown = interval_at(level) * 0.5
	set_physics_process(true)


func _refresh_behavior() -> void:
	_behavior = null
	if data == null or data.behavior_id.is_empty():
		return
	if level < data.unlock_level:
		return
	_behavior = TowerBehaviorRegistry.create(data.behavior_id)


func can_upgrade() -> bool:
	return data != null and data.levels != null and data.levels.can_upgrade(level)


func upgrade_cost() -> int:
	if data == null or data.levels == null:
		return 0
	return data.levels.upgrade_cost(data.placement_cost, level)


## Applies one level. The caller performs the cash transaction.
func upgrade() -> bool:
	if not can_upgrade():
		return false
	level += 1
	_refresh_behavior()
	changed.emit(self)
	return true


func damage_at(target_level: int) -> float:
	if data == null or data.levels == null:
		return 0.0
	return data.levels.damage_at(data.damage, target_level)


func range_at(target_level: int) -> float:
	if data == null or data.levels == null:
		return 0.0
	return data.levels.range_at(data.range, target_level)


func interval_at(target_level: int) -> float:
	if data == null or data.levels == null:
		return 0.0
	return maxf(data.levels.interval_at(data.attack_interval, target_level), data.levels.min_interval)


func effective_damage() -> float:
	return ModifierService.get_stat(&"unit_damage", damage_at(level))


func effective_range() -> float:
	return range_at(level)


func effective_interval() -> float:
	var haste := maxf(ModifierService.get_stat(&"attack_speed", 1.0), 0.01)
	if data == null or data.levels == null:
		return 0.0
	return maxf(interval_at(level) / haste, data.levels.min_interval)


func _physics_process(delta: float) -> void:
	if data == null:
		return
	var dt: float = _clock.scaled(delta) if _clock != null else delta
	if dt <= 0.0:
		return
	_cooldown = maxf(_cooldown - dt, 0.0)
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	for shot: Dictionary in _build_shots():
		shot_requested.emit(global_position, target, shot)
	_cooldown = maxf(effective_interval(), 0.01)


func _find_target() -> Enemy:
	if _target_index == null or data == null:
		return null
	var candidates := _target_index.query_radius(global_position, effective_range())
	return TargetingStrategy.select(data.target_mode, global_position, candidates)


func _build_shots() -> Array[Dictionary]:
	var shot := {
		"damage": effective_damage(),
		"crit_chance": clampf(ModifierService.get_stat(&"crit_chance", data.crit_chance), 0.0, 0.6),
		"crit_multiplier": ModifierService.get_stat(&"crit_damage", data.crit_multiplier),
		"projectile_speed": data.projectile_speed,
		"texture": data.projectile_texture,
		"splash_radius": data.splash_radius,
		"splash_min_ratio": data.splash_min_ratio,
		"slow_pct": data.status_on_hit.slow_pct if data.status_on_hit != null else 0.0,
		"slow_duration": data.status_on_hit.duration if data.status_on_hit != null else 0.0,
		"source_id": data.id,
	}
	if _behavior != null:
		return _behavior.modify_shots(data.behavior_params, level, shot)
	var shots: Array[Dictionary] = [shot]
	return shots
