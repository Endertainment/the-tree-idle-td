## Generates the M4b data resources: Magica nodes, cards and mission templates.
##
## Run headless after editing the tables below:
##   godot --headless --path . --script res://tools/generate_m4b_data.gd
##
## The generator is the source of truth for the initial content pass; designers can
## then tune the .tres files directly (the game loads the resources, not this tool).
extends SceneTree

const MAGICA_DIR := "res://data/magica/"
const CARDS_DIR := "res://data/cards/"
const MISSIONS_PATH := "res://data/missions/templates.tres"

const ICON_TIME := "res://assets/art/ui/icons/icon_clock.png"
const ICON_GEM := "res://assets/art/ui/icons/icon_gem.png"
const ICON_COIN := "res://assets/art/ui/icons/icon_coin.png"
const ICON_MAGIC := "res://assets/art/ui/icons/icon_magic.png"
const ICON_SWORD := "res://assets/art/ui/icons/icon_sword.png"
const ICON_HAMMER := "res://assets/art/ui/icons/icon_hammer.png"
const ICON_TROPHY := "res://assets/art/ui/icons/icon_trophy.png"
const ICON_STAR := "res://assets/art/ui/icons/icon_star.png"
const ICON_HEART := "res://assets/art/ui/icons/icon_heart.png"
const ICON_CARDS := "res://assets/art/ui/icons/icon_cards.png"
const ICON_AD := "res://assets/art/ui/icons/icon_ad.png"
const CARD_ART := "res://assets/art/meta/cards/card_art_placeholder.png"
const MISSION_ICON := "res://assets/art/meta/missions/mission_icon.png"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAGICA_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARDS_DIR))
	_generate_magica()
	_generate_cards()
	_generate_missions()
	quit(0)


# --- Magica ----------------------------------------------------------------------


