## IapService — Play Billing purchases, restore and ownership (spec 7.1 / 7.3).
##
## The store lives behind an adapter (Android Play Billing or the desktop stub).
## Products and grants are catalogue-driven; every successful purchase is granted
## through RewardBundle exactly once (purchase-token ledger), consumed/acknowledged,
## and persisted before the signal fires. Receipt verification is deliberately a
## no-op hook for M7 server validation.
extends Node

signal purchase_completed(product_id: StringName, receipt: Dictionary)
signal purchase_failed(product_id: StringName, reason: StringName)
signal purchases_restored(products: PackedStringArray)
signal purchase_pending(product_id: StringName)
signal store_availability_changed(available: bool)
signal products_updated

const REASON_STORE_UNAVAILABLE := &"store_unavailable"
const REASON_ALREADY_OWNED := &"already_owned"
const REASON_UNKNOWN_PRODUCT := &"unknown_product"
const REASON_BUSY := &"busy"
const REASON_RECEIPT_INVALID := &"receipt_invalid"
const PURCHASE_STATE_PURCHASED := 1
const PURCHASE_STATE_PENDING := 2

var _adapter: RefCounted
var _adapter_ready: bool = false
var _purchase_in_flight: String = ""
var _processed_tokens: Dictionary = {}
var _restoring: bool = false
var _restored_products: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_adapter = IapAdapterFactory.create(self)
	call_deferred(&"_deferred_init")


func _deferred_init() -> void:
	_load_processed_tokens()
	_adapter.initialize({
		"availability": Callable(self, &"_on_availability"),
		"purchase": Callable(self, &"_on_purchase_result"),
		"restored": Callable(self, &"_on_restored"),
	})


## Called by App after the save is loaded.
func init_service() -> void:
	_load_processed_tokens()


## True when the Play Store connection answered the product query.
func is_available() -> bool:
	return _adapter_ready and _adapter != null and bool(_adapter.is_available())


## Catalogue annotated with live ownership, store price and availability.
func query_products() -> Array[Dictionary]:
	var products := IapCatalog.all()
	var available := is_available()
	for product: Dictionary in products:
		var product_id := str(product.get("id", ""))
		product["owned"] = owns(product_id)
		product["available"] = available
		if available and _adapter != null:
			var store_price := str(_adapter.price_for(product_id))
			if not store_price.is_empty():
				product["price"] = store_price
	return products


## Launches the store sheet for one product. Results arrive through signals.
func purchase(product_id: StringName) -> void:
	var id := String(product_id)
	var product := IapCatalog.find(id)
	if product.is_empty():
		purchase_failed.emit(product_id, REASON_UNKNOWN_PRODUCT)
		return
	if not _purchase_in_flight.is_empty():
		purchase_failed.emit(product_id, REASON_BUSY)
		return
	if not is_available():
		purchase_failed.emit(product_id, REASON_STORE_UNAVAILABLE)
		return
	if not bool(product.get("consumable", true)) and owns(id):
		purchase_failed.emit(product_id, REASON_ALREADY_OWNED)
		return
	_purchase_in_flight = id
	var result: Dictionary = _adapter.purchase(id)
	if int(result.get("response_code", 2)) != BillingReasons.OK:
		var reason := BillingReasons.reason_for(int(result.get("response_code", 2)))
		_purchase_in_flight = ""
		purchase_failed.emit(product_id, reason)


## Re-queries the store for owned products. Non-consumables are re-granted
## idempotently, so a reinstall restores the entitlements saved in the profile.
func restore() -> void:
	if not is_available():
		var owned := _locally_owned_products()
		purchases_restored.emit(owned)
		return
	_restoring = true
	_restored_products = PackedStringArray()
	_adapter.restore()


## True when a non-consumable product was already granted (save-backed).
func owns(product_id: String) -> bool:
	var owned_products: Array = GameState.shop.get("owned_products", [])
	return owned_products.has(product_id)


## True while a purchase sheet is open (shop disables the other buttons).
func is_purchase_in_flight() -> bool:
	return not _purchase_in_flight.is_empty()


## Debug-only fake purchase: grants the same RewardBundle the real flow does.
## Never available in a release build.
func debug_simulate_purchase(product_id: String) -> bool:
	if not OS.is_debug_build():
		push_warning("IapService: debug purchases are disabled in release builds")
		return false
	var product := IapCatalog.find(product_id)
	if product.is_empty():
		purchase_failed.emit(StringName(product_id), REASON_UNKNOWN_PRODUCT)
		return false
	if not bool(product.get("consumable", true)) and owns(product_id):
		purchase_failed.emit(StringName(product_id), REASON_ALREADY_OWNED)
		return false
	_grant_product(product_id)
	var token := "debug:%s:%d" % [product_id, TimeService.now_unix()]
	_processed_tokens[token] = product_id
	_save_processed_tokens()
	SaveService.flush()
	purchase_completed.emit(
		StringName(product_id),
		{"debug": true, "product_id": product_id, "purchase_token": token}
	)
	print("[IapService] debug purchase granted '%s'" % product_id)
	return true


func is_stub() -> bool:
	return not IapAdapterFactory.is_android()


# --- adapter callbacks -----------------------------------------------------

func _on_availability(available: bool) -> void:
	_adapter_ready = available
	store_availability_changed.emit(is_available())
	products_updated.emit()


