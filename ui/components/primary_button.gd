## PrimaryButton — reusable themed call-to-action button.
##
## Add it as a scene instance and set `text`, `icon_texture` or `theme_type_variation`.
## The built-in pressed signal still works; `clicked` is an extra semantic alias.
class_name PrimaryButton
extends Button

signal clicked

## Optional icon shown left of the label.
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		icon = value

## Optional UI click sound. The hook is silent when no stream is assigned.
@export var click_sound: AudioStream

@export var play_click_sound: bool = true


func _ready() -> void:
	if icon_texture != null:
		icon = icon_texture
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if play_click_sound and click_sound != null:
		AudioBus.play_sfx(click_sound)
	clicked.emit()
