## RewardedAdStub — M3 placeholder for the rewarded "Double coins" button.
##
## M6 replaces this with `AdsService`. Until then ads are unavailable; debug builds
## get a fake success so the reward flow is playable and testable without a
## network or ad SDK. The result is a dictionary so a future service can keep the
## same call shape: {success, debug_fake, reason}.
class_name RewardedAdStub
extends RefCounted


## Returns false until a real ads service exists (M6).
static func is_available() -> bool:
	return false


## Requests one rewarded view. Debug builds fake a success.
static func request_reward() -> Dictionary:
	if OS.is_debug_build():
		return {"success": true, "debug_fake": true, "reason": "debug_fake"}
	return {"success": false, "debug_fake": false, "reason": "ads_unavailable"}
