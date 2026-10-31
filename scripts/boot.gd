## Boot — fades in the logo, initialises services, then enters the main menu.
##
## M0 intentionally has no first-launch branch yet; it is added in M2/M4 when
## GameState.is_onboarded becomes meaningful.
extends Control

const FADE_SECONDS := 0.6

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _version: Label = %Version
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	_title.text = LocaleService.t("app.title", "The Tree")
	_subtitle.text = LocaleService.t("app.subtitle", "Idle Tower Defense")
	_version.text = "%s %s" % [LocaleService.t("app.version", "v"), App.version_string()]

	App.init_services()

	_fade.visible = true
	_fade.color.a = 1.0
	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await fade_in.finished
	_fade.visible = false

	SceneRouter.goto(&"main_menu")
