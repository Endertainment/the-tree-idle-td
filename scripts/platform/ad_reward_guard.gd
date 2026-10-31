## AdRewardGuard — exactly one reward per rewarded-ad view.
##
## A view is "active" from the moment show_rewarded() starts until the SDK reports
## dismissal. claim() returns true on the first earned callback only, so a
## duplicate SDK callback (or a double-tap on the button) can never grant twice.
class_name AdRewardGuard
extends RefCounted

var _active: StringName = &""
var _claimed: bool = false


## Marks the start of a view. Returns false when another view is still active.
func begin(placement: StringName) -> bool:
	if is_busy():
		return false
	_active = placement
	_claimed = false
	return true


## Claims the reward once for the active placement.
func claim(placement: StringName) -> bool:
	if _active != placement or _claimed:
		return false
	_claimed = true
	return true


## Ends the active view (called on dismissal/failure).
func finish() -> void:
	_active = &""
	_claimed = false


## True while an ad view owns the slot (prevents stacking ads).
func is_busy() -> bool:
	return not _active.is_empty()


## True when the current view already paid out.
func is_claimed() -> bool:
	return _claimed


## Placement of the active view (empty when idle).
func active_placement() -> StringName:
	return _active
