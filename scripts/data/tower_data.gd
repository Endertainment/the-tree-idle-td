## TowerData — build cost, combat stats, tiers and strategy ids for one tower.
##
## Behaviour and targeting are ids resolved through registries (`TowerBehavior`,
## `TargetingStrategy`), never `if tower_id == ...` chains. Level growth comes
## from a shared LevelCurve resource, and the three art tiers are selected by
## `tier_thresholds` (L1-4 / L5-7 / L8-10 by data).
class_name TowerData
extends Resource

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var display_name: String = ""
@export var description_key: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var tier_textures: Array[Texture2D] = []
@export var tier_thresholds: PackedInt32Array = PackedInt32Array([1, 5, 8])
@export var build_cost: int = 60
@export var damage: float = 14.0
@export var attack_interval: float = 0.9
@export var range: float = 300.0
@export var projectile_speed: float = 900.0
@export var projectile_texture: Texture2D
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var splash_radius: float = 0.0
@export var splash_min_ratio: float = 0.35
@export var status_on_hit: StatusData
@export var target_mode: StringName = &"first"
@export var aura_modifiers: Array[ModifierData] = []
@export var aura_radius: float = 0.0
@export var behavior_id: StringName = &""
@export var behavior_params: Dictionary = {}
@export var unlock_level: int = 5
@export var levels: LevelCurve
@export var sell_refund_pct: float = 0.7


## Returns the texture for `level` (1-based), clamped to the authored tiers.
func texture_for_level(level: int) -> Texture2D:
	if tier_textures.is_empty():
		return null
	var tier := 0
	for index in tier_thresholds.size():
		if level >= tier_thresholds[index]:
			tier = index
	return tier_textures[clampi(tier, 0, tier_textures.size() - 1)]


## Aura-only towers (totem) have zero damage and no attack interval.
func is_aura_only() -> bool:
	return damage <= 0.0 or attack_interval <= 0.0


func has_aura() -> bool:
	return aura_radius > 0.0 and not aura_modifiers.is_empty()
