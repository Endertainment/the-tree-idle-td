## Generates the M6 data resources from the code defaults.
##
## Usage:
##   godot --headless --path . --script res://tools/generate_m6_config.gd
##
## Writes res://config/shop.tres (the seven §7.3 products) and
## res://config/monetization.tres (test ad IDs, placement caps, analytics off).
## Idempotent; safe to re-run. Never writes production IDs.
extends SceneTree


func _initialize() -> void:
	var shop := ShopCatalog.new()
	shop.products = IapCatalog.builtin_products()
	var shop_error := ResourceSaver.save(shop, ShopCatalog.PATH)
	print("shop.tres: %s (%d products)" % [error_string(shop_error), shop.products.size()])

	var monetization := MonetizationConfig.new()
	var monetization_error := OK
	if not FileAccess.file_exists(MonetizationConfig.PATH):
		monetization_error = ResourceSaver.save(monetization, MonetizationConfig.PATH)
	print("monetization.tres: %s (test ids: %s)" % [
		error_string(monetization_error), str(monetization.test_ids)
	])

	quit(0 if shop_error == OK and monetization_error == OK else 1)
