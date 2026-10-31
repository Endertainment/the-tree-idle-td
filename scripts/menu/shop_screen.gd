## ShopScreen — Gems / Coins / Special offer grid (spec 13.10).
##
## Prices, buy buttons and restore are driven by IapService. On desktop (no store)
## every price falls back to "—" and the button reads "Store unavailable". On
## Android the Play Billing adapter supplies formatted prices and the purchase
## sheet; pending/cancelled/already-owned results are all surfaced explicitly.
extends Control

const TABS: Array[StringName] = [&"gems", &"coins", &"special"]
const TAB_LABELS: Dictionary = {
	&"gems": ["shop.tab.gems", "Gems"],
	&"coins": ["shop.tab.coins", "Coins"],
	&"special": ["shop.tab.special", "Special"],
}

@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %TitleLabel
@onready var _coins: CurrencyPill = %CoinsPill
@onready var _gems: CurrencyPill = %GemsPill
@onready var _tabs: HBoxContainer = %Tabs
@onready var _store_note: Label = %StoreNote
@onready var _offers: GridContainer = %Offers
@onready var _restore_button: Button = %RestoreButton
@onready var _debug_button: Button = %DebugButton
@onready var _nav: MenuNav = %NavBar
@onready var _confirm: Modal = %PurchaseConfirm

var _active_tab: StringName = &"gems"
var _tab_buttons: Dictionary = {}
var _pending_product: String = ""


func _ready() -> void:
	var params := SceneRouter.get_params()
	var requested := StringName(str(params.get("tab", "gems")))
	if TABS.has(requested):
		_active_tab = requested
	_localize()
	_build_tabs()
	_back_button.pressed.connect(_on_back_pressed)
	_restore_button.pressed.connect(_on_restore_pressed)
	_debug_button.pressed.connect(_on_debug_purchase_pressed)
	_confirm.confirmed.connect(_on_purchase_confirmed)
	_debug_button.visible = OS.is_debug_build()
	IapService.purchases_restored.connect(_on_purchases_restored)
	IapService.purchase_completed.connect(_on_purchase_completed)
	IapService.purchase_failed.connect(_on_purchase_failed)
	IapService.purchase_pending.connect(_on_purchase_pending)
	IapService.store_availability_changed.connect(_on_store_availability_changed)
	IapService.products_updated.connect(_refresh_offers)
	EventBus.currency_changed.connect(_on_currency_changed)
	LocaleService.language_changed.connect(_on_language_changed)
	_refresh_wallet()
	_refresh_offers()
	AudioBus.bind_buttons(self)


func _exit_tree() -> void:
	if IapService.purchases_restored.is_connected(_on_purchases_restored):
		IapService.purchases_restored.disconnect(_on_purchases_restored)
	if IapService.purchase_completed.is_connected(_on_purchase_completed):
		IapService.purchase_completed.disconnect(_on_purchase_completed)
	if IapService.purchase_failed.is_connected(_on_purchase_failed):
		IapService.purchase_failed.disconnect(_on_purchase_failed)
	if IapService.purchase_pending.is_connected(_on_purchase_pending):
		IapService.purchase_pending.disconnect(_on_purchase_pending)
	if IapService.store_availability_changed.is_connected(_on_store_availability_changed):
		IapService.store_availability_changed.disconnect(_on_store_availability_changed)
	if IapService.products_updated.is_connected(_refresh_offers):
		IapService.products_updated.disconnect(_refresh_offers)
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_localize()
	_refresh_tabs()
	_refresh_offers()


func _localize() -> void:
	_title_label.text = LocaleService.t("shop.title", "Shop")
	_back_button.text = LocaleService.t("common.back", "Back")
	_store_note.text = (
		LocaleService.t("shop.store_connected_note", "Purchases are processed securely by Google Play.")
		if IapService.is_available()
		else LocaleService.t(
			"shop.store_unavailable_note",
			"The store is not available in this build. Prices and purchases stay disabled."
		)
	)
	_restore_button.text = LocaleService.t("shop.restore", "Restore purchases")
	_debug_button.text = LocaleService.t("shop.debug_simulate", "Debug: simulate purchase")
	_nav.setup(&"shop")