func _on_purchase_result(result: Dictionary) -> void:
	var code := int(result.get("response_code", BillingReasons.ERROR))
	var purchases: Array = result.get("purchases", [])
	if code != BillingReasons.OK:
		var reason := BillingReasons.reason_for(code)
		var failed_id := _purchase_in_flight
		if failed_id.is_empty():
			failed_id = _first_product_id(purchases)
		_purchase_in_flight = ""
		purchase_failed.emit(StringName(failed_id), reason)
		return
	for purchase: Dictionary in purchases:
		_handle_purchase(purchase, false)
	_purchase_in_flight = ""
	products_updated.emit()


func _on_restored(purchases: Array) -> void:
	for purchase: Dictionary in purchases:
		_handle_purchase(purchase, true)
	_restoring = false
	purchases_restored.emit(_restored_products)


## Handles one purchase dictionary from on_purchase_updated/query_purchases.
func _handle_purchase(purchase: Dictionary, restoring: bool) -> bool:
	var product_id := _known_product_id(purchase.get("product_ids", []))
	if product_id.is_empty():
		return false
	var state := int(purchase.get("purchase_state", 0))
	if state == PURCHASE_STATE_PENDING:
		purchase_pending.emit(StringName(product_id))
		return false
	if state != PURCHASE_STATE_PURCHASED:
		return false

	var token := str(purchase.get("purchase_token", ""))
	var already_processed := not token.is_empty() and _processed_tokens.has(token)
	if not already_processed and not _verify_receipt(purchase):
		purchase_failed.emit(StringName(product_id), REASON_RECEIPT_INVALID)
		return false

	var granted := _grant_product(product_id) if not already_processed else true
	if not token.is_empty():
		_processed_tokens[token] = product_id
		_save_processed_tokens()
	_settle_purchase(product_id, token, bool(purchase.get("is_acknowledged", false)))
	if not granted:
		return false

	SaveService.flush()
	AnalyticsService.track(&"purchase", {"product_id": product_id, "restored": restoring})
	if restoring:
		_restored_products.append(product_id)
	else:
		var receipt := purchase.duplicate(true)
		receipt["product_id"] = product_id
		purchase_completed.emit(StringName(product_id), receipt)
	return true


## Consumes consumables and acknowledges non-consumables (Play requirement).
func _settle_purchase(product_id: String, token: String, is_acknowledged: bool) -> void:
	if token.is_empty() or _adapter == null:
		return
	if IapCatalog.is_consumable(product_id):
		_adapter.consume(token)
	elif not is_acknowledged:
		_adapter.acknowledge(token)


## Applies the product's contents. Idempotent for non-consumables.
func _grant_product(product_id: String) -> bool:
	var product := IapCatalog.find(product_id)
	if product.is_empty():
		return false
	var non_consumable := not bool(product.get("consumable", true))
	if non_consumable and owns(product_id):
		return true
	var granted := false
	var bundle := IapCatalog.bundle_for(product_id)
	if bundle != null and not bundle.is_empty():
		granted = GameState.grant_bundle(bundle, &"iap")
	var rarity := str(product.get("card_rarity", ""))
	if not rarity.is_empty():
		granted = _grant_card_of_rarity(rarity) or granted
	if product.has("unlock"):
		GameState.grant_extra_unlock(StringName(str(product["unlock"])))
		granted = true
	if non_consumable:
		_mark_owned(product_id)
		# Cosmetic-only products (No Ads) deliver ownership itself.
		granted = true
	if not granted:
		return false
	return true


## M7 hook: verify the receipt against Google Play / the backend before granting.
## Returning true is intentional for M6 (local trusted test purchases only).
func _verify_receipt(_receipt: Dictionary) -> bool:
	return true


func _grant_card_of_rarity(rarity: String) -> bool:
	for card: CardData in CardService.get_cards():
		if String(card.rarity) == rarity:
			CardService.grant_card(card.id)
			return true
	return false


func _mark_owned(product_id: String) -> void:
	var owned_products: Array = GameState.shop.get("owned_products", [])
	if owned_products.has(product_id):
		return
	owned_products.append(product_id)
	GameState.shop["owned_products"] = owned_products


func _known_product_id(ids: Variant) -> String:
	if not (ids is Array or ids is PackedStringArray):
		return ""
	for id: Variant in ids:
		if not IapCatalog.find(str(id)).is_empty():
			return str(id)
	return ""


func _first_product_id(purchases: Array) -> String:
	for purchase: Dictionary in purchases:
		var known := _known_product_id(purchase.get("product_ids", []))
		if not known.is_empty():
			return known
	return ""


func _locally_owned_products() -> PackedStringArray:
	var result := PackedStringArray()
	for product: Dictionary in IapCatalog.all():
		var id := str(product.get("id", ""))
		if not bool(product.get("consumable", true)) and owns(id):
			result.append(id)
	return result


func _load_processed_tokens() -> void:
	var tokens: Variant = GameState.shop.get("processed_tokens", [])
	_processed_tokens.clear()
	if tokens is Array:
		for token: Variant in tokens:
			_processed_tokens[str(token)] = true


func _save_processed_tokens() -> void:
	var tokens: Array = _processed_tokens.keys()
	if tokens.size() > 100:
		tokens = tokens.slice(tokens.size() - 100, tokens.size())
	GameState.shop["processed_tokens"] = tokens
