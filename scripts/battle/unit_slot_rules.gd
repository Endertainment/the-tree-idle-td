## UnitSlotRules — pure unlock logic for the four canopy unit slots.
##
## Kept free of autoloads and nodes so the headless unit test can call it with a
## player level, gem balance and workshop flags. `describe()` returns the authored
## English condition shown on a locked slot (localised in M5).
class_name UnitSlotRules
extends RefCounted

const KIND_LEVEL := &"level"
const KIND_GEMS := &"gems"
const KIND_WORKSHOP := &"workshop"


## Returns true when `requirement` is satisfied (null = always unlocked).
static func meets_requirement(
	requirement: SlotRequirement,
	player_level: int,
	gems: int,
	workshop_flags: Dictionary
) -> bool:
	if requirement == null:
		return true
	if _meets_kind(requirement.kind, requirement.value, requirement.flag, player_level, gems, workshop_flags):
		return true
	if not requirement.alt_kind.is_empty():
		return _meets_kind(
			requirement.alt_kind,
			requirement.alt_value,
			requirement.alt_flag,
			player_level,
			gems,
			workshop_flags
		)
	return false


## The visible lock condition ("Player level 4", "Workshop: Third Branch", ...).
static func describe(requirement: SlotRequirement) -> String:
	if requirement == null:
		return ""
	return requirement.label_text


static func _meets_kind(
	kind: StringName,
	value: int,
	flag: StringName,
	player_level: int,
	gems: int,
	workshop_flags: Dictionary
) -> bool:
	match kind:
		KIND_LEVEL:
			return player_level >= value
		KIND_GEMS:
			return gems >= value
		KIND_WORKSHOP:
			if flag.is_empty():
				return false
			return bool(workshop_flags.get(String(flag), false))
		_:
			return false
