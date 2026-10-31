## Enemy — one walking enemy moving along a lane curve.
##
## The node owns its lane progress (px), samples the baked Curve2D every physics
## tick and applies a seeded lateral offset so a wave never looks like a single
## file. Damage is applied only through DamageResolver results handed in by
## projectiles; this script never rolls crits or armor itself.
class_name Enemy
extends Node2D

signal died(enemy: Enemy)
signal leaked(enemy: Enemy)

const LEAK_RATIO := 0.995
const HP_BAR_LINGER := 2.0
const HP_BAR_FADE := 3.0


var data: EnemyData
var enemy_uid: int = 0
var max_hp: float = 0.0
var hp: float = 0.0
var armor: float = 0.0
var speed: float = 0.0
var leak_damage_pct: float = 0.0
var progress_ratio: float = 0.0

var _lane: Path2D
var _curve: Curve2D
var _lane_length: float = 0.0
var _progress: float = 0.0
var _lateral: float = 0.0
var _cash_multiplier: float = 1.0
var _clock: BattleClock
var _finished: bool = false
var _hp_bar_time: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow
@onready var _hp_bar: Node2D = $HpBar
@onready var _hp_fill: Sprite2D = $HpBar/Fill


func _ready() -> void:
	add_to_group(&"enemies")
	set_physics_process(false)
	_hp_bar.visible = false
	_hp_bar.modulate.a = 0.0


## Configures the enemy. Must be called after add_child() so @onready refs exist.
func setup(
	p_data: EnemyData,
	p_lane: Path2D,
	hp_multiplier: float,
	speed_multiplier: float,
	cash_multiplier: float,
	lateral: float,
	clock: BattleClock,
	run_uid: int
) -> void:
	data = p_data
	enemy_uid = run_uid
	max_hp = data.max_hp * hp_multiplier
	hp = max_hp
	armor = data.armor
	speed = data.speed * speed_multiplier
	leak_damage_pct = data.leak_damage_pct
	_cash_multiplier = cash_multiplier
	_clock = clock
	_lane = p_lane
	_curve = p_lane.curve
	_lane_length = maxf(_curve.get_baked_length(), 0.001)
	_progress = 0.0
	_lateral = lateral
	if data.frames != null:
		_sprite.sprite_frames = data.frames
		if data.frames.has_animation(&"walk"):
			_sprite.play(&"walk")
	_sprite.scale = Vector2.ONE * data.scale
	_shadow.scale = Vector2.ONE * data.scale
	_update_position()
	set_physics_process(true)


func is_alive() -> bool:
	return not _finished and hp > 0.0


## Applies one already-resolved hit. Returns true when this hit killed the enemy.
func apply_damage(amount: float, is_crit: bool, source_id: StringName) -> bool:
	if _finished:
		return false
	hp = maxf(hp - maxf(amount, 0.0), 0.0)
	_show_hp_bar()
	var is_kill := hp <= 0.0
	EventBus.damage_dealt.emit(source_id, enemy_uid, amount, is_crit, is_kill)
	if is_kill:
		_die()
	return is_kill


## Cash value of a kill for this wave, rounded to a whole coin.
func cash_value() -> int:
	return int(round(float(data.cash_reward) * _cash_multiplier))


func _physics_process(delta: float) -> void:
	if _finished:
		return
	var dt: float = _clock.scaled(delta) if _clock != null else delta
	if dt <= 0.0:
		return
	_progress = minf(_progress + speed * dt, _lane_length)
	progress_ratio = _progress / _lane_length
	_update_position()
	_tick_hp_bar(dt)
	if progress_ratio >= LEAK_RATIO:
		_leak()


func _update_position() -> void:
	var point := _curve.sample_baked(_progress, true)
	var look_ahead := minf(_progress + 12.0, _lane_length)
	var tangent := _curve.sample_baked(look_ahead, true) - point
	if tangent.length_squared() < 0.0001:
		tangent = Vector2.UP
	var normal := tangent.normalized().orthogonal()
	global_position = _lane.to_global(point + normal * _lateral)
	if absf(tangent.x) > 0.01:
		_sprite.flip_h = tangent.x < 0.0


func _show_hp_bar() -> void:
	_hp_bar_time = HP_BAR_LINGER
	_hp_bar.visible = true
	_hp_bar.modulate.a = 1.0
	_hp_fill.scale.x = clampf(hp / max_hp, 0.0, 1.0)


func _tick_hp_bar(delta: float) -> void:
	if _hp_bar_time > 0.0:
		_hp_bar_time = maxf(_hp_bar_time - delta, 0.0)
	elif _hp_bar.visible:
		_hp_bar.modulate.a = maxf(_hp_bar.modulate.a - delta * HP_BAR_FADE, 0.0)
		if _hp_bar.modulate.a <= 0.0:
			_hp_bar.visible = false


func _die() -> void:
	if _finished:
		return
	_finished = true
	set_physics_process(false)
	died.emit(self)
	queue_free()


func _leak() -> void:
	if _finished:
		return
	_finished = true
	set_physics_process(false)
	leaked.emit(self)
	queue_free()