func _generate_magica() -> void:
	# (id, branch, order, name, description, icon, requires, duration, coins, gems,
	#  effect_text, effects[(stat, add, mul)])
	var nodes: Array[Dictionary] = [
		# Time
		{"id": &"quickened_roots_1", "branch": &"time", "order": 0,
			"name": "Quickened Roots I", "desc": "The forest learns to think faster.",
			"icon": ICON_TIME, "requires": [], "duration": 1800, "coins": 200, "gems": 0,
			"text": "+10 % research speed",
			"effects": [["magica_speed", 0.0, 0.10]]},
		{"id": &"quickened_roots_2", "branch": &"time", "order": 1,
			"name": "Quickened Roots II", "desc": "Older roots remember older seasons.",
			"icon": ICON_TIME, "requires": [&"quickened_roots_1"], "duration": 7200, "coins": 900, "gems": 0,
			"text": "+10 % research speed",
			"effects": [["magica_speed", 0.0, 0.10]]},
		{"id": &"quickened_roots_3", "branch": &"time", "order": 2,
			"name": "Quickened Roots III", "desc": "Time bends around the canopy.",
			"icon": ICON_TIME, "requires": [&"quickened_roots_2"], "duration": 28800, "coins": 3000, "gems": 0,
			"text": "+10 % research speed",
			"effects": [["magica_speed", 0.0, 0.10]]},
		{"id": &"flow_of_ages", "branch": &"time", "order": 3,
			"name": "Flow of Ages", "desc": "A fourth pace for the battle clock.",
			"icon": ICON_TIME, "requires": [&"quickened_roots_1"], "duration": 14400, "coins": 1200, "gems": 0,
			"text": "Battle speed option +0.25x",
			"effects": [["battle_speed_extra", 0.25, 0.0]]},
		{"id": &"auto_restart", "branch": &"time", "order": 4,
			"name": "Auto-Restart", "desc": "The forest regrows the moment a run ends.",
			"icon": ICON_GEM, "requires": [&"flow_of_ages"], "duration": 43200, "coins": 0, "gems": 15,
			"text": "Auto-start the next run after the summary",
			"effects": [["auto_restart", 1.0, 0.0]]},
		# Wealth
		{"id": &"golden_sap_1", "branch": &"wealth", "order": 0,
			"name": "Golden Sap I", "desc": "Sweet sap, heavier purse.",
			"icon": ICON_COIN, "requires": [], "duration": 2700, "coins": 250, "gems": 0,
			"text": "+10 % coins from waves",
			"effects": [["coin_gain", 0.0, 0.10]]},
		{"id": &"golden_sap_2", "branch": &"wealth", "order": 1,
			"name": "Golden Sap II", "desc": "The sap runs in richer veins.",
			"icon": ICON_COIN, "requires": [&"golden_sap_1"], "duration": 10800, "coins": 1000, "gems": 0,
			"text": "+10 % coins from waves",
			"effects": [["coin_gain", 0.0, 0.10]]},
		{"id": &"golden_sap_3", "branch": &"wealth", "order": 2,
			"name": "Golden Sap III", "desc": "A season of gold.",
			"icon": ICON_COIN, "requires": [&"golden_sap_2"], "duration": 36000, "coins": 3500, "gems": 0,
			"text": "+10 % coins from waves",
			"effects": [["coin_gain", 0.0, 0.10]]},
		{"id": &"night_harvest", "branch": &"wealth", "order": 3,
			"name": "Night Harvest", "desc": "The forest works while you sleep.",
			"icon": ICON_TIME, "requires": [&"golden_sap_1"], "duration": 21600, "coins": 2000, "gems": 20,
			"text": "+100 % offline income",
			"effects": [["offline_coin_rate", 0.0, 1.0]]},
		{"id": &"merchant_favor", "branch": &"wealth", "order": 4,
			"name": "Merchant's Favor", "desc": "Old debts become old discounts.",
			"icon": ICON_COIN, "requires": [&"golden_sap_1"], "duration": 7200, "coins": 800, "gems": 0,
			"text": "Shop prices -5 %, in-run upgrades -5 %",
			"effects": [["in_run_discount", 0.05, 0.0], ["shop_discount", 0.05, 0.0]]},
		# Knowledge
		{"id": &"fourth_branch", "branch": &"knowledge", "order": 0,
			"name": "Fourth Branch", "desc": "One more canopy for a guardian.",
			"icon": ICON_GEM, "requires": [], "duration": 28800, "coins": 0, "gems": 25,
			"text": "Unit slot 3",
			"effects": [["unit_slot_bonus", 1.0, 0.0]]},
		{"id": &"deep_roots", "branch": &"knowledge", "order": 1,
			"name": "Deep Roots", "desc": "Room for one more card in the loadout.",
			"icon": ICON_CARDS, "requires": [&"fourth_branch"], "duration": 18000, "coins": 1500, "gems": 0,
			"text": "+1 card slot",
			"effects": [["card_slot_bonus", 1.0, 0.0]]},
		{"id": &"ancient_memory", "branch": &"knowledge", "order": 2,
			"name": "Ancient Memory", "desc": "The forest remembers its first archer.",
			"icon": ICON_SWORD, "requires": [], "duration": 10800, "coins": 1000, "gems": 0,
			"text": "Start each run with a free Archer Tower",
			"effects": [["free_archer_voucher", 1.0, 0.0]]},
		{"id": &"second_wind", "branch": &"knowledge", "order": 3,
			"name": "Second Wind", "desc": "Once per run, the Tree refuses to fall.",
			"icon": ICON_HEART, "requires": [&"ancient_memory"], "duration": 64800, "coins": 0, "gems": 40,
			"text": "Once per run: survive a lethal hit at 15 % HP",
			"effects": [["second_wind", 1.0, 0.0]]},
	]
	for row: Dictionary in nodes:
		var node := MagicaNode.new()
		node.id = row["id"]
		node.branch = row["branch"]
		node.order = int(row["order"])
		node.name_key = "magica.%s" % row["id"]
		node.name = str(row["name"])
		node.description_key = "magica.%s_desc" % row["id"]
		node.description = str(row["desc"])
		node.icon = load(str(row["icon"])) as Texture2D
		var requirements: Array[StringName] = []
		for requirement: Variant in row["requires"]:
			requirements.append(StringName(str(requirement)))
		node.requires = requirements
		node.duration_seconds = int(row["duration"])
		node.coin_cost = int(row["coins"])
		node.gem_cost = int(row["gems"])
		node.effect_text = str(row["text"])
		var effects: Array[ModifierData] = []
		for effect_row: Array in row["effects"]:
			effects.append(_effect(str(effect_row[0]), float(effect_row[1]), float(effect_row[2])))
		node.effects = effects
		var path := "%s%s.tres" % [MAGICA_DIR, row["id"]]
		var error := ResourceSaver.save(node, path)
		if error != OK:
			push_error("could not save %s (%d)" % [path, error])
	print("[data] magica nodes: %d" % nodes.size())


