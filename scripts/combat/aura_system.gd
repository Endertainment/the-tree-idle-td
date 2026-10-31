## AuraSystem — applies shaman speed auras and totem tower/Tree buffs.
##
## Runs at a fixed 10 Hz from BattleController instead of every frame: auras only
## need to be visually current, and both loops walk owned arrays (never the scene
## tree). Tower/Tree buffs are additive fractions and are reset each pass, so
## selling a totem instantly removes its buff.
class_name AuraSystem
extends RefCounted


## Recomputes every aura. `enemies`, `towers` are the live owned arrays.
func apply(enemies: Array[Enemy], towers: Array[Tower], tree: TreeEntity) -> void:
	for tower in towers:
		if is_instance_valid(tower):
			tower.set_external_buffs(0.0, 0.0)
	if tree != null and is_instance_valid(tree):
		tree.set_external_buffs(0.0, 0.0)

	for source in towers:
		if not is_instance_valid(source) or not source.is_aura_tower():
			continue
		var aura := source.aura_values()
		var radius := float(aura["radius"])
		for target in towers:
			if target == source or not is_instance_valid(target):
				continue
			if source.global_position.distance_to(target.global_position) <= radius:
				target.add_external_buff(float(aura["damage"]), float(aura["speed"]))
		if tree != null and is_instance_valid(tree):
			if source.global_position.distance_to(tree.global_position) <= radius:
				tree.add_external_buff(float(aura["damage"]), float(aura["speed"]))

	_apply_enemy_auras(enemies)


func _apply_enemy_auras(enemies: Array[Enemy]) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			enemy.set_aura_speed_multiplier(1.0)

	for source in enemies:
		if not is_instance_valid(source) or not source.is_alive():
			continue
		if source.data == null or source.data.aura == null:
			continue
		var aura := source.data.aura
		for enemy in enemies:
			if enemy == source or not is_instance_valid(enemy) or not enemy.is_alive():
				continue
			if source.global_position.distance_to(enemy.global_position) <= aura.radius:
				enemy.set_aura_speed_multiplier(
					maxf(enemy.get_aura_speed_multiplier(), aura.speed_multiplier)
				)
