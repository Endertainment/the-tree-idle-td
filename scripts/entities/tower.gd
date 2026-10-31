## Tower — a built tower that acquires one target and fires pooled projectiles.
##
## M2: 10 levels from a data LevelCurve, three art tiers, a level-5 behavior from
## TowerBehaviorRegistry, four targeting modes, splash/status in the shot, and an
## aura profile for the Totem. Nothing here branches on tower id: everything is
## TowerData + strategy objects.
class_name Tower
extends Area2D

signal shot_requested(origin: Vector2, target: Enemy, shot: Dictionary)
signal pressed(tower: Tower)

var data: TowerData
var level: int = 1
var invested: int = 0

var _clock: BattleClock
var _target_index: SpatialHash
var _cooldown: float = 0.0
var _behavior: TowerBehavior
var _external_damage: float = 0.0
var _external_speed: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	set_physics_process(false)
	input_event.connect(_on_input_event)


## Applies the tower profile and starts its fire loop. Called by BattleController
## after the node is inside the tree.
func setup(tower_data: TowerData, clock: BattleClock, target_index: SpatialHash) -> void:
	data = tower_data
	_clock = clock
	_target_index = target_index
	level = 1
	invested = data.build_cost
	_refresh_behavior()
	_sprite.texture = data.texture_for_level(level)
	_cooldown = interval_at(level) * 0.5
	set_physics_process(not data.is_aura_only())


## Level 5+ behavior, selected by data id through the registry.
func _refresh_behavior() -> void:
	_behavior = null
	if data == null or data.behavior_id.is_empty():
		return
	if level < data.unlock_level:
		return
	_behavior = TowerBehaviorRegistry.create(data.behavior_id)


func can_upgrade() -> bool:
	return data != null and data.levels != null and data.levels.can_upgrade(level)


## Price of the next level (0 at max level).
func upgrade_cost() -> int:
	if data == null or data.levels == null:
		return 0
	return data.levels.upgrade_cost(data.build_cost, level)


## Applies one level. The caller (BattleController) performs the cash transaction.
func upgrade() -> bool:
	if not can_upgrade():
		return false
	invested += upgrade_cost()
	level += 1
	_refresh_behavior()
	_sprite.texture = data.texture_for_level(level)
	return true


## 70 % (data) of every coin invested in this tower, rounded down.
func sell_value() -> int:
	if data == null:
		return 0
	return int(floor(float(invested) * data.sell_refund_pct))


func damage_at(target_level: int) -> float:
	if data == null or data.levels == null:
		return 0.0
	return data.levels.damage_at(data.damage, target_level)


func range_at(target_level: int) -> float:
	if data == null or data.levels == null:
		return 0.0
	return data.levels.range_at(data.range, target_level)


func interval_at(target_level: int) -> float:
	if data == null or data.levels == null or data.attack_interval <= 0.0:
		return 0.0
	var scaled := data.levels.interval_at(data.attack_interval, target_level)
	return maxf(scaled / (1.0 + _external_speed), data.levels.min_interval)


func effective_damage() -> float:
	return damage_at(level) * (1.0 + _external_damage)


func effective_range() -> float:
	return range_at(level)


func effective_interval() -> float:
	return interval_at(level)


func effective_splash_radius() -> float:
	return data.splash_radius if data != null else 0.0


## True for the Totem: no attack, contributes a tower/Tree aura instead.
func is_aura_tower() -> bool:
	return data != null and data.has_aura()


## Aura profile after behavior modifiers: {radius, damage, speed}. Values are
## additive fractions (0.15 = +15 %).
func aura_values() -> Dictionary:
	var aura := {
		"radius": data.aura_radius if data != null else 0.0,
		"damage": 0.0,
		"speed": 0.0,
	}
	if data != null:
		for modifier in data.aura_modifiers:
			if modifier == null:
				continue
			if modifier.stat == &"damage":
				aura["damage"] = float(aura["damage"]) + modifier.multiplier
			elif modifier.stat == &"attack_speed":
				aura["speed"] = float(aura["speed"]) + modifier.multiplier
	if _behavior != null:
		aura = _behavior.modify_aura(data.behavior_params, level, aura)
	return aura


## Resets accumulated aura buffs (called once per AuraSystem pass).
func set_external_buffs(damage_add: float, attack_speed_add: float) -> void:
	_external_damage = maxf(damage_add, 0.0)
	_external_speed = maxf(attack_speed_add, 0.0)


func add_external_buff(damage_add: float, attack_speed_add: float) -> void:
	_external_damage += maxf(damage_add, 0.0)
	_external_speed += maxf(attack_speed_add, 0.0)


func _physics_process(delta: float) -> void:
	if data == null or data.is_aura_only():
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
		"crit_chance": data.crit_chance,
		"crit_multiplier": data.crit_multiplier,
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


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	get_viewport().set_input_as_handled()
	pressed.emit(self)
