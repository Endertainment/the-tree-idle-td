## LevelService — player XP, levels and the level-up signal (autoload).
##
## The curve is spec 6.2: xp_required(level) = round(120 * 1.18^(level-1)).
## Level and xp live on GameState.player (the save schema owns them). Adding xp
## may grant several levels at once; each level emits EventBus.level_up and asks
## UnlockService to publish newly available features.
extends Node

const MAX_LEVEL := 20
const BASE_XP := 120.0
const XP_GROWTH := 1.18


func _ready() -> void:
	init_service()


func init_service() -> void:
	var level := int(GameState.player.get("level", 1))
	GameState.player["level"] = clampi(level, 1, MAX_LEVEL)
	GameState.player["xp"] = maxi(int(GameState.player.get("xp", 0)), 0)


## XP required to move from `level` to `level + 1` (spec 6.2 curve).
static func xp_required_for(level: int) -> int:
	return int(round(BASE_XP * pow(XP_GROWTH, float(maxi(level, 1) - 1))))


func get_level() -> int:
	return int(GameState.player.get("level", 1))


func get_xp() -> int:
	return int(GameState.player.get("xp", 0))


func xp_required() -> int:
	return xp_required_for(get_level())


## XP left before the next level (0 at max level).
func xp_to_next() -> int:
	if get_level() >= MAX_LEVEL:
		return 0
	return maxi(xp_required() - get_xp(), 0)


## Adds xp and applies every level crossing. Returns the number of levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	GameState.player["xp"] = get_xp() + amount
	var gained := 0
	while get_level() < MAX_LEVEL and get_xp() >= xp_required_for(get_level()):
		GameState.player["xp"] = get_xp() - xp_required_for(get_level())
		GameState.player["level"] = get_level() + 1
		gained += 1
		EventBus.level_up.emit(get_level())
		UnlockService.on_level_up(get_level())
	if get_level() >= MAX_LEVEL:
		GameState.player["xp"] = mini(get_xp(), xp_required_for(MAX_LEVEL) - 1)
	if gained > 0:
		SaveService.request_save()
	return gained
