## WaveDefinition — one authored wave: spawn groups plus scaling multipliers.
##
## Multipliers are applied by WaveManager when spawning; they are never baked
## into EnemyData so the same enemy resource is reusable at every wave.
class_name WaveDefinition
extends Resource

@export var index: int = 1
@export var groups: Array[SpawnGroup] = []
@export var hp_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var cash_multiplier: float = 1.0
@export var is_boss: bool = false
@export var reward_bonus: int = 0


## Total authored spawn count across all groups.
func total_count() -> int:
	var total := 0
	for group in groups:
		total += group.count
	return total
