## M6 tests: ad placement caps, reward-once guard, IAP catalogue resource,
## billing reason mapping, consent defaults, speed boost persistence, analytics.
extends RefCounted

const M6_LOCALE_KEYS: Array[String] = [
	"consent.title",
	"consent.body",
	"consent.accept",
	"consent.decline",
	"ads.cap_reached",
	"ads.not_available",
	"ads.consent_required",
	"debug_ad.title",
	"menu.ad_loading",
	"menu.speed_trial_granted",
	"battle.ad_free_cash",
	"battle.ad_tree_blessing",
	"summary.ad_loading",
	"shop.purchase_success",
	"shop.purchase_cancelled",
	"shop.purchase_network_error",
	"settings.ad_consent",
]


func test_ad_placement_caps() -> Variant:
	var caps := AdCaps.new()
	caps.configure({
		"run_double_coins": {"type": "rewarded", "cap": 1, "period": "run"},
		"free_cash": {"type": "rewarded", "cap": 2, "period": "run"},
		"speed_unlock_24h": {"type": "rewarded", "cap": 1, "period": "day"},
		"shop_banner": {"type": "banner", "cap": 0, "period": "none"},
	})
	var today := "2026-10-31"
	if not bool(caps.can_show(&"run_double_coins", today).available):
		return _fail("fresh per-run placement should be available")
	caps.record(&"run_double_coins", today)
	if bool(caps.can_show(&"run_double_coins", today).available):
		return _fail("double coins is capped at 1/run")
	if int(caps.can_show(&"run_double_coins", today).used) != 1:
		return _fail("used count should be 1")
	caps.record(&"free_cash", today)
	caps.record(&"free_cash", today)
	if bool(caps.can_show(&"free_cash", today).available):
		return _fail("free cash is capped at 2/run")
	caps.reset_run()
	if not bool(caps.can_show(&"free_cash", today).available):
		return _fail("run caps reset between runs")
	if not bool(caps.can_show(&"speed_unlock_24h", today).available):
		return _fail("daily placement starts available")
	caps.record(&"speed_unlock_24h", today)
	if bool(caps.can_show(&"speed_unlock_24h", today).available):
		return _fail("speed trial is capped at 1/day")
	if not bool(caps.can_show(&"speed_unlock_24h", "2026-11-01").available):
		return _fail("daily caps reset on a new local date")
	if bool(caps.can_show(&"shop_banner", today).available):
		return _fail("banners are not supported in M6")
	var restored := AdCaps.new()
	restored.configure({"free_cash": {"type": "rewarded", "cap": 2, "period": "run"}})
	restored.from_dict(caps.to_dict())
	if int(restored.used(&"free_cash")) != 0:
		return _fail("caps restore the recorded run count")
	return true


func test_interstitial_cadence() -> Variant:
	var caps := AdCaps.new()
	caps.configure({"run_end_interstitial": {"type": "interstitial", "cap": 0, "period": "none"}})
	var ok := caps.can_show_interstitial(1000, 3, 5, 0, 3, 120, 5)
	if not bool(ok.available):
		return _fail("3rd run at wave 5 with no previous interstitial should show")
	if bool(caps.can_show_interstitial(1000, 4, 5, 0, 3, 120, 5).available):
		return _fail("only every 3rd run may show an interstitial")
	if bool(caps.can_show_interstitial(1000, 3, 4, 0, 3, 120, 5).available):
		return _fail("interstitials never show before wave 5")
	if bool(caps.can_show_interstitial(1000, 3, 9, 950, 3, 120, 5).available):
		return _fail("interstitials respect the 120 s minimum interval")
	if not bool(caps.can_show_interstitial(1200, 3, 9, 950, 3, 120, 5).available):
		return _fail("interstitial is available after the interval")
	return true


func test_reward_once_guard() -> Variant:
	var guard := AdRewardGuard.new()
	if not guard.begin(&"free_cash"):
		return _fail("first view should start")
	if guard.begin(&"tree_blessing"):
		return _fail("a second ad must not start while one is active")
	if not guard.claim(&"free_cash"):
		return _fail("first claim should pay")
	if guard.claim(&"free_cash"):
		return _fail("duplicate SDK callback must not pay twice")
	if guard.claim(&"tree_blessing"):
		return _fail("a different placement cannot claim the active view")
	guard.finish()
	if guard.claim(&"free_cash"):
		return _fail("finished view cannot claim")
	if not guard.begin(&"tree_blessing"):
		return _fail("guard is reusable after dismissal")
	return true


func test_iap_catalog_resource() -> Variant:
	var catalog := load(ShopCatalog.PATH) as ShopCatalog
	if catalog == null:
		return _fail("config/shop.tres must load as ShopCatalog")
	if catalog.products.size() != 7:
		return _fail("shop.tres must contain the seven §7.3 products")
	var expected := PackedStringArray([
		"thetree.gems_100", "thetree.gems_550", "thetree.gems_1200",
		"thetree.coins_5000", "thetree.starter_pack", "thetree.no_ads",
		"thetree.speed_pack",
	])
	for product: Dictionary in catalog.products:
		var id := str(product.get("id", ""))
		if not expected.has(id):
			return _fail("unexpected product %s" % id)
		if str(product.get("price", "")).strip_edges() != "":
			return _fail("committed catalog must not ship store prices")
	if IapCatalog.all().size() != 7:
		return _fail("IapCatalog must expose the catalog resource")
	if IapCatalog.for_tab("gems").size() != 3:
		return _fail("three gem products")
	if IapCatalog.for_tab("coins").size() != 1:
		return _fail("one coin product")
	if IapCatalog.for_tab("special").size() != 3:
		return _fail("three special products")
	if IapCatalog.find("thetree.no_ads").is_empty():
		return _fail("no-ads product must exist")
	if not IapCatalog.is_consumable("thetree.gems_100"):
		return _fail("gem packs are consumable")
	if IapCatalog.is_consumable("thetree.no_ads"):
		return _fail("no-ads is a one-time purchase")
	return true


