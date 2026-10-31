## AdsService — the only ads entry point for UI (spec 7.1).
##
## Owns placement caps, the consent gate, one-reward-per-view and the interstitial
## cadence. The platform SDK lives behind an adapter (Android AdMob or desktop stub);
## `OS.has_feature("android")` never appears here. No placement can grant anything
## without a successful reward callback, and every failure carries a reason the UI
## turns into a toast.
extends Node

signal rewarded_earned(placement: StringName)
signal rewarded_failed(placement: StringName, reason: StringName)
signal interstitial_closed()
signal consent_changed(granted: bool)
signal availability_changed(ready: bool)

const PLACEMENT_DOUBLE_COINS := &"run_double_coins"
const PLACEMENT_SPEED := &"speed_unlock_24h"
const PLACEMENT_FREE_CASH := &"free_cash"
const PLACEMENT_TREE_BLESSING := &"tree_blessing"
const PLACEMENT_RESEARCH := &"research_speedup"
const PLACEMENT_INTERSTITIAL := &"run_end_interstitial"
const REASON_CAP_REACHED := &"cap_reached"
const REASON_CONSENT := &"consent_required"
const REASON_BUSY := &"busy"
const REASON_UNAVAILABLE := &"ad_unavailable"
const REASON_DISMISSED := &"dismissed"
const WATCHDOG_SECONDS := 60.0

var _config: MonetizationConfig
var _caps: AdCaps
var _guard: AdRewardGuard
var _adapter: RefCounted
var _initialized: bool = false
var _adapter_ready: bool = false
var _consent_granted: bool = false
var _consent_in_flight: bool = false
var _consent_waiters: Array[Callable] = []
var _pending_placement: StringName = &""
var _watchdog_generation: int = 0
var _watchdog: SceneTreeTimer
var _interstitial_runs: int = 0
var _interstitial_wave: int = 0
var _last_interstitial: int = 0


func _ready() -> void:
	_ensure_state()
	# SDK init must never block boot: do it after the first frame.
	call_deferred(&"_deferred_init")


## Builds the config/policy objects once (also safe if init_service runs early).
func _ensure_state() -> void:
	if _config != null and _caps != null and _guard != null and _adapter != null:
		return
	_config = MonetizationConfig.load_config()
	_caps = AdCaps.new()
	_caps.configure(_config.placements)
	_guard = AdRewardGuard.new()
	_consent_granted = SettingsService.consent_granted
	if _adapter == null:
		_adapter = AdAdapterFactory.create(self)


func _deferred_init() -> void:
	if _initialized:
		return
	_initialized = true
	_adapter.initialize()
	_adapter_ready = _adapter.is_available()
	if not _adapter_ready:
		push_warning("AdsService: adapter unavailable; rewarded placements will fail gracefully")


## Called by the Android adapter when GMA finishes initializing (async).
func _on_adapter_ready() -> void:
	if _adapter_ready:
		return
	_adapter_ready = true
	print("[AdsService] ad SDK ready")
	availability_changed.emit(true)


## Called by App after the save is loaded: restores cap counters and consent.
func init_service() -> void:
	_ensure_state()
	_consume_persisted()
	_consent_granted = SettingsService.consent_granted


## Restores per-run/day counters and the last interstitial timestamp.
func _consume_persisted() -> void:
	var data: Dictionary = GameState.ads
	var caps: Variant = data.get("caps", {})
	if caps is Dictionary:
		_caps.from_dict(caps)
	_last_interstitial = int(data.get("interstitial_last", 0))


func is_ready(placement: StringName) -> bool:
	if not _config.is_rewarded(placement):
		return false
	if _guard.is_busy() or not _pending_placement.is_empty():
		return false
	_adapter_ready = _adapter_ready and _adapter.is_available()
	if not _adapter_ready:
		return false
	return bool(_caps.can_show(placement, _today()).get("available", false))


## Requests one rewarded view. Returns true when the request was accepted (the
## result arrives via rewarded_earned / rewarded_failed).
func show_rewarded(placement: StringName) -> bool:
	if not _config.is_rewarded(placement):
		_fail(placement, &"unknown_placement")
		return false
	if _guard.is_busy() or not _pending_placement.is_empty():
		_fail(placement, REASON_BUSY)
		return false
	_adapter_ready = _adapter_ready and _adapter.is_available()
	if not _adapter_ready:
		_fail(placement, REASON_UNAVAILABLE)
		return false
	var status := _caps.can_show(placement, _today())
	if not bool(status.get("available", false)):
		_fail(placement, StringName(str(status.get("reason", REASON_CAP_REACHED))))
		return false
	_pending_placement = placement
	_ensure_consent(_on_consent_then_show.bind(placement))
	return true


func _on_consent_then_show(granted: bool, placement: StringName) -> void:
	if not granted:
		_pending_placement = &""
		_fail(placement, REASON_CONSENT)
		return
	if not _guard.begin(placement):
		_pending_placement = &""
		_fail(placement, REASON_BUSY)
		return
	AnalyticsService.track(&"ad_shown", {"placement": String(placement), "type": "rewarded"})
	_start_watchdog(placement)
	_adapter.show_rewarded(placement, _on_ad_earned, _on_ad_failed, _on_ad_closed)


## Attempts the run-end interstitial. Returns false when capped, not ready or when
## the "No Ads" entitlement disables interstitials.
func show_interstitial(placement: StringName) -> bool:
	if placement != PLACEMENT_INTERSTITIAL or not _config.is_interstitial(placement):
		return false
	if _has_no_ads():
		return false
	_adapter_ready = _adapter_ready and _adapter.is_available()
	if not _adapter_ready:
		return false
	if not _consent_granted:
		# Ask first; the caller can continue without the ad.
		_ensure_consent(func(_granted: bool) -> void:
			if _granted:
				_show_interstitial_now(placement)
		)
		return true
	return _show_interstitial_now(placement)


