## MainMenu — the approved menu reference (spec 13.3).
##
## Top bar (coins/gems + buy shortcuts, settings), logotype, stats card (best
## wave, avatar, nickname, level + XP), Battle CTA, Speed Trial rewarded offer,
## daily missions card, Magica entry and the five-tab navigation. Wallet state is
## read-only here; currency mutations stay behind WalletService and the shop.
extends Control

const AVATAR_DIR := "res://assets/art/ui/menu/"
const AVATAR_FALLBACK := "avatar_01"

const PLUS_NORMAL := preload("res://assets/art/ui/buttons/button_plus_normal.png")
const PLUS_PRESSED := preload("res://assets/art/ui/buttons/button_plus_pressed.png")

@onready var _coins: CurrencyPill = %CoinsPill
@onready var _gems: CurrencyPill = %GemsPill
@onready var _coin_plus: Button = %CoinPlus
@onready var _gem_plus: Button = %GemPlus
@onready var _settings_button: Button = %SettingsButton
@onready var _battle_button: PrimaryButton = %BattleButton
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _stats_card: Button = %StatsCard
@onready var _best_wave_value: Label = %BestWaveValue
@onready var _avatar: TextureRect = %Avatar
@onready var _nickname: Label = %Nickname
@onready var _player_level: Label = %PlayerLevel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_label: Label = %XpLabel
@onready var _speed_trial: Button = %SpeedTrial
@onready var _daily_progress: Label = %DailyProgress
@onready var _view_button: Button = %ViewButton
@onready var _nav: MenuNav = %NavBar
@onready var _magica_button: Button = %MagicaButton
@onready var _magica_status: Label = %MagicaStatus
@onready var _magica_badge: Label = %MagicaBadge
@onready var _welcome_modal: Modal = %WelcomeModal

var _speed_ad_pending: bool = false


func _ready() -> void:
	_localize()
	_refresh_wallet()
	_refresh_stats()
	_refresh_daily()
	_refresh_magica()
	AudioBus.bind_buttons(self)

	_battle_button.pressed.connect(_on_battle_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	for plus in [_coin_plus, _gem_plus]:
		plus.button_down.connect(_on_plus_down.bind(plus))
		plus.button_up.connect(_on_plus_up.bind(plus))
	_coin_plus.pressed.connect(_on_buy_pressed.bind(&"coins"))
	_gem_plus.pressed.connect(_on_buy_pressed.bind(&"gems"))
	_stats_card.pressed.connect(_on_profile_pressed)
	_speed_trial.pressed.connect(_on_speed_trial_pressed)
	_view_button.pressed.connect(_on_missions_pressed)
	_nav.setup(&"home")
	_magica_button.pressed.connect(_on_magica_pressed)
	_welcome_modal.confirmed.connect(_on_welcome_claimed)
	AdsService.rewarded_earned.connect(_on_rewarded_earned)
	AdsService.rewarded_failed.connect(_on_rewarded_failed)
	_refresh_speed_trial()

	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.level_up.connect(_on_level_up)
	LocaleService.language_changed.connect(_on_language_changed)
	_show_welcome_back()
	_show_pending_unlocks()


func _exit_tree() -> void:
	if EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.disconnect(_on_currency_changed)
	if EventBus.level_up.is_connected(_on_level_up):
		EventBus.level_up.disconnect(_on_level_up)
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)
	if AdsService.rewarded_earned.is_connected(_on_rewarded_earned):
		AdsService.rewarded_earned.disconnect(_on_rewarded_earned)
	if AdsService.rewarded_failed.is_connected(_on_rewarded_failed):
		AdsService.rewarded_failed.disconnect(_on_rewarded_failed)


func _on_language_changed(_code: String) -> void:
	_localize()
	_refresh_stats()
	_refresh_daily()
	_refresh_magica()
	_refresh_speed_trial()


