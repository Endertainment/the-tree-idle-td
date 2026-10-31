## RunSummary — end-of-run overlay: stats, RewardBundle, best wave, double coins.
##
## Rewards are built as one RewardBundle and granted through GameState exactly once
## per run id (RewardLedger). Cash is intentionally lost at run end; the panel says
## so. "Double coins" asks AdsService for the `run_double_coins` placement and only
## grants when the rewarded callback fires; a failed ad never blocks Continue.
class_name RunSummary
extends CanvasLayer

const COUNT_UP_SECONDS := 0.6

@onready var _title: Label = %Title
@onready var _wave_label: Label = %WaveLabel
@onready var _new_best: Label = %NewBest
@onready var _stats: Label = %StatsLabel
@onready var _best: Label = %BestLabel
@onready var _cash_lost: Label = %CashLost
@onready var _coins: Label = %CoinsLabel
@onready var _gems: Label = %GemsLabel
@onready var _xp: Label = %XpLabel
@onready var _double_button: Button = %DoubleButton
@onready var _ad_note: Label = %AdNote
@onready var _continue_button: Button = %ContinueButton

var _bundle: RewardBundle
var _run_id: String = ""
var _waves: int = 0
var _is_new_best: bool = false
var _best_before: int = 0
var _applied: bool = false
var _doubled: bool = false
var _already_claimed: bool = false
var _ad_pending: bool = false
var _tutorial_hint: TutorialHint


func _ready() -> void:
	_title.text = LocaleService.t("summary.title", "Run over")
	_new_best.text = LocaleService.t("summary.new_best", "NEW BEST")
	_double_button.text = LocaleService.t("summary.double_coins", "Double coins (AD)")
	_continue_button.text = LocaleService.t("summary.continue", "Continue")
	_continue_button.pressed.connect(_on_continue_pressed)
	_double_button.pressed.connect(_on_double_pressed)
	AdsService.rewarded_earned.connect(_on_rewarded_earned)
	AdsService.rewarded_failed.connect(_on_rewarded_failed)


func _exit_tree() -> void:
	if AdsService.rewarded_earned.is_connected(_on_rewarded_earned):
		AdsService.rewarded_earned.disconnect(_on_rewarded_earned)
	if AdsService.rewarded_failed.is_connected(_on_rewarded_failed):
		AdsService.rewarded_failed.disconnect(_on_rewarded_failed)


## Fills the summary and grants rewards once. Repeated calls only re-render.
## `run_id` keys the reward ledger; `cash_left` is shown as lost.
func setup(
	waves_cleared: int,
	kills: int,
	leaks: int,
	elapsed_seconds: float,
	run_id: String = "",
	boss_waves: int = 0,
	cash_left: int = 0
) -> void:
	_waves = maxi(waves_cleared, 0)
	_run_id = run_id if not run_id.is_empty() else "run_%d_%d" % [_waves, Time.get_ticks_msec()]
	_best_before = GameState.get_best_wave()
	_is_new_best = _waves > _best_before
	_bundle = RewardBundle.for_run(_waves, boss_waves, _is_new_best)
	_scale_bundle()
	if not _applied:
		_applied = true
		_apply_rewards()
		GameState.record_run_end(_waves, kills, elapsed_seconds)
		AnalyticsService.track(&"run_end", {
			"waves": _waves,
			"duration": int(elapsed_seconds),
			"coins": _bundle.coins if _bundle != null else 0,
			"kills": kills,
			"leaks": leaks,
		})
		SaveService.flush()

	_wave_label.text = "%s %d" % [LocaleService.t("summary.wave", "Wave"), _waves]
	_new_best.visible = _is_new_best
	var best_now := maxi(_best_before, _waves)
	_best.text = "%s: %d" % [LocaleService.t("summary.best_wave", "Best wave"), best_now]
	_stats.text = "%s: %d    %s: %d    %s: %d    %s: %s" % [
		LocaleService.t("summary.waves", "Waves"), _waves,
		LocaleService.t("summary.kills", "Kills"), kills,
		LocaleService.t("summary.leaks", "Leaks"), leaks,
		LocaleService.t("summary.time", "Time"), TimeService.format_clock(int(elapsed_seconds)),
	]
	_cash_lost.text = "%s: %d" % [
		LocaleService.t("summary.cash_lost", "Cash is lost when the run ends"), cash_left
	]
	_animate_reward(_coins, LocaleService.t("summary.coins", "Coins"), _bundle.coins)
	_animate_reward(_gems, LocaleService.t("summary.gems", "Gems"), _bundle.gems)
	_animate_reward(_xp, LocaleService.t("summary.xp", "XP"), _bundle.xp)
	_ad_note.text = ""
	if _already_claimed:
		_ad_note.text = LocaleService.t("summary.already_claimed", "Rewards were already granted for this run.")
	_double_button.disabled = _doubled or _bundle.coins <= 0
	if TutorialService.take(&"first_defeat"):
		_tutorial_hint = TutorialHint.new()
		add_child(_tutorial_hint)
		_tutorial_hint.show_hint(TutorialService.text(&"first_defeat"), 12.0)


