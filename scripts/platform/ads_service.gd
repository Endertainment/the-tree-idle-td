## AdsService — clearly labelled M5b stub behind the spec §7.1 interface.
##
## M6 replaces this file with the AdMob adapter; screens only ever call these
## methods/signals, so the UI does not change when the real implementation lands.
## No placement can grant anything yet: `show_rewarded()` logs the debug fake,
## reports `stub_not_implemented` and the caller shows the "Ads arrive with M6"
## toast. Keeping the failure explicit prevents a silent fake reward in release.
extends Node

signal rewarded_earned(placement: StringName)
signal rewarded_failed(placement: StringName, reason: StringName)
signal interstitial_closed()

const STUB_REASON := &"stub_not_implemented"


## Always false in M5b: there is no ad SDK in the project yet.
func is_ready(_placement: StringName) -> bool:
	return false


## Debug fake: logs the placement and reports a failure. Returns false so callers
## do not treat the placement as rewarded.
func show_rewarded(placement: StringName) -> bool:
	print("[AdsService] stub rewarded placement '%s' requested (M6)" % placement)
	rewarded_failed.emit(placement, STUB_REASON)
	return false


## Interstitials are never available before M6.
func show_interstitial(placement: StringName) -> bool:
	print("[AdsService] stub interstitial '%s' requested (M6)" % placement)
	return false


## No caps exist until the real SDK is wired.
func get_cap_status(_placement: StringName) -> Dictionary:
	return {"available": false, "shown_today": 0, "limit": 0, "reason": String(STUB_REASON)}


## True while this autoload is the M5b stub (used by screens for the M6 toast).
func is_stub() -> bool:
	return true