func _localize() -> void:
	_title_label.text = LocaleService.t("app.title", "The Tree")
	_subtitle_label.text = LocaleService.t("app.subtitle", "Idle Tower Defense")
	_battle_button.text = LocaleService.t("menu.battle", "Battle")
	_speed_trial.text = LocaleService.t("menu.speed_trial_offer", "Speed Trial  +1.5x")
	_speed_trial.tooltip_text = LocaleService.t(
		"menu.speed_trial_hint", "Watch an ad for a 24 h speed boost"
	)
	_view_button.text = LocaleService.t("menu.view", "View")
	_settings_button.tooltip_text = LocaleService.t("menu.settings", "Settings")
	_coin_plus.tooltip_text = LocaleService.t("menu.buy_coins", "Buy coins")
	_gem_plus.tooltip_text = LocaleService.t("menu.buy_gems", "Buy gems")
	_stats_card.tooltip_text = LocaleService.t("menu.open_profile", "Player profile")
	_magica_button.text = LocaleService.t("menu.open", "Open")
	_nav.setup(&"home")


func _refresh_wallet() -> void:
	_coins.set_amount(GameState.get_balance(&"coins"))
	_gems.set_amount(GameState.get_balance(&"gems"))


func _refresh_stats() -> void:
	_best_wave_value.text = LocaleService.format_number(GameState.get_best_wave())
	var level := LevelService.get_level()
	var xp := LevelService.get_xp()
	var required := LevelService.xp_required()
	_player_level.text = str(level)
	_xp_bar.max_value = float(maxi(required, 1))
	_xp_bar.value = float(mini(xp, maxi(required, 1)))
	_xp_label.text = LocaleService.t("menu.xp_progress", "%d / %d XP") % [xp, required]
	var nickname := str(GameState.player.get("nickname", "")).strip_edges()
	_nickname.text = nickname if not nickname.is_empty() else LocaleService.t(
		"menu.nickname_fallback", "Tree Warden"
	)
	_avatar.texture = _avatar_texture(str(GameState.player.get("avatar_id", AVATAR_FALLBACK)))


func _avatar_texture(avatar_id: String) -> Texture2D:
	var safe_id := avatar_id if not avatar_id.is_empty() else AVATAR_FALLBACK
	var path := AVATAR_DIR + safe_id + ".png"
	if not ResourceLoader.exists(path):
		path = AVATAR_DIR + AVATAR_FALLBACK + ".png"
	return load(path) as Texture2D


func _refresh_daily() -> void:
	var completed := 0
	for row: Dictionary in MissionService.get_daily():
		if int(row.get("progress", 0)) >= int(row.get("target", 1)):
			completed += 1
	_daily_progress.text = LocaleService.t("menu.daily_progress", "%d / %d Complete") % [
		completed, MissionService.get_daily().size()
	]


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


func _on_battle_pressed() -> void:
	SceneRouter.goto(&"battle")


func _on_plus_down(button: Button) -> void:
	button.icon = PLUS_PRESSED


func _on_plus_up(button: Button) -> void:
	button.icon = PLUS_NORMAL


func _on_settings_pressed() -> void:
	SceneRouter.goto(&"settings")


func _on_profile_pressed() -> void:
	SceneRouter.goto(&"profile")


func _on_missions_pressed() -> void:
	SceneRouter.goto(&"missions")


func _on_magica_pressed() -> void:
	SceneRouter.goto(&"magica")


## Both "+" shortcuts open the shop; M5b has no direct purchase from the menu.
func _on_buy_pressed(tab: StringName) -> void:
	SceneRouter.goto(&"shop", {"tab": String(tab)})


## The rewarded speed offer is a real placement in M6: rewarded_earned grants 24 h
## of 1.5x (or the next locked step) through GameState; failures only toast.
func _on_speed_trial_pressed() -> void:
	if _speed_ad_pending:
		return
	if GameState.speed_boost_remaining() > 0:
		ToastService.show_toast(
			LocaleService.t("menu.speed_trial_active_toast", "Speed Trial active for %s") % LocaleService.format_duration(
				GameState.speed_boost_remaining()
			)
		)
		return
	_speed_ad_pending = true
	_refresh_speed_trial()
	if not AdsService.show_rewarded(AdsService.PLACEMENT_SPEED):
		_speed_ad_pending = false
		_refresh_speed_trial()


