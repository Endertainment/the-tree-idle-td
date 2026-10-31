## RunSummary — end-of-run overlay: cleared waves, rewards and Continue.
##
## Rewards are computed from the cleared-wave count and applied to GameState
## exactly once per summary instance (`_applied` guard). Cash is intentionally
## lost at run end; only the meta currencies and XP persist.
class_name RunSummary
extends CanvasLayer

@onready var _title: Label = %Title
@onready var _wave_label: Label = %WaveLabel
@onready var _new_best: Label = %NewBest
@onready var _stats: Label = %StatsLabel
@onready var _coins: Label = %CoinsLabel
@onready var _gems: Label = %GemsLabel
@onready var _xp: Label = %XpLabel
@onready var _continue_button: Button = %ContinueButton

var _applied: bool = false


func _ready() -> void:
	_title.text = LocaleService.t("summary.title", "Run over")
	_new_best.text = LocaleService.t("summary.new_best", "NEW BEST")
	_continue_button.text = LocaleService.t("summary.continue", "Continue")
	_continue_button.pressed.connect(_on_continue_pressed)


## Fills the summary and grants rewards. Safe to call once; later calls only
## refresh the displayed numbers (never re-grant).
func setup(waves_cleared: int, kills: int, leaks: int, elapsed_seconds: float) -> void:
	var rewards := RunRewards.compute(waves_cleared)
	var best_before := int(GameState.player.get("best_wave", 0))
	var is_new_best := waves_cleared > best_before
	if not _applied:
		_applied = true
		_apply_rewards(rewards)
		if is_new_best:
			GameState.player["best_wave"] = waves_cleared
		SaveService.save(GameState.to_dict())

	_wave_label.text = "%s %d" % [LocaleService.t("summary.wave", "Wave"), waves_cleared]
	_new_best.visible = is_new_best
	_stats.text = "%s: %d    %s: %d    %s: %d    %s: %s" % [
		LocaleService.t("summary.waves", "Waves"), waves_cleared,
		LocaleService.t("summary.kills", "Kills"), kills,
		LocaleService.t("summary.leaks", "Leaks"), leaks,
		LocaleService.t("summary.time", "Time"), TimeService.format_clock(int(elapsed_seconds)),
	]
	_coins.text = "%s +%d" % [LocaleService.t("summary.coins", "Coins"), int(rewards["coins"])]
	_gems.text = "%s +%d" % [LocaleService.t("summary.gems", "Gems"), int(rewards["gems"])]
	_xp.text = "%s +%d" % [LocaleService.t("summary.xp", "XP"), int(rewards["xp"])]


## Applies rewards through RunRewards and never re-grants on repeated setup().
func _apply_rewards(rewards: Dictionary) -> void:
	GameState.set_balance(&"coins", GameState.get_balance(&"coins") + int(rewards["coins"]))
	GameState.set_balance(&"gems", GameState.get_balance(&"gems") + int(rewards["gems"]))
	GameState.player["xp"] = int(GameState.player.get("xp", 0)) + int(rewards["xp"])


func _on_continue_pressed() -> void:
	SceneRouter.goto(&"main_menu")
