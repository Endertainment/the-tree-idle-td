## Ads flow smoke — exercises the real AdsService → stub adapter path headlessly.
##
## Usage:
##   godot --headless --path . --script res://tools/ads_flow_smoke.gd
##
## Verifies: consent-gated request, visible debug overlay (not asserted headless),
## one reward signal, per-day cap persistence and the graceful failure path when
## fake monetization is disabled. Restores the profile's shop/settings afterwards.
extends SceneTree

var _earned := 0
var _failed := 0
var _last_reason: StringName = &""


func _initialize() -> void:
	var app := root.get_node_or_null("App")
	if app == null:
		print("[FAIL] App autoload missing")
		quit(1)
		return
	await process_frame
	app.call("init_services")
	await process_frame
	var game_state := root.get_node_or_null("GameState")
	var settings := root.get_node_or_null("SettingsService")
	var ads := root.get_node_or_null("AdsService")
	if game_state == null or settings == null or ads == null:
		print("[FAIL] autoloads missing")
		quit(1)
		return
	var saved_shop: Dictionary = game_state.shop.duplicate(true)
	var saved_ads: Dictionary = game_state.ads.duplicate(true)
	var saved_fake: bool = settings.fake_monetization
	game_state.ads = {"rv_today": 0, "rv_day": "", "interstitial_last": 0, "caps": {}}
	ads.reset_for_test()
	ads.init_service()

	ads.rewarded_earned.connect(func(placement: StringName) -> void:
		_earned += 1
		print("[ads] earned: ", placement)
	)
	ads.rewarded_failed.connect(func(placement: StringName, reason: StringName) -> void:
		_failed += 1
		_last_reason = reason
		print("[ads] failed: ", placement, " ", reason)
	)

	var caps: Dictionary = ads.get_cap_status(&"speed_unlock_24h")
	print("[ads] cap before: ", caps)
	var accepted: bool = ads.show_rewarded(&"speed_unlock_24h")
	print("[ads] accepted: ", accepted)
	await create_timer(3.0).timeout

	var ok := _earned == 1 and _failed == 0
	if not ok:
		print("[FAIL] expected exactly one earned, got earned=%d failed=%d (%s)" % [
			_earned, _failed, _last_reason
		])

	# Cap: the same daily placement must now be rejected without a new ad.
	var second: bool = ads.show_rewarded(&"speed_unlock_24h")
	var caps_after: Dictionary = ads.get_cap_status(&"speed_unlock_24h")
	if second or bool(caps_after.get("available", true)):
		print("[FAIL] daily cap did not block the second request: ", caps_after)
		ok = false

	# Failure path: disabling the fake SDK must fail gracefully (no crash).
	settings.fake_monetization = false
	_earned = 0
	_failed = 0
	var accepted_fail: bool = ads.show_rewarded(&"free_cash")
	await create_timer(0.2).timeout
	if accepted_fail or _failed != 1 or _last_reason != &"ad_unavailable":
		print("[FAIL] expected a graceful ad_unavailable failure, got accepted=%s failed=%d reason=%s" % [
			str(accepted_fail), _failed, str(_last_reason)
		])
		ok = false

	# Restore the profile so the smoke has no side effects.
	game_state.shop = saved_shop
	game_state.ads = saved_ads
	settings.fake_monetization = saved_fake
	print("[ads] %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
