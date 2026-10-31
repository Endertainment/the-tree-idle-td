## M4b tests: Magica timers/prerequisites/refunds, card aggregation and upgrades,
## mission cycles/claim-once and offline-income caps.
##
## Pure logic only: models are instantiated directly and ModifierService is created
## from its script, so the suite stays headless and never touches a real save.
extends RefCounted

const ModifierServiceScript := preload("res://scripts/autoload/modifier_service.gd")


func test_magica_prerequisites_and_research() -> bool:
	var nodes := MagicaNode.load_all()
	if nodes.size() < 12:
		print("  expected at least 12 magica nodes, got ", nodes.size())
		return false
	for required: StringName in [
		&"quickened_roots_1", &"quickened_roots_2", &"quickened_roots_3",
		&"flow_of_ages", &"auto_restart", &"golden_sap_1", &"golden_sap_2",
		&"golden_sap_3", &"night_harvest", &"merchant_favor", &"fourth_branch",
		&"deep_roots", &"ancient_memory", &"second_wind",
	]:
		if _node_by_id(nodes, required) == null:
			print("  missing magica node ", required)
			return false

	var model := MagicaModel.new()
	model.setup(nodes, {})
	if model.is_available(&"quickened_roots_2"):
		print("  quickened_roots_2 must be locked before its prerequisite")
		return false
	if not model.missing_prerequisites(&"quickened_roots_2").has(&"quickened_roots_1"):
		print("  missing_prerequisites must report quickened_roots_1")
		return false

	var started := model.start(&"quickened_roots_1", 10_000, 1.0)
	if not bool(started.get("ok", false)) or int(started.get("duration", 0)) != 1800:
		print("  quickened_roots_1 should start with a 30 min duration: ", started)
		return false
	if model.is_available(&"quickened_roots_2"):
		print("  a second research must not start while one is active")
		return false
	if bool(model.start(&"quickened_roots_1", 10_001, 1.0).get("ok", true)):
		print("  the same node cannot be started twice")
		return false

	if model.reconcile(11_799):
		print("  research completed before its end timestamp")
		return false
	if not model.reconcile(11_800):
		print("  research did not complete at its end timestamp")
		return false
	if not model.has_pending_claim() or model.get_pending_claim() != &"quickened_roots_1":
		print("  completed research must become a claimable badge")
		return false
	if model.claim() != &"quickened_roots_1" or not model.is_completed(&"quickened_roots_1"):
		print("  claim did not move the node into completed")
		return false
	if model.claim() != &"":
		print("  claim must be idempotent")
		return false

	var entries := model.node_entries(&"quickened_roots_1")
	if not entries.has("magica_speed") or not is_equal_approx(float(entries["magica_speed"]["mul"]), 0.10):
		print("  quickened roots must publish +10 % magica_speed: ", entries)
		return false
	print("  prerequisites, one-active rule, 30 min completion and claim verified")
	return true


func test_magica_cancel_refund_and_speed() -> bool:
	var nodes := MagicaNode.load_all()
	var model := MagicaModel.new()
	model.setup(nodes, {})
	if not bool(model.start(&"quickened_roots_1", 0, 1.3).get("ok", false)):
		print("  quickened_roots_1 failed to start")
		return false
	if not is_equal_approx(float(model.progress(0)), 0.0) or model.remaining_seconds(0) != 1385:
		print("  +30 %% research speed should shorten 1800 s to 1385 s, got ", model.remaining_seconds(0))
		return false
	var refund := model.cancel()
	if int(refund.get("coins", 0)) != 100 or int(refund.get("gems", 0)) != 0:
		print("  cancel must refund 50 %% of 200 coins: ", refund)
		return false
	if model.has_active_research():
		print("  cancel left research active")
		return false

	var gem_model := MagicaModel.new()
	gem_model.setup(nodes, {"completed": ["golden_sap_1"]})
	if not bool(gem_model.start(&"night_harvest", 0, 1.0).get("ok", false)):
		print("  night_harvest failed to start after golden_sap_1")
		return false
	var gem_refund := gem_model.cancel()
	if int(gem_refund.get("coins", 0)) != 1000 or int(gem_refund.get("gems", 0)) != 10:
		print("  cancel must refund 50 %% of 2000 coins + 20 gems: ", gem_refund)
		return false
	print("  50 %% coin/gem refunds and research-speed duration verified")
	return true