func _on_rewarded_earned(placement: StringName) -> void:
	if placement != AdsService.PLACEMENT_SPEED or not _speed_ad_pending:
		return
	_speed_ad_pending = false
	var unlock := GameState.grant_speed_boost()
	if unlock.is_empty():
		ToastService.show_toast(LocaleService.t("menu.speed_trial_maxed", "Both speeds are already unlocked."))
	else:
		ToastService.show_toast(
			LocaleService.t("menu.speed_trial_granted", "Speed Trial unlocked for 24 h!")
		)
		AnalyticsService.track(&"ad_rewarded", {"placement": "speed_unlock_24h", "unlock": String(unlock)})
	SaveService.flush()
	_refresh_speed_trial()


func _on_rewarded_failed(placement: StringName, reason: StringName) -> void:
	if placement != AdsService.PLACEMENT_SPEED or not _speed_ad_pending:
		return
	_speed_ad_pending = false
	var message := LocaleService.t("ads.not_available", "Ad not available, try again later")
	if reason == AdsService.REASON_CAP_REACHED:
		message = LocaleService.t("ads.cap_reached", "You have reached the ad limit for now.")
	elif reason == AdsService.REASON_CONSENT:
		message = LocaleService.t("ads.consent_required", "Ads need your consent first.")
	ToastService.show_toast(message)
	_refresh_speed_trial()


func _refresh_speed_trial() -> void:
	if _speed_ad_pending:
		_speed_trial.text = LocaleService.t("menu.ad_loading", "Loading ad…")
		_speed_trial.disabled = true
		return
	var remaining := GameState.speed_boost_remaining()
	if remaining > 0:
		_speed_trial.text = LocaleService.t("menu.speed_trial_active", "Speed Trial  %s left") % LocaleService.format_duration(remaining)
		_speed_trial.disabled = true
		return
	_speed_trial.text = LocaleService.t("menu.speed_trial_offer", "Speed Trial  +1.5x")
	_speed_trial.disabled = false


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
	ToastService.show_toast(
		LocaleService.t("menu.offline_claimed", "+%s coins from the forest") % LocaleService.format_number(coins)
	)


## Shows one combined toast for features unlocked by the last level-up(s).
func _show_pending_unlocks() -> void:
	var pending := UnlockService.take_pending_unlocks()
	if pending.is_empty():
		return
	var names: PackedStringArray = []
	for unlock_id: StringName in pending:
		names.append(UnlockService.display_name(unlock_id))
	ToastService.show_toast(LocaleService.t("menu.unlocked", "Unlocked: %s") % ", ".join(names))


func _on_level_up(_level: int) -> void:
	_refresh_stats()
	_show_pending_unlocks()


func _on_currency_changed(kind: StringName, amount: int) -> void:
	match kind:
		&"coins":
			_coins.set_amount(amount)
		&"gems":
			_gems.set_amount(amount)


## Tooling-only populated state for docs/preview captures.
func stage_preview() -> void:
	_coins.set_amount(12480)
	_gems.set_amount(350)
	_best_wave_value.text = "18"
	_player_level.text = "7"
	_xp_bar.max_value = 120.0
	_xp_bar.value = 50.0
	_xp_label.text = LocaleService.t("menu.xp_progress", "%d / %d XP") % [50, 120]
	_nickname.text = "Elderwood"
	_avatar.texture = _avatar_texture("avatar_04")
	_daily_progress.text = LocaleService.t("menu.daily_progress", "%d / %d Complete") % [1, 3]
	_magica_status.text = LocaleService.t("menu.magica_claim", "Research complete: %s") % "Golden Sap I"
	_magica_badge.visible = true
	_nav.set_notification(&"missions", true)
	_nav.set_notification(&"cards", true)
	_nav.set_notification(&"home", true)
