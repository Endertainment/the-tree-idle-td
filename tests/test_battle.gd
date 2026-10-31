## M2 battle test suite: damage pipeline, status effects, targeting, behaviors,
## wave table cadence, splash falloff, layout, unit slot unlocking and rewards.
##
## Pure logic only: no scene tree, no autoloads. Scene smoke coverage lives in
## tools/battle_smoke.gd.
extends RefCounted

const WAVE_TABLE_PATH := "res://data/waves/wave_table_m2.tres"
const MAP_PATH := "res://data/maps/forest_clearing.tres"
const ENEMY_DIR := "res://data/enemies/"
const MIN_LANE_CLEARANCE := 110.0
const BOSS_WAVES: Array[int] = [10, 20, 30, 40, 50, 60]
const SWARM_WAVES: Array[int] = [5, 15, 25, 35, 45, 55]

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


func test_damage_true_and_multipliers() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3

	var true_hit := DamageResolver.resolve(100.0, 0.0, 2.0, rng, 50.0, 1.0, 1.0, true)
	if absf(float(true_hit["amount"]) - 100.0) > 0.001:
		print("  true damage should ignore armor, got ", true_hit["amount"])
		return false

	var boosted := DamageResolver.resolve(100.0, 0.0, 2.0, rng, 10.0, 1.5)
	if absf(float(boosted["amount"]) - 140.0) > 0.001:
		print("  damage multiplier should apply before armor, got ", boosted["amount"])
		return false

	var weakened := DamageResolver.resolve(100.0, 0.0, 2.0, rng, 0.0, 1.0, 0.5, false, 0.5)
	if absf(float(weakened["amount"]) - 25.0) > 0.001:
		print("  falloff + target multiplier should compound, got ", weakened["amount"])
		return false
	print("  true damage, damage multiplier and target multiplier verified")
	return true


func test_splash_falloff() -> bool:
	var center := DamageResolver.splash_falloff(0.0, 70.0, 0.4)
	var middle := DamageResolver.splash_falloff(35.0, 70.0, 0.4)
	var edge := DamageResolver.splash_falloff(70.0, 70.0, 0.4)
	if absf(center - 1.0) > 0.001 or absf(middle - 0.7) > 0.001 or absf(edge - 0.4) > 0.001:
		print("  linear falloff wrong: %.3f / %.3f / %.3f" % [center, middle, edge])
		return false
	if absf(DamageResolver.splash_falloff(500.0, 70.0, 0.4) - 0.4) > 0.001:
		print("  falloff should clamp at the minimum ratio")
		return false
	if absf(DamageResolver.splash_falloff(10.0, 0.0, 0.4) - 1.0) > 0.001:
		print("  zero radius should mean no splash")
		return false
	print("  splash falls off linearly 1.0 -> 0.4 at the edge")
	return true


func test_status_refresh() -> bool:
	var status := StatusEffectComponent.new()
	status.apply_slow(0.35, 1.5)
	status.apply_slow(0.35, 1.5)
	if absf(status.speed_multiplier() - 0.65) > 0.001:
		print("  slow stacked instead of refreshing: ", status.speed_multiplier())
		status.free()
		return false
	if absf(status.time_left() - 1.5) > 0.001:
		print("  refresh did not restart the timer: ", status.time_left())
		status.free()
		return false

	status.apply_slow(0.5, 1.0)
	if absf(status.speed_multiplier() - 0.5) > 0.001:
		print("  stronger slow was not applied: ", status.speed_multiplier())
		status.free()
		return false
	if absf(status.time_left() - 1.5) > 0.001:
		print("  shorter slow shortened the active timer: ", status.time_left())
		status.free()
		return false

	status.tick(1.6)
	if absf(status.speed_multiplier() - 1.0) > 0.001 or status.is_slowed():
		print("  slow did not expire")
		status.free()
		return false
	status.free()
	print("  slow refreshes without stacking and expires cleanly")
	return true


func test_targeting_modes() -> bool:
	var first := Enemy.new()
	first.hp = 100.0
	first.max_hp = 100.0
	first.progress_ratio = 0.2
	first.global_position = Vector2(100.0, 0.0)

	var second := Enemy.new()
	second.hp = 50.0
	second.max_hp = 50.0
	second.progress_ratio = 0.8
	second.global_position = Vector2(200.0, 0.0)

	var third := Enemy.new()
	third.hp = 300.0
	third.max_hp = 300.0
	third.progress_ratio = 0.5
	third.global_position = Vector2(300.0, 0.0)

	var candidates: Array[Enemy] = [first, second, third]
	var ok := true
	if TargetingStrategy.select(&"first", Vector2.ZERO, candidates) != second:
		print("  first mode should pick the furthest-along enemy")
		ok = false
	if TargetingStrategy.select(&"last", Vector2.ZERO, candidates) != first:
		print("  last mode should pick the least advanced enemy")
		ok = false
	if TargetingStrategy.select(&"closest", Vector2.ZERO, candidates) != first:
		print("  closest mode should pick the nearest enemy")
		ok = false
	if TargetingStrategy.select(&"strongest", Vector2.ZERO, candidates) != third:
		print("  strongest mode should pick the highest-HP enemy")
		ok = false
	if TargetingStrategy.select(&"first", Vector2.ZERO, candidates) != second:
		print("  default mode should behave like first")
		ok = false
	for enemy in candidates:
		enemy.free()
	if not ok:
		return false
	print("  first/last/closest/strongest select the expected enemy")
	return true


