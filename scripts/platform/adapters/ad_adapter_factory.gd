## AdAdapterFactory — picks the Android AdMob adapter or the desktop stub.
##
## The OS check lives inside AndroidAdsAdapter.is_supported(); this factory only
## asks the adapters, so AdsService stays platform-agnostic (spec 7.1).
class_name AdAdapterFactory
extends RefCounted

const AndroidAdapter := preload("res://scripts/platform/adapters/android_ads_adapter.gd")
const StubAdapter := preload("res://scripts/platform/adapters/stub_ads_adapter.gd")


static func create(host: Node) -> RefCounted:
	if AndroidAdapter.is_supported():
		return AndroidAdapter.new(host)
	return StubAdapter.new(host)


## True when the Android AdMob adapter is compiled in and its singleton exists.
static func is_android() -> bool:
	return AndroidAdapter.is_supported()
