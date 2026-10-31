## Boot — fades in the logo, initialises services, then routes to onboarding or
## the main menu. Never calls change_scene_to_file directly (SceneRouter owns it).
extends Control

const FADE_SECONDS := 0.8

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _version: Label = %Version
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	_title.text = LocaleService.t("app.title", "The Tree")
	_subtitle.text = LocaleService.t("app.subtitle", "Idle Tower Defense")
	_version.text = "%s %s" % [LocaleService.t("app.version", "v"), App.version_string()]

	App.init_services()
	SettingsService.apply_text_scale(get_window())

	_fade.visible = true
	_fade.color.a = 1.0
	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await fade_in.finished
	_fade.visible = false

	if GameState.is_onboarded:
		SceneRouter.goto(&"main_menu")
	else:
		SceneRouter.goto(&"onboarding")