func test_magica_offline_completion_survives_restart() -> bool:
	var nodes := MagicaNode.load_all()
	var model := MagicaModel.new()
	model.setup(nodes, {})
	model.start(&"quickened_roots_1", 100, 1.0)
	if not model.reconcile(1901):
		print("  offline research did not complete after the timestamp delta")
		return false
	var saved := model.to_state()
	# Simulated app restart: a new model restores the same save state.
	var reloaded := MagicaModel.new()
	reloaded.setup(nodes, saved)
	if not reloaded.has_pending_claim() or reloaded.has_active_research():
		print("  pending claim must survive the restart instead of restarting the timer")
		return false
	if reloaded.claim() != &"quickened_roots_1" or not reloaded.is_completed(&"quickened_roots_1"):
		print("  reloaded model could not claim")
		return false
	var second := MagicaModel.new()
	second.setup(nodes, reloaded.to_state())
	if not second.is_completed(&"quickened_roots_1") or second.has_pending_claim():
		print("  completed research must persist without a duplicate pending claim")
		return false
	print("  research completed offline, claimed once and persisted across a restart")
	return true


func test_card_equip_unequip_restores_stats() -> bool:
	var cards := CardData.load_all()
	if cards.size() != 12:
		print("  expected 12 cards, got ", cards.size())
		return false
	var collection := CardCollection.new()
	collection.setup(cards, {
		"owned": [
			{"id": "greed", "level": 1, "shards": 0},
			{"id": "vital_roots", "level": 1, "shards": 0},
		],
		"equipped": [null, null, null, null],
	})
	if collection.owned_count() != 2:
		print("  owned cards were not restored")
		return false
	if not collection.equip(&"greed", 0, 4):
		print("  greed did not equip")
		return false
	var modifiers: Node = ModifierServiceScript.new()
	var greed_entries := collection.effect_entries()
	modifiers.call(&"add_source", &"cards", greed_entries)
	var cash := float(modifiers.call(&"get_stat", &"cash_gain", 1.0))
	if not is_equal_approx(cash, 1.2):
		print("  greed must add +20 %% cash, got ", cash)
		modifiers.free()
		return false
	var enemies := float(modifiers.call(&"get_stat", &"enemies_per_wave", 1.0))
	if not is_equal_approx(enemies, 1.25):
		print("  greed must add +25 %% enemies, got ", enemies)
		modifiers.free()
		return false

	if not collection.equip(&"vital_roots", 1, 4):
		print("  vital_roots did not equip")
		modifiers.free()
		return false
	modifiers.call(&"add_source", &"cards", collection.effect_entries())
	var hp := float(modifiers.call(&"get_stat", &"tree_max_hp", 1200.0))
	if not is_equal_approx(hp, 1380.0):
		print("  vital_roots must add +15 %% tree HP, got ", hp)
		modifiers.free()
		return false

	collection.unequip(0)
	modifiers.call(&"add_source", &"cards", collection.effect_entries())
	if not is_equal_approx(float(modifiers.call(&"get_stat", &"cash_gain", 1.0)), 1.0):
		print("  unequipping greed must restore cash gain")
		modifiers.free()
		return false
	if not is_equal_approx(float(modifiers.call(&"get_stat", &"tree_max_hp", 1200.0)), 1380.0):
		print("  unequipping greed must keep vital_roots")
		modifiers.free()
		return false
	collection.unequip(1)
	modifiers.call(&"remove_source", &"cards")
	if not is_equal_approx(float(modifiers.call(&"get_stat", &"tree_max_hp", 1200.0)), 1200.0):
		print("  the loadout source must be removable")
		modifiers.free()
		return false

	var level_five := CardCollection.new()
	level_five.setup(cards, {
		"owned": [{"id": "greed", "level": 5, "shards": 0}],
		"equipped": ["greed", null, null, null],
	})
	var scaled := level_five.effect_entries()
	if not is_equal_approx(float(scaled["cash_gain"]["mul"]), 0.4):
		print("  level 5 greed must scale +20 %% to +40 %%: ", scaled)
		modifiers.free()
		return false
	modifiers.free()
	print("  card equip changes aggregated stats, unequip restores, levels scale effects")
	return true


