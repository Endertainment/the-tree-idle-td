## Workshop track generator — writes the 24 spec 6.3 tracks as .tres resources.
##
## Run: godot --headless --path . --script res://tools/generate_workshop_tracks.gd
## The generated resources are committed and are the source of truth; the engine
## reads only the .tres. Idempotent: it overwrites the output files.
extends SceneTree

const OUTPUT_DIR := "res://data/workshop/"
const ICON_DIR := "res://assets/art/ui/icons/"

## id, category, order, stat, op, effect, cap, base_cost, unit, icon, display suffix
const TRACKS := [
	# Attack
	["tree_damage", "attack", 1, "tree_damage", "mul", 0.04, 0.0, 50, "percent", "icon_sword.png", ""],
	["unit_damage", "attack", 2, "unit_damage", "mul", 0.04, 0.0, 60, "percent", "icon_sword.png", ""],
	["tower_damage", "attack", 3, "tower_damage", "mul", 0.04, 0.0, 70, "percent", "icon_sword.png", ""],
	["crit_chance", "attack", 4, "crit_chance", "add", 0.004, 0.25, 80, "pp", "icon_star.png", ""],
	["crit_damage", "attack", 5, "crit_damage", "mul", 0.05, 0.0, 80, "percent", "icon_star.png", ""],
	["attack_speed", "attack", 6, "attack_speed", "mul", 0.015, 0.0, 120, "percent", "icon_speed.png", ""],
	# Defense
	["tree_max_hp", "defense", 1, "tree_max_hp", "mul", 0.05, 0.0, 50, "percent", "icon_heart.png", ""],
	["tree_regen", "defense", 2, "tree_regen", "add", 0.0004, 0.0, 90, "pp", "icon_heart.png", " /s"],
	["damage_reduction", "defense", 3, "damage_reduction", "add", 0.005, 0.6, 100, "percent", "icon_shield.png", ""],
	["starting_cash", "defense", 4, "starting_cash", "add", 6.0, 0.0, 70, "flat", "icon_cash.png", ""],
	["start_shield", "defense", 5, "start_shield", "add", 40.0, 0.0, 150, "shield", "icon_shield.png", ""],
	["leak_damage_reduction", "defense", 6, "leak_damage_reduction", "add", 0.005, 0.4, 140, "percent", "icon_shield.png", ""],
	# Utility
	["cash_gain", "utility", 1, "cash_gain", "mul", 0.03, 0.0, 60, "percent", "icon_cash.png", ""],
	["coin_gain", "utility", 2, "coin_gain", "mul", 0.03, 0.0, 90, "percent", "icon_coin.png", ""],
	["xp_gain", "utility", 3, "xp_gain", "mul", 0.03, 0.0, 80, "percent", "icon_star.png", ""],
	["in_run_discount", "utility", 4, "in_run_discount", "add", 0.008, 0.4, 110, "percent", "icon_shop.png", ""],
	["wave_clear_bonus", "utility", 5, "wave_clear_bonus", "add", 4.0, 0.0, 75, "flat", "icon_reward.png", ""],
	["offline_cap_minutes", "utility", 6, "offline_cap_minutes", "add", 20.0, 0.0, 120, "minutes", "icon_clock.png", ""],
	# Environment
	["offline_coin_rate", "environment", 1, "offline_coin_rate", "mul", 0.05, 0.0, 100, "percent", "icon_clock.png", ""],
	["ad_reward_bonus", "environment", 2, "ad_reward_bonus", "mul", 0.04, 0.0, 90, "percent", "icon_ad.png", ""],
	["mission_reward_bonus", "environment", 3, "mission_reward_bonus", "mul", 0.04, 0.0, 90, "percent", "icon_calendar.png", ""],
	["magica_speed", "environment", 4, "magica_speed", "mul", 0.02, 0.0, 130, "percent", "icon_magic.png", ""],
	["free_daily_gems", "environment", 5, "free_daily_gems", "add", 0.1, 5.0, 200, "gems_per_day", "icon_gem.png", ""],
	["card_drop_chance", "environment", 6, "card_drop_chance", "add", 0.005, 0.15, 160, "percent", "icon_cards.png", ""],
]


func _initialize() -> void:
	var dir := DirAccess.open(OUTPUT_DIR)
	if dir == null:
		push_error("generate_workshop_tracks: cannot open %s" % OUTPUT_DIR)
		quit(1)
		return

	for entry: Array in TRACKS:
		var track := WorkshopTrack.new()
		track.id = StringName(entry[0])
		track.category = StringName(entry[1])
		track.order = int(entry[2])
		track.stat = StringName(entry[3])
		track.op = StringName(entry[4])
		track.effect_per_level = float(entry[5])
		track.cap = float(entry[6])
		track.base_cost = int(entry[7])
		track.display_unit = StringName(entry[8])
		track.icon = load(ICON_DIR + str(entry[9])) as Texture2D
		track.display_suffix = str(entry[10])
		track.name_key = "workshop.%s" % track.id
		track.name = _title(track.id)
		track.description_key = "workshop.%s_desc" % track.id
		track.description = _title(track.id)
		var error := ResourceSaver.save(track, "%s%s.tres" % [OUTPUT_DIR, track.id])
		if error != OK:
			push_error("generate_workshop_tracks: could not save %s (error %d)" % [track.id, error])
			quit(1)
			return
	print("[workshop] wrote %d tracks to %s" % [TRACKS.size(), OUTPUT_DIR])
	quit(0)


func _title(id: StringName) -> String:
	var words := String(id).split("_")
	var parts: PackedStringArray = []
	for word: String in words:
		parts.append(word.capitalize())
	return " ".join(parts)