func test_monetization_config() -> Variant:
	var config := MonetizationConfig.load_config()
	if config == null:
		return _fail("monetization config must load")
	if not config.test_ids:
		return _fail("committed config must use test ad IDs")
	if not config.app_id.begins_with("ca-app-pub-3940256099942544"):
		return _fail("app id must be Google's test app id")
	if not config.rewarded_unit_id.begins_with("ca-app-pub-3940256099942544"):
		return _fail("rewarded unit must be a test unit")
	if config.analytics_enabled:
		return _fail("analytics must be off by default")
	var placements := config.placements
	if int((placements.get("run_double_coins", {}) as Dictionary).get("cap", 0)) != 1:
		return _fail("double coins cap 1/run")
	if int((placements.get("free_cash", {}) as Dictionary).get("cap", 0)) != 2:
		return _fail("free cash cap 2/run")
	if int((placements.get("research_speedup", {}) as Dictionary).get("cap", 0)) != 3:
		return _fail("research speedup cap 3/day")
	if int(config.interstitial_every_runs) != 3:
		return _fail("interstitial every 3rd run")
	if int(config.interstitial_min_interval_seconds) != 120:
		return _fail("interstitial min interval 120 s")
	if int(config.interstitial_min_wave) != 5:
		return _fail("interstitial never before wave 5")
	return true


func test_billing_reason_mapping() -> Variant:
	if BillingReasons.reason_for(BillingReasons.OK) != &"ok":
		return _fail("OK code")
	if BillingReasons.reason_for(BillingReasons.USER_CANCELED) != &"cancelled":
		return _fail("user cancel maps to cancelled")
	if BillingReasons.reason_for(BillingReasons.ITEM_ALREADY_OWNED) != &"already_owned":
		return _fail("already owned")
	if BillingReasons.reason_for(BillingReasons.NETWORK_ERROR) != &"network_error":
		return _fail("network error")
	if BillingReasons.reason_for(BillingReasons.BILLING_UNAVAILABLE) != &"store_unavailable":
		return _fail("billing unavailable")
	if BillingReasons.reason_for(999) != &"unknown":
		return _fail("unknown code")
	if BillingReasons.locale_key(&"cancelled") != "shop.purchase_cancelled":
		return _fail("cancelled locale key")
	return true


func test_speed_boost_persistence() -> Variant:
	var game_state := _autoload("GameState")
	var time_service := _autoload("TimeService")
	if game_state == null or time_service == null:
		return _fail("GameState/TimeService autoloads must exist")
	var saved: Dictionary = game_state.shop.duplicate(true)
	var now := int(time_service.now_unix())
	game_state.shop["speed_boost_until"] = now + 3600
	game_state.shop["speed_boost_unlock"] = "speed_1_5"
	if not game_state.has_speed_boost(&"speed_1_5"):
		return _fail("active boost should unlock 1.5x")
	if game_state.has_speed_boost(&"speed_2"):
		return _fail("1.5x boost must not grant 2x")
	game_state.shop["speed_boost_unlock"] = "speed_2"
	if not game_state.has_speed_boost(&"speed_1_5") or not game_state.has_speed_boost(&"speed_2"):
		return _fail("a 2x boost implies the lower tier")
	if game_state.speed_boost_remaining() <= 0:
		return _fail("remaining seconds should be positive")
	game_state.shop["speed_boost_until"] = now - 1
	if game_state.has_speed_boost(&"speed_1_5"):
		return _fail("expired boost must not unlock")
	if game_state.speed_boost_remaining() != 0:
		return _fail("expired boost reports zero seconds")
	game_state.shop = saved
	return true


func test_m6_locale_keys() -> Variant:
	var locale := _autoload("LocaleService")
	if locale == null:
		return _fail("LocaleService autoload must exist")
	for key: String in M6_LOCALE_KEYS:
		if not locale.has_key(key):
			return _fail("missing M6 locale key: %s" % key)
	return true


func test_analytics_privacy_sanitize() -> Variant:
	var analytics := _autoload("AnalyticsService")
	if analytics == null:
		return _fail("AnalyticsService autoload must exist")
	var clean: Dictionary = analytics._sanitize({
		"wave": 7,
		"ratio": 0.5,
		"flag": true,
		"nickname": "Vova",
		"nested": {"secret": "x"},
		"long": "x".repeat(300),
	})
	if not clean.has("wave") or not clean.has("ratio") or not clean.has("flag"):
		return _fail("scalar props should survive")
	if clean.has("nested"):
		return _fail("nested dictionaries must never be sent")
	if int(clean.get("long", "").length()) > 120:
		return _fail("strings must be truncated")
	if analytics.is_enabled():
		return _fail("analytics must be disabled without an endpoint")
	if analytics.pending_count() != 0:
		return _fail("disabled analytics must not queue")
	return true


func _autoload(node_name: String) -> Node:
	return Engine.get_main_loop().root.get_node_or_null(NodePath(node_name)) as Node


func _fail(message: String) -> Variant:
	print("  FAIL: ", message)
	return false
