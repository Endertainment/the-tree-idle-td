## Wave table generator — writes the authored 30-wave M3.1 table.
##
## Run: godot --headless --path . --script res://tools/generate_wave_table.gd
##
## The generated .tres is committed and is the source of truth for balance; this
## script documents how the curve and the boss/swarm cadence were composed. The
## engine reads only the .tres. Idempotent: it overwrites the output file.
extends SceneTree

const OUTPUT_PATH := "res://data/waves/wave_table_m2.tres"

const ENEMY_GRUNT := &"grunt"
const ENEMY_RUNNER := &"runner"
const ENEMY_TANK := &"tank"
const ENEMY_SHAMAN := &"shaman"
const ENEMY_BOSS := &"boss_troll"

const MAX_WAVES := 60
const BOSS_BONUS_HP := 1.20
const BOSS_COINS := 50
## M8 balance pass (docs/BALANCE.md): the zero-meta curve must fall at wave
## 8-12, mid-meta at 25-35 and maxed at 45+, while in-run DPS grows ~2.7 %/wave
## from the upgrade cost curves. A 1.11^w HP curve outgrew that too slowly and
## every profile reached the old 30-wave table end. M8 flattens the steady curve
## to 1.06^w but applies a 4x early ramp by wave 10; the flat ramp keeps waves
## 1-4 gentle while making the wave-10 boss the first real wall.
const HP_GROWTH := 1.06
## The wave-10 boss is the first wall: waves 1-9 stay gentle (1.0 -> 1.96) and
## wave 10 jumps to 4.0, so both a weak and a strong zero-meta opening fall in
## the 8-12 band instead of the curve spreading them over ten waves.
const EARLY_RAMP_MAX := 4.0
const EARLY_RAMP_WAVES := 10
## Beyond wave 40 the maxed profile still had no leaks; a second acceleration
## keeps the 45-60 band lethal without touching the new/mid range (they fall
## before wave 35).
const LATE_HP_START := 40
const LATE_HP_GROWTH := 1.20
const COUNT_BASE := 5
const COUNT_PER_WAVE := 0.80
const COUNT_CAP := 40
const SPAWN_INTERVAL_BASE := 1.00
const SPAWN_INTERVAL_STEP := 0.010
const SPAWN_INTERVAL_FLOOR := 0.50
const STARTING_CASH := 120
const CLEAR_BONUS_BASE := 60
const CLEAR_BONUS_PER_WAVE := 14


func _initialize() -> void:
	var table := WaveTable.new()
	table.boss_every = 10
	table.swarm_every = 5
	table.prep_time = 6.0
	table.starting_cash = STARTING_CASH
	table.clear_bonus_base = CLEAR_BONUS_BASE
	table.clear_bonus_per_wave = CLEAR_BONUS_PER_WAVE
	table.skip_bonus_base = 10
	table.skip_bonus_per_wave = 2
	table.skip_bonus_cap = 120

	for wave_number in range(1, MAX_WAVES + 1):
		table.waves.append(_build_wave(wave_number))

	var error := ResourceSaver.save(table, OUTPUT_PATH)
	if error != OK:
		push_error("generate_wave_table: could not save %s (error %d)" % [OUTPUT_PATH, error])
		quit(1)
		return
	print("[waves] wrote %d waves to %s" % [table.waves.size(), OUTPUT_PATH])
	for wave in table.waves:
		print("  wave %2d  count %2d  hp x%.3f  cash x%.3f  boss %s  groups %d" % [
			wave.index, wave.total_count(), wave.hp_multiplier, wave.cash_multiplier,
			str(wave.is_boss), wave.groups.size()
		])
	quit(0)


