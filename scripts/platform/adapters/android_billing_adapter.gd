## AndroidBillingAdapter — godot-google-play-billing 3.3.0 wrapper.
##
## The only file that checks OS.has_feature("android") for billing. IapService owns
## products, grants and states; this adapter only translates the plugin's signal
## dictionaries and maps response codes to stable reason ids.
extends RefCounted

const BILLING_ADDON := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

var _host: Node
var _client: BillingClient
var _available: bool = false
var _prices: Dictionary = {}
var _callbacks: Dictionary = {}


static func is_supported() -> bool:
	return OS.has_feature("android")


func _init(host: Node) -> void:
	_host = host


## Starts the Play Billing connection. Never called during boot; deferred by
## IapService so a missing Play Store cannot stall startup.
func initialize(callbacks: Dictionary) -> void:
	_callbacks = callbacks
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		_set_available(false)
		return
	_client = BillingClient.new()
	_client.connected.connect(_on_connected)
	_client.disconnected.connect(_on_disconnected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases)
	_client.on_purchase_updated.connect(_on_purchase_updated)
	_client.start_connection()


func is_available() -> bool:
	return _available


func price_for(product_id: String) -> String:
	return str(_prices.get(product_id, ""))


func purchase(product_id: String) -> Dictionary:
	if _client == null:
		return {"response_code": BillingReasons.SERVICE_UNAVAILABLE}
	return _client.purchase(product_id)


func restore() -> void:
	if _client != null and _available:
		_client.query_purchases(BillingClient.ProductType.INAPP)


func consume(token: String) -> void:
	if _client != null:
		_client.consume_purchase(token)


func acknowledge(token: String) -> void:
	if _client != null:
		_client.acknowledge_purchase(token)


func _on_connected() -> void:
	var ids := PackedStringArray()
	for product: Dictionary in IapCatalog.all():
		ids.append(str(product.get("id", "")))
	_client.query_product_details(ids, BillingClient.ProductType.INAPP)


func _on_connect_error(_code: int, _message: String) -> void:
	_set_available(false)


func _on_disconnected() -> void:
	_set_available(false)


func _on_product_details(result: Dictionary) -> void:
	if int(result.get("response_code", BillingReasons.ERROR)) != BillingReasons.OK:
		_set_available(false)
		return
	for detail: Dictionary in result.get("product_details", []):
		var product_id := str(detail.get("product_id", ""))
		var offers: Array = detail.get("one_time_purchase_offer_details_list", [])
		var price := ""
		if not offers.is_empty() and offers[0] is Dictionary:
			price = str((offers[0] as Dictionary).get("formatted_price", ""))
		_prices[product_id] = price
	_set_available(true)


func _on_purchases(result: Dictionary) -> void:
	if int(result.get("response_code", BillingReasons.ERROR)) != BillingReasons.OK:
		if _callbacks.has("restored"):
			(_callbacks["restored"] as Callable).call([])
		return
	if _callbacks.has("restored"):
		(_callbacks["restored"] as Callable).call(result.get("purchases", []))


func _on_purchase_updated(result: Dictionary) -> void:
	if _callbacks.has("purchase"):
		(_callbacks["purchase"] as Callable).call(result)


func _set_available(value: bool) -> void:
	if _available == value:
		return
	_available = value
	print("[IapService] store availability: %s" % str(value))
	if _callbacks.has("availability"):
		(_callbacks["availability"] as Callable).call(value)
