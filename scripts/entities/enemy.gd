## Enemy — one walking enemy moving along a lane curve.
##
## M2: pooled (never freed during a run), carries a StatusEffectComponent for
## slows, accepts a shaman speed aura, flashes on hit and emits hp_changed so the
## boss bar can bind to it. Damage still only arrives as a DamageResolver result;
## this script never rolls crits or armor itself.
class_name Enemy
extends Node2D

signal died(enemy: Enemy)
signal leaked(enemy: Enemy)
signal hit_taken(enemy: Enemy, amount: float, is_crit: bool, source_id: StringName)
signal hp_changed(current_hp: float, max_hp: float)
## Emitted once per ranged attack; BattleController turns it into a projectile.
signal ranged_shot(enemy: Enemy)

const LEAK_RATIO := 0.995
const HP_BAR_LINGER := 2.0
const HP_BAR_FADE := 3.0
const FLASH_SECONDS := 0.08
const HIT_FLASH_SHADER := preload("res://ui/shaders/hit_flash.gdshader")

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
var _tree_target: Node2D
var _progress: float = 0.0
var _lateral: float = 0.0
var _cash_multiplier: float = 1.0
var _clock: BattleClock
var _finished: bool = false
var _hp_bar_time: float = 0.0
var _aura_speed_multiplier: float = 1.0
var _flash_time: float = 0.0
var _flash_material: ShaderMaterial
var _attack_cooldown: float = 0.0
var _attacking: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow
@onready var _hp_bar: Node2D = $HpBar
@onready var _hp_fill: Sprite2D = $HpBar/Fill
@onready var _status: StatusEffectComponent = $StatusEffect


func _ready() -> void:
	add_to_group(&"enemies")
	set_physics_process(false)
	_hp_bar.visible = false
	_hp_bar.modulate.a = 0.0
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = HIT_FLASH_SHADER
	_sprite.material = _flash_material


## Configures (or reconfigures a pooled) enemy. Must be called after add_child().
func setup(
	p_data: EnemyData,
	p_lane: Path2D,
	hp_multiplier: float,
	speed_multiplier: float,
	cash_multiplier: float,
	lateral: float,
	clock: BattleClock,
	run_uid: int,
	tree_target: Node2D = null
) -> void:
	data = p_data
	enemy_uid = run_uid
	_tree_target = tree_target
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
	progress_ratio = 0.0
	_lateral = lateral
	_finished = false
	_aura_speed_multiplier = 1.0
	_flash_time = 0.0
	_attacking = false
	## Half an interval of wind-up keeps a stopped enemy from firing the instant
	## it enters range, which read as a free hit in the preview capture.
	_attack_cooldown = data.attack_interval * 0.5 if data.has_ranged_attack() else 0.0
	_status.reset()
	if data.frames != null:
		_sprite.sprite_frames = data.frames
		if data.frames.has_animation(&"walk"):
			_sprite.play(&"walk")
	_sprite.scale = Vector2.ONE * data.scale
	_shadow.scale = Vector2.ONE * data.scale
	_hp_bar.visible = false
	_hp_bar.modulate.a = 0.0
	_hp_bar.position.y = -76.0 * maxf(data.scale, 0.8)
	_set_flash(0.0)
	visible = true
	_update_position()
	set_physics_process(true)


func is_alive() -> bool:
	return not _finished and hp > 0.0


## True while this instance sits in the pool (dead, leaked or never used).
func is_pooled() -> bool:
	return _finished


## Applies one already-resolved hit. Returns true when this hit killed the enemy.
func apply_damage(amount: float, is_crit: bool, source_id: StringName) -> bool:
	if _finished:
		return false
	var applied := maxf(amount, 0.0)
	hp = maxf(hp - applied, 0.0)
	_flash_time = FLASH_SECONDS
	_set_flash(1.0)
	_show_hp_bar()
	hit_taken.emit(self, applied, is_crit, source_id)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
		return true
	return false


## Applies (or refreshes) a slow from a StatusData resource.
func apply_status(status: StatusData) -> void:
	if status == null or _finished:
		return
	_status.apply_slow(status.slow_pct, status.duration)


func apply_slow(pct: float, duration: float) -> void:
	if _finished:
		return
	_status.apply_slow(pct, duration)


func is_slowed() -> bool:
	return _status.is_slowed()


## Cash value of a kill for this wave, rounded to a whole coin.
func cash_value() -> int:
	return int(round(float(data.cash_reward) * _cash_multiplier))


## Aura speed multiplier contributed by shamans (1.0 = no aura).
func set_aura_speed_multiplier(multiplier: float) -> void:
	_aura_speed_multiplier = maxf(multiplier, 0.1)


func get_aura_speed_multiplier() -> float:
	return _aura_speed_multiplier


## Current movement multiplier (status only; aura is applied separately).
func movement_multiplier() -> float:
	return _status.speed_multiplier()


## Returns the instance to the controller pool: hidden, inert, status cleared.
func release() -> void:
	_finished = true
	set_physics_process(false)
	visible = false
	_aura_speed_multiplier = 1.0
	_status.reset()
	_attack_cooldown = 0.0
	_attacking = false
	_hp_bar.visible = false
	_hp_bar.modulate.a = 0.0


func _physics_process(delta: float) -> void:
	if _finished:
		return
	var dt: float = _clock.scaled(delta) if _clock != null else delta
	if dt <= 0.0:
		return
	_status.tick(dt)
	_attacking = wants_to_attack()
	if _attacking:
		_tick_attack(dt)
	else:
		_progress = minf(_progress + speed * _aura_speed_multiplier * _status.speed_multiplier() * dt, _lane_length)
	progress_ratio = _progress / _lane_length
	_update_position()
	_tick_hp_bar(dt)
	_tick_flash(dt)
	# A ranged enemy never leaks: it wins by chipping the Tree down from range.
	if not _attacking and progress_ratio >= LEAK_RATIO:
		_leak()


## True while this enemy stands in its attack window and must not advance.
##
## `attack_range` is a real distance to the Tree, not progress along the lane:
## the lane bends, so "440 px before the end" could still be 670 px from the Tree
## and outside every tower's reach (that bug shipped once — see the ranged probe).
func wants_to_attack() -> bool:
	if data == null or not data.has_ranged_attack():
		return false
	var distance := _distance_to_tree()
	return in_attack_window(distance, data.attack_range)


## Distance to the Tree when known, lane remainder as a fallback for bare scenes.
func _distance_to_tree() -> float:
	if _tree_target != null and is_instance_valid(_tree_target):
		return global_position.distance_to(_tree_target.global_position)
	return _lane_length - _progress


func is_attacking() -> bool:
	return _attacking


## Pure geometry rule, static so the headless tests can check it without a scene.
static func in_attack_window(remaining_distance: float, attack_range: float) -> bool:
	return attack_range > 0.0 and remaining_distance <= attack_range


func _tick_attack(dt: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - dt, 0.0)
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = maxf(data.attack_interval, 0.05)
	ranged_shot.emit(self)


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


func _tick_flash(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time = maxf(_flash_time - delta, 0.0)
	_set_flash(_flash_time / FLASH_SECONDS)


func _set_flash(amount: float) -> void:
	if _flash_material == null:
		return
	_flash_material.set_shader_parameter(&"flash_amount", clampf(amount, 0.0, 1.0))


func _die() -> void:
	if _finished:
		return
	_finished = true
	set_physics_process(false)
	died.emit(self)


func _leak() -> void:
	if _finished:
		return
	_finished = true
	set_physics_process(false)
	leaked.emit(self)
