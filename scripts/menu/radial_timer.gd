## RadialTimer — a lightweight circular progress ring for Magica research.
##
## Draws a background track and a clockwise arc from 12 o'clock. The remaining time
## label is a separate Label owned by the screen, so this control stays reusable.
class_name RadialTimer
extends Control

var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var track_color: Color = Color(0.08, 0.12, 0.09, 0.7)
@export var fill_color: Color = Color(0.55, 0.95, 0.5, 1.0)
@export var line_width: float = 14.0
@export var start_angle: float = -PI / 2.0


func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - line_width
	draw_arc(center, radius, 0.0, TAU, 96, track_color, line_width, true)
	if progress <= 0.0:
		return
	draw_arc(center, radius, start_angle, start_angle + TAU * progress, 96, fill_color, line_width, true)
	draw_circle(center, maxf(line_width * 0.45, 2.0), fill_color)
