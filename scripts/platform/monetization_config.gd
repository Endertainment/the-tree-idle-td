## MonetizationConfig — ad unit IDs, placement caps and analytics endpoint.
##
## Committed values are Google's official *test* ad unit IDs only. Production IDs
## are injected at export time by replacing res://config/monetization.tres (or by
## setting a user://monetization_override.tres locally, which wins when present).
## Never commit real ad unit IDs (spec 7.1).
class_name MonetizationConfig
extends Resource

const PATH := "res://config/monetization.tres"
const OVERRIDE_PATH := "user://monetization_override.tres"

## Google's "Always test" App ID, rewarded and interstitial units (Android).
const TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"

@export var app_id: String = TEST_APP_ID
@export var rewarded_unit_id: String = TEST_REWARDED_ID
@export var interstitial_unit_id: String = TEST_INTERSTITIAL_ID
## When true the exported manifest uses only test IDs (checked by export_android.ps1).
@export var test_ids: bool = true
## Ads are blocked until the consent dialog answered. False in release defaults.
@export var consent_required: bool = true
## Fake desktop ad (SettingsService.fake_monetization) needs a visible overlay.
@export var debug_ad_seconds: float = 2.0
## Placement → {type, cap, period}; period is "run" or "day".
@export var placements: Dictionary = {
	"run_double_coins": {"type": "rewarded", "cap": 1, "period": "run"},
	"speed_unlock_24h": {"type": "rewarded", "cap": 1, "period": "day"},
	"free_cash": {"type": "rewarded", "cap": 2, "period": "run"},
	"tree_blessing": {"type": "rewarded", "cap": 1, "period": "run"},
	"research_speedup": {"type": "rewarded", "cap": 3, "period": "day"},
	"run_end_interstitial": {"type": "interstitial", "cap": 0, "period": "none"},
	"shop_banner": {"type": "banner", "cap": 0, "period": "none"},
}
## Interstitial cadence from spec 7.2: every 3rd run, 120 s apart, never < wave 5.
@export var interstitial_every_runs: int = 3
@export var interstitial_min_interval_seconds: int = 120
@export var interstitial_min_wave: int = 5
## Analytics is opt-in: disabled unless an endpoint is configured.
@export var analytics_enabled: bool = false
@export var analytics_endpoint: String = ""
@export var analytics_batch_size: int = 20


## Loads the local override when present, otherwise the committed test config.
static func load_config() -> MonetizationConfig:
	var config: MonetizationConfig = null
	if ResourceLoader.exists(OVERRIDE_PATH):
		config = load(OVERRIDE_PATH) as MonetizationConfig
	if config == null and ResourceLoader.exists(PATH):
		config = load(PATH) as MonetizationConfig
	if config == null:
		config = MonetizationConfig.new()
	return config


## Ad unit id for one placement (all rewarded placements share the test unit).
func unit_id_for(placement: StringName) -> String:
	var definition: Dictionary = placements.get(String(placement), {})
	match str(definition.get("type", "")):
		"rewarded":
			return rewarded_unit_id
		"interstitial":
			return interstitial_unit_id
		_:
			return ""


## True when the placement exists and is a rewarded placement.
func is_rewarded(placement: StringName) -> bool:
	var definition: Dictionary = placements.get(String(placement), {})
	return str(definition.get("type", "")) == "rewarded"


## True when the placement is the run-end interstitial.
func is_interstitial(placement: StringName) -> bool:
	var definition: Dictionary = placements.get(String(placement), {})
	return str(definition.get("type", "")) == "interstitial"
