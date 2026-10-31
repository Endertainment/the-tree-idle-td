## AndroidAdsAdapter — Poing Studios AdMob plugin v5.1.0 on Godot 4.7.2.
##
## The only file that checks OS.has_feature("android") for ads. AdsService talks to
## this adapter through a small duck-typed interface, so swapping the SDK touches
## this file plus the factory. SDK init is deferred by AdsService (never boot-blocking)
## and every failure reports a localized reason instead of throwing.
extends RefCounted

var _host: Node
var _config: MonetizationConfig
var _initialized: bool = false
var _sdk_ready: bool = false
var _ump_available: bool = false

var _rewarded_ad: RewardedAd = null
var _rewarded_loader: RewardedAdLoader = null
var _rewarded_loading: bool = false
var _pending_rewarded: bool = false
var _interstitial_ad: InterstitialAd = null
var _interstitial_loader: InterstitialAdLoader = null

var _on_earned: Callable
var _on_failed: Callable
var _on_closed: Callable
var _on_interstitial_closed: Callable
var _on_interstitial_failed: Callable


## True only on Android where the native Poing AdMob singleton is registered.
static func is_supported() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("PoingGodotAdMob")


func _init(host: Node) -> void:
	_host = host
	_config = MonetizationConfig.load_config()


## Initializes GMA once. Deferred by AdsService; safe to call more than once.
## GMA initialization is asynchronous — loading an ad before the completion
## callback crashes the native SDK, so preloading waits for it.
func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_ump_available = Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform")
	if not Engine.has_singleton("PoingGodotAdMob"):
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_sdk_initialized
	MobileAds.initialize(listener)


func _on_sdk_initialized(_status: InitializationStatus) -> void:
	_sdk_ready = true
	print("[AdsService] GMA initialized (plugin %s, platform %s)" % [
		MobileAds.get_version(), MobileAds.get_platform_version()
	])
	_preload_rewarded()
	if _host != null and _host.has_method(&"_on_adapter_ready"):
		_host.call(&"_on_adapter_ready")


func is_available() -> bool:
	return _sdk_ready and Engine.has_singleton("PoingGodotAdMob")


func rewarded_available(_placement: StringName) -> bool:
	return is_available()


func consent_available() -> bool:
	return _ump_available


## UMP consent flow. The callback receives {granted, unavailable}; unavailable=true
## tells AdsService to fall back to the local ConsentDialog.
func request_consent(callback: Callable) -> void:
	if not _ump_available:
		callback.call({"granted": false, "unavailable": true})
		return
	var request := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		request,
		_on_consent_update_success.bind(callback),
		_on_consent_update_failed.bind(callback)
	)


func _on_consent_update_success(callback: Callable) -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(
			_on_consent_form_loaded.bind(callback),
			_on_consent_form_failed.bind(callback)
		)
		return
	_consent_result(callback)


func _on_consent_update_failed(_error: Variant, callback: Callable) -> void:
	callback.call({"granted": false, "unavailable": true})


func _on_consent_form_loaded(form: ConsentForm, callback: Callable) -> void:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_form_dismissed.bind(callback))
		return
	_consent_result(callback)


func _on_consent_form_failed(_error: Variant, callback: Callable) -> void:
	callback.call({"granted": false, "unavailable": true})


func _on_form_dismissed(_error: Variant, callback: Callable) -> void:
	_consent_result(callback)


func _consent_result(callback: Callable) -> void:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	var granted := (
		status == ConsentInformation.ConsentStatus.OBTAINED
		or status == ConsentInformation.ConsentStatus.NOT_REQUIRED
	)
	callback.call({"granted": granted, "unavailable": false})


# --- rewarded --------------------------------------------------------------

func show_rewarded(
	placement: StringName,
	on_earned: Callable,
	on_failed: Callable,
	on_closed: Callable
) -> void:
	_on_earned = on_earned
	_on_failed = on_failed
	_on_closed = on_closed
	if not _sdk_ready:
		_fail_rewarded(placement, &"ad_unavailable")
		return
	if _rewarded_ad != null:
		_show_loaded_rewarded()
		return
	_pending_rewarded = true
	_preload_rewarded()


