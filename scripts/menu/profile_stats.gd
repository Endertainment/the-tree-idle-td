## ProfileStats — pure aggregation for the profile screen (spec 13.12 + M5b).
##
## Keeps the formatting-free number crunching out of the screen so it can be
## tested without autoloads. `coins_earned` prefers the lifetime counter added in
## M5b and falls back to the current balance for saves created before it.
class_name ProfileStats
extends RefCounted

## Same spec 6.2 curve as LevelService; duplicated here so this aggregation stays
## free of autoload dependencies and can be unit-tested in isolation.
const BASE_XP := 120.0
const XP_GROWTH := 1.18


static func build(player: Dictionary, stats: Dictionary, wallet: Dictionary) -> Dictionary:
	var best_wave := maxi(int(stats.get("best_wave", 0)), int(player.get("best_wave", 0)))
	var coins_earned := int(stats.get("coins_earned", -1))
	if coins_earned < 0:
		coins_earned = maxi(int(wallet.get("coins", 0)), 0)
	var level := maxi(int(player.get("level", 1)), 1)
	var xp := maxi(int(player.get("xp", 0)), 0)
	var xp_required := xp_required_for(level)
	return {
		"best_wave": best_wave,
		"runs_played": maxi(int(stats.get("runs_played", 0)), 0),
		"total_kills": maxi(int(stats.get("total_kills", 0)), 0),
		"total_playtime": maxi(int(stats.get("total_playtime", 0)), 0),
		"coins_earned": maxi(coins_earned, 0),
		"level": level,
		"xp": xp,
		"xp_required": xp_required,
		"xp_ratio": clampf(float(xp) / float(maxi(xp_required, 1)), 0.0, 1.0),
	}


## XP required to move from `level` to `level + 1` (spec 6.2).
static func xp_required_for(level: int) -> int:
	return int(round(BASE_XP * pow(XP_GROWTH, float(maxi(level, 1) - 1))))


## Localised nickname fallback key is applied by the screen; this helper only
## decides when the saved nickname is unusable.
static func has_nickname(player: Dictionary) -> bool:
	return not str(player.get("nickname", "")).strip_edges().is_empty()
