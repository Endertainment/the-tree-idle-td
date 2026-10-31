## WaveTable — the authored wave list for one map plus pacing/economy knobs.
##
## WaveManager reads this resource only; changing a wave in the .tres changes the
## game. Bonus formulas live here so gameplay code contains no balance literals.
class_name WaveTable
extends Resource

@export var waves: Array[WaveDefinition] = []
@export var boss_every: int = 10
@export var swarm_every: int = 5
@export var prep_time: float = 6.0
@export var starting_cash: int = 50
## Cash granted when a wave is cleared: base + per_wave * wave.
@export var clear_bonus_base: int = 20
@export var clear_bonus_per_wave: int = 5
## Cash granted for skipping the prep break: min(base + per_wave * wave, cap).
@export var skip_bonus_base: int = 10
@export var skip_bonus_per_wave: int = 2
@export var skip_bonus_cap: int = 120


## Returns the 1-based wave, or null past the table.
func get_wave(index: int) -> WaveDefinition:
	if index < 1 or index > waves.size():
		return null
	return waves[index - 1]


func wave_count() -> int:
	return waves.size()


func clear_bonus(wave: int) -> int:
	return clear_bonus_base + clear_bonus_per_wave * maxi(wave, 0)


func skip_bonus(wave: int) -> int:
	return mini(skip_bonus_base + skip_bonus_per_wave * maxi(wave, 0), skip_bonus_cap)
