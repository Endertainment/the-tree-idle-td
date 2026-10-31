## StubAdsAdapter — desktop/editor fake ads (spec 7.1).
##
## Active only in debug builds with SettingsService.fake_monetization enabled. It
## plays the visible DebugAdOverlay for `debug_ad_seconds` and then reports success.
## No network, no SDK, no production IDs.
extends RefCounted

var _host: Node
var _config: MonetizationConfig
var _overlay: DebugAdOverlay
var _timer: SceneTreeTimer


func _init(host: Node) -> void:
	_host = host
	_config = MonetizationConfig.load_config()


func initialize() -> void:
	pass


func is_available() -> bool:
	return App.is_debug_build() and SettingsService.fake_monetization


func rewarded_available(_placement: StringName) -> bool:
	return is_available()


func consent_available() -> bool:
	return false


## The stub never owns a real UMP SDK; the service shows the local dialog.
func request_consent(callback: Callable) -> void:
	callback.call({"granted": false, "unavailable": true})


func show_rewarded(
	placement: StringName,
	on_earned: Callable,
	on_failed: Callable,
	on_closed: Callable
) -> void:
	if not is_available():
		on_failed.call(placement, &"ad_unavailable")
		return
	_play_overlay(placement, true, func() -> void:
		on_earned.call(placement)
		on_closed.call(placement)
	)


func show_interstitial(placement: StringName, on_closed: Callable, on_failed: Callable) -> bool:
	if not is_available():
		on_failed.call(placement, &"ad_unavailable")
		return false
	_play_overlay(placement, false, func() -> void:
		on_closed.call(placement)
	)
	return true


func _play_overlay(placement: StringName, rewarded: bool, done: Callable) -> void:
	if _host == null or not is_instance_valid(_host):
		# Headless/tool context: resolve immediately instead of leaking a timer.
		done.call()
		return
	var seconds := maxf(_config.debug_ad_seconds, 0.0)
	_overlay = DebugAdOverlay.new()
	_host.add_child(_overlay)
	_overlay.finished.connect(func() -> void:
		_overlay = null
		done.call()
	)
	_overlay.play(seconds, placement, rewarded)