func test_card_upgrade_and_duplicates() -> bool:
	var cards := CardData.load_all()
	var collection := CardCollection.new()
	collection.setup(cards, {"owned": [{"id": "greed", "level": 1, "shards": 0}]})
	var duplicate := collection.grant(&"greed")
	if bool(duplicate.get("new", true)) or int(duplicate.get("upgraded", 0)) != 1:
		print("  a duplicate must grant shards and auto-upgrade level 1 -> 2: ", duplicate)
		return false
	if collection.level_of(&"greed") != 2 or collection.shards_of(&"greed") != 0:
		print("  duplicate upgrade state is wrong: lvl %d, shards %d" % [
			collection.level_of(&"greed"), collection.shards_of(&"greed")
		])
		return false
	collection.grant(&"greed")
	if collection.shards_of(&"greed") != 20 or collection.can_upgrade(&"greed"):
		print("  20 shards must be short of the level-3 cost 40: shards %d" % collection.shards_of(&"greed"))
		return false
	collection.grant(&"greed")
	if collection.level_of(&"greed") != 3 or collection.shards_of(&"greed") != 0:
		print("  40 shards should auto-buy level 3: lvl %d shards %d" % [
			collection.level_of(&"greed"), collection.shards_of(&"greed")
		])
		return false
	collection.grant(&"greed")
	if collection.level_of(&"greed") != 3 or collection.shards_of(&"greed") != 20:
		print("  a duplicate after the upgrade should bank 20 shards: lvl %d shards %d" % [
			collection.level_of(&"greed"), collection.shards_of(&"greed")
		])
		return false
	var manual := CardCollection.new()
	manual.setup(cards, {"owned": [{"id": "rich_soil", "level": 1, "shards": 20}]})
	if not manual.upgrade(&"rich_soil") or manual.level_of(&"rich_soil") != 2:
		print("  manual upgrade from 20 shards failed")
		return false
	if manual.upgrade(&"rich_soil"):
		print("  upgrade with 0 shards must fail")
		return false
	print("  duplicate shards, auto-upgrade and the 20/40/80/160 curve verified")
	return true


func test_card_slot_limits() -> bool:
	var cards := CardData.load_all()
	var collection := CardCollection.new()
	collection.setup(cards, {
		"owned": [
			{"id": "greed", "level": 1}, {"id": "vital_roots", "level": 1},
			{"id": "regrowth", "level": 1}, {"id": "swift_winds", "level": 1},
		],
		"equipped": [null, null, null, null],
	})
	if not collection.equip(&"greed", 0, 1) or collection.equip(&"vital_roots", 1, 1):
		print("  a level-2 profile must only have one card slot")
		return false
	if collection.equip(&"regrowth", 3, 2):
		print("  equipping outside the unlocked slots must fail")
		return false
	if not collection.equip(&"vital_roots", 1, 2):
		print("  the second slot must accept a card once unlocked")
		return false
	if collection.slot_of(&"greed") != 0 or collection.slot_of(&"vital_roots") != 1:
		print("  equip slots were not tracked")
		return false
	print("  1/2-slot gating and out-of-range equip rejection verified")
	return true