func _show_interstitial_now(placement: StringName) -> bool:
	var status := _caps.can_show_interstitial(
		TimeService.now_unix(),
		_interstitial_runs,
		_interstitial_wave,
		_last_interstitial,
		_config.interstitial_every_runs,
		_config.interstitial_min_interval_seconds,
		_config.interstitial_min_wave
	)
	if not bool(status.get("available", false)):
		return false
	var started: bool = bool(_adapter.show_interstitial(placement, _on_interstitial_closed, _on_interstitial_failed))
	if not started:
		return false
	_last_interstitial = TimeService.now_unix()
	_persist()
	AnalyticsService.track(&"ad_shown", {"placement": String(placement), "type": "interstitial"})
	return true


## Context for the interstitial cadence: lifetime runs after the finished run and
## the wave that run reached. RunSummary calls this right before Continue.
func set_interstitial_context(runs_played: int, wave: int) -> void:
	_interstitial_runs = maxi(runs_played, 0)
	_interstitial_wave = maxi(wave, 0)


func get_cap_status(placement: StringName) -> Dictionary:
	var status := _caps.can_show(placement, _today())
	status["ready"] = _adapter_ready
	status["consent"] = _consent_granted
	if not _adapter_ready:
		status["reason"] = REASON_UNAVAILABLE
	return status


## Resets per-run counters; BattleController calls this when a run starts.
func start_run(_run_id: String) -> void:
	_caps.reset_run()
	_pending_placement = &""
	_guard.finish()
	_cancel_watchdog()


## True when the player owns No Ads (interstitials off, rewarded stays opt-in).
func has_no_ads() -> bool:
	return _has_no_ads()


func _has_no_ads() -> bool:
	return IapService.owns("thetree.no_ads")


func is_consent_granted() -> bool:
	return _consent_granted


## Shows the consent flow on demand (Settings -> Ad privacy). No ad is requested.
func request_consent(callback: Callable = Callable()) -> void:
	_ensure_consent(func(granted: bool) -> void:
		if callback.is_valid():
			callback.call(granted)
	)


func _ensure_consent(callback: Callable) -> void:
	if _consent_granted:
		callback.call(true)
		return
	_consent_waiters.append(callback)
	if _consent_in_flight:
		return
	_consent_in_flight = true
	if not _config.consent_required:
		_resolve_consent(true)
		return
	_adapter.request_consent(_on_consent_result)


func _on_consent_result(result: Dictionary) -> void:
	if bool(result.get("unavailable", false)):
		var dialog := ConsentDialog.new()
		add_child(dialog)
		dialog.open(_resolve_consent)
		return
	_resolve_consent(bool(result.get("granted", false)))


func _resolve_consent(granted: bool) -> void:
	_consent_in_flight = false
	if granted != _consent_granted:
		_consent_granted = granted
		SettingsService.set_consent_granted(granted)
		consent_changed.emit(granted)
	var waiters := _consent_waiters.duplicate()
	_consent_waiters.clear()
	for waiter: Callable in waiters:
		waiter.call(granted)


func _on_ad_earned(placement: StringName) -> void:
	_cancel_watchdog()
	if not _guard.claim(placement):
		return
	_caps.record(placement, _today())
	_persist()
	SaveService.request_save()
	AnalyticsService.track(&"ad_rewarded", {"placement": String(placement)})
	rewarded_earned.emit(placement)


func _on_ad_closed(placement: StringName) -> void:
	_cancel_watchdog()
	var was_claimed := _guard.is_claimed()
	_guard.finish()
	_pending_placement = &""
	if not was_claimed and not placement.is_empty():
		rewarded_failed.emit(placement, REASON_DISMISSED)


func _on_ad_failed(placement: StringName, reason: StringName) -> void:
	_cancel_watchdog()
	_guard.finish()
	_pending_placement = &""
	rewarded_failed.emit(placement, reason)


func _on_interstitial_closed(_placement: StringName) -> void:
	interstitial_closed.emit()


func _on_interstitial_failed(_placement: StringName, reason: StringName) -> void:
	AnalyticsService.track(&"error", {"scope": "interstitial", "reason": String(reason)})
	interstitial_closed.emit()


func _fail(placement: StringName, reason: StringName) -> void:
	rewarded_failed.emit(placement, reason)


func _persist() -> void:
	GameState.ads["caps"] = _caps.to_dict()
	GameState.ads["interstitial_last"] = _last_interstitial


func _today() -> String:
	return Time.get_date_string_from_system()


func _start_watchdog(placement: StringName) -> void:
	_cancel_watchdog()
	_watchdog_generation += 1
	var generation := _watchdog_generation
	_watchdog = get_tree().create_timer(WATCHDOG_SECONDS)
	_watchdog.timeout.connect(func() -> void:
		if generation != _watchdog_generation:
			return
		if _pending_placement == placement and not _guard.is_claimed():
			_on_ad_failed(placement, REASON_UNAVAILABLE)
	)


func _cancel_watchdog() -> void:
	_watchdog_generation += 1
	_watchdog = null


## True while this build only has the desktop stub (used by the shop/settings UI).
func is_stub() -> bool:
	return not AdAdapterFactory.is_android()


## Test-only reset so headless suites never inherit a previous consent/cap.
func reset_for_test() -> void:
	_caps.reset_run()
	_caps.daily_counts.clear()
	_caps.day = ""
	_guard.finish()
	_pending_placement = &""
	_cancel_watchdog()
	_consent_waiters.clear()
	_consent_in_flight = false
