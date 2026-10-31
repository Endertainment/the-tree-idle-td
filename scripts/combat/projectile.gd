## Projectile — pooled homing (or straight) shot that applies one resolved hit.
##
## Movement uses move_toward-style stepping (no physics body) and the hit goes
## through DamageResolver, then Enemy.apply_damage. Reused instances are hidden
## and parked, never freed, so a 40-enemy wave allocates nothing per shot.
class_name Projectile
extends Node2D

signal expired(projectile: Projectile)

const HIT_RADIUS := 14.0
const STRAIGHT_LIFETIME := 2.0

var source_id: StringName = &""
var active: bool = false

var _target: Enemy
var _clock: BattleClock
var _rng: RandomNumberGenerator
var _speed: float = 900.0
var _damage: float = 0.0
var _crit_chance: float = 0.0
var _crit_multiplier: float = 2.0
var _armor: float = 0.0
var _homing: bool = true
var _direction: Vector2 = Vector2.RIGHT
var _lifetime: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


## Arms the projectile. The node must already be inside the scene tree.
func launch(
	from: Vector2,
	target: Enemy,
	speed: float,
	damage: float,
	crit_chance: float,
	crit_multiplier: float,
	texture: Texture2D,
	clock: BattleClock,
	rng: RandomNumberGenerator,
	shot_source: StringName,
	homing: bool = true
) -> void:
	global_position = from
	_target = target
	_clock = clock
	_rng = rng
	_speed = maxf(speed, 1.0)
	_damage = damage
	_crit_chance = crit_chance
	_crit_multiplier = crit_multiplier
	_armor = target.armor if target != null else 0.0
	source_id = shot_source
	_homing = homing
	_lifetime = 0.0
	_direction = (target.global_position - from).normalized() if target != null else Vector2.RIGHT
	_sprite.texture = texture
	visible = true
	active = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not active:
		return
	var dt: float = _clock.scaled(delta) if _clock != null else delta
	if dt <= 0.0:
		return
	_lifetime += dt
	if _target == null or not is_instance_valid(_target) or not _target.is_alive():
		if _homing:
			_expire()
			return
		_advance(_direction, dt)
		return
	var to_target := _target.global_position - global_position
	var step := _speed * dt
	if to_target.length() <= step + HIT_RADIUS:
		_hit_target()
		return
	_advance(to_target.normalized(), dt)


func _advance(direction: Vector2, dt: float) -> void:
	global_position += direction * _speed * dt
	rotation = direction.angle()
	if not _homing and _lifetime >= STRAIGHT_LIFETIME:
		_expire()


func _hit_target() -> void:
	var target := _target
	if target == null or not is_instance_valid(target):
		_expire()
		return
	var result := DamageResolver.resolve(_damage, _crit_chance, _crit_multiplier, _rng, target.armor)
	target.apply_damage(float(result["amount"]), bool(result["is_crit"]), source_id)
	_expire()


func _expire() -> void:
	if not active:
		return
	active = false
	visible = false
	_target = null
	set_physics_process(false)
	expired.emit(self)
