## Tree — the run's core structure: HP, auto-attack and leak damage.
##
## The Tree targets the enemy furthest along a lane through the shared spatial
## hash (no scene-tree scans) and asks BattleController to fire a pooled homing
## projectile. Meta and in-run bonuses are read from ModifierService only: the
## workshop, cards and Tree tracks are registered there as sources (ADR-022), so
## no stat formula is duplicated between systems.
class_name TreeEntity
extends Node2D

signal defeated
signal hp_changed(current_hp: float, max_hp: float)
signal shot_requested(origin: Vector2, target: Enemy, shot: Dictionary)

const LEVELUP_TEXTURE := preload("res://assets/art/battle/fx/fx_levelup.png")
const LEVELUP_SECONDS := 0.45
const CRIT_CAP := 0.6

var data: TreeData
var max_hp: float = 0.0
var hp: float = 0.0
## Absorbs damage before HP; granted by the workshop "Shield at Run Start" track.
var shield: float = 0.0

var _clock: BattleClock
var _rng: RandomNumberGenerator
var _target_index: SpatialHash
var _cooldown: float = 0.0
var _defeated: bool = false
var _second_wind_used: bool = false
var _external_damage: float = 0.0
var _external_speed: float = 0.0

@onready var _sprite: Sprite2D = $Sprite


## Applies the tree profile. Called by BattleController before the wave starts.
func setup(
	tree_data: TreeData,
	clock: BattleClock,
	rng: RandomNumberGenerator,
	target_index: SpatialHash
) -> void:
	data = tree_data
	_clock = clock
	_rng = rng
	_target_index = target_index
	max_hp = maxf(ModifierService.get_stat(&"tree_max_hp", data.max_hp), 1.0)
	hp = max_hp
	shield = maxf(ModifierService.get_stat(&"start_shield", 0.0), 0.0)
	hp_changed.emit(hp, max_hp)


func is_defeated() -> bool:
	return _defeated


func hp_ratio() -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(hp / max_hp, 0.0, 1.0)


## Applies a leak as a percentage of max HP, resolved through DamageResolver.
## Both permanent reduction tracks (generic + leak-specific) are applied here.
func receive_leak(damage_pct: float) -> void:
	if _defeated:
		return
	var reduction := clampf(
		ModifierService.get_stat(&"damage_reduction", 0.0)
		+ ModifierService.get_stat(&"leak_damage_reduction", 0.0),
		0.0,
		0.9
	)
	var effective_pct := damage_pct * (1.0 - reduction)
	var result := DamageResolver.resolve(max_hp * effective_pct / 100.0, 0.0, 1.0, _rng, 0.0)
	apply_damage(float(result["amount"]), bool(result["is_crit"]), &"leak")


## Applies one resolved hit. Public so tests can exercise the HP math directly.
func apply_damage(amount: float, is_crit: bool, source_id: StringName) -> void:
	if _defeated:
		return
	var incoming := maxf(amount, 0.0)
	if shield > 0.0:
		var absorbed := minf(shield, incoming)
		shield -= absorbed
		incoming -= absorbed
	hp = maxf(hp - incoming, 0.0)
	var is_kill := hp <= 0.0
	EventBus.damage_dealt.emit(source_id, 0, amount, is_crit, is_kill)
	hp_changed.emit(hp, max_hp)
	if is_kill:
		# Magica "Second Wind": once per run, survive a lethal hit at 15 % HP.
		if not _second_wind_used and ModifierService.get_stat(&"second_wind", 0.0) >= 1.0:
			_second_wind_used = true
			hp = maxf(max_hp * 0.15, 1.0)
			hp_changed.emit(hp, max_hp)
			EventBus.second_wind_used.emit()
			return
		_defeated = true
		set_physics_process(false)
		defeated.emit()


func effective_damage() -> float:
	if data == null:
		return 0.0
	return ModifierService.get_stat(&"tree_damage", data.damage) * (1.0 + _external_damage)


