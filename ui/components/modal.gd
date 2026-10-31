## Modal — scrim + panel + title/body + one or two buttons.
##
## Call open() with already-localised strings (callers use LocaleService.t()).
## Emits confirmed only after the primary button is pressed.
class_name Modal
extends Control

signal confirmed

@onready var _scrim: ColorRect = %Scrim
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _cancel: Button = %CancelButton
@onready var _confirm: Button = %ConfirmButton


func _ready() -> void:
	visible = false
	_cancel.pressed.connect(close)
	_confirm.pressed.connect(_on_confirm_pressed)
	_scrim.gui_input.connect(_on_scrim_gui_input)


## Shows the modal. Pass an empty cancel_text to hide the secondary button.
func open(
	title_text: String = "",
	body_text: String = "",
	confirm_text: String = "",
	cancel_text: String = ""
) -> void:
	_title.text = title_text
	_body.text = body_text
	_confirm.text = confirm_text
	_cancel.text = cancel_text
	_cancel.visible = not cancel_text.is_empty()
	visible = true


## Hides the modal without emitting confirmed.
func close() -> void:
	visible = false


func _on_confirm_pressed() -> void:
	confirmed.emit()
	close()


func _on_scrim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close()
