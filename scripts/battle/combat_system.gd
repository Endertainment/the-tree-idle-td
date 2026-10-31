## CombatSystem — pooled projectiles plus the one hit-resolution path.
##
## Moved out of BattleController in the M2 close-out split so the controller stays
## state/flow. It launches pooled homing projectiles and, on impact, asks
## DamageResolver for the primary hit and every splash hit (linear falloff), then
## applies status. No other script computes a damage number.
class_name CombatSystem
extends Node

const STARTING_PROJECTILES := 16
const FX_HIT_TEXTURE := preload("res://assets/art/battle/fx/fx_hit.png")

var _projectiles_root: Node2D
var _projectile_scene: PackedScene
var _clock: BattleClock
var _rng: RandomNumberGenerator
var _target_index: SpatialHash
var _fx: FxPool
var _pool: Array[Projectile] = []


func setup(
	projectiles_root: Node2D,
	projectile_scene: PackedScene,
	clock: BattleClock,
	rng: RandomNumberGenerator,
	target_index: SpatialHash,
	fx: FxPool
) -> void:
	_projectiles_root = projectiles_root
	_projectile_scene = projectile_scene
	_clock = clock
	_rng = rng
	_target_index = target_index
	_fx = fx
	for _index in STARTING_PROJECTILES:
		_create_projectile()


## Fires one pooled projectile for `shot`. Dead targets are ignored.
func fire(origin: Vector2, target: Enemy, shot: Dictionary) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	var projectile := _get_projectile()
	projectile.launch(origin, target, shot, _clock)


## Resolves the primary hit, splash falloff and slow for one impact.
func apply_hit(primary: Enemy, shot: Dictionary, impact_position: Vector2) -> void:
	if primary == null or not is_instance_valid(primary) or not primary.is_alive():
		return
	var target_multiplier := primary.data.damage_taken_multiplier if primary.data != null else 1.0
	var result := DamageResolver.resolve(
		float(shot.get("damage", 0.0)),
		float(shot.get("crit_chance", 0.0)),
		float(shot.get("crit_multiplier", 2.0)),
		_rng,
		primary.armor,
		1.0,
		1.0,
		false,
		target_multiplier
	)
	primary.apply_damage(float(result["amount"]), bool(result["is_crit"]), shot.get("source_id", &""))
	_apply_status(primary, shot)

	var splash_radius := float(shot.get("splash_radius", 0.0))
	if splash_radius <= 0.0:
		_fx.play(impact_position, FX_HIT_TEXTURE, 0.45, 0.18)
		return
	var min_ratio := float(shot.get("splash_min_ratio", 0.35))
	for enemy in _target_index.query_radius(impact_position, splash_radius):
		if enemy == primary or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var distance := impact_position.distance_to(enemy.global_position)
		var falloff := DamageResolver.splash_falloff(distance, splash_radius, min_ratio)
		var splash_target_multiplier := 1.0
		if enemy.data != null:
			splash_target_multiplier = enemy.data.damage_taken_multiplier
		var splash_result := DamageResolver.resolve(
			float(shot.get("damage", 0.0)),
			float(shot.get("crit_chance", 0.0)),
			float(shot.get("crit_multiplier", 2.0)),
			_rng,
			enemy.armor,
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


func _apply_status(enemy: Enemy, shot: Dictionary) -> void:
	var slow_pct := float(shot.get("slow_pct", 0.0))
	if slow_pct <= 0.0:
		return
	enemy.apply_slow(slow_pct, float(shot.get("slow_duration", 0.0)))


func _get_projectile() -> Projectile:
	for projectile in _pool:
		if not projectile.active:
			return projectile
	return _create_projectile()


## Number of projectiles currently in flight (debug overlay / perf probe).
func get_active_count() -> int:
	var count := 0
	for projectile in _pool:
		if is_instance_valid(projectile) and projectile.active:
			count += 1
	return count


func _create_projectile() -> Projectile:
	var projectile := _projectile_scene.instantiate() as Projectile
	_projectiles_root.add_child(projectile)
	projectile.hit_landed.connect(_on_projectile_hit_landed)
	_pool.append(projectile)
	return projectile


func _on_projectile_hit_landed(
	_projectile: Projectile,
	target: Enemy,
	shot: Dictionary,
	impact_position: Vector2
) -> void:
	apply_hit(target, shot, impact_position)