# --- Cards -----------------------------------------------------------------------


func _generate_cards() -> void:
	# (id, name, rarity, description, where_to_get, effects[(stat, add, mul)])
	var cards: Array[Dictionary] = [
		{"id": &"greed", "name": "Greed", "rarity": &"common",
			"desc": "More enemies, more pockets to empty.",
			"get": "Wave clears and card packs",
			"effects": [["enemies_per_wave", 0.0, 0.25], ["cash_gain", 0.0, 0.20]]},
		{"id": &"vital_roots", "name": "Vital Roots", "rarity": &"common",
			"desc": "The trunk drinks deeper.",
			"get": "Wave clears and card packs",
			"effects": [["tree_max_hp", 0.0, 0.15]]},
		{"id": &"regrowth", "name": "Regrowth", "rarity": &"rare",
			"desc": "Bark knits itself closed.",
			"get": "Rare card packs and weekly bonuses",
			"effects": [["tree_regen", 0.0035, 0.0]]},
		{"id": &"sharpened_tips", "name": "Sharpened Tips", "rarity": &"rare",
			"desc": "Every branch ends in a point.",
			"get": "Rare card packs and weekly bonuses",
			"effects": [["crit_chance", 0.08, 0.0]]},
		{"id": &"heavy_bolts", "name": "Heavy Bolts", "rarity": &"rare",
			"desc": "Slow to load, terrible to meet.",
			"get": "Rare card packs and weekly bonuses",
			"effects": [["crit_damage", 0.0, 0.30]]},
		{"id": &"swift_winds", "name": "Swift Winds", "rarity": &"epic",
			"desc": "The canopy never stops moving.",
			"get": "Epic card packs and the weekly bonus",
			"effects": [["attack_speed", 0.0, 0.15]]},
		{"id": &"rich_soil", "name": "Rich Soil", "rarity": &"common",
			"desc": "Everything grows a little more valuable.",
			"get": "Wave clears and card packs",
			"effects": [["coin_gain", 0.0, 0.10]]},
		{"id": &"bark_shield", "name": "Bark Shield", "rarity": &"rare",
			"desc": "A second skin of ironwood.",
			"get": "Rare card packs and weekly bonuses",
			"effects": [["armor", 3.0, 0.0], ["leak_damage_reduction", 0.20, 0.0]]},
		{"id": &"lucky_clover", "name": "Lucky Clover", "rarity": &"epic",
			"desc": "Gems hide between the roots.",
			"get": "Epic card packs and the weekly bonus",
			"effects": [["gem_chance", 0.10, 0.0]]},
		{"id": &"guardian_bond", "name": "Guardian Bond", "rarity": &"epic",
			"desc": "One more guardian answers the call.",
			"get": "Epic card packs and the weekly bonus",
			"effects": [["unit_slot_bonus", 1.0, 0.0]]},
		{"id": &"overgrowth", "name": "Overgrowth", "rarity": &"rare",
			"desc": "Towers grow into the canopy.",
			"get": "Rare card packs and weekly bonuses",
			"effects": [["tower_damage", 0.0, 0.12], ["tower_range", 0.0, 0.08]]},
		{"id": &"ancient_pact", "name": "Ancient Pact", "rarity": &"legendary",
			"desc": "Power borrowed from the old forest, paid in bark.",
			"get": "Legendary packs and the weekly completion bonus",
			"effects": [
				["tree_damage", 0.0, 0.25], ["tower_damage", 0.0, 0.25],
				["unit_damage", 0.0, 0.25], ["tree_max_hp", 0.0, -0.10],
			]},
	]
	var art := load(CARD_ART) as Texture2D
	for row: Dictionary in cards:
		var card := CardData.new()
		card.id = row["id"]
		card.name_key = "card.%s" % row["id"]
		card.name = str(row["name"])
		card.rarity = row["rarity"]
		card.description_key = "card.%s_desc" % row["id"]
		card.description = str(row["desc"])
		card.art = art
		card.where_to_get = str(row["get"])
		var effects: Array[ModifierData] = []
		for effect_row: Array in row["effects"]:
			effects.append(_effect(str(effect_row[0]), float(effect_row[1]), float(effect_row[2])))
		card.effects = effects
		var path := "%s%s.tres" % [CARDS_DIR, row["id"]]
		var error := ResourceSaver.save(card, path)
		if error != OK:
			push_error("could not save %s (%d)" % [path, error])
	print("[data] cards: %d" % cards.size())