func effective_interval() -> float:
	if data == null:
		return 0.0
	var haste := maxf(ModifierService.get_stat(&"attack_speed", 1.0), 0.01)
	return maxf(data.attack_interval / haste / (1.0 + _external_speed), 0.1)


func effective_range() -> float:
	if data == null:
		return 0.0
	return ModifierService.get_stat(&"tree_range", data.range)


## Crit chance after all modifiers, capped at 60 %.
func effective_crit_chance() -> float:
	if data == null:
		return 0.0
	return clampf(ModifierService.get_stat(&"crit_chance", data.crit_chance), 0.0, CRIT_CAP)


## Crit multiplier after all modifiers.
func effective_crit_multiplier() -> float:
	if data == null:
		return 2.0
	return ModifierService.get_stat(&"crit_damage", data.crit_multiplier)


## Fraction of max HP regenerated per second.
func regen_per_second() -> float:
	return maxf(ModifierService.get_stat(&"tree_regen", 0.0), 0.0)


## Level-up feedback: a gold flash and an expanding ring (spec 4.10).
func play_level_up() -> void:
	if _sprite == null:
		return
	var ring := Sprite2D.new()
	ring.texture = LEVELUP_TEXTURE
	ring.position = Vector2(0.0, -120.0)
	ring.modulate = Color(1.0, 0.9, 0.45, 0.9)
	ring.scale = Vector2(0.5, 0.5)
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.6, 1.6), LEVELUP_SECONDS)
	tween.tween_property(ring, "modulate:a", 0.0, LEVELUP_SECONDS)
	tween.chain().tween_callback(ring.queue_free)
	var flash := create_tween()
	flash.tween_property(_sprite, "modulate", Color(1.0, 0.86, 0.4, 1.0), 0.08)
	flash.tween_property(_sprite, "modulate", Color.WHITE, 0.22)


## Resets accumulated Totem buffs (called once per AuraSystem pass).
func set_external_buffs(damage_add: float, attack_speed_add: float) -> void:
	_external_damage = maxf(damage_add, 0.0)
	_external_speed = maxf(attack_speed_add, 0.0)


func add_external_buff(damage_add: float, attack_speed_add: float) -> void:
	_external_damage += maxf(damage_add, 0.0)
	_external_speed += maxf(attack_speed_add, 0.0)


func _physics_process(delta: float) -> void:
	if _defeated or data == null:
		return
	var dt: float = _clock.scaled(delta) if _clock != null else delta
	if dt <= 0.0:
		return
	var regen := regen_per_second()
	if regen > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * regen * dt)
		hp_changed.emit(hp, max_hp)
	_cooldown = maxf(_cooldown - dt, 0.0)
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	shot_requested.emit(global_position, target, _build_shot())
	_cooldown = effective_interval()


func _find_target() -> Enemy:
	if _target_index == null:
		return null
	var candidates := _target_index.query_radius(global_position, effective_range())
	if candidates.is_empty():
		return null
	# Ranged attackers take priority: they park outside most tower coverage and
	# would otherwise chip the Tree for free (docs/ENEMY_ROSTER.md, balance pass).
	var attackers: Array[Enemy] = []
	for enemy in candidates:
		if enemy != null and enemy.is_alive() and enemy.is_attacking():
			attackers.append(enemy)
	if not attackers.is_empty():
		return TargetingStrategy.select(&"first", global_position, attackers)
	return TargetingStrategy.select(&"first", global_position, candidates)


func _build_shot() -> Dictionary:
	return {
		"damage": effective_damage(),
		"crit_chance": effective_crit_chance(),
		"crit_multiplier": effective_crit_multiplier(),
		"projectile_speed": data.projectile_speed,
		"texture": data.projectile_texture,
		"splash_radius": 0.0,
		"splash_min_ratio": 1.0,
		"slow_pct": 0.0,
		"slow_duration": 0.0,
		"source_id": &"tree",
	}


## Collapse feedback used by the controller on defeat (scale + fade placeholder).
func play_collapse(duration: float = 1.2) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "scale", _sprite.scale * 0.35, duration)
	tween.tween_property(_sprite, "modulate:a", 0.0, duration)
