extends Node2D

## Sparse ambient merchant traffic. Decorative now; later ships can become visible offer carriers.

var _world_size: Vector2 = Vector2(4096, 4096)
var _vessels: Array = []

func initialize(world_data: Dictionary) -> void:
	var raw_size: Variant = world_data.get("world_size", Vector2(4096, 4096))
	if raw_size is Vector2:
		_world_size = raw_size
	var ship_sizes: Array[float] = [7.0, 10.0, 14.0, 9.0, 18.0, 11.0]
	var ship_colors: Array[Color] = [
		Color(0.9, 0.9, 0.82, 1.0),
		Color(0.75, 0.72, 0.55, 1.0),
		Color(0.8, 0.45, 0.22, 1.0),
		Color(0.65, 0.85, 0.95, 1.0),
		Color(0.55, 0.58, 0.62, 1.0),
		Color(0.95, 0.72, 0.30, 1.0)
	]
	for index in range(ship_sizes.size()):
		var start: Vector2 = Vector2(
			fposmod(320.0 + index * 643.0, _world_size.x),
			fposmod(510.0 + index * 389.0, _world_size.y)
		)
		var destination: Vector2 = Vector2(
			fposmod(2100.0 + index * 287.0, _world_size.x),
			fposmod(1200.0 + index * 521.0, _world_size.y)
		)
		_vessels.append({
			"position": start,
			"destination": destination,
			"speed": 18.0 + index * 3.0,
			"size": ship_sizes[index],
			"color": ship_colors[index]
		})
	queue_redraw()

func _process(delta: float) -> void:
	for index in range(_vessels.size()):
		var vessel: Dictionary = _vessels[index]
		var position: Vector2 = vessel.get("position", Vector2.ZERO)
		var destination: Vector2 = vessel.get("destination", Vector2.ZERO)
		var speed: float = float(vessel.get("speed", 20.0))
		if position.distance_to(destination) <= speed * delta:
			vessel["position"] = destination
			vessel["destination"] = Vector2(
				fposmod(destination.x + 1177.0 + index * 73.0, _world_size.x),
				fposmod(destination.y + 809.0 + index * 131.0, _world_size.y)
			)
		else:
			vessel["position"] = position.move_toward(destination, speed * delta)
		_vessels[index] = vessel
	queue_redraw()

func _draw() -> void:
	for vessel in _vessels:
		var position: Vector2 = vessel.get("position", Vector2.ZERO)
		var destination: Vector2 = vessel.get("destination", Vector2.ZERO)
		var size: float = float(vessel.get("size", 8.0))
		var color: Color = vessel.get("color", Color.WHITE)
		var direction: Vector2 = (destination - position).normalized()
		var side: Vector2 = Vector2(-direction.y, direction.x)
		var points: PackedVector2Array = PackedVector2Array([
			position + direction * size,
			position - direction * size * 0.7 + side * size * 0.55,
			position - direction * size * 0.7 - side * size * 0.55
		])
		draw_colored_polygon(points, color)
