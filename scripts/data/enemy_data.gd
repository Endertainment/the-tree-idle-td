## EnemyData — one enemy archetype. All numbers are balance data, never code.
##
## M1 uses a single walking animation named "walk" and a uniform `scale`.
class_name EnemyData
extends Resource

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var max_hp: float = 60.0
@export var speed: float = 55.0
@export var armor: float = 0.0
@export var leak_damage_pct: float = 4.0
@export var cash_reward: int = 4
@export var frames: SpriteFrames
@export var scale: float = 1.0
@export var is_boss: bool = false
