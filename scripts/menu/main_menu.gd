## MainMenu — M0 shell: currencies, title, Battle CTA, daily card, bottom tabs.
##
## Only Battle navigates. Settings and the four locked tabs intentionally show a
## "coming soon" toast; their screens ship in later milestones.
extends Control

@onready var _coins: CurrencyPill = %CoinsPill
@onready var _gems: CurrencyPill = %GemsPill
@onready var _battle_button: PrimaryButton = %BattleButton
@onready var _settings_button: Button = %SettingsButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _version_label: Label = %VersionLabel
@onready var _daily_title: Label = %DailyTitle
@onready var _daily_progress: Label = %DailyProgress
@onready var _view_button: Button = %ViewButton
@onready var _nav_home: Button = %NavHome
@onready var _nav_workshop: Button = %NavWorkshop
@onready var _nav_cards: Button = %NavCards
@onready var _nav_missions: Button = %NavMissions
@onready var _nav_shop: Button = %NavShop
@onready var _nav_home_label: Label = %NavHomeLabel
@onready var _nav_workshop_label: Label = %NavWorkshopLabel
@onready var _nav_cards_label: Label = %NavCardsLabel
@onready var _nav_missions_label: Label = %NavMissionsLabel
@onready var _nav_shop_label: Label = %NavShopLabel
@onready var _magica_button: Button = %MagicaButton
@onready var _magica_status: Label = %MagicaStatus
@onready var _magica_badge: Label = %MagicaBadge
@onready var _welcome_modal: Modal = %WelcomeModal
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel

var _toast_tween: Tween


