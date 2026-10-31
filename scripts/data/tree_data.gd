## TreeData — base combat stats of the Tree (the run's core structure).
##
## M1 reads HP, auto-attack cadence, range, crit and the projectile texture.
## Upgrade tracks are M3 data and deliberately absent here.
class_name TreeData
extends Resource

@export var id: StringName = &""
@export var max_hp: float = 1200.0
@export var damage: float = 12.0
@export var attack_interval: float = 1.1
@export var range: float = 640.0
@export var projectile_speed: float = 900.0
@export var crit_chance: float = 0.05
@export var crit_multiplier: float = 2.0
@export var projectile_texture: Texture2D
