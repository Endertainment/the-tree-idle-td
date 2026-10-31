## Tower — a built tower that acquires one target and fires a pooled projectile.
##
## M1 ships one tower type and level 1 only; `upgrade()` is intentionally a
## typed no-op returning false so M3 can replace it without touching callers.
class_name Tower
extends Node2D

signal shot_requested(
	origin: Vector2,
	target: Enemy,
	speed: float,
	damage: float,
	crit_chance: float,
	crit_multiplier: float,
	texture: Texture2D
)

var data: TowerData
var level: int = 1

var _clock: BattleClock
var _cooldown: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	set_physics_process(false)


## Applies the tower profile and starts its fire loop.
func setup(tower_data: TowerData, clock: BattleClock) -> void:
	data = tower_data
	_clock = clock
	_sprite.texture = data.texture_for_level(level)
	_cooldown = data.attack_interval
	set_physics_process(true)


## Tower upgrades arrive in M3; the API exists so the sheet can call it safely.
func upgrade() -> bool:
	return false


func sell_value() -> int:
	if data == null:
		return 0
	return int(floor(float(data.build_cost) * data.sell_refund_pct))


func _physics_process(delta: float) -> void:
	if data == null:
		return
	var dt: float = _clock.scaled(delta) if _clock != null else delta
	if dt <= 0.0:
		return
	_cooldown = maxf(_cooldown - dt, 0.0)
	if _cooldown > 0.0:
		return
	var target := _find_nearest_target()
	if target == null:
		return
	shot_requested.emit(
		global_position,
		target,
		data.projectile_speed,
		data.damage,
		data.crit_chance,
		data.crit_multiplier,
		data.projectile_texture
	)
	_cooldown = data.attack_interval


func _find_nearest_target() -> Enemy:
	var best: Enemy = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance > data.range or distance >= best_distance:
			continue
		best_distance = distance
		best = enemy
	return best
