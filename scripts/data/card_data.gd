## CardData — one collectible card (spec 6.5).
##
## Effects are authored as ModifierData entries and scaled by the card level:
## level 1 is the authored value, every level adds 25 % of it (level 5 = x2.0).
## Cards never touch battle stats directly; CardService publishes one aggregated
## `&"cards"` source to ModifierService when the loadout changes.
class_name CardData
extends Resource

const DEFAULT_DIR := "res://data/cards/"
const RARITIES: Array[StringName] = [&"common", &"rare", &"epic", &"legendary"]
const MAX_LEVEL := 5
const LEVEL_STEP := 0.25

const RARITY_NAMES: Dictionary = {
	&"common": "Common",
	&"rare": "Rare",
	&"epic": "Epic",
	&"legendary": "Legendary",
}

const RARITY_COLORS: Dictionary = {
	&"common": Color(0.72, 0.78, 0.68, 1.0),
	&"rare": Color(0.45, 0.7, 1.0, 1.0),
	&"epic": Color(0.75, 0.5, 1.0, 1.0),
	&"legendary": Color(1.0, 0.78, 0.3, 1.0),
}

const FRAME_PATHS: Dictionary = {
	&"common": "res://assets/art/meta/cards/card_frame_common.png",
	&"rare": "res://assets/art/meta/cards/card_frame_rare.png",
	&"epic": "res://assets/art/meta/cards/card_frame_epic.png",
	&"legendary": "res://assets/art/meta/cards/card_frame_legendary.png",
}

const STAT_LABELS: Dictionary = {
	&"tree_max_hp": ["Tree max HP", "percent"],
	&"tree_regen": ["Tree regen", "per_second"],
	&"crit_chance": ["Crit chance", "pp"],
	&"crit_damage": ["Crit damage", "percent"],
	&"attack_speed": ["Attack speed", "percent"],
	&"coin_gain": ["Coins", "percent"],
	&"cash_gain": ["Cash from kills", "percent"],
	&"armor": ["Armor", "flat"],
	&"leak_damage_reduction": ["Leak damage reduction", "percent"],
	&"gem_chance": ["Gem chance on wave clear", "percent"],
	&"unit_slot_bonus": ["Unit slots", "flat"],
	&"tower_damage": ["Tower damage", "percent"],
	&"tower_range": ["Tower range", "percent"],
	&"enemies_per_wave": ["Enemies per wave", "percent"],
	&"tree_damage": ["All damage", "percent"],
	&"unit_damage": ["Unit damage", "percent"],
}

@export var id: StringName = &""
@export var name_key: String = ""
@export var name: String = ""
@export var rarity: StringName = &"common"
@export var description_key: String = ""
@export var description: String = ""
@export var art: Texture2D
## Shards needed to go from level 1->2, 2->3, 3->4, 4->5.
@export var shard_costs: Array[int] = [20, 40, 80, 160]
@export var effects: Array[ModifierData] = []
## Where the player can find duplicates (shown in the detail modal).
@export var where_to_get: String = "Wave clears, rewards and card packs"


## Loads every CardData in `dir_path`, ordered by rarity (legendary last) then id.
static func load_all(dir_path: String = DEFAULT_DIR) -> Array[CardData]:
	var cards: Array[CardData] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("CardData: cannot open '%s'" % dir_path)
		return cards
	var files: Array[String] = []
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir() and (file.ends_with(".tres") or file.ends_with(".res")):
			files.append(file)
		file = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for resource_file in files:
		var resource: Resource = load(dir_path + resource_file)
		if resource is CardData:
			cards.append(resource as CardData)
		else:
			push_warning("CardData: '%s' is not a CardData" % resource_file)
	cards.sort_custom(_sort_cards)
	return cards


static func _sort_cards(a: CardData, b: CardData) -> bool:
	var ra := RARITIES.find(a.rarity)
	var rb := RARITIES.find(b.rarity)
	if ra == rb:
		return String(a.id) < String(b.id)
	return ra < rb


## Effect multiplier for `level` (1 -> 1.0, 5 -> 2.0).
static func effect_scale(level: int) -> float:
	return 1.0 + LEVEL_STEP * float(clampi(level, 1, MAX_LEVEL) - 1)


## Shards needed to reach the next level, or 0 at max level.
func shard_cost(level: int) -> int:
	var safe_level := clampi(level, 1, MAX_LEVEL)
	if safe_level >= MAX_LEVEL or shard_costs.is_empty():
		return 0
	return shard_costs[mini(safe_level - 1, shard_costs.size() - 1)]


func frame_texture() -> Texture2D:
	var path := str(FRAME_PATHS.get(rarity, FRAME_PATHS[&"common"]))
	return load(path) as Texture2D


func rarity_label() -> String:
	return str(RARITY_NAMES.get(rarity, "Common"))


func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## One readable line for an effect at `level`, with the live scaled number.
func effect_line(effect: ModifierData, level: int) -> String:
	if effect == null:
		return ""
	var scale := effect_scale(level)
	var label_entry: Array = STAT_LABELS.get(effect.stat, [String(effect.stat).capitalize(), "percent"])
	var label := str(label_entry[0])
	var unit := str(label_entry[1])
	var value := 0.0
	var is_percent := false
	if not is_zero_approx(effect.add):
		value = effect.add * scale
	elif not is_zero_approx(effect.multiplier):
		value = effect.multiplier * scale
		is_percent = true
	match unit:
		"pp":
			return "%s %+d pp" % [label, int(round(value * 100.0))]
		"per_second":
			return "%s %+0.2f %%/s" % [label, value * 100.0]
		"flat":
			if is_equal_approx(value, roundf(value)):
				return "%s %+d" % [label, int(round(value))]
			return "%s %+0.1f" % [label, value]
		_:
			return "%s %+d %%" % [label, int(round(value * 100.0))]


## All effect lines for the detail modal.
func effect_lines(level: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for effect: ModifierData in effects:
		var line := effect_line(effect, level)
		if not line.is_empty():
			lines.append(line)
	return lines