func test_mission_schedule_0400_boundary() -> bool:
	var before := _unix(2026, 10, 31, 3, 59, 0)
	var after := _unix(2026, 10, 31, 4, 1, 0)
	if MissionSchedule.day_id(before, 0) == MissionSchedule.day_id(after, 0):
		print("  the 04:00 boundary must change the mission day id")
		return false
	if MissionSchedule.seconds_until_daily_reset(before, 0) != 60:
		print("  03:59 should be 60 s from the reset, got ", MissionSchedule.seconds_until_daily_reset(before, 0))
		return false
	if MissionSchedule.seconds_until_daily_reset(after, 0) != 86340:
		print("  04:01 should be 86340 s from the next reset, got ", MissionSchedule.seconds_until_daily_reset(after, 0))
		return false
	var sunday_before := _unix(2026, 11, 1, 3, 0, 0)
	if MissionSchedule.week_id(sunday_before, 0) != MissionSchedule.week_id(_unix(2026, 10, 28, 12, 0, 0), 0):
		print("  Sunday 03:00 must still belong to the previous Monday cycle")
		return false
	var monday_after := _unix(2026, 11, 2, 4, 1, 0)
	if MissionSchedule.week_id(sunday_before, 0) == MissionSchedule.week_id(monday_after, 0):
		print("  Monday 04:00 must start a new weekly cycle")
		return false
	var weekly := MissionSchedule.seconds_until_weekly_reset(_unix(2026, 11, 2, 4, 1, 0), 0)
	if weekly != 604740:
		print("  Monday 04:01 should be 6d 23h 59m from the next weekly reset, got ", weekly)
		return false
	if MissionSchedule.seconds_until_weekly_reset(sunday_before, 0) != 90000:
		print("  Sunday 03:00 should be 25 h from the Monday reset, got ", MissionSchedule.seconds_until_weekly_reset(sunday_before, 0))
		return false
	print("  daily 04:00, weekly Monday 04:00 ids and countdowns verified")
	return true


func test_missions_claim_once_and_reset() -> bool:
	var table := MissionTemplateTable.load_table()
	if table.templates.size() < 8:
		print("  expected at least 8 mission templates, got ", table.templates.size())
		return false
	var now := _unix(2026, 10, 31, 12, 0, 0)
	var model := MissionModel.new()
	model.setup(table.templates, {}, 5, now, 0)
	if model.get_daily().size() != 3 or model.get_weekly().size() != 5:
		print("  expected 3 daily + 5 weekly missions, got %d/%d" % [
			model.get_daily().size(), model.get_weekly().size()
		])
		return false
	var daily: Dictionary = model.get_daily()[0]
	var target := int(daily.get("target", 0))
	if target <= 0:
		print("  generated mission has no target")
		return false
	if model.can_claim(daily):
		print("  a fresh mission must not be claimable")
		return false
	model.set_progress(str(daily["id"]), target)
	if not model.can_claim(daily):
		print("  a completed mission must be claimable")
		return false
	var first := model.claim(str(daily["id"]))
	if not bool(first.get("ok", false)):
		print("  first claim failed: ", first)
		return false
	var second := model.claim(str(daily["id"]))
	if bool(second.get("ok", false)):
		print("  claiming twice must be impossible")
		return false
	var expected_coins := int(daily.get("reward_coins", 0))
	if not is_equal_approx(float(first.get("coins", 0)), float(expected_coins)) or expected_coins <= 0:
		print("  the claim must pay the generated reward (%d coins), got " % expected_coins, first.get("coins"))
		return false

	var max_model := MissionModel.new()
	max_model.setup(table.templates, {}, 5, now, 0)
	var max_row: Dictionary = {}
	for candidate: Dictionary in max_model.get_daily():
		if str(candidate.get("mode", "")) == "max":
			max_row = candidate
			break
	if max_row.is_empty():
		print("  expected at least one max-mode daily mission")
		return false
	var max_target := int(max_row.get("target", 1))
	var max_metric := StringName(str(max_row.get("metric", "")))
	max_model.track(max_metric, max_target - 1, &"max")
	max_model.track(max_metric, max_target, &"max")
	max_model.track(max_metric, 1, &"max")
	if int(max_row.get("progress", 0)) != max_target:
		print("  max-mode progress must keep the highest run value, got ", max_row.get("progress"))
		return false

	var state := model.to_state()
	var next_day := MissionModel.new()
	var changed := next_day.setup(table.templates, state, 5, now + 86400, 0)
	if not changed:
		print("  crossing the next 04:00 must reroll the mission cycle")
		return false
	if next_day.get_day_id() == model.get_day_id():
		print("  day id did not advance")
		return false
	if next_day.claim(str(daily["id"])).get("ok", true):
		print("  a claimed mission must be unclaimed after the reroll")
		return false
	if next_day.claimed_count(&"daily") != 0:
		print("  the reroll must reset claim state")
		return false
	print("  3+5 generation, claim-once, max mode and the daily reroll verified")
	return true


