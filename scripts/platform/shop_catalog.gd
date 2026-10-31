## ShopCatalog — the seven launch IAP products from spec 7.3 as a data resource.
##
## res://config/shop.tres is the committed catalogue; IapCatalog falls back to its
## built-in table when the resource is missing (e.g. in a stripped export).
class_name ShopCatalog
extends Resource

const PATH := "res://config/shop.tres"

@export var products: Array[Dictionary] = []


## Loads the committed catalogue, or the built-in table as a safe fallback.
static func load_products() -> Array[Dictionary]:
	if ResourceLoader.exists(PATH):
		var catalog := load(PATH) as ShopCatalog
		if catalog != null and not catalog.products.is_empty():
			return catalog.products.duplicate(true)
	return IapCatalog.builtin_products()
