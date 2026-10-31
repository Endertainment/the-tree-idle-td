## BattleArena — constructs the static map: background, lanes, road visuals and
## the eight pedestals. Extracted from BattleController so the controller keeps
## state/flow only; the arena owns no gameplay state beyond node references.
class_name BattleArena
extends RefCounted

var lane_north: Path2D
var lane_south: Path2D
var pedestals: Array[Pedestal] = []


## Builds the arena into the already-instantiated scene roots.
func build(
	map: MapData,
	background: Sprite2D,
	lanes_root: Node2D,
	pedestals_root: Node2D,
	pedestal_scene: PackedScene,
	on_pedestal_pressed: Callable
) -> void:
	background.texture = map.background
	background.position = map.arena_size * 0.5
	lane_north = _create_lane(&"LaneNorth", map.lane_north_points, lanes_root)
	lane_south = _create_lane(&"LaneSouth", map.lane_south_points, lanes_root)
	for index in map.pedestal_positions.size():
		var pedestal := pedestal_scene.instantiate() as Pedestal
		pedestals_root.add_child(pedestal)
		pedestal.position = map.pedestal_positions[index]
		pedestal.setup(index)
		pedestal.pressed.connect(on_pedestal_pressed)
		pedestals.append(pedestal)


func get_pedestal(index: int) -> Pedestal:
	if index < 0 or index >= pedestals.size():
		return null
	return pedestals[index]


func _create_lane(lane_name: StringName, points: PackedVector2Array, root: Node2D) -> Path2D:
	var lane := Path2D.new()
	lane.name = lane_name
	lane.curve = CurveBuilder.build(points)
	root.add_child(lane)
	_add_lane_visual(String(lane_name), lane.curve, root)
	return lane


## Path2D only draws its curve in the editor, so the playable lane gets an
## explicit Line2D sampled from the same curve (ADR-006).
func _add_lane_visual(lane_name: String, curve: Curve2D, root: Node2D) -> void:
	var road := Line2D.new()
	road.name = lane_name + "Road"
	road.width = 84.0
	road.default_color = Color(0.42, 0.32, 0.20, 0.85)
	road.joint_mode = Line2D.LINE_JOINT_ROUND
	road.begin_cap_mode = Line2D.LINE_CAP_ROUND
	road.end_cap_mode = Line2D.LINE_CAP_ROUND
	road.antialiased = true
	road.z_index = -5
	var length := curve.get_baked_length()
	var steps := maxi(int(length / 24.0), 2)
	for i in steps + 1:
		road.add_point(curve.sample_baked(length * float(i) / float(steps), true))
	root.add_child(road)
