## DamageNumbers — pooled floating damage labels (spec 4.7).
##
## 25 fixed labels, 0.7 s rise + fade, crit variant larger and gold. Labels reuse
## their node, so a long run allocates nothing per hit. Animation uses real time:
## floating numbers should still finish while the battle clock is paused by a sheet.
class_name DamageNumbers
extends Node2D

const MAX_LABELS := 25
const LIFETIME := 0.7
const RISE_DISTANCE := 96.0
const NORMAL_FONT_SIZE := 44
const CRIT_FONT_SIZE := 64
const CRIT_COLOR := Color(1.0, 0.79, 0.25, 1.0)
const NORMAL_COLOR := Color(1.0, 0.96, 0.88, 1.0)

var _labels: Array[Label] = []
var _elapsed: Array[float] = []
var _start: Array[Vector2] = []
var _next: int = 0


func _ready() -> void:
	z_index = 40
	for _index in MAX_LABELS:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(160, 60)
		label.visible = false
		label.z_index = 40
		add_child(label)
		_labels.append(label)
		_elapsed.append(0.0)
		_start.append(Vector2.ZERO)


func _process(delta: float) -> void:
	for index in _labels.size():
		var label := _labels[index]
		if not label.visible:
			continue
		_elapsed[index] = _elapsed[index] + delta
		var ratio := clampf(_elapsed[index] / LIFETIME, 0.0, 1.0)
		label.position = _start[index] + Vector2(0.0, -RISE_DISTANCE * ratio)
		label.modulate.a = 1.0 - ratio * ratio
		if ratio >= 1.0:
			label.visible = false


## Shows a pooled number at a world position. Oldest label is reused at the cap.
func show_number(world_position: Vector2, amount: float, is_crit: bool) -> void:
	var index := _next
	_next = (_next + 1) % MAX_LABELS
	var label := _labels[index]
	label.text = str(int(round(maxf(amount, 0.0))))
	label.add_theme_font_size_override(&"font_size", CRIT_FONT_SIZE if is_crit else NORMAL_FONT_SIZE)
	label.add_theme_color_override(&"font_color", CRIT_COLOR if is_crit else NORMAL_COLOR)
	var jitter := Vector2(randf_range(-16.0, 16.0), randf_range(-6.0, 6.0))
	_start[index] = world_position + jitter
	_elapsed[index] = 0.0
	label.position = _start[index]
	label.modulate.a = 1.0
	label.visible = true


## Number of labels currently rising (smoke test).
func active_count() -> int:
	var count := 0
	for label in _labels:
		if label.visible:
			count += 1
	return count
