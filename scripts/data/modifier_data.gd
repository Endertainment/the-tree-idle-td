## ModifierData — one stat delta contributed by an aura source (totem).
##
## Stats are string ids so a new aura stat is data + one consumer, never a new
## resource class. Consumers read `multiplier` as an additive fraction (0.15 =
## +15 %) and `add` as a flat value.
class_name ModifierData
extends Resource

@export var stat: StringName = &"damage"
@export var multiplier: float = 0.0
@export var add: float = 0.0
