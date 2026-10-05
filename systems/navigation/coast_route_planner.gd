extends RefCounted

## Visibility graph around island shores. Collision authority stays in ShipPhysics.
const CLEARANCE: float = 48.0
const RING_POINTS: int = 8

func plan(start: Vector2, destination: Vector2, islands: Array, can_move: Callable, clearance: float = CLEARANCE) -> PackedVector2Array:
	if not can_move.is_valid() or not bool(can_move.call(start, destination)):
		return PackedVector2Array([destination])
	var graph := AStar2D.new()
	graph.add_point(0, start)
	graph.add_point(1, destination)
	var next_id: int = 2
	for raw_island in islands:
		var island: Dictionary = raw_island
		for raw_polygon in island.get("navigation_obstacles", []):
			var polygon: PackedVector2Array = raw_polygon
			if polygon.size() < 3:
				continue
			var centroid := Vector2.ZERO
			for point in polygon:
				centroid += point / polygon.size()
			if centroid.distance_to(Geometry2D.get_closest_point_to_segment(centroid, start, destination)) > 700.0:
				continue
			for corner in polygon.size():
				var point: Vector2 = polygon[corner]
				var inward := (polygon[(corner + polygon.size() - 1) % polygon.size()] - point).normalized() + (polygon[(corner + 1) % polygon.size()] - point).normalized()
				graph.add_point(next_id, point - inward.normalized() * clearance * 1.5)
				next_id += 1
		var center: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var radius: float = float(island.get("radius", 0.0))
		if radius <= 0.0:
			continue
		if center.distance_to(Geometry2D.get_closest_point_to_segment(center, start, destination)) > radius + 600.0:
			continue
		# Ring chords must also remain outside the shore, not just their endpoints.
		var outer_radius: float = (radius + clearance) / cos(PI / RING_POINTS)
		for index in RING_POINTS:
			var angle: float = TAU * index / RING_POINTS
			graph.add_point(next_id, center + Vector2.from_angle(angle) * outer_radius)
			next_id += 1
		var bay_angle: float = float(island.get("bay_angle", 1000.0))
		if bay_angle < 900.0 and float(island.get("bay_width", 0.0)) > 0.0:
			graph.add_point(next_id, center + Vector2.from_angle(bay_angle) * outer_radius)
			next_id += 1
	for first in next_id:
		for second in range(first + 1, next_id):
			var a: Vector2 = graph.get_point_position(first)
			var b: Vector2 = graph.get_point_position(second)
			if not bool(can_move.call(a, b)) and not bool(can_move.call(b, a)):
				graph.connect_points(first, second)
	var path: PackedVector2Array = graph.get_point_path(0, 1)
	if not path.is_empty():
		path.remove_at(0)
	return path
