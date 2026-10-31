## RangeIndicator — circle drawn under a selected tower while its sheet is open.
##
## Presentation only; the radius comes from the tower's effective stats. Uses a
## single draw call (one arc) and redraws only when shown.
class_name RangeIndicator
extends Node2D

const LINE_COLOR := Color(0.55, 0.85, 1.0, 0.55)
const FILL_COLOR := Color(0.45, 0.75, 1.0, 0.10)
const LINE_WIDTH := 5.0

var _radius: float = 0.0
var _shown: bool = false


func _ready() -> void:
	z_index = -2
	visible = false


func show_at(center: Vector2, radius: float) -> void:
	position = center
	_radius = maxf(radius, 1.0)
	_shown = true
	visible = true
	queue_redraw()


func hide_indicator() -> void:
	_shown = false
	visible = false


func is_shown() -> bool:
	return _shown


func _draw() -> void:
	if not _shown:
		return
	draw_circle(Vector2.ZERO, _radius, FILL_COLOR)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 72, LINE_COLOR, LINE_WIDTH, true)
