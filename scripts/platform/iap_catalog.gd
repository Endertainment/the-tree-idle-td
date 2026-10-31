## IapCatalog — the launch product catalogue from spec §7.3.
##
## Pure data shared by IapService (owns the purchase flow) and the shop screen
## (renders the cards). Prices are intentionally empty until the store answers in
## M6; the UI shows the localized em dash fallback in the meantime.
class_name IapCatalog
extends RefCounted

const TAB_GEMS := "gems"
const TAB_COINS := "coins"
const TAB_SPECIAL := "special"

## Every launch product. `bundle` is a RewardBundle-compatible dictionary.
## Kept as the built-in fallback for res://config/shop.tres (spec 7.3).
const PRODUCTS: Array[Dictionary] = [
	{
		"id": "thetree.gems_100",
		"tab": TAB_GEMS,
		"title_key": "shop.product.gems_100",
		"contents_key": "shop.contents.gems_100",
		"icon": "res://assets/art/ui/icons/icon_gem.png",
		"price": "",
		"bonus_percent": 0,
		"best_value": false,
		"consumable": true,
		"bundle": {"gems": 100},
	},
	{
		"id": "thetree.gems_550",
		"tab": TAB_GEMS,
		"title_key": "shop.product.gems_550",
		"contents_key": "shop.contents.gems_550",
		"icon": "res://assets/art/ui/icons/icon_gem.png",
		"price": "",
		"bonus_percent": 10,
		"best_value": false,
		"consumable": true,
		"bundle": {"gems": 550},
	},
	{
		"id": "thetree.gems_1200",
		"tab": TAB_GEMS,
		"title_key": "shop.product.gems_1200",
		"contents_key": "shop.contents.gems_1200",
		"icon": "res://assets/art/ui/icons/icon_gem.png",
		"price": "",
		"bonus_percent": 20,
		"best_value": true,
		"consumable": true,
		"bundle": {"gems": 1200},
	},
	{
		"id": "thetree.coins_5000",
		"tab": TAB_COINS,
		"title_key": "shop.product.coins_5000",
		"contents_key": "shop.contents.coins_5000",
		"icon": "res://assets/art/ui/icons/icon_coin.png",
		"price": "",
		"bonus_percent": 0,
		"best_value": false,
		"consumable": true,
		"bundle": {"coins": 5000},
	},
	{
		"id": "thetree.starter_pack",
		"tab": TAB_SPECIAL,
		"title_key": "shop.product.starter_pack",
		"contents_key": "shop.contents.starter_pack",
		"icon": "res://assets/art/meta/shop/icon_starter_pack.png",
		"price": "",
		"bonus_percent": 0,
		"best_value": true,
		"consumable": false,
		"bundle": {"gems": 300, "coins": 2500},
		"card_rarity": "epic",
	},
	{
		"id": "thetree.no_ads",
		"tab": TAB_SPECIAL,
		"title_key": "shop.product.no_ads",
		"contents_key": "shop.contents.no_ads",
		"icon": "res://assets/art/meta/shop/icon_no_ads.png",
		"price": "",
		"bonus_percent": 0,
		"best_value": false,
		"consumable": false,
		"bundle": {},
	},
	{
		"id": "thetree.speed_pack",
		"tab": TAB_SPECIAL,
		"title_key": "shop.product.speed_pack",
		"contents_key": "shop.contents.speed_pack",
		"icon": "res://assets/art/ui/icons/icon_speed.png",
		"price": "",
		"bonus_percent": 0,
		"best_value": false,
		"consumable": false,
		"bundle": {},
		"unlock": "speed_pack",
	},
]


## Returns a deep copy of the built-in catalogue (never touches config resources).
static func builtin_products() -> Array[Dictionary]:
	return PRODUCTS.duplicate(true)


## Catalogue actually used at runtime: res://config/shop.tres when present.
static func products() -> Array[Dictionary]:
	return ShopCatalog.load_products()


## Returns a deep copy of every product (callers may annotate ownership).
static func all() -> Array[Dictionary]:
	return products()


## Products belonging to one shop tab, in catalogue order.
static func for_tab(tab: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for product: Dictionary in products():
		if str(product.get("tab", "")) == tab:
			result.append(product.duplicate(true))
	return result


## Looks a product up by store id; returns an empty dictionary when unknown.
static func find(product_id: String) -> Dictionary:
	for product: Dictionary in products():
		if str(product.get("id", "")) == product_id:
			return product.duplicate(true)
	return {}


## True when the id is a one-time purchase.
static func is_consumable(product_id: String) -> bool:
	var product := find(product_id)
	return bool(product.get("consumable", true))


## Reward bundle for a product (empty for cosmetic products such as No Ads).
static func bundle_for(product_id: String) -> RewardBundle:
	var product := find(product_id)
	if product.is_empty():
		return null
	return RewardBundle.from_dict(product.get("bundle", {}))
