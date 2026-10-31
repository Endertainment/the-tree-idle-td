## TowerBehaviorRegistry — maps a TowerData.behavior_id to a strategy object.
##
## This is the M2 replacement for `if tower_id == "cannon"` chains: the data
## names a behavior, the registry instantiates it. Unknown ids fall back to the
## base behavior (null) so content can ship before its script.
class_name TowerBehaviorRegistry
extends RefCounted

const BEHAVIOR_SCRIPTS := {
	&"double_shot": preload("res://scripts/combat/behaviors/double_shot.gd"),
	&"shrapnel": preload("res://scripts/combat/behaviors/shrapnel.gd"),
	&"deep_chill": preload("res://scripts/combat/behaviors/deep_chill.gd"),
	&"rooted_gift": preload("res://scripts/combat/behaviors/rooted_gift.gd"),
}


## Returns a fresh behavior instance, or null for an unknown/empty id.
static func create(behavior_id: StringName) -> TowerBehavior:
	var script: Script = BEHAVIOR_SCRIPTS.get(behavior_id, null)
	if script == null:
		return null
	return script.new() as TowerBehavior


static func has_behavior(behavior_id: StringName) -> bool:
	return BEHAVIOR_SCRIPTS.has(behavior_id)


## Every authored behavior id (used by tests and tooling).
static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in BEHAVIOR_SCRIPTS.keys():
		result.append(key)
	return result
