## GamePanel — reusable PanelContainer with an optional header label.
class_name GamePanel
extends PanelContainer

## Shown in the header when non-empty; the header disappears otherwise.
@export var header_text: String:
	set(value):
		header_text = value
		_update_header()

@onready var _header: Label = %Header
@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	_update_header()


## Returns the container that callers should add their content to.
func get_content() -> VBoxContainer:
	return _content


## Sets the header after the panel is already in the tree.
func set_header(text: String) -> void:
	header_text = text


func _update_header() -> void:
	if not is_instance_valid(_header):
		return
	_header.text = header_text
	_header.visible = not header_text.is_empty()