func test_tower_behavior_registry() -> bool:
	if TowerBehaviorRegistry.ids().size() != 4:
		print("  expected 4 registered behaviors, got ", TowerBehaviorRegistry.ids().size())
		return false
	if TowerBehaviorRegistry.create(&"does_not_exist") != null:
		print("  unknown behavior id should return null")
		return false

	var double_shot := TowerBehaviorRegistry.create(&"double_shot")
	var shot := {
		"damage": 100.0,
		"splash_radius": 70.0,
		"splash_min_ratio": 0.35,
		"slow_pct": 0.35,
		"slow_duration": 1.5,
	}
	var shots := double_shot.modify_shots({"extra_shots": 1, "damage_scale": 0.7}, 5, shot)
	if shots.size() != 2 or absf(float(shots[1]["damage"]) - 70.0) > 0.001:
		print("  double_shot should add one 70%% shot: ", shots.size())
		return false
	if absf(float(shot["damage"]) - 100.0) > 0.001:
		print("  behavior mutated the base shot")
		return false

	var shrapnel := TowerBehaviorRegistry.create(&"shrapnel")
	var wide := shrapnel.modify_shots({"radius_scale": 1.5, "min_ratio": 0.6}, 5, shot)
	if absf(float(wide[0]["splash_radius"]) - 105.0) > 0.001:
		print("  shrapnel radius wrong: ", wide[0]["splash_radius"])
		return false

	var deep_chill := TowerBehaviorRegistry.create(&"deep_chill")
	var chilled := deep_chill.modify_shots({"slow_pct_bonus": 0.15, "duration_bonus": 0.5}, 5, shot)
	if absf(float(chilled[0]["slow_pct"]) - 0.5) > 0.001:
		print("  deep_chill slow wrong: ", chilled[0]["slow_pct"])
		return false

	var rooted_gift := TowerBehaviorRegistry.create(&"rooted_gift")
	var aura := rooted_gift.modify_aura({"damage_bonus": 0.1, "speed_bonus": 0.05}, 5, {
		"radius": 260.0, "damage": 0.15, "speed": 0.1,
	})
	if absf(float(aura["damage"]) - 0.25) > 0.001 or absf(float(aura["speed"]) - 0.15) > 0.001:
		print("  rooted_gift aura wrong: ", aura)
		return false
	print("  registry creates all 4 behaviors and applies their data params")
	return true


func test_unit_slot_unlocking() -> bool:
	if not UnitSlotRules.meets_requirement(null, 1, 0, {}):
		print("  a null requirement should always be unlocked")
		return false

	var level_four := SlotRequirement.new()
	level_four.kind = &"level"
	level_four.value = 4
	if UnitSlotRules.meets_requirement(level_four, 3, 0, {}):
		print("  level 3 should not unlock a level-4 slot")
		return false
	if not UnitSlotRules.meets_requirement(level_four, 4, 0, {}):
		print("  level 4 should unlock a level-4 slot")
		return false

	var workshop := SlotRequirement.new()
	workshop.kind = &"workshop"
	workshop.flag = &"third_branch"
	if UnitSlotRules.meets_requirement(workshop, 50, 0, {}):
		print("  workshop slot unlocked without the workshop flag")
		return false
	if not UnitSlotRules.meets_requirement(workshop, 1, 0, {"third_branch": true}):
		print("  workshop slot did not unlock with the flag")
		return false

	var either := SlotRequirement.new()
	either.kind = &"level"
	either.value = 12
	either.alt_kind = &"gems"
	either.alt_value = 150
	if UnitSlotRules.meets_requirement(either, 11, 149, {}):
		print("  level 12 / 150 gems slot unlocked too early")
		return false
	if not UnitSlotRules.meets_requirement(either, 12, 0, {}):
		print("  level 12 did not unlock the slot")
		return false
	if not UnitSlotRules.meets_requirement(either, 1, 150, {}):
		print("  150 gems did not unlock the slot")
		return false
	print("  level / workshop / level-or-gems slot conditions verified")
	return true


