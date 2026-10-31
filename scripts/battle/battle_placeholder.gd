## BattlePlaceholder — intentionally empty M0 battle screen.
##
## Proves SceneRouter back-navigation works. Combat, waves and run state arrive
## in M1; no fake gameplay is simulated here.
extends Control

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_title.text = LocaleService.t("battle.placeholder", "Battle (M1)")
	_subtitle.text = LocaleService.t("battle.placeholder_hint", "Combat arrives in the next milestone")
	_back_button.tooltip_text = LocaleService.t("common.back", "Back")
	_back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	SceneRouter.back()
