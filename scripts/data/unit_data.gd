## UnitData — a guardian unit placed on one of the Tree's four canopy slots.
##
## Units share the tower combat pipeline (targeting, projectile, damage, status)
## but are bought and upgraded from the unit sheet. Level growth comes from a
## shared LevelCurve resource so numbers stay in data.
class_name UnitData
extends Resource

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var display_name: String = ""
@export var description_key: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var sprite_texture: Texture2D
@export var placement_cost: int = 50
@export var damage: float = 8.0
@export var attack_interval: float = 0.8
@export var range: float = 360.0
@export var projectile_speed: float = 900.0
@export var projectile_texture: Texture2D
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var splash_radius: float = 0.0
@export var splash_min_ratio: float = 0.35
@export var status_on_hit: StatusData
@export var target_mode: StringName = &"first"
@export var behavior_id: StringName = &""
@export var behavior_params: Dictionary = {}
@export var unlock_level: int = 5
@export var levels: LevelCurve
