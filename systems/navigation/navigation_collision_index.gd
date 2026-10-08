extends RefCounted

## Runtime bounds for static shore and pier geometry. Rebuilt with the world overlay.
const CELL_SIZE: float = 256.0
const SHORE_CLEARANCE: float = 30.0

static func prepare(world: Dictionary) -> Dictionary:
	for island in world.get("islands", []):
		var center: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var radius: float = maxf(0.0, float(island.get("radius", 0.0)))
		var bounds := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		var obstacle_bounds: Array[Rect2] = []
		for raw_polygon in island.get("navigation_obstacles", []):
			var polygon: PackedVector2Array = raw_polygon
			var obstacle := Rect2()
			if not polygon.is_empty():
				obstacle = Rect2(polygon[0], Vector2.ZERO)
				for vertex in polygon:
					obstacle = obstacle.expand(vertex)
				bounds = bounds.merge(obstacle)
			obstacle_bounds.append(obstacle)
		island["navigation_bounds"] = bounds
		island["navigation_obstacle_bounds"] = obstacle_bounds
		var coast: PackedVector2Array = island.get("coast_polygon", PackedVector2Array())
		var coast_bounds: Array[Rect2] = []
		var coast_cells: Dictionary = {}
		for edge in coast.size():
			var edge_bounds := Rect2(coast[edge], coast[(edge + 1) % coast.size()] - coast[edge]).abs()
			coast_bounds.append(edge_bounds)
			var expanded := edge_bounds.grow(SHORE_CLEARANCE)
			var first := Vector2i((expanded.position / CELL_SIZE).floor())
			var last := Vector2i((expanded.end / CELL_SIZE).floor())
			for x in range(first.x, last.x + 1):
				for y in range(first.y, last.y + 1):
					var key := Vector2i(x, y)
					if not coast_cells.has(key): coast_cells[key] = []
					coast_cells[key].append(edge)
		island["navigation_coast_edge_bounds"] = coast_bounds
		island["navigation_coast_cells"] = coast_cells
	return world

static func nearby_coast_edges(island: Dictionary, area: Rect2, count: int) -> Array:
	if not island.has("navigation_coast_cells"):
		return range(count)
	var first := Vector2i((area.position / CELL_SIZE).floor())
	var last := Vector2i((area.end / CELL_SIZE).floor())
	# Long route probes are cheaper to check against the whole outline.
	if (last.x - first.x + 1) * (last.y - first.y + 1) > 64:
		return range(count)
	var cells: Dictionary = island.navigation_coast_cells
	var result: Array = []
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			for edge in cells.get(Vector2i(x, y), []):
				if not result.has(edge): result.append(edge)
	return result
