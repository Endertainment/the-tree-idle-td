## CurrencyPill — icon + formatted amount, used in top bars.
class_name CurrencyPill
extends PanelContainer

## Icon shown at the left of the pill (coin, gem, stone...).
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_instance_valid(_icon):
			_icon.texture = value

## Amount applied in _ready(); callers may override later with set_amount().
@export var initial_amount: int = 0

@onready var _icon: TextureRect = %Icon
@onready var _amount: Label = %Amount


func _ready() -> void:
	if icon_texture != null:
		_icon.texture = icon_texture
	set_amount(initial_amount)


## Updates the displayed amount using locale-aware grouping.
func set_amount(value: int) -> void:
	if not is_instance_valid(_amount):
		return
	_amount.text = LocaleService.format_number(value)
