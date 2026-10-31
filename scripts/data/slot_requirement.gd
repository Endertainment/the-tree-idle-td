## SlotRequirement — the unlock condition of one canopy unit slot.
##
## `kind` is one of `level`, `gems` or `workshop`; `alt_kind` adds the "or" branch
## (slot 4: player level 12 OR 150 gems). `label_text` is the visible condition
## shown while the slot is locked; M5 replaces it with `label_key`.
class_name SlotRequirement
extends Resource

@export var kind: StringName = &"level"
@export var value: int = 1
@export var flag: StringName = &""
@export var alt_kind: StringName = &""
@export var alt_value: int = 0
@export var alt_flag: StringName = &""
@export var label_key: String = ""
@export var label_text: String = ""
