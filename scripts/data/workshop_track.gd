## WorkshopTrack — one permanent meta upgrade line bought with coins (spec 6.3).
##
## Authored as data in `res://data/workshop/`: the screen, the cost curve and the
## modifier entries are all generated from these resources. `op` declares how the
## level total reaches ModifierService: `add` is a flat/percentage-point addition
## to the base stat, `mul` is a fraction applied as (1 + total) to the base.
class_name WorkshopTrack
extends Resource

const COST_ROUNDING := 5

@export var id: StringName = &""
## Attack | Defense | Utility | Environment (lowercase ids used by the tabs).
@export var category: StringName = &"attack"
## Panel order inside the category; ties fall back to id.
@export var order: int = 0
@export var name_key: String = ""
@export var name: String = ""
@export var description_key: String = ""
@export var description: String = ""
@export var icon: Texture2D
## ModifierService stat id consumed by the battle (`tree_damage`, `starting_cash`...).
@export var stat: StringName = &"tree_damage"
## "add" or "mul" (see the class comment).
@export var op: StringName = &"mul"
## Absolute effect per level: 0.04 = +4 %, 0.004 = +0.4 pp, 6.0 = +6 cash.
@export var effect_per_level: float = 0.04
## Cap on the accumulated total; 0 means uncapped (spec caps crit, reduction...).
@export var cap: float = 0.0
@export var base_cost: int = 50
@export var cost_growth: float = 1.18
@export var max_level: int = 50
## Display unit: percent | pp | flat | minutes | gems_per_day | shield.
@export var display_unit: StringName = &"percent"
@export var display_suffix: String = ""


## Next-level price: base_cost * 1.18^level, rounded to 5 (spec 6.3).
func cost_at(current_level: int) -> int:
	var raw := float(base_cost) * pow(cost_growth, float(maxi(current_level, 0)))
	return maxi(COST_ROUNDING, int(round(raw / float(COST_ROUNDING))) * COST_ROUNDING)


## Accumulated effect at `level`, capped when `cap` is set.
func total_at(level: int) -> float:
	var raw := absf(effect_per_level) * float(maxi(level, 0))
	if cap > 0.0:
		raw = minf(raw, cap)
	return raw


func next_total(current_level: int) -> float:
	return total_at(current_level + 1)


func delta_at(current_level: int) -> float:
	return maxf(next_total(current_level) - total_at(current_level), 0.0)


## True when no further level can be bought (level or effect cap reached).
func is_maxed(current_level: int) -> bool:
	if current_level >= max_level:
		return true
	return cap > 0.0 and total_at(current_level) >= cap


## ModifierService entry for the accumulated effect (`{op: total}`); empty when 0.
func modifier_entry(level: int) -> Dictionary:
	var total := total_at(level)
	if total <= 0.0:
		return {}
	return {String(op): total}


## Human-readable accumulated value ("40%", "4 pp", "60 cash", "20 min").
func format_total(level: int) -> String:
	var total := total_at(level)
	match display_unit:
		&"pp":
			return "%s pp" % _trim(total * 100.0)
		&"flat":
			return "%d%s" % [int(roundf(total)), display_suffix]
		&"minutes":
			return "%d min" % int(roundf(total))
		&"gems_per_day":
			return "%s /day" % _trim(total)
		&"shield":
			return "%d HP" % int(roundf(total))
		_:
			return "%s%%%s" % [_trim(total * 100.0), display_suffix]


func _trim(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