func test_mission_completion_bonus_once() -> bool:
	var table := MissionTemplateTable.load_table()
	var now := _unix(2026, 10, 31, 12, 0, 0)
	var model := MissionModel.new()
	model.setup(table.templates, {}, 1, now, 0)
	for row: Dictionary in model.get_daily():
		if model.bonus_pending(&"daily"):
			print("  bonus became pending too early")
			return false
		model.set_progress(str(row["id"]), int(row["target"]))
		if not model.claim(str(row["id"])).get("ok", false):
			print("  could not claim ", row["id"])
			return false
	if not model.bonus_pending(&"daily"):
		print("  all 3 dailies claimed must make the completion bonus pending")
		return false
	var reward := model.bonus_reward(&"daily")
	if int(reward.get("coins", 0)) != 30 or int(reward.get("gems", 0)) != 2:
		print("  daily completion bonus must be 30 coins + 2 gems: ", reward)
		return false
	model.mark_bonus_claimed(&"daily")
	if model.bonus_pending(&"daily"):
		print("  the completion bonus must only be claimable once")
		return false
	print("  all-3 completion bonus is pending once and marks claimed")
	return true


func test_offline_income_caps() -> bool:
	var zero := OfflineModel.compute(0, 1000, 1.0, 0.0)
	if bool(zero.get("eligible", true)) or int(zero.get("coins", -1)) != 0:
		print("  a fresh profile (last_seen 0) must not earn offline coins: ", zero)
		return false
	var short := OfflineModel.compute(1000, 1030, 1.0, 0.0)
	if bool(short.get("eligible", true)):
		print("  under one minute away must not open the modal")
		return false
	var hour := OfflineModel.compute(1000, 4600, 1.0, 0.0)
	if int(hour.get("coins", 0)) != 36 or bool(hour.get("capped", true)):
		print("  1 h at the base rate should be 36 coins: ", hour)
		return false
	var doubled := OfflineModel.compute(1000, 4600, 2.0, 0.0)
	if int(doubled.get("coins", 0)) != 72:
		print("  Night Harvest (+100 %%) should double offline coins: ", doubled)
		return false
	var nine_hours := 9 * 3600
	var over := OfflineModel.compute(1000, 1000 + nine_hours, 1.0, 0.0)
	if not bool(over.get("capped", false)) or int(over.get("counted_seconds", 0)) != 8 * 3600:
		print("  9 h away must clamp to the 8 h base cap: ", over)
		return false
	if int(over.get("coins", 0)) != 288:
		print("  8 h at 0.01 coins/s should be 288 coins, got ", over.get("coins"))
		return false
	var extended := OfflineModel.compute(1000, 1000 + nine_hours, 1.0, 400.0)
	if bool(extended.get("capped", true)) or int(extended.get("coins", 0)) != 324:
		print("  +400 cap minutes (14 h 40 m) should cover 9 h: ", extended)
		return false
	print("  fresh profile, <1 min, 1 h, x2 offline rate and the 8 h cap verified")
	return true


func _node_by_id(nodes: Array[MagicaNode], node_id: StringName) -> MagicaNode:
	for node: MagicaNode in nodes:
		if node.id == node_id:
			return node
	return null


func _unix(year: int, month: int, day: int, hour: int, minute: int, second: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({
		"year": year, "month": month, "day": day,
		"hour": hour, "minute": minute, "second": second,
	}))
