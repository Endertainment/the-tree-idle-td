## Pedestal — one of the eight build slots around the Tree.
##
## Owns only its visual state. A tap emits `pressed`; BattleController decides
## whether a build sheet opens. Tower nodes are parented to the y-sorted Towers
## container, not to the pedestal, so overlap sorting stays correct.
class_name Pedestal
extends Area2D

signal pressed(pedestal: Pedestal)

enum State { EMPTY, SELECTED, OCCUPIED, LOCKED }

var index: int = 0
var state: State = State.EMPTY
var tower: Tower

@onready var _base: Sprite2D = $Base
@onready var _rune: Sprite2D = $Rune
@onready var _selection: Sprite2D = $Selection


func _ready() -> void:
	input_event.connect(_on_input_event)
	_refresh_visuals()


## Stores the authored slot index (0..7) for debug and future save data.
func setup(slot_index: int) -> void:
	index = slot_index


func is_buildable() -> bool:
	return state == State.EMPTY


func is_occupied() -> bool:
	return state == State.OCCUPIED


func select() -> void:
	if state != State.EMPTY:
		return
	state = State.SELECTED
	_refresh_visuals()


func deselect() -> void:
	if state != State.SELECTED:
		return
	state = State.EMPTY
	_refresh_visuals()


## Marks the pedestal as holding a tower; called once the build succeeded.
func mark_occupied(built_tower: Tower) -> void:
	tower = built_tower
	state = State.OCCUPIED
	_refresh_visuals()


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	_rune.visible = state == State.EMPTY or state == State.SELECTED
	_selection.visible = state == State.SELECTED


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	get_viewport().set_input_as_handled()
	pressed.emit(self)