func test_tower_and_unit_data() -> bool:
	var archer := load("res://data/towers/tower_archer.tres") as TowerData
	var cannon := load("res://data/towers/tower_cannon.tres") as TowerData
	var frost := load("res://data/towers/tower_frost_spire.tres") as TowerData
	var totem := load("res://data/towers/tower_totem.tres") as TowerData
	var towers: Array[TowerData] = [archer, cannon, frost, totem]
	for data in towers:
		if data == null:
			print("  tower resource failed to load")
			return false
		if data.levels == null or data.levels.max_level != 10:
			print("  tower %s has no 10-level curve" % data.id)
			return false
		if data.tier_textures.size() != 3 or data.tier_thresholds.size() != 3:
			print("  tower %s should have 3 data-driven tiers" % data.id)
			return false
		if data.texture_for_level(1) != data.tier_textures[0]:
			print("  tower %s tier 1 texture wrong" % data.id)
			return false
		if data.texture_for_level(5) != data.tier_textures[1]:
			print("  tower %s tier 2 texture wrong" % data.id)
			return false
		if data.texture_for_level(8) != data.tier_textures[2]:
			print("  tower %s tier 3 texture wrong" % data.id)
			return false
		if not TowerBehaviorRegistry.has_behavior(data.behavior_id):
			print("  tower %s behavior '%s' is not registered" % [data.id, data.behavior_id])
			return false
		if not TargetingStrategy.is_valid(data.target_mode):
			print("  tower %s targeting mode '%s' is invalid" % [data.id, data.target_mode])
			return false

	if archer.build_cost != 60 or absf(archer.damage - 14.0) > 0.001 or absf(archer.attack_interval - 0.9) > 0.001:
		print("  archer base stats do not match spec 4.5")
		return false
	if absf(archer.range - 400.0) > 0.001 or archer.levels.upgrade_cost(archer.build_cost, 1) != 48:
		print("  archer range/level-2 cost wrong")
		return false
	if cannon.build_cost != 110 or absf(cannon.damage - 45.0) > 0.001 or absf(cannon.splash_radius - 70.0) > 0.001:
		print("  cannon base stats do not match spec 4.5")
		return false
	if absf(cannon.range - 370.0) > 0.001:
		print("  cannon range should be 370 (M3.1 coverage), got %.0f" % cannon.range)
		return false
	if frost.build_cost != 90 or absf(frost.damage - 6.0) > 0.001 or frost.status_on_hit == null:
		print("  frost spire base stats do not match spec 4.5")
		return false
	if absf(frost.range - 340.0) > 0.001:
		print("  frost range should be 340 (M3.1 coverage), got %.0f" % frost.range)
		return false
	if absf(frost.status_on_hit.slow_pct - 0.35) > 0.001 or absf(frost.status_on_hit.duration - 1.5) > 0.001:
		print("  frost slow should be 35%% for 1.5 s")
		return false
	if totem.build_cost != 130 or not totem.is_aura_only() or not totem.has_aura():
		print("  totem should cost 130 and be aura-only")
		return false
	if absf(totem.aura_radius - 260.0) > 0.001 or totem.aura_modifiers.size() != 2:
		print("  totem aura profile wrong")
		return false
	if absf(totem.aura_modifiers[0].multiplier - 0.15) > 0.001 or absf(totem.aura_modifiers[1].multiplier - 0.10) > 0.001:
		print("  totem should give +15%% damage / +10%% attack speed")
		return false

	var archer_levels := archer.levels
	if absf(archer_levels.damage_at(14.0, 10) - 14.0 * pow(1.18, 9.0)) > 0.01:
		print("  damage growth should be x1.18 per level")
		return false
	if absf(archer_levels.range_at(300.0, 10) - 300.0 * pow(1.02, 9.0)) > 0.01:
		print("  range growth should be x1.02 per level")
		return false
	if archer_levels.interval_at(0.9, 10) < 0.35 - 0.0001:
		print("  attack interval must floor at 0.35 s")
		return false
	if archer_levels.upgrade_cost(60, 9) <= archer_levels.upgrade_cost(60, 1):
		print("  upgrade cost should grow with level")
		return false

	var unit_archer := load("res://data/units/unit_archer.tres") as UnitData
	var unit_mage := load("res://data/units/unit_mage.tres") as UnitData
	var unit_druid := load("res://data/units/unit_druid.tres") as UnitData
	var units: Array[UnitData] = [unit_archer, unit_mage, unit_druid]
	for data in units:
		if data == null or data.levels == null or data.levels.max_level != 10:
			print("  unit resources need a 10-level curve")
			return false
		if data.levels.upgrade_cost(data.placement_cost, 1) != 50:
			print("  unit level-2 cost should be 50 cash, got %d" % data.levels.upgrade_cost(data.placement_cost, 1))
			return false
		if not TargetingStrategy.is_valid(data.target_mode):
			print("  unit %s targeting mode invalid" % data.id)
			return false
	if absf(unit_archer.damage - 8.0) > 0.001 or absf(unit_archer.attack_interval - 0.8) > 0.001:
		print("  unit_archer stats wrong")
		return false
	if absf(unit_mage.damage - 18.0) > 0.001 or absf(unit_mage.splash_radius - 50.0) > 0.001:
		print("  unit_mage stats wrong")
		return false
	if absf(unit_druid.damage - 5.0) > 0.001 or unit_druid.status_on_hit == null:
		print("  unit_druid stats wrong")
		return false
	print("  4 towers (3 tiers, L10 curves, behaviors) and 3 units match spec 4.4/4.5")
	return true


