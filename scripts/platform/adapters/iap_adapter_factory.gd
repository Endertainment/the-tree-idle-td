## IapAdapterFactory — Android Play Billing adapter or the desktop stub.
class_name IapAdapterFactory
extends RefCounted

const AndroidAdapter := preload("res://scripts/platform/adapters/android_billing_adapter.gd")
const StubAdapter := preload("res://scripts/platform/adapters/stub_billing_adapter.gd")


static func create(host: Node) -> RefCounted:
	if AndroidAdapter.is_supported():
		return AndroidAdapter.new(host)
	return StubAdapter.new(host)


static func is_android() -> bool:
	return AndroidAdapter.is_supported()
