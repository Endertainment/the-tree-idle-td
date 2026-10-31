## EnemyData — one enemy archetype. All numbers are balance data, never code.
##
## M2 adds aura support (shaman), boss metadata and per-enemy scale. The walking
## animation is named "walk"; a boss reuses the same scene with a bigger sprite
## and a dedicated HUD bar.
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