func _build_tabs() -> void:
	for tab: StringName in TABS:
		var button := Button.new()
		button.name = "Tab%s" % String(tab).capitalize()
		button.custom_minimum_size = Vector2(0, 88)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = &"SecondaryButton"
		button.pressed.connect(_on_tab_pressed.bind(tab))
		_tabs.add_child(button)
		_tab_buttons[tab] = button
	_refresh_tabs()


func _refresh_tabs() -> void:
	for tab: StringName in _tab_buttons.keys():
		var button: Button = _tab_buttons[tab]
		var active := tab == _active_tab
		button.theme_type_variation = &"GoldButton" if active else &"SecondaryButton"
		button.modulate = Color.WHITE if active else Color(0.8, 0.84, 0.78, 1.0)
		var entry: Array = TAB_LABELS[tab]
		button.text = LocaleService.t(str(entry[0]), str(entry[1]))


func _on_tab_pressed(tab: StringName) -> void:
	if tab == _active_tab:
		return
	_active_tab = tab
	AudioBus.play_ui(&"ui_toggle")
	_refresh_tabs()
	_refresh_offers()


func _refresh_wallet() -> void:
	_coins.set_amount(GameState.get_balance(&"coins"))
	_gems.set_amount(GameState.get_balance(&"gems"))


func _refresh_offers() -> void:
	for child: Node in _offers.get_children():
		_offers.remove_child(child)
		child.queue_free()
	var available := IapService.is_available()
	for product: Dictionary in IapService.query_products():
		if str(product.get("tab", "")) == String(_active_tab):
			_offers.add_child(_offer_card(product, available))
	AudioBus.bind_buttons(self)


func _offer_card(product: Dictionary, store_available: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Offer_%s" % str(product.get("id", "")).replace(".", "_")
	card.custom_minimum_size = Vector2(0, 470)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.theme_type_variation = &"OfferCard"

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(92, 92)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = load(str(product.get("icon", ""))) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)

	var title := Label.new()
	title.text = LocaleService.t(str(product.get("title_key", "")), "")
	title.theme_type_variation = &"Body"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)

	var contents := Label.new()
	contents.text = LocaleService.t(str(product.get("contents_key", "")), "")
	contents.theme_type_variation = &"Caption"
	contents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.custom_minimum_size = Vector2(0, 112)
	box.add_child(contents)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 6)
	box.add_child(badge_row)
	var bonus := int(product.get("bonus_percent", 0))
	if bonus > 0:
		badge_row.add_child(_badge(
			LocaleService.t("shop.bonus_percent", "+%d %%") % bonus,
			Color(1.0, 0.78, 0.24, 1.0)
		))
	if bool(product.get("best_value", false)):
		badge_row.add_child(_badge(LocaleService.t("shop.best_value", "Best value"), Color(1.0, 0.86, 0.35, 1.0)))

	var price := Label.new()
	var price_text := str(product.get("price", ""))
	price.text = price_text if not price_text.is_empty() else LocaleService.t("shop.price_unavailable", "—")
	price.theme_type_variation = &"Body"
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.add_theme_color_override("font_color", Color(1.0, 0.78, 0.24, 1.0))
	box.add_child(price)

	var product_id := str(product.get("id", ""))
	var owned := IapService.owns(product_id)
	var buy := Button.new()
	buy.name = "Buy"
	buy.custom_minimum_size = Vector2(0, 86)
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = true
	if owned:
		buy.text = LocaleService.t("shop.owned", "Owned")
		buy.theme_type_variation = &"SecondaryButton"
	elif store_available:
		var store_price := str(product.get("price", ""))
		buy.text = store_price if not store_price.is_empty() else LocaleService.t("shop.buy", "Buy")
		buy.disabled = false
		buy.theme_type_variation = &"PrimaryButton"
		buy.pressed.connect(_on_buy_pressed.bind(product_id))
	else:
		buy.text = LocaleService.t("shop.store_unavailable", "Store unavailable")
		buy.theme_type_variation = &"PrimaryButton"
	box.add_child(buy)
	return card


