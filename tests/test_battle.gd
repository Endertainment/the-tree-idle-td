## M1 battle test suite: damage pipeline, wave data integrity, layout and rewards.
##
## Pure logic only: no scene tree, no autoloads, so it can run before the service
## tree exists. Scene smoke coverage lives in tools/battle_smoke.gd.
extends RefCounted

const WAVE_TABLE_PATH := "res://data/waves/wave_table_m1.tres"
const MAP_PATH := "res://data/maps/forest_clearing.tres"
const ENEMY_DIR := "res://data/enemies/"
const MIN_LANE_CLEARANCE := 110.0

const VALID_LANES: Array[StringName] = [&"north", &"south", &"both"]


func test_damage_armor_floor() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var floored := DamageResolver.resolve(100.0, 0.0, 2.0, rng, 95.0)
	if absf(float(floored["amount"]) - 10.0) > 0.001:
		print("  armor floor should be 10, got ", floored["amount"])
		return false
	if bool(floored["is_crit"]):
		print("  0%% crit chance produced a crit")
		return false

	var armored := DamageResolver.resolve(100.0, 0.0, 2.0, rng, 5.0)
	if absf(float(armored["amount"]) - 95.0) > 0.001:
		print("  expected 95 after armor, got ", armored["amount"])
		return false
	print("  armor floor and flat reduction hold")
	return true


func test_damage_crit() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	var crit := DamageResolver.resolve(50.0, 1.0, 2.0, rng, 20.0)
	if not bool(crit["is_crit"]):
		print("  100%% crit chance did not crit")
		return false
	if absf(float(crit["amount"]) - 80.0) > 0.001:
		print("  expected 80 after crit and armor, got ", crit["amount"])
		return false

	var floor_after_crit := DamageResolver.resolve(100.0, 1.0, 2.0, rng, 195.0)
	if absf(float(floor_after_crit["amount"]) - 20.0) > 0.001:
		print("  crit armor floor should be 20, got ", floor_after_crit["amount"])
		return false
	print("  crit multiplier applied before armor with a 10% floor")
	return true


func test_wave_table_integrity() -> bool:
	var table := load(WAVE_TABLE_PATH) as WaveTable
	if table == null:
		print("  could not load ", WAVE_TABLE_PATH)
		return false
	if table.waves.size() != 10:
		print("  expected 10 waves, got ", table.waves.size())
		return false

	var previous_hp := 0.0
	for i in table.waves.size():
		var wave := table.waves[i]
		var number := i + 1
		if wave == null:
			print("  wave %d is null" % number)
			return false
		if wave.index != number:
			print("  wave %d index is %d" % [number, wave.index])
			return false
		if wave.groups.is_empty():
			print("  wave %d has no spawn groups" % number)
			return false
		var expected_hp := pow(1.16, float(i))
		if absf(wave.hp_multiplier - expected_hp) > 0.001:
			print("  wave %d hp multiplier %f != %f" % [number, wave.hp_multiplier, expected_hp])
			return false
		if number > 1 and wave.hp_multiplier <= previous_hp:
			print("  hp multiplier is not increasing at wave %d" % number)
			return false
		previous_hp = wave.hp_multiplier
		for group in wave.groups:
			if not VALID_LANES.has(group.lane):
				print("  wave %d has invalid lane '%s'" % [number, group.lane])
				return false
			if not FileAccess.file_exists(ENEMY_DIR + "enemy_%s.tres" % group.enemy_id):
				print("  wave %d references missing enemy '%s'" % [number, group.enemy_id])
				return false
			if group.count <= 0 or group.interval <= 0.0:
				print("  wave %d has an empty spawn group" % number)
				return false
		var expected_total := mini(6 + int(floor(1.2 * float(number))), 30)
		if number == 10:
			expected_total *= 2
		if wave.total_count() != expected_total:
			print("  wave %d count %d != %d" % [number, wave.total_count(), expected_total])
			return false

	if table.waves[4].groups.size() <= 2:
		print("  wave 5 should be a swarm wave with extra groups")
		return false
	if table.waves[9].total_count() != 36:
		print("  wave 10 should be doubled (36), got ", table.waves[9].total_count())
		return false
	print("  10 waves, ids/lanes/counts and 1.16x hp scaling verified")
	return true


func test_map_layout() -> bool:
	var map := load(MAP_PATH) as MapData
	if map == null:
		print("  could not load ", MAP_PATH)
		return false
	if map.pedestal_positions.size() != 8:
		print("  expected 8 pedestals, got ", map.pedestal_positions.size())
		return false
	if map.unit_slot_positions.size() != 4:
		print("  expected 4 unit slots, got ", map.unit_slot_positions.size())
		return false

	var lanes: Array[PackedVector2Array] = [map.lane_north_points, map.lane_south_points]
	for points in lanes:
		if points.size() < 6 or points.size() > 8:
			print("  lane has %d control points, expected 6..8" % points.size())
			return false
		if points[points.size() - 1].distance_to(Vector2(540.0, 980.0)) > 150.0:
			print("  lane does not end near the trunk: ", points[points.size() - 1])
			return false
		var curve := CurveBuilder.build(points)
		var length := curve.get_baked_length()
		var steps := maxi(int(length / 4.0), 1)
		for i in steps + 1:
			var point := curve.sample_baked(length * float(i) / float(steps), true)
			for pedestal in map.pedestal_positions:
				if point.distance_to(pedestal) < MIN_LANE_CLEARANCE:
					print("  clearance %.1f px at %s" % [point.distance_to(pedestal), point])
					return false
	print("  lanes smooth, end at trunk and keep %.0f px from pedestals" % MIN_LANE_CLEARANCE)
	return true


func test_summary_cash_math() -> bool:
	var zero := RunRewards.compute(0)
	if int(zero["coins"]) != 0 or int(zero["gems"]) != 0 or int(zero["xp"]) != 0:
		print("  zero-wave rewards should be zero: ", zero)
		return false

	var five := RunRewards.compute(5)
	if int(five["coins"]) != 70 or int(five["gems"]) != 1 or int(five["xp"]) != 50:
		print("  wave 5 rewards wrong: ", five)
		return false

	var ten := RunRewards.compute(10)
	if int(ten["coins"]) != 190 or int(ten["gems"]) != 2 or int(ten["xp"]) != 100:
		print("  wave 10 rewards wrong: ", ten)
		return false
	print("  coins sum(8+2w), gems floor(w/5), xp 10w verified")
	return true
