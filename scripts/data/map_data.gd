## MapData — static geometry for one battle map.
##
## Owned by the battle scene. Lane points are authored in the 1080x1920 design
## space and converted to smooth Curve2D by CurveBuilder at runtime; pedestal and
## unit-slot anchors are absolute arena positions.
class_name MapData
extends Resource

@export var id: StringName = &""
@export var arena_size: Vector2 = Vector2(1080.0, 1920.0)
@export var background: Texture2D
@export var lane_north_points: PackedVector2Array = PackedVector2Array()
@export var lane_south_points: PackedVector2Array = PackedVector2Array()
@export var pedestal_positions: PackedVector2Array = PackedVector2Array()
@export var unit_slot_positions: PackedVector2Array = PackedVector2Array()


## Returns the authored points for a lane id (&"north" or &"south").
func get_lane_points(lane: StringName) -> PackedVector2Array:
	if lane == &"north":
		return lane_north_points
	if lane == &"south":
		return lane_south_points
	return PackedVector2Array()
