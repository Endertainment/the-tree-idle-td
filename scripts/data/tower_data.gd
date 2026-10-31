## TowerData — build cost, combat stats and tier art for one tower type.
##
## Strategy ids (behavior/targeting) arrive in M2; M1 only needs the numeric
## profile plus the projectile texture and three tier textures.
class_name TowerData
extends Resource

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var icon: Texture2D
@export var tier_textures: Array[Texture2D] = []
@export var build_cost: int = 60
@export var damage: float = 14.0
@export var attack_interval: float = 0.9
@export var range: float = 300.0
@export var projectile_speed: float = 900.0
@export var projectile_texture: Texture2D
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var sell_refund_pct: float = 0.7


## Returns the texture for `level` (1-based), clamped to the authored tiers.
func texture_for_level(level: int) -> Texture2D:
	if tier_textures.is_empty():
		return null
	return tier_textures[clampi(level - 1, 0, tier_textures.size() - 1)]
