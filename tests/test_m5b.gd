## M5b tests: shop catalogue integrity, leaderboard ordering/own-rank insertion,
## profile stat aggregation and the global toast queue. Pure logic only.
extends RefCounted

const IapCatalogScript := preload("res://scripts/platform/iap_catalog.gd")
const LocalBackendStubScript := preload("res://scripts/platform/local_backend_stub.gd")
const ProfileStatsScript := preload("res://scripts/menu/profile_stats.gd")
const ToastQueueScript := preload("res://scripts/ui/toast_queue.gd")


func test_shop_catalog_integrity() -> bool:
	var products: Array[Dictionary] = IapCatalogScript.all()
	if products.size() != 7:
		print("  expected 7 products, got ", products.size())
		return false
	var expected_ids: Array[String] = [
		"thetree.gems_100", "thetree.gems_550", "thetree.gems_1200",
		"thetree.coins_5000", "thetree.starter_pack", "thetree.no_ads",
		"thetree.speed_pack",
	]
	var seen: Dictionary = {}
	var tab_counts: Dictionary = {"gems": 0, "coins": 0, "special": 0}
	for product: Dictionary in products:
		var product_id := str(product.get("id", ""))
		if product_id.is_empty() or seen.has(product_id):
			print("  empty or duplicate product id: ", product_id)
			return false
		if not expected_ids.has(product_id):
			print("  unexpected product id: ", product_id)
			return false
		seen[product_id] = true
		var tab := str(product.get("tab", ""))
		if not tab_counts.has(tab):
			print("  bad tab: ", tab)
			return false
		tab_counts[tab] = int(tab_counts[tab]) + 1
		if str(product.get("title_key", "")).is_empty() or str(product.get("contents_key", "")).is_empty():
			print("  missing localization keys for ", product_id)
			return false
		if not FileAccess.file_exists(str(product.get("icon", ""))):
			print("  icon missing for ", product_id, ": ", product.get("icon", ""))
			return false
		var bundle: Dictionary = product.get("bundle", {})
		for kind: String in bundle.keys():
			if int(bundle[kind]) <= 0:
				print("  non-positive bundle amount for ", product_id)
				return false
	if tab_counts["gems"] != 3 or tab_counts["coins"] != 1 or tab_counts["special"] != 3:
		print("  tab distribution wrong: ", tab_counts)
		return false
	if bool(IapCatalogScript.find("thetree.no_ads").get("consumable", true)):
		print("  no_ads must be non-consumable")
		return false
	if bool(IapCatalogScript.find("thetree.speed_pack").get("consumable", true)):
		print("  speed_pack must be non-consumable")
		return false
	var starter := IapCatalogScript.find("thetree.starter_pack")
	var starter_bundle: Dictionary = starter.get("bundle", {})
	if int(starter_bundle.get("gems", 0)) != 300 or int(starter_bundle.get("coins", 0)) != 2500:
		print("  starter pack contents mismatch: ", starter_bundle)
		return false
	if str(starter.get("card_rarity", "")) != "epic":
		print("  starter pack must include an epic card")
		return false
	if IapCatalogScript.find("thetree.missing").is_empty() == false:
		print("  unknown product lookup must return {}")
		return false
	var en := load("res://localization/strings.en.translation") as Translation
	var uk := load("res://localization/strings.uk.translation") as Translation
	if en == null or uk == null:
		print("  translation catalogues did not load")
		return false
	for product: Dictionary in products:
		for key_field: String in ["title_key", "contents_key"]:
			var key := str(product.get(key_field, ""))
			if en.get_message(key).is_empty() or uk.get_message(key).is_empty():
				print("  missing en/uk translation for ", key)
				return false
	print("  7 products, 3/1/3 tabs, bundles, keys and en/uk text valid")
	return true


