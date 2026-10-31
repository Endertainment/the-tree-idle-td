## CurveBuilder — turns authored lane points into a smooth Catmull-Rom curve.
##
## MapData stores only positions (spec 11.5). Control handles are derived from
## neighbours so every lane is C1-continuous: no corner snapping or jitter.
class_name CurveBuilder
extends RefCounted


## Builds a Curve2D through `points`, using the neighbouring points as tangents.
static func build(points: PackedVector2Array) -> Curve2D:
	var curve := Curve2D.new()
	var count := points.size()
	if count < 2:
		return curve
	for i in count:
		var previous := points[maxi(i - 1, 0)]
		var next := points[mini(i + 1, count - 1)]
		var tangent := (next - previous) / 6.0
		curve.add_point(points[i], -tangent, tangent)
	return curve