## Applies the bundle once per run id; a re-shown summary never double-pays.
func _apply_rewards() -> void:
	if not GameState.claim_run_reward(_run_id):
		_already_claimed = true
		return
	GameState.grant_bundle(_bundle, &"run_end")


## Workshop "Coin Gain" / "XP Gain" apply to the run payout only.
func _scale_bundle() -> void:
	if _bundle == null:
		return
	_bundle.coins = _scaled(_bundle.coins, &"coin_gain")
	_bundle.xp = _scaled(_bundle.xp, &"xp_gain")


## Applies a permanent gain multiplier and rounds to a whole reward.
func _scaled(amount: int, stat: StringName) -> int:
	if amount <= 0:
		return 0
	return maxi(1, int(round(float(amount) * maxf(ModifierService.get_stat(stat, 1.0), 0.0))))


func _animate_reward(label: Label, prefix: String, amount: int) -> void:
	label.text = "%s +%s" % [prefix, LocaleService.format_number(amount)]
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			label.text = "%s +%s" % [prefix, LocaleService.format_number(int(roundf(value)))],
		0.0,
		float(amount),
		COUNT_UP_SECONDS
	)


func _on_double_pressed() -> void:
	if _doubled or _ad_pending or _bundle == null or _bundle.coins <= 0:
		return
	_ad_pending = true
	_double_button.disabled = true
	_double_button.text = LocaleService.t("summary.ad_loading", "Loading ad…")
	_ad_note.text = LocaleService.t("summary.ad_loading_note", "Watch the ad to double this run's coins.")
	if not AdsService.show_rewarded(AdsService.PLACEMENT_DOUBLE_COINS):
		_end_ad_request(LocaleService.t("summary.ad_failed", "Ad not available, try again later"))


func _on_rewarded_earned(placement: StringName) -> void:
	if placement != AdsService.PLACEMENT_DOUBLE_COINS or not _ad_pending:
		return
	_ad_pending = false
	_doubled = true
	_double_button.text = LocaleService.t("summary.doubled", "Coins doubled")
	_double_button.disabled = true
	if not GameState.claim_run_reward(_run_id + ":double"):
		_ad_note.text = LocaleService.t("summary.already_claimed", "Rewards were already granted for this run.")
		return
	GameState.grant_bundle(RewardBundle.coins_only(_bundle.coins), &"run_double")
	SaveService.flush()
	AnalyticsService.track(&"ad_rewarded", {"placement": "run_double_coins", "coins": _bundle.coins})
	_ad_note.text = LocaleService.t("summary.doubled", "Coins doubled")
	_animate_reward(_coins, LocaleService.t("summary.coins", "Coins"), _bundle.coins * 2)


func _on_rewarded_failed(placement: StringName, reason: StringName) -> void:
	if placement != AdsService.PLACEMENT_DOUBLE_COINS or not _ad_pending:
		return
	_ad_pending = false
	var message := LocaleService.t("summary.ad_failed", "Ad not available, try again later")
	if reason == AdsService.REASON_CAP_REACHED:
		message = LocaleService.t("ads.cap_reached", "You have reached the ad limit for now.")
	_end_ad_request(message)


func _end_ad_request(message: String) -> void:
	_double_button.text = LocaleService.t("summary.double_coins", "Double coins (AD)")
	_double_button.disabled = _doubled or _bundle == null or _bundle.coins <= 0
	_ad_note.text = message
	AudioBus.play_ui(&"ui_error")


func _on_continue_pressed() -> void:
	# Run-end interstitial (every 3rd run, 120 s apart, never before wave 5).
	AdsService.set_interstitial_context(GameState.stats.get("runs_played", 0), _waves)
	AdsService.show_interstitial(AdsService.PLACEMENT_INTERSTITIAL)
	SceneRouter.goto(&"main_menu")
