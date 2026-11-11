## EnemyData — one enemy archetype. All numbers are balance data, never code.
##
## M2 adds aura support (shaman), boss metadata and per-enemy scale. The walking
## animation is named "walk"; a boss reuses the same scene with a bigger sprite
## and a dedicated HUD bar.
##
## Ranged attack (ported enemies, docs/ENEMY_ROSTER.md): with `attack_range > 0`
## the enemy stops that many pixels short of the Tree and fires every
## `attack_interval` seconds for `attack_damage_pct` of the Tree's max HP. A zero
## range keeps the walker behaviour — walk in, leak once on arrival.
class_name EnemyData
extends Resource

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var display_name: String = ""
@export var max_hp: float = 60.0
@export var speed: float = 55.0
@export var armor: float = 0.0
@export var leak_damage_pct: float = 4.0
@export var cash_reward: int = 4
@export var frames: SpriteFrames
@export var scale: float = 1.0
@export var spawn_weight: float = 1.0
@export var is_boss: bool = false
@export var boss_bar_scale: float = 1.0
@export var aura: AuraData
@export var status_resistances: Dictionary = {}
@export var damage_taken_multiplier: float = 1.0

## Ranged attack profile. `attack_range` is measured along the lane, so 0 means
## "melee walker" and a value >= the lane length would fire from the spawn point.
@export var attack_range: float = 0.0
@export var attack_interval: float = 2.5
@export var attack_damage_pct: float = 1.5
@export var attack_projectile: Texture2D
@export var attack_projectile_speed: float = 420.0
@export var attack_sfx: StringName = &""


## True when this archetype fights from range instead of leaking on arrival.
func has_ranged_attack() -> bool:
	return attack_range > 0.0 and attack_interval > 0.0 and attack_damage_pct > 0.0
