## PauseMenu — pause overlay: resume, restart, abandon, settings placeholder.
##
## Presentation only. Restart and Abandon require a confirmation modal; the HUD
## routes the confirmed signals to BattleController (restart/abandon) and keeps the
## battle simulation frozen through BattleClock while the overlay is open.
class_name PauseMenu
extends Control

signal resume_requested
signal restart_requested
signal abandon_requested

enum Pending { NONE, RESTART, ABANDON }

@onready var _title: Label = %PauseTitle
@onready var _stats: Label = %PauseStats
@onready var _resume: Button = %ResumeButton
@onready var _restart: Button = %RestartButton
@onready var _abandon: Button = %AbandonButton
@onready var _settings: Button = %SettingsButton
@onready var _confirm: Modal = %PauseConfirm

var _pending: Pending = Pending.NONE


func _ready() -> void:
	visible = false
	_localize()
	LocaleService.language_changed.connect(_on_language_changed)
	_resume.pressed.connect(_on_resume_pressed)
	_restart.pressed.connect(_on_restart_pressed)
	_abandon.pressed.connect(_on_abandon_pressed)
	_settings.pressed.connect(_on_settings_pressed)
	_confirm.confirmed.connect(_on_confirmed)


func _exit_tree() -> void:
	if LocaleService.language_changed.is_connected(_on_language_changed):
		LocaleService.language_changed.disconnect(_on_language_changed)


func _on_language_changed(_code: String) -> void:
	_localize()


func _localize() -> void:
	_title.text = LocaleService.t("battle.paused", "Paused")
	_resume.text = LocaleService.t("battle.resume", "Resume")
	_restart.text = LocaleService.t("battle.restart", "Restart")
	_abandon.text = LocaleService.t("battle.abandon", "Abandon run")
	_settings.text = LocaleService.t("battle.settings", "Settings")


func open(stats_text: String = "") -> void:
	_pending = Pending.NONE
	_stats.text = stats_text
	visible = true


func close() -> void:
	_confirm.close()
	_pending = Pending.NONE
	visible = false


func is_open() -> bool:
	return visible


func _on_resume_pressed() -> void:
	close()
	resume_requested.emit()


func _on_restart_pressed() -> void:
	_pending = Pending.RESTART
	_confirm.open(
		LocaleService.t("battle.restart_confirm_title", "Restart run?"),
		LocaleService.t("battle.restart_confirm_body", "The current run ends now and its cash is lost."),
		LocaleService.t("battle.restart", "Restart"),
		LocaleService.t("common.cancel", "Cancel")
	)


func _on_abandon_pressed() -> void:
	_pending = Pending.ABANDON
	_confirm.open(
		LocaleService.t("battle.abandon_confirm_title", "Abandon run?"),
		LocaleService.t("battle.abandon_confirm_body", "You keep the rewards for cleared waves. Cash is lost."),
		LocaleService.t("battle.abandon", "Abandon"),
		LocaleService.t("common.cancel", "Cancel")
	)


func _on_settings_pressed() -> void:
	_pending = Pending.NONE
	SceneRouter.open_overlay(&"settings")


func _on_confirmed() -> void:
	var pending := _pending
	_pending = Pending.NONE
	match pending:
		Pending.RESTART:
			restart_requested.emit()
		Pending.ABANDON:
			abandon_requested.emit()
