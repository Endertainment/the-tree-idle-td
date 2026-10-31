## SpatialHash — uniform grid of living enemies, rebuilt once per battle tick.
##
## Towers, units, the Tree and splash damage query this grid instead of walking
## `get_nodes_in_group("enemies")`, which keeps targeting O(cells) per query and
## never touches dead/pooled enemies. Rebuilding from the controller's active
## array is O(n) with n <= ~120 and removes any despawn bookkeeping bug class.
class_name SpatialHash
extends RefCounted

var _cell_size: float = 128.0
var _cells: Dictionary = {}


func _init(cell_size: float = 128.0) -> void:
	_cell_size = maxf(cell_size, 16.0)


func clear() -> void:
	_cells.clear()


## Replaces the grid contents with the living enemies in `enemies`.
func rebuild(enemies: Array[Enemy]) -> void:
	clear()
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		_insert(enemy)


## Returns every living enemy within `radius` of `center`.
func query_radius(center: Vector2, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	if radius <= 0.0:
		return result
	var min_cell := _cell_of(center - Vector2.ONE * radius)
	var max_cell := _cell_of(center + Vector2.ONE * radius)
	var radius_sq := radius * radius
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var bucket: Array = _cells.get(Vector2i(x, y), [])
			for value: Variant in bucket:
				var enemy := value as Enemy
				if enemy == null:
					continue
				if enemy.global_position.distance_squared_to(center) <= radius_sq:
					result.append(enemy)
	return result


func cell_count() -> int:
	return _cells.size()


func _cell_of(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / _cell_size), floori(position.y / _cell_size))


func _insert(enemy: Enemy) -> void:
	var key := _cell_of(enemy.global_position)
	var bucket: Array = _cells.get(key, [])
	bucket.append(enemy)
	_cells[key] = bucket
