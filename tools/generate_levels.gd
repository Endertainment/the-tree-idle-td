## Level unlock table generator — writes data/progression/levels.tres (spec 6.2).
##
## Run: godot --headless --path . --script res://tools/generate_levels.gd
## The generated resource is committed and is the source of truth for level gates.
extends SceneTree

const OUTPUT_PATH := "res://data/progression/levels.tres"

## level -> unlock ids from the spec table (levels without unlocks are omitted).
const TABLE := {
	1: ["battle", "workshop", "settings"],
	2: ["cards", "card_slot_1"],
	3: ["magica", "speed_1_5"],
	4: ["unit_slot_2", "missions"],
	5: ["card_slot_2", "shop"],
	6: ["leaderboard"],
	8: ["tower_specialization"],
	10: ["speed_2", "unit_slot_3"],
	12: ["unit_slot_4", "tournament"],
	15: ["card_slot_3"],
	20: ["card_slot_4", "prestige"],
}


func _initialize() -> void:
	var progression := LevelProgression.new()
	progression.max_level = 20
	for level: int in TABLE.keys():
		progression.unlock_levels[level] = TABLE[level]
	var error := ResourceSaver.save(progression, OUTPUT_PATH)
	if error != OK:
		push_error("generate_levels: could not save %s (error %d)" % [OUTPUT_PATH, error])
		quit(1)
		return
	print("[levels] wrote %d unlock levels to %s" % [TABLE.size(), OUTPUT_PATH])
	quit(0)