func _preload_rewarded() -> void:
	if _rewarded_ad != null or _rewarded_loading or not _sdk_ready or not Engine.has_singleton("PoingGodotAdMob"):
		return
	_rewarded_loading = true
	_rewarded_loader = RewardedAdLoader.new()
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = _on_rewarded_loaded
	callback.on_ad_failed_to_load = _on_rewarded_load_failed
	_rewarded_loader.load(_config.rewarded_unit_id, AdRequest.new(), callback)


func _on_rewarded_loaded(ad: RewardedAd) -> void:
	_rewarded_loading = false
	_rewarded_ad = ad
	print("[AdsService] rewarded ad loaded")
	if _pending_rewarded:
		_pending_rewarded = false
		_show_loaded_rewarded()


func _on_rewarded_load_failed(error: LoadAdError) -> void:
	_rewarded_loading = false
	_pending_rewarded = false
	print("[AdsService] rewarded load failed: %s" % _error_text(error))
	var placement := StringName(str(_host.get("_pending_placement"))) if _host != null else &""
	_fail_rewarded(placement, _reason_for(error))


func _show_loaded_rewarded() -> void:
	if _rewarded_ad == null:
		return
	var content := FullScreenContentCallback.new()
	content.on_ad_dismissed_full_screen_content = _on_rewarded_dismissed
	content.on_ad_failed_to_show_full_screen_content = _on_rewarded_show_failed
	_rewarded_ad.full_screen_content_callback = content
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = _on_user_earned_reward
	_rewarded_ad.show(listener)


func _on_user_earned_reward(_item: RewardedItem) -> void:
	print("[AdsService] rewarded earned callback")
	if _on_earned.is_valid():
		_on_earned.call(_pending_placement())


func _on_rewarded_dismissed() -> void:
	_destroy_rewarded()
	_preload_rewarded()
	if _on_closed.is_valid():
		_on_closed.call(_pending_placement())


func _on_rewarded_show_failed(error: AdError) -> void:
	_destroy_rewarded()
	_fail_rewarded(_pending_placement(), _reason_for(error))


func _fail_rewarded(placement: StringName, reason: StringName) -> void:
	_destroy_rewarded()
	if _on_failed.is_valid():
		_on_failed.call(placement, reason)


func _destroy_rewarded() -> void:
	if _rewarded_ad != null:
		_rewarded_ad.destroy()
		_rewarded_ad = null


func _pending_placement() -> StringName:
	if _host != null:
		return StringName(str(_host.get("_pending_placement")))
	return &""


# --- interstitial ----------------------------------------------------------

func show_interstitial(placement: StringName, on_closed: Callable, on_failed: Callable) -> bool:
	_on_interstitial_closed = on_closed
	_on_interstitial_failed = on_failed
	if not _sdk_ready:
		return false
	if _interstitial_ad != null:
		_show_loaded_interstitial()
		return true
	if not Engine.has_singleton("PoingGodotAdMob"):
		return false
	_interstitial_loader = InterstitialAdLoader.new()
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_ad = ad
		_show_loaded_interstitial()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		if _on_interstitial_failed.is_valid():
			_on_interstitial_failed.call(placement, _reason_for(error))
	_interstitial_loader.load(_config.interstitial_unit_id, AdRequest.new(), callback)
	return true


func _show_loaded_interstitial() -> void:
	if _interstitial_ad == null:
		return
	var content := FullScreenContentCallback.new()
	content.on_ad_dismissed_full_screen_content = func() -> void:
		_interstitial_ad.destroy()
		_interstitial_ad = null
		if _on_interstitial_closed.is_valid():
			_on_interstitial_closed.call(&"run_end_interstitial")
	content.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		if _interstitial_ad != null:
			_interstitial_ad.destroy()
			_interstitial_ad = null
		if _on_interstitial_failed.is_valid():
			_on_interstitial_failed.call(&"run_end_interstitial", _reason_for(error))
	_interstitial_ad.full_screen_content_callback = content
	_interstitial_ad.show()


func _reason_for(error: Variant) -> StringName:
	if error == null:
		return &"ad_unavailable"
	if error is AdError and (error as AdError).code == 0:
		return &"no_fill"
	return &"ad_unavailable"


func _error_text(error: Variant) -> String:
	if error is AdError:
		var ad_error := error as AdError
		return "code=%d domain=%s message=%s" % [ad_error.code, ad_error.domain, ad_error.message]
	return "unknown"
