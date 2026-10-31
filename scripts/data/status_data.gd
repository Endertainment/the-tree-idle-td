## StatusData — one authored on-hit status (slow) applied by towers and units.
##
## Slow stack rules are data: `refresh` (default) keeps the strongest active slow
## and restarts its timer instead of multiplying speed penalties.
class_name StatusData
extends Resource

@export var id: StringName = &""
@export var display_name_key: String = ""
## Fraction of movement speed removed while the status is active (0.35 = 35 %).
@export var slow_pct: float = 0.35
@export var duration: float = 1.5
@export var stack_mode: StringName = &"refresh"
