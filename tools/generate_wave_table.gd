## Wave table generator — writes the authored 30-wave M2 table.
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

const MAX_WAVES := 30
const BOSS_BONUS_HP := 1.6
const BOSS_COINS := 50


func _initialize() -> void:
	var table := WaveTable.new()
	table.boss_every = 10
	table.swarm_every = 5
	table.prep_time = 6.0
	table.starting_cash = 50
	table.clear_bonus_base = 20
	table.clear_bonus_per_wave = 5
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
	wave.hp_multiplier = pow(1.16, float(wave_number - 1))
	wave.speed_multiplier = minf(1.0 + 0.01 * float(wave_number - 1), 1.40)
	wave.cash_multiplier = pow(1.09, float(wave_number - 1))
	wave.is_boss = wave_number % 10 == 0
	wave.reward_bonus = BOSS_COINS if wave.is_boss else 0

	var total := mini(6 + int(floor(1.2 * float(wave_number))), 40)
	var swarm := wave_number % 5 == 0 and not wave.is_boss
	var interval := maxf(0.72 - 0.012 * float(wave_number), 0.35)
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
