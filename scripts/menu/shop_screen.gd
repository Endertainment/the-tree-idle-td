## ShopScreen — Gems / Coins / Special offer grid (spec 13.10).
##
## The store is not connected in M5b: every price shows "—", every buy button is
## disabled with "Store unavailable" and the restore link reports the local
## ownership list. A debug-only footer button exercises the same RewardBundle
## grant path the M6 billing adapter will call, so the flow is testable offline.
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

var _active_tab: StringName = &"gems"
var _tab_buttons: Dictionary = {}


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
	_debug_button.visible = OS.is_debug_build()
	IapService.purchases_restored.connect(_on_purchases_restored)
	EventBus.currency_changed.connect(_on_currency_changed)
	LocaleService.language_changed.connect(_on_language_changed)
	_refresh_wallet()
	_refresh_offers()
	AudioBus.bind_buttons(self)


func _exit_tree() -> void:
	if IapService.purchases_restored.is_connected(_on_purchases_restored):
		IapService.purchases_restored.disconnect(_on_purchases_restored)
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
	_store_note.text = LocaleService.t(
		"shop.store_unavailable_note",
		"In-app purchases arrive with M6. Prices and the buy button stay disabled in this build."
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
	for product: Dictionary in IapCatalog.for_tab(String(_active_tab)):
		_offers.add_child(_offer_card(product))
	AudioBus.bind_buttons(self)


func _offer_card(product: Dictionary) -> PanelContainer:
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
