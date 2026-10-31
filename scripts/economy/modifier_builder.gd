## ModifierBuilder — merges ModifierData effect lists into one source dictionary.
##
## ModifierService applies `(base + sum(add)) * (1 + sum(mul))` per source, so a
## source that touches the same stat twice must sum its add/mul parts before it is
## registered. Cards, magica nodes and any future effect list use this helper, which
## keeps the aggregation rule in one place.
class_name ModifierBuilder
extends RefCounted


## Adds one effect to `entries`, scaled by `scale` (card level multiplier).
static func add_effect(entries: Dictionary, effect: ModifierData, scale: float = 1.0) -> void:
	if effect == null:
		return
	var stat := String(effect.stat)
	if stat.is_empty():
		return
	if not entries.has(stat):
		entries[stat] = {}
	var entry: Dictionary = entries[stat]
	if not is_zero_approx(effect.add):
		entry["add"] = float(entry.get("add", 0.0)) + effect.add * scale
	if not is_zero_approx(effect.multiplier):
		entry["mul"] = float(entry.get("mul", 0.0)) + effect.multiplier * scale


## Builds a ModifierService source dictionary from an effect list.
static func entries_from(effects: Array[ModifierData], scale: float = 1.0) -> Dictionary:
	var entries: Dictionary = {}
	for effect: ModifierData in effects:
		add_effect(entries, effect, scale)
	return entries
