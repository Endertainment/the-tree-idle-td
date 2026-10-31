## UnitSlot — one canopy anchor that can hold a guardian unit.
##
## The slot owns only its visual state and unlock flag; UnitSlotRules decides
## whether the requirement is met and UnitSlots (battle flow) owns placement.
class_name UnitSlot
extends Area2D

signal pressed(slot: UnitSlot)

enum State { LOCKED, EMPTY, SELECTED, OCCUPIED }

var index: int = 0
var state: State = State.LOCKED
var requirement: SlotRequirement
var unit: Unit

@onready var _base: Sprite2D = $Base
@onready var _locked: Sprite2D = $Locked
@onready var _selection: Sprite2D = $Selection
@onready var _hint: Label = $Hint


func _ready() -> void:
	input_event.connect(_on_input_event)
	_refresh_visuals()


func setup(slot_index: int, slot_requirement: SlotRequirement, unlocked: bool) -> void:
	index = slot_index
	requirement = slot_requirement
	set_unlocked(unlocked)


func set_unlocked(unlocked: bool) -> void:
	if unlocked:
		if state == State.LOCKED:
			state = State.EMPTY
	else:
		state = State.LOCKED
	_refresh_visuals()


func is_unlocked() -> bool:
	return state != State.LOCKED


func is_empty() -> bool:
	return state == State.EMPTY or state == State.SELECTED


func is_occupied() -> bool:
	return state == State.OCCUPIED


## Visible condition on a locked slot ("Player level 4", ...).
func lock_hint() -> String:
	return UnitSlotRules.describe(requirement)


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


func mark_occupied(placed_unit: Unit) -> void:
	unit = placed_unit
	state = State.OCCUPIED
	_refresh_visuals()


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	var locked := state == State.LOCKED
	_locked.visible = locked
	_base.modulate = Color(0.55, 0.55, 0.55, 0.9) if locked else Color.WHITE
	_selection.visible = state == State.SELECTED
	_hint.visible = locked and not lock_hint().is_empty()
	_hint.text = lock_hint()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	get_viewport().set_input_as_handled()
	pressed.emit(self)