func test_wave_table_integrity() -> bool:
	var table := load(WAVE_TABLE_PATH) as WaveTable
	if table == null:
		print("  could not load ", WAVE_TABLE_PATH)
		return false
	if table.waves.size() != 60:
		print("  expected 60 waves, got ", table.waves.size())
		return false

	var boss_count := 0
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
		var expected_hp := _expected_hp(number)
		if absf(wave.hp_multiplier - expected_hp) > 0.01:
			print("  wave %d hp multiplier %f != %f" % [number, wave.hp_multiplier, expected_hp])
			return false
		var expected_speed := minf(1.0 + 0.01 * float(i), 1.40)
		if absf(wave.speed_multiplier - expected_speed) > 0.001:
			print("  wave %d speed multiplier wrong" % number)
			return false
		var expected_cash := pow(1.12, float(i))
		if absf(wave.cash_multiplier - expected_cash) > 0.001:
			print("  wave %d cash multiplier wrong" % number)
			return false
		if number > 1 and wave.hp_multiplier <= previous_hp:
			print("  hp multiplier is not increasing at wave %d" % number)
			return false
		previous_hp = wave.hp_multiplier

		var expected_total := mini(5 + int(floor(0.8 * float(number))), 40)
		if wave.total_count() != expected_total:
			print("  wave %d count %d != %d" % [number, wave.total_count(), expected_total])
			return false

		var boss_groups := 0
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
			if group.enemy_id == &"boss_troll":
				boss_groups += 1
				if group.count != 1:
					print("  wave %d spawns %d bosses" % [number, group.count])
					return false
				if absf(group.hp_multiplier - 1.20) > 0.001:
					print("  wave %d boss hp multiplier %f != 1.20" % [number, group.hp_multiplier])
					return false

		if BOSS_WAVES.has(number):
			boss_count += 1
			if not wave.is_boss:
				print("  wave %d should be a boss wave" % number)
				return false
			if boss_groups != 1:
				print("  wave %d should have exactly one boss group" % number)
				return false
		elif boss_groups != 0:
			print("  wave %d should not contain boss_troll" % number)
			return false
		if SWARM_WAVES.has(number) and wave.is_boss:
			print("  wave %d cannot be both swarm and boss" % number)
			return false

	if boss_count != BOSS_WAVES.size():
		print("  expected %d boss waves, got %d" % [BOSS_WAVES.size(), boss_count])
		return false
	for number in SWARM_WAVES:
		var swarm := table.get_wave(number)
		if swarm.groups.size() < 3:
			print("  wave %d should be a multi-group swarm (%d groups)" % [number, swarm.groups.size()])
			return false
	if table.starting_cash != 120:
		print("  starting cash should be 120 (M3.1), got %d" % table.starting_cash)
		return false
	if table.clear_bonus_base != 60 or table.clear_bonus_per_wave != 14:
		print("  clear bonus should be 60 + 14*wave, got %d + %d*wave" % [
			table.clear_bonus_base, table.clear_bonus_per_wave
		])
		return false
	print("  60 waves, 1.06x hp with a 4x step at wave 10 + late 1.20x, 1.12x cash, bosses x1.20")
	return true


## M8 wave curve: flat 1.06^w, a 4x step at the wave-10 boss, and a late 1.20^w
## acceleration past wave 40 so the maxed profile also ends before wave 60.
func _expected_hp(wave_number: int) -> float:
	var value := pow(1.06, float(wave_number - 1))
	if wave_number >= 10:
		value *= 4.0
	else:
		value *= 1.0 + 0.12 * float(wave_number - 1)
	if wave_number > 40:
		value *= pow(1.20, float(wave_number - 40))
	return value


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
	if map.unit_slot_requirements.size() != 4:
		print("  expected 4 slot requirements, got ", map.unit_slot_requirements.size())
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