func _badge(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"Chip"
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Caption"
	label.add_theme_color_override("font_color", color)
	chip.add_child(label)
	return chip


func _on_restore_pressed() -> void:
	AudioBus.play_ui(&"ui_toggle")
	IapService.restore()


func _on_buy_pressed(product_id: String) -> void:
	var product := IapCatalog.find(product_id)
	if product.is_empty():
		return
	_pending_product = product_id
	var price := str(IapService.query_products().filter(
		func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == product_id
	)[0].get("price", ""))
	_confirm.open(
		LocaleService.t(str(product.get("title_key", "")), product_id),
		"%s\n%s" % [
			LocaleService.t(str(product.get("contents_key", "")), ""),
			price if not price.is_empty() else LocaleService.t("shop.price_unavailable", "—"),
		],
		LocaleService.t("shop.confirm_purchase", "Buy"),
		LocaleService.t("common.cancel", "Cancel")
	)


func _on_purchase_confirmed() -> void:
	if _pending_product.is_empty():
		return
	AudioBus.play_ui(&"ui_toggle")
	IapService.purchase(StringName(_pending_product))


func _on_purchase_pending(product_id: StringName) -> void:
	_pending_product = ""
	ToastService.show_toast(
		LocaleService.t("shop.purchase_pending", "Payment is pending. The item will unlock when the store confirms it.")
	)
	_refresh_offers()


func _on_purchase_completed(product_id: StringName, _receipt: Dictionary) -> void:
	_pending_product = ""
	AudioBus.play_ui(&"ui_purchase")
	var product := IapCatalog.find(String(product_id))
	ToastService.show_toast(
		LocaleService.t("shop.purchase_success", "Purchase complete: %s") % LocaleService.t(
			str(product.get("title_key", "")), String(product_id)
		)
	)
	AnalyticsService.track(&"purchase", {"product_id": String(product_id)})
	_refresh_wallet()
	_refresh_offers()


func _on_purchase_failed(product_id: StringName, reason: StringName) -> void:
	_pending_product = ""
	AudioBus.play_ui(&"ui_error")
	var key := BillingReasons.locale_key(reason)
	var fallback := LocaleService.t("shop.purchase_failed", "Purchase could not be completed. Try again later.")
	ToastService.show_toast(LocaleService.t(key, fallback))
	_refresh_offers()


func _on_store_availability_changed(_available: bool) -> void:
	_localize()
	_refresh_offers()


func _on_purchases_restored(products: PackedStringArray) -> void:
	if products.is_empty():
		ToastService.show_toast(LocaleService.t("shop.restore_none", "No purchases to restore."))
	else:
		ToastService.show_toast(
			LocaleService.t("shop.restore_done", "Restored %d purchases.") % products.size()
		)
	_refresh_offers()


## Debug-only: runs the local RewardBundle grant for the first unowned offer in
## the active tab. Hidden in release builds; M6 replaces it with the real sheet.
func _on_debug_purchase_pressed() -> void:
	var target := ""
	for product: Dictionary in IapCatalog.for_tab(String(_active_tab)):
		var product_id := str(product.get("id", ""))
		if not IapService.owns(product_id):
			target = product_id
			break
	if target.is_empty():
		ToastService.show_toast(LocaleService.t("shop.debug_owned", "Already owned."))
		return
	if IapService.debug_simulate_purchase(target):
		AudioBus.play_ui(&"ui_purchase")
		var product := IapCatalog.find(target)
		ToastService.show_toast(
			LocaleService.t("shop.debug_granted", "Debug purchase granted: %s") % LocaleService.t(
				str(product.get("title_key", "")), target
			)
		)
	else:
		AudioBus.play_ui(&"ui_error")
		ToastService.show_toast(
			LocaleService.t("shop.purchase_failed", "Purchase unavailable: the store is not connected yet.")
		)
	_refresh_wallet()
	_refresh_offers()


func _on_currency_changed(kind: StringName, amount: int) -> void:
	match kind:
		&"coins":
			_coins.set_amount(amount)
		&"gems":
			_gems.set_amount(amount)


func _on_back_pressed() -> void:
	SaveService.request_save()
	SceneRouter.back()


## Tooling-only populated state for docs/preview captures.
func stage_preview() -> void:
	_coins.set_amount(12480)
	_gems.set_amount(350)
	_debug_button.visible = false