# --- Missions --------------------------------------------------------------------


func _generate_missions() -> void:
	var table := MissionTemplateTable.new()
	var templates: Array[MissionTemplate] = []

	templates.append(_mission(&"d_waves", &"daily", 0, "Clear {n} waves", "waves_cleared", &"add", 8, 25, 0, 20, ICON_SWORD))
	templates.append(_mission(&"d_kills", &"daily", 1, "Kill {n} enemies", "kills", &"add", 60, 30, 0, 20, ICON_SWORD))
	templates.append(_mission(&"d_towers", &"daily", 2, "Build {n} towers in one run", "towers_built", &"max", 4, 30, 0, 20, ICON_HAMMER))
	templates.append(_mission(&"d_reach", &"daily", 3, "Reach wave {n}", "wave_reached", &"max", 7, 35, 0, 25, ICON_TROPHY))
	templates.append(_mission(&"d_crits", &"daily", 4, "Deal {n} critical hits", "crits", &"add", 15, 25, 0, 20, ICON_STAR))
	templates.append(_mission(&"d_clean", &"daily", 5, "Clear a run without leaking", "clean_runs", &"add", 1, 40, 1, 25, ICON_HEART))

	templates.append(_mission(&"w_waves", &"weekly", 0, "Clear {n} waves", "waves_cleared", &"add", 60, 150, 3, 150, ICON_SWORD))
	templates.append(_mission(&"w_kills", &"weekly", 1, "Kill {n} enemies", "kills", &"add", 500, 180, 3, 150, ICON_SWORD))
	templates.append(_mission(&"w_reach", &"weekly", 2, "Reach wave {n}", "wave_reached", &"max", 12, 200, 4, 200, ICON_TROPHY))
	templates.append(_mission(&"w_towers", &"weekly", 3, "Build {n} towers in one run", "towers_built", &"max", 8, 160, 0, 120, ICON_HAMMER))
	templates.append(_mission(&"w_cards", &"weekly", 4, "Equip {n} cards at once", "cards_equipped", &"max", 3, 160, 2, 120, ICON_CARDS))
	templates.append(_mission(&"w_ads", &"weekly", 5, "Watch {n} rewarded ads", "ads_watched", &"add", 3, 120, 2, 100, ICON_AD))
	templates.append(_mission(&"w_clean", &"weekly", 6, "Clear {n} runs without leaking", "clean_runs", &"add", 2, 180, 3, 150, ICON_HEART))

	table.templates = templates
	var error := ResourceSaver.save(table, MISSIONS_PATH)
	if error != OK:
		push_error("could not save %s (%d)" % [MISSIONS_PATH, error])
	print("[data] mission templates: %d" % templates.size())


func _mission(
	id: StringName,
	period: StringName,
	order: int,
	title: String,
	metric: StringName,
	mode: StringName,
	target: int,
	coins: int,
	gems: int,
	xp: int,
	icon_path: String
) -> MissionTemplate:
	var template := MissionTemplate.new()
	template.id = id
	template.period = period
	template.order = order
	template.title_key = "mission.%s" % id
	template.title = title
	template.description_key = "mission.%s_desc" % id
	template.description = title
	template.metric = metric
	template.mode = mode
	template.base_target = target
	template.base_coins = coins
	template.base_gems = gems
	template.base_xp = xp
	template.icon = load(icon_path) as Texture2D
	return template


func _effect(stat: String, add: float, multiplier: float) -> ModifierData:
	var effect := ModifierData.new()
	effect.stat = StringName(stat)
	effect.add = add
	effect.multiplier = multiplier
	return effect
