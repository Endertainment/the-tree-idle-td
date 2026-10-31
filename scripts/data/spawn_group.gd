## SpawnGroup — an ordered slice of a wave: which enemy, lane, count and cadence.
##
## `lane` is &"north", &"south" or &"both" (alternating). Groups within a wave run
## sequentially; `start_delay` is measured from the previous group's completion.
class_name SpawnGroup
extends Resource

@export var enemy_id: StringName = &"grunt"
@export var lane: StringName = &"north"
@export var count: int = 5
@export var interval: float = 0.8
@export var start_delay: float = 0.0
