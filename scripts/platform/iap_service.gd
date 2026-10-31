## IapService — M5b store stub behind the spec §7.1 interface.
##
## The real Google Play Billing adapter lands in M6. Until then `is_available()`
## is false, the shop shows "Store unavailable" and every purchase attempt fails
## with `store_unavailable`. A debug-only `debug_simulate_purchase()` runs the
## complete local flow (RewardBundle -> WalletService -> ownership -> signal) so
## the UI and the grant path can be tested without a store. It is compiled out of
## release behaviour by the `OS.is_debug_build()` guard.
extends Node

signal purchase_completed(product_id: StringName, receipt: Dictionary)
signal purchase_failed(product_id: StringName, reason: StringName)
signal purchases_restored(products: PackedStringArray)

const REASON_STORE_UNAVAILABLE := &"store_unavailable"
const REASON_ALREADY_OWNED := &"already_owned"
const REASON_UNKNOWN_PRODUCT := &"unknown_product"


## No Play Services / store bridge exists in M5b.
func is_available() -> bool:
	return false


## Catalogue annotated with live ownership, ready for the shop grid.
func query_products() -> Array[Dictionary]:
	var products := IapCatalog.all()
	for product: Dictionary in products:
		product["owned"] = owns(str(product.get("id", "")))
		product["available"] = is_available()
	return products


## Real store purchases are disabled until M6; the UI never enables the button
## while `is_available()` is false, but the guard keeps the service safe anyway.
func purchase(product_id: StringName) -> void:
	var product := IapCatalog.find(String(product_id))
	if product.is_empty():
		purchase_failed.emit(product_id, REASON_UNKNOWN_PRODUCT)
		return
	print("[IapService] stub purchase '%s' requested (M6)" % product_id)
	purchase_failed.emit(product_id, REASON_STORE_UNAVAILABLE)


## Restores non-consumable ownership. The stub reports what the save already has.
func restore() -> void:
	var owned := PackedStringArray()
	for product: Dictionary in IapCatalog.all():
		var product_id := str(product.get("id", ""))
		if not bool(product.get("consumable", true)) and owns(product_id):
			owned.append(product_id)
	purchases_restored.emit(owned)


## True when a non-consumable product was already granted (save-backed).
func owns(product_id: String) -> bool:
	var owned_products: Array = GameState.shop.get("owned_products", [])
	return owned_products.has(product_id)


## Debug-only fake purchase: grants the same RewardBundle the real flow will, so
## the shop, toasts, balance refresh and ownership state can be exercised on
## desktop. Never available in a release build.
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
	var granted := false
	var bundle := IapCatalog.bundle_for(product_id)
	if bundle != null and not bundle.is_empty():
		granted = GameState.grant_bundle(bundle, &"iap")
	var rarity := str(product.get("card_rarity", ""))
	if not rarity.is_empty():
		granted = _grant_card_of_rarity(rarity) or granted
	if not bool(product.get("consumable", true)):
		_mark_owned(product_id)
	if not granted and bundle != null and bundle.is_empty() and product.get("unlock", "") == "":
		# Cosmetic-only product (No Ads): ownership is the delivered value.
		granted = true
	if product.has("unlock"):
		GameState.grant_extra_unlock(StringName(str(product["unlock"])))
		granted = true
	if not granted:
		purchase_failed.emit(StringName(product_id), REASON_STORE_UNAVAILABLE)
		return false
	SaveService.request_save()
	purchase_completed.emit(StringName(product_id), {"debug": true, "product_id": product_id})
	print("[IapService] debug purchase granted '%s'" % product_id)
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