func _build_wave(wave_number: int) -> WaveDefinition:
	var wave := WaveDefinition.new()
	wave.index = wave_number
	wave.hp_multiplier = pow(HP_GROWTH, float(wave_number - 1)) * _early_ramp(wave_number) * _late_ramp(wave_number)
	wave.speed_multiplier = minf(1.0 + 0.01 * float(wave_number - 1), 1.40)
	wave.cash_multiplier = pow(1.12, float(wave_number - 1))
	wave.is_boss = wave_number % 10 == 0
	wave.reward_bonus = BOSS_COINS if wave.is_boss else 0

	var total := mini(COUNT_BASE + int(floor(COUNT_PER_WAVE * float(wave_number))), COUNT_CAP)
	var swarm := wave_number % 5 == 0 and not wave.is_boss
	var interval := maxf(
		SPAWN_INTERVAL_BASE - SPAWN_INTERVAL_STEP * float(wave_number), SPAWN_INTERVAL_FLOOR
	)
	var groups: Array[SpawnGroup] = []

	if wave.is_boss:
		groups.append(_group(ENEMY_BOSS, &"north", 1, 1.0, 0.0, BOSS_BONUS_HP))
		var support := total - 1
		var tanks := mini(4 if wave_number >= 20 else 2, support / 3)
		var shamans := 1 if wave_number >= 20 and support > 6 else 0
		var runners := int(round(float(support) * 0.55))
		var grunts := maxi(support - runners - tanks - shamans, 0)
		if grunts == 0:
			runners = maxi(support - tanks - shamans, 0)
		_add_type(groups, ENEMY_GRUNT, grunts, interval, 0.4)
		_add_type(groups, ENEMY_RUNNER, runners, interval * 0.8, 0.2)
		_add_type(groups, ENEMY_TANK, tanks, interval * 1.4, 0.6)
		_add_type(groups, ENEMY_SHAMAN, shamans, interval * 1.4, 0.8)
	elif swarm:
		var runners := int(round(float(total) * 0.78))
		var grunts := total - runners
		_add_type(groups, ENEMY_RUNNER, runners, 0.42, 0.0)
		_add_type(groups, ENEMY_GRUNT, grunts, 0.5, 0.25)
	else:
		var runners := 0
		if wave_number >= 2:
			runners = int(round(float(total) * 0.42))
		var tanks := 0
		if wave_number >= 4:
			tanks = maxi(1, int(round(float(total) * 0.18)))
		var shamans := 0
		if wave_number >= 6:
			shamans = maxi(1, int(round(float(total) * 0.09)))
		var grunts := total - runners - tanks - shamans
		if grunts < 0:
			runners = maxi(runners + grunts, 0)
			grunts = total - runners - tanks - shamans
		# Interleave types so a wave is not a single enemy file.
		_add_type(groups, ENEMY_GRUNT, grunts, interval, 0.0)
		_add_type(groups, ENEMY_RUNNER, runners, interval * 0.8, 0.2)
		_add_type(groups, ENEMY_TANK, tanks, interval * 1.4, 0.4)
		_add_type(groups, ENEMY_SHAMAN, shamans, interval * 1.4, 0.7)

	wave.groups = groups
	return wave


## Difficulty ramp: gentle 1.0 -> 1.96 over waves 1-9, then a step to 4.0 from
## the wave-10 boss onward.
func _early_ramp(wave_number: int) -> float:
	if wave_number >= EARLY_RAMP_WAVES:
		return EARLY_RAMP_MAX
	return 1.0 + 0.12 * float(wave_number - 1)


## Late acceleration: 1x through wave 40, then 1.07x per wave.
func _late_ramp(wave_number: int) -> float:
	if wave_number <= LATE_HP_START:
		return 1.0
	return pow(LATE_HP_GROWTH, float(wave_number - LATE_HP_START))


## Splits one enemy type across both lanes so each group spawns on a single lane.
func _add_type(groups: Array[SpawnGroup], enemy_id: StringName, count: int, interval: float, delay: float) -> void:
	if count <= 0:
		return
	var north := int(ceil(float(count) * 0.55))
	var south := count - north
	if north > 0:
		groups.append(_group(enemy_id, &"north", north, interval, delay))
	if south > 0:
		groups.append(_group(enemy_id, &"south", south, interval, delay + 0.15))


func _group(
	enemy_id: StringName,
	lane: StringName,
	count: int,
	interval: float,
	delay: float,
	hp_multiplier: float = 1.0
) -> SpawnGroup:
	var group := SpawnGroup.new()
	group.enemy_id = enemy_id
	group.lane = lane
	group.count = count
	group.interval = maxf(interval, 0.2)
	group.start_delay = delay
	group.hp_multiplier = hp_multiplier
	return group