func _ready() -> void:
	_localize()
	_refresh_wallet()
	AudioBus.bind_buttons(self)

	_battle_button.pressed.connect(_on_battle_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_view_button.pressed.connect(_on_missions_pressed)
	_nav_home.pressed.connect(_on_home_pressed)
	_nav_workshop.pressed.connect(_on_workshop_pressed)
	_nav_cards.pressed.connect(_on_cards_pressed)
	_nav_missions.pressed.connect(_on_missions_pressed)
	_nav_shop.pressed.connect(_on_shop_pressed)
	_magica_button.pressed.connect(_on_magica_pressed)
	_welcome_modal.confirmed.connect(_on_welcome_claimed)

	EventBus.currency_changed.connect(_on_currency_changed)
	LocaleService.language_changed.connect(_on_language_changed)
	_toast.visible = false
	_refresh_daily()
	_refresh_magica()
	_show_welcome_back()
	_show_pending_unlocks()


func _exit_tree() -> void:
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_localize()
	_refresh_daily()


func _localize() -> void:
	_title_label.text = LocaleService.t("app.title", "The Tree")
	_subtitle_label.text = LocaleService.t("app.subtitle", "Idle Tower Defense")
	_version_label.text = "%s %s" % [LocaleService.t("menu.version", "Version"), App.version_string()]
	_battle_button.text = LocaleService.t("menu.battle", "Battle")
	_daily_title.text = LocaleService.t("menu.daily_missions", "Daily Missions")
	_daily_progress.text = LocaleService.t("menu.daily_progress", "0 / 3 Complete")
	_view_button.text = LocaleService.t("menu.view", "View")
	_nav_home_label.text = LocaleService.t("menu.nav.home", "Home")
	_nav_workshop_label.text = LocaleService.t("menu.nav.workshop", "Workshop")
	_nav_cards_label.text = LocaleService.t("menu.nav.cards", "Cards")
	_nav_missions_label.text = LocaleService.t("menu.nav.missions", "Missions")
	_nav_shop_label.text = LocaleService.t("menu.nav.shop", "Shop")
	_settings_button.tooltip_text = LocaleService.t("menu.settings", "Settings")
	_magica_button.text = LocaleService.t("menu.open", "Open")
	_refresh_magica()


func _refresh_daily() -> void:
	var claimed := MissionService.claimed_count(&"daily")
	var total := 3
	_daily_progress.text = LocaleService.t("menu.daily_progress", "%d / %d Complete") % [claimed, total]


func _refresh_magica() -> void:
	if MagicaService.has_pending_claim():
		var pending := MagicaService.get_node_by_id(MagicaService.pending_claim_id())
		_magica_status.text = LocaleService.t("menu.magica_claim", "Research complete: %s") % (
			_locale_node_name(pending) if pending != null else ""
		)
		_magica_badge.visible = true
	elif MagicaService.has_active_research():
		var active := MagicaService.get_node_by_id(MagicaService.active_node_id())
		_magica_status.text = "%s %s" % [
			LocaleService.t("menu.magica_researching", "Researching:"),
			_locale_node_name(active) if active != null else "",
		]
		_magica_badge.visible = false
	else:
		_magica_status.text = LocaleService.t("menu.magica_idle", "No active research")
		_magica_badge.visible = false


func _locale_node_name(node: MagicaNode) -> String:
	if node == null:
		return ""
	return LocaleService.t(node.name_key, node.name)


func _refresh_wallet() -> void:
	_coins.set_amount(GameState.get_balance(&"coins"))
	_gems.set_amount(GameState.get_balance(&"gems"))


func _on_battle_pressed() -> void:
	SceneRouter.goto(&"battle")


func _on_settings_pressed() -> void:
	SceneRouter.goto(&"settings")


func _on_missions_pressed() -> void:
	SceneRouter.goto(&"missions")


func _on_cards_pressed() -> void:
	SceneRouter.goto(&"cards")


func _on_shop_pressed() -> void:
	_show_toast(LocaleService.t("menu.shop_soon", "Shop arrives with M6"))


func _on_magica_pressed() -> void:
	SceneRouter.goto(&"magica")


func _on_home_pressed() -> void:
	# Already on Home; keep the active tab inert.
	pass


func _on_workshop_pressed() -> void:
	SceneRouter.goto(&"workshop")


func _show_welcome_back() -> void:
	var pending := OfflineService.get_pending()
	if pending.is_empty() or int(pending.get("coins", 0)) <= 0:
		return
	var away := LocaleService.format_duration(int(pending.get("away_seconds", 0)))
	var body := LocaleService.t(
		"menu.welcome_body",
		"You were away for %s. The forest gathered %d coins while you were gone."
	) % [away, int(pending.get("coins", 0))]
	if bool(pending.get("capped", false)):
		body += "\n" + LocaleService.t("menu.welcome_capped", "Offline income is capped by your Offline Cap upgrade.")
	_welcome_modal.open(
		LocaleService.t("menu.welcome_title", "Welcome back"),
		body,
		LocaleService.t("menu.claim", "Claim"),
		""
	)


func _on_welcome_claimed() -> void:
	var coins := OfflineService.claim()
	if coins > 0:
		AudioBus.play_ui(&"ui_claim")
	_show_toast(LocaleService.t("menu.offline_claimed", "+%d coins from the forest") % coins)


## Shows one combined toast for features unlocked by the last level-up(s).
func _show_pending_unlocks() -> void:
	var pending := UnlockService.take_pending_unlocks()
	if pending.is_empty():
		return
	var names: PackedStringArray = []
	for unlock_id: StringName in pending:
		names.append(UnlockService.display_name(unlock_id))
	_show_toast(LocaleService.t("menu.unlocked", "Unlocked: %s") % ", ".join(names))


func _on_locked_tab() -> void:
	_show_toast(LocaleService.t("menu.coming_soon", "Coming soon"))


func _on_currency_changed(kind: StringName, amount: int) -> void:
	match kind:
		&"coins":
			_coins.set_amount(amount)
		&"gems":
			_gems.set_amount(amount)


func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.25)
	_toast_tween.tween_callback(_hide_toast)


func _hide_toast() -> void:
	_toast.visible = false


## Tooling-only populated state for docs/preview captures.
func stage_preview() -> void:
	_coins.set_amount(12480)
	_gems.set_amount(350)
	_daily_progress.text = LocaleService.t("menu.daily_progress", "%d / %d Complete") % [1, 3]
	_magica_status.text = LocaleService.t("menu.magica_claim", "Research complete: %s") % "Golden Sap I"
	_magica_badge.visible = true