func test_leaderboard_sorting_and_own_rank() -> bool:
	var now := 1_800_000_000
	var board := &"weekly"
	var entries: Array[Dictionary] = LocalBackendStubScript.generate(board, 18, now, "week-42")
	if entries.size() != 50:
		print("  expected 50 fake entries, got ", entries.size())
		return false
	var again: Array[Dictionary] = LocalBackendStubScript.generate(board, 18, now, "week-42")
	if entries != again:
		print("  fake cohort is not deterministic")
		return false
	var seen_names: Dictionary = {}
	for index in entries.size():
		var entry: Dictionary = entries[index]
		if seen_names.has(str(entry.get("nickname", ""))):
			print("  duplicate fake nickname: ", entry.get("nickname", ""))
			return false
		seen_names[str(entry.get("nickname", ""))] = true
		if index > 0 and int(entries[index - 1].get("best_wave", 0)) < int(entry.get("best_wave", 0)):
			print("  entries not sorted at index ", index)
			return false
	var own := {
		"id": "player_1", "nickname": "Tester", "avatar_id": "avatar_01",
		"best_wave": 19, "playtime": 3000, "submitted_at": now, "is_player": true,
	}
	var with_own: Array[Dictionary] = LocalBackendStubScript.insert_own(entries, own)
	if with_own.size() != 51:
		print("  own entry was not inserted exactly once: ", with_own.size())
		return false
	var rank: int = LocalBackendStubScript.rank_of(with_own, "player_1")
	if rank < 1 or rank > 51:
		print("  own rank out of range: ", rank)
		return false
	var own_count := 0
	for entry: Dictionary in with_own:
		if str(entry.get("id", "")) == "player_1":
			own_count += 1
	if own_count != 1:
		print("  duplicate own entry: ", own_count)
		return false
	var tied: Array[Dictionary] = [
		{"id": "late", "best_wave": 20, "submitted_at": now + 10, "playtime": 100},
		{"id": "early", "best_wave": 20, "submitted_at": now, "playtime": 900},
		{"id": "slow", "best_wave": 20, "submitted_at": now, "playtime": 1000},
	]
	var sorted_tie: Array[Dictionary] = LocalBackendStubScript.sort_entries(tied)
	if str(sorted_tie[0]["id"]) != "early" or str(sorted_tie[1]["id"]) != "slow":
		print("  tie-break is not earlier-submission then lower-playtime: ", sorted_tie)
		return false
	var tiers: Array[Dictionary] = LocalBackendStubScript.reward_tiers()
	if tiers.size() != 5:
		print("  expected 5 reward tiers, got ", tiers.size())
		return false
	var expected_stones := [100, 40, 20, 10, 5]
	for index in tiers.size():
		var tier: Dictionary = tiers[index]
		if int(tier.get("stones", 0)) != expected_stones[index]:
			print("  reward tier %d mismatch" % index)
			return false
	var tournament: Array[Dictionary] = LocalBackendStubScript.generate(&"tournament", 30, now, "w")
	if tournament.size() != 50:
		print("  tournament cohort size mismatch")
		return false
	print("  50 deterministic entries, stable sort, own rank and tiers verified")
	return true


func test_profile_stats_aggregation() -> bool:
	var player := {"level": 7, "xp": 50, "best_wave": 18, "nickname": "Tester"}
	var stats := {
		"best_wave": 18, "runs_played": 12, "total_kills": 340,
		"total_playtime": 7200, "coins_earned": 950,
	}
	var wallet := {"coins": 12480, "gems": 350}
	var summary: Dictionary = ProfileStatsScript.build(player, stats, wallet)
	if int(summary["best_wave"]) != 18 or int(summary["runs_played"]) != 12:
		print("  profile best wave/runs mismatch: ", summary)
		return false
	if int(summary["total_kills"]) != 340 or int(summary["total_playtime"]) != 7200:
		print("  profile kills/playtime mismatch: ", summary)
		return false
	if int(summary["coins_earned"]) != 950:
		print("  lifetime coins should win over balance: ", summary["coins_earned"])
		return false
	if int(summary["level"]) != 7 or int(summary["xp"]) != 50:
		print("  profile level/xp mismatch: ", summary)
		return false
	if float(summary["xp_ratio"]) <= 0.0 or float(summary["xp_ratio"]) > 1.0:
		print("  xp ratio out of range: ", summary["xp_ratio"])
		return false
	var legacy_stats := {"best_wave": 4, "runs_played": 1, "total_kills": 12, "total_playtime": 30}
	var legacy: Dictionary = ProfileStatsScript.build(
		{"level": 2, "xp": 10, "best_wave": 4},
		legacy_stats,
		{"coins": 300, "gems": 0}
	)
	if int(legacy["coins_earned"]) != 300:
		print("  legacy save should fall back to wallet coins: ", legacy["coins_earned"])
		return false
	if not ProfileStatsScript.has_nickname({"nickname": "Tester"}):
		print("  nickname helper rejected a valid name")
		return false
	if ProfileStatsScript.has_nickname({"nickname": "   "}):
		print("  nickname helper accepted blank text")
		return false
	print("  profile aggregation, legacy fallback and xp ratio verified")
	return true


func test_toast_queue() -> bool:
	var queue: ToastQueue = ToastQueueScript.new()
	if not queue.push("first"):
		print("  first toast was not promoted")
		return false
	if queue.push("second"):
		print("  second toast must wait behind the first")
		return false
	if queue.push("second"):
		print("  duplicate consecutive toast was queued")
		return false
	if queue.pending_count() != 1:
		print("  pending count should be 1, got ", queue.pending_count())
		return false
	if queue.current != "first":
		print("  current toast changed too early: ", queue.current)
		return false
	queue.complete()
	if queue.current != "second" or queue.pending_count() != 0:
		print("  queue did not advance to the second toast")
		return false
	queue.complete()
	if queue.is_active():
		print("  queue remained active after the last toast")
		return false
	if queue.push("  "):
		print("  empty toast was accepted")
		return false
	queue.push("a")
	queue.push("b")
	queue.clear()
	if queue.is_active() or queue.pending_count() != 0:
		print("  clear did not reset the queue")
		return false
	print("  one-at-a-time FIFO, duplicate suppression and clear verified")
	return true
