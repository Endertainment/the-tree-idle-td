## M1 layout validator — proves lanes keep clearance from the pedestal ring.
##
## Run: godot --headless --path . --script res://tools/validate_layout.gd
## Exit 0 when every lane centreline stays >= MIN_CLEARANCE px from every
## pedestal centre and all authored anchors are inside the arena.
extends SceneTree

const MAP_PATH := "res://data/maps/forest_clearing.tres"
const MIN_CLEARANCE := 110.0
const SAMPLE_STEP := 4.0

var _failures: int = 0


func _initialize() -> void:
	var map := load(MAP_PATH) as MapData
	if map == null:
		_fail("map resource does not load: %s" % MAP_PATH)
		_finish()
		return
	if map.pedestal_positions.size() != 8:
		_fail("expected 8 pedestals, found %d" % map.pedestal_positions.size())
	if map.unit_slot_positions.size() != 4:
		_fail("expected 4 unit slots, found %d" % map.unit_slot_positions.size())

	_validate_lane(&"north", map.lane_north_points, map)
	_validate_lane(&"south", map.lane_south_points, map)
	_validate_points("pedestal", map.pedestal_positions, map.arena_size)
	_validate_points("unit slot", map.unit_slot_positions, map.arena_size)
	_finish()


func _validate_lane(lane: StringName, points: PackedVector2Array, map: MapData) -> void:
	if points.size() < 6 or points.size() > 8:
		_fail("%s lane has %d points, expected 6..8" % [lane, points.size()])
	var curve := CurveBuilder.build(points)
	var length := curve.get_baked_length()
	var samples := maxi(int(length / SAMPLE_STEP), 1)
	var worst := INF
	var worst_at := Vector2.ZERO
	for i in samples + 1:
		var point := curve.sample_baked(length * float(i) / float(samples), true)
		for pedestal in map.pedestal_positions:
			var distance := point.distance_to(pedestal)
			if distance < worst:
				worst = distance
				worst_at = point
	if worst < MIN_CLEARANCE:
		_fail("%s lane clearance %.1f px at %s (minimum %.0f)" % [lane, worst, worst_at, MIN_CLEARANCE])
	else:
		_pass("%s lane length %.0f px, worst pedestal clearance %.1f px" % [lane, length, worst])


func _validate_points(label: String, points: PackedVector2Array, arena: Vector2) -> void:
	var rect := Rect2(Vector2.ZERO, arena)
	for point in points:
		if not rect.has_point(point):
			_fail("%s %s is outside the arena" % [label, point])
	_pass("%d %s anchors inside the arena" % [points.size(), label])


func _pass(message: String) -> void:
	print("[ PASS ] ", message)


func _fail(message: String) -> void:
	_failures += 1
	print("[ FAIL ] ", message)


func _finish() -> void:
	print("== layout validation: %s ==" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
