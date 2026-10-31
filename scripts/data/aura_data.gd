## AuraData — a radius buff authored on an enemy (shaman) or tower (totem).
##
## Enemy auras scale movement speed of other enemies inside `radius`; tower auras
## contribute damage and attack-speed multipliers through ModifierData instead.
class_name AuraData
extends Resource

@export var id: StringName = &""
@export var display_name_key: String = ""
@export var radius: float = 140.0
@export var speed_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var attack_speed_multiplier: float = 1.0
