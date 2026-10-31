## BillingReasons — maps Google Play Billing response codes to app reason ids.
##
## Pure constants only (no BillingClient dependency) so the mapping is unit-tested
## headlessly and the shop can localize one stable set of reasons.
class_name BillingReasons
extends RefCounted

const OK := 0
const USER_CANCELED := 1
const SERVICE_UNAVAILABLE := 2
const BILLING_UNAVAILABLE := 3
const ITEM_UNAVAILABLE := 4
const DEVELOPER_ERROR := 5
const ERROR := 6
const ITEM_ALREADY_OWNED := 7
const ITEM_NOT_OWNED := 8
const NETWORK_ERROR := 12
const SERVICE_DISCONNECTED := -1
const FEATURE_NOT_SUPPORTED := -2
const SERVICE_TIMEOUT := -3


## Stable StringName used by IapService.purchase_failed and the shop toasts.
static func reason_for(code: int) -> StringName:
	match code:
		OK:
			return &"ok"
		USER_CANCELED:
			return &"cancelled"
		SERVICE_UNAVAILABLE, NETWORK_ERROR, SERVICE_TIMEOUT:
			return &"network_error"
		BILLING_UNAVAILABLE, SERVICE_DISCONNECTED:
			return &"store_unavailable"
		ITEM_UNAVAILABLE:
			return &"product_unavailable"
		DEVELOPER_ERROR:
			return &"store_error"
		ERROR:
			return &"store_error"
		ITEM_ALREADY_OWNED:
			return &"already_owned"
		ITEM_NOT_OWNED:
			return &"not_owned"
		FEATURE_NOT_SUPPORTED:
			return &"not_supported"
		_:
			return &"unknown"


## Locale key for a reason (the shop falls back to a generic message).
static func locale_key(reason: StringName) -> String:
	match reason:
		&"cancelled":
			return "shop.purchase_cancelled"
		&"already_owned":
			return "shop.purchase_already_owned"
		&"pending":
			return "shop.purchase_pending"
		&"network_error":
			return "shop.purchase_network_error"
		&"store_unavailable":
			return "shop.store_unavailable"
		&"product_unavailable":
			return "shop.purchase_product_unavailable"
		_:
			return "shop.purchase_failed"


## True when the response means the billing flow started successfully.
static func is_ok(code: int) -> bool:
	return code == OK
