## UpgradeTrack — one purchasable in-run Tree upgrade line, authored as data.
##
## The upgrade panel is generated from a directory of these resources, so adding a
## new Tree stat is a `.tres` file plus one stat id in TreeUpgrades. Costs use the
## shared CostCurve; effects accumulate and may be capped (crit chance).
class_name UpgradeTrack
extends Resource

@export var id: StringName = &""
## Panel order; lower first. Ties fall back to the resource file name.
@export var order: int = 0
@export var name_key: String = ""
@export var name: String = ""
@export var description_key: String = ""
@export var description: String = ""
@export var icon: Texture2D
## Stat id consumed by TreeEntity (`damage`, `attack_speed`, `crit_chance`,
## `crit_damage`, `range`, `regen`). New tracks need one matching TreeEntity read.
@export var stat_id: StringName = &"damage"
## Absolute bonus per level as a fraction: 0.08 = +8 %, 0.02 = +2 percentage
## points (display only), 0.003 = +0.3 % max HP/s for regen.
@export var effect_per_level: float = 0.08
## Absolute cap in the same units; 0 means uncapped. Crit chance caps at 60 %.
@export var cap: float = 0.0
## Appended after the percentage in the preview (" pp" for chance points,
## " /s" for regen) so the row reads correctly without per-stat UI code.
@export var display_suffix: String = ""
@export var cost_base: int = 40
@export var cost_growth: float = 1.35
@export var max_level: int = 30


## Price of the next level when the track already has `current_level` levels.
## Level 0 costs `cost_base`; each purchase multiplies by `cost_growth`.
func cost_at(current_level: int) -> int:
	return CostCurve.cost_at(cost_base, cost_growth, maxi(current_level, 0) + 1)


## True when no further level can be bought (level cap or effect cap reached).
func is_maxed(current_level: int) -> bool:
	if current_level >= max_level:
		return true
	return cap > 0.0 and is_equal_approx(value_at(current_level), cap)


## Accumulated bonus at `level` (fraction, capped when `cap` is set).
func value_at(level: int) -> float:
	var raw := absf(effect_per_level) * float(maxi(level, 0))
	if cap > 0.0:
		raw = minf(raw, cap)
	return raw


## Bonus after one more level (never below the current value at the cap).
func next_value(current_level: int) -> float:
	return value_at(current_level + 1)


## How much the next level adds, for the green delta in the row.
func delta_at(current_level: int) -> float:
	return maxf(next_value(current_level) - value_at(current_level), 0.0)


## Human-readable preview value ("8%", "2 pp", "0.3% /s").
func format_value(value: float) -> String:
	var percent := value * 100.0
	var text: String
	if is_equal_approx(percent, roundf(percent)):
		text = str(int(roundf(percent)))
	else:
		text = "%.1f" % percent
	return "%s%%%s" % [text, display_suffix]
