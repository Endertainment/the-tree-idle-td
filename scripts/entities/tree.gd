## Tree — the run's core structure: HP, auto-attack and leak damage.
##
## The Tree targets the enemy furthest along a lane once per attack interval and
## asks BattleController (via shot_requested) to fire a pooled homing projectile.
## Leak damage also goes through DamageResolver, so no HP formula lives here.
class_name TreeEntity
extends Node2D

signal defeated
signal hp_changed(current_hp: float, max_hp: float)
signal shot_requested(
	origin: Vector2,
	target: Enemy,
	speed: float,
	damage: float,
	crit_chance: float,
	crit_multiplier: float,
	texture: Texture2D
)

var data: TreeData
var max_hp: float = 0.0
var hp: float = 0.0

var _clock: BattleClock
var _rng: RandomNumberGenerator
var _cooldown: float = 0.0
var _defeated: bool = false

@onready var _sprite: Sprite2D = $Sprite


## Applies the tree profile. Called by BattleController before the wave starts.
func setup(tree_data: TreeData, clock: BattleClock, rng: RandomNumberGenerator) -> void:
	data = tree_data
	_clock = clock
	_rng = rng
	max_hp = data.max_hp
	hp = max_hp
	hp_changed.emit(hp, max_hp)


func is_defeated() -> bool:
	return _defeated


func hp_ratio() -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(hp / max_hp, 0.0, 1.0)


## Applies a leak as a percentage of max HP, resolved through DamageResolver.
func receive_leak(damage_pct: float) -> void:
	if _defeated:
		return
	var result := DamageResolver.resolve(max_hp * damage_pct / 100.0, 0.0, 1.0, _rng, 0.0)
	apply_damage(float(result["amount"]), bool(result["is_crit"]), &"leak")


## Applies one resolved hit. Public so tests can exercise the HP math directly.
func apply_damage(amount: float, is_crit: bool, source_id: StringName) -> void:
	if _defeated:
		return
	hp = maxf(hp - maxf(amount, 0.0), 0.0)
	var is_kill := hp <= 0.0
	EventBus.damage_dealt.emit(source_id, 0, amount, is_crit, is_kill)
	hp_changed.emit(hp, max_hp)
	if is_kill:
		_defeated = true
		set_physics_process(false)
		defeated.emit()


func _physics_process(delta: float) -> void:
	if _defeated or data == null:
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


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_progress := -1.0
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		if global_position.distance_to(enemy.global_position) > data.range:
			continue
		if enemy.progress_ratio > best_progress:
			best_progress = enemy.progress_ratio
			best = enemy
	return best


## Collapse feedback used by the controller on defeat (scale + fade placeholder).
func play_collapse(duration: float = 1.2) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", _sprite.scale * 0.35, duration)
	tween.tween_property(_sprite, "modulate:a", 0.0, duration)
