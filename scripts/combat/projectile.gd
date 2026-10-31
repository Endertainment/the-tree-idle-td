## Projectile — pooled homing shot that reports its impact to BattleController.
##
## Movement is a distance check against the live target (no physics body). The
## projectile never computes damage itself: on impact it emits `hit_landed` with
## the shot dictionary and the controller resolves the primary hit, splash and
## status through DamageResolver.
class_name Projectile
extends Node2D

signal hit_landed(projectile: Projectile, target: Enemy, shot: Dictionary, impact_position: Vector2)

const HIT_RADIUS := 14.0

var source_id: StringName = &""
var active: bool = false

var _target: Enemy
var _shot: Dictionary
var _clock: BattleClock
var _speed: float = 900.0
var _lifetime: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


## Arms the projectile. The node must already be inside the scene tree.
func launch(from: Vector2, target: Enemy, shot: Dictionary, clock: BattleClock) -> void:
	global_position = from
	_target = target
	_shot = shot
	_clock = clock
	_speed = maxf(float(shot.get("projectile_speed", 900.0)), 1.0)
	source_id = shot.get("source_id", &"")
	var texture := shot.get("texture", null) as Texture2D
	if texture != null:
		_sprite.texture = texture
	_lifetime = 0.0
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
		_expire()
		return
	var to_target := _target.global_position - global_position
	var step := _speed * dt
	if to_target.length() <= step + HIT_RADIUS:
		hit_landed.emit(self, _target, _shot, _target.global_position)
		_expire()
		return
	var direction := to_target.normalized()
	global_position += direction * step
	rotation = direction.angle()


func _expire() -> void:
	if not active:
		return
	active = false
	visible = false
	_target = null
	set_physics_process(false)
