## MagicaNode — one research node in the Time/Wealth/Knowledge tree (spec 6.4).
##
## Authored as data under `res://data/magica/`: the screen, the prerequisite graph
## and the ModifierService entries are generated from these resources. Durations are
## real-time seconds; the service converts them with the current research speed and
## stores UTC unix timestamps so research finishes while the app is closed.
class_name MagicaNode
extends Resource

const DEFAULT_DIR := "res://data/magica/"
const BRANCHES: Array[StringName] = [&"time", &"wealth", &"knowledge"]

@export var id: StringName = &""
## time | wealth | knowledge
@export var branch: StringName = &"time"
@export var order: int = 0
@export var name_key: String = ""
@export var name: String = ""
@export var description_key: String = ""
@export var description: String = ""
@export var icon: Texture2D
## Node ids that must already be completed before this one can start.
@export var requires: Array[StringName] = []
@export var duration_seconds: int = 1800
@export var coin_cost: int = 0
@export var gem_cost: int = 0
## ModifierData entries published to ModifierService when completed.
@export var effects: Array[ModifierData] = []
## Authored summary of the effect ("+10 % research speed").
@export var effect_text: String = ""


## Loads every MagicaNode in `dir_path`, ordered by branch then order/id.
static func load_all(dir_path: String = DEFAULT_DIR) -> Array[MagicaNode]:
	var nodes: Array[MagicaNode] = []
	var files := ResourceDir.list(dir_path)
	if files.is_empty():
		push_error("No resources found in %s (exported builds use .remap)" % dir_path)
		return nodes
	files.sort()
	for resource_file in files:
		var resource: Resource = load(resource_file)
		if resource is MagicaNode:
			nodes.append(resource as MagicaNode)
		else:
			push_warning("MagicaNode: '%s' is not a MagicaNode" % resource_file)
	nodes.sort_custom(_sort_nodes)
	return nodes


static func _sort_nodes(a: MagicaNode, b: MagicaNode) -> bool:
	if a.branch == b.branch:
		if a.order == b.order:
			return String(a.id) < String(b.id)
		return a.order < b.order
	return BRANCHES.find(a.branch) < BRANCHES.find(b.branch)


## True when the node has a nonzero coin or gem price.
func has_cost() -> bool:
	return coin_cost > 0 or gem_cost > 0


## Human-readable duration ("30m", "2h", "18h").
func duration_text() -> String:
	if duration_seconds >= 3600:
		var hours := duration_seconds / 3600
		var minutes := (duration_seconds % 3600) / 60
		return "%dh %dm" % [hours, minutes] if minutes > 0 else "%dh" % hours
	return "%dm" % maxi(duration_seconds / 60, 1)


## Cost summary ("200 coins", "15 gems", "2 000 coins + 20 gems").
func cost_text() -> String:
	var parts: PackedStringArray = []
	if coin_cost > 0:
		parts.append("%d coins" % coin_cost)
	if gem_cost > 0:
		parts.append("%d gems" % gem_cost)
	return " + ".join(parts)
