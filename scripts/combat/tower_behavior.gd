## TowerBehavior — base strategy for a tower's level-5 signature behavior.
##
## Behaviors are selected by `TowerData.behavior_id` / `UnitData.behavior_id`
## through TowerBehaviorRegistry; gameplay code never branches on tower id. A
## behavior may rewrite the shot (extra projectiles, bigger splash, stronger
## slow) and the totem aura (stronger buffs). Values come from the data's
## `behavior_params` dictionary, so behaviors work for both towers and units and
## a new tower can reuse an existing behavior without code changes.
class_name TowerBehavior
extends RefCounted


## Returns the shots a single attack should fire. One shot by default.
func modify_shots(_params: Dictionary, _level: int, shot: Dictionary) -> Array[Dictionary]:
	var shots: Array[Dictionary] = [shot]
	return shots


## Returns the aura dictionary ({radius, damage, speed}) after this behavior.
func modify_aura(_params: Dictionary, _level: int, aura: Dictionary) -> Dictionary:
	return aura
