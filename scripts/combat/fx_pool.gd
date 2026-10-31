## FxPool — pooled one-shot sprite effects (death, splash).
##
## Fixed pool, manual fade/scale update; no per-kill node allocation or tween
## object. FX are presentation-only and never affect gameplay.
class_name FxPool
extends Node2D

const POOL_SIZE := 20

var _sprites: Array[Sprite2D] = []
var _elapsed: Array[float] = []
var _duration: Array[float] = []
var _next: int = 0
var _scale: Array[float] = []


func _ready() -> void:
	z_index = 20
	for _index in POOL_SIZE:
		var sprite := Sprite2D.new()
		sprite.visible = false
		add_child(sprite)
		_sprites.append(sprite)
		_elapsed.append(0.0)
		_duration.append(0.0)
		_scale.append(1.0)


func _process(delta: float) -> void:
	for index in _sprites.size():
		var sprite := _sprites[index]
		if not sprite.visible:
			continue
		_elapsed[index] = _elapsed[index] + delta
		var ratio := clampf(_elapsed[index] / maxf(_duration[index], 0.001), 0.0, 1.0)
		sprite.modulate.a = 1.0 - ratio
		var scale := _scale[index] * (1.0 + ratio * 0.6)
		sprite.scale = Vector2(scale, scale)
		if ratio >= 1.0:
			sprite.visible = false


## Plays `texture` at `world_position` for `duration` seconds.
func play(world_position: Vector2, texture: Texture2D, scale: float, duration: float) -> void:
	if texture == null:
		return
	var index := _next
	_next = (_next + 1) % POOL_SIZE
	var sprite := _sprites[index]
	sprite.texture = texture
	sprite.global_position = world_position
	sprite.rotation = randf_range(-0.25, 0.25)
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_scale[index] = maxf(scale, 0.1)
	sprite.scale = Vector2(_scale[index], _scale[index])
	_elapsed[index] = 0.0
	_duration[index] = maxf(duration, 0.01)
	sprite.visible = true


func active_count() -> int:
	var count := 0
	for sprite in _sprites:
		if sprite.visible:
			count += 1
	return count
