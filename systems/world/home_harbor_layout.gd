extends RefCounted

## Deterministic presentation/collision overlay. Saved port anchors and seed stay intact.
func decorate(world: Dictionary, home_id: String) -> Dictionary:
	var result: Dictionary
	if FileAccess.file_exists("res://data/world/faction_harbors.json"):
		result = load("res://systems/world/faction_harbor_layout.gd").new().decorate(world, home_id)
	else:
		result = _decorate_legacy(world, home_id)
	return preload("res://systems/navigation/navigation_collision_index.gd").prepare(result)

func _decorate_legacy(world: Dictionary, home_id: String) -> Dictionary:
	var result: Dictionary = world.duplicate(true)
	var port: Dictionary = result.get("ports", {}).get(home_id, {})
	if port.is_empty():
		var portless_world: Dictionary = _add_port_obstacles(_decorate_foreign_cities(result, home_id))
		return _clear_removed_user_asset_identity(portless_world)
	var islands: Array = result.get("islands", [])
	var target_id := str(port.get("island_id", ""))
	var anchor := Vector2(port.get("position", Vector2.ZERO))
	var preferred := float(port.get("harbor_angle", 0.0))
	var layout: Dictionary = GameData.read("res://data/world/home_base_visuals.json")
	var reference := float(layout.get("reference_radius_m", 60.0))
	var best_radius: float = 0.0
	var best_angle: float = preferred
	var best_center := anchor
	# Fit a city without covering neighboring land or relocating any port.
	for candidate_radius in [1500.0, 1200.0, 1000.0, 800.0, 600.0, 450.0, 300.0]:
		for turn in range(16):
			var angle := preferred + float(turn) * TAU / 16.0
			var center: Vector2 = anchor - Vector2.from_angle(angle) * float(candidate_radius) * 0.70
			var fits := true
			for other in islands:
				if str(other.get("id", "")) == target_id:
					continue
				if center.distance_to(Vector2(other.get("position", Vector2.ZERO))) < candidate_radius * 1.16 + float(other.get("radius", 0.0)) + 120.0:
					fits = false
					break
			if fits:
				best_radius = candidate_radius
				best_angle = angle
				best_center = center
				break
		if best_radius > 0.0:
			break
	for island in islands:
		if str(island.get("id", "")) != target_id:
			continue
		if best_radius <= 0:
			best_radius = float(island.radius)
			best_center = anchor - Vector2.from_angle(preferred) * best_radius * 0.70
		var polygon := PackedVector2Array()
		for raw in layout.get("coastline", []):
			# Blender +Y is the opening; map-space forward is bay_angle.
			polygon.append(best_center + (Vector2.from_angle(best_angle) * float(raw[1]) + Vector2.from_angle(best_angle + PI * 0.5) * float(raw[0])) * best_radius / reference)
		island["position"] = best_center
		island["radius"] = best_radius * 1.16
		island["visual_radius"] = best_radius
		island["coast_polygon"] = polygon
		island["bay_angle"] = best_angle
		island["bay_width"] = 0.34
		island["bay_depth"] = 0.30
		island["reef_inner_radius"] = best_radius * 1.055
		island["reef_outer_radius"] = best_radius * 1.15
		island["home_city"] = true
		port["harbor_angle"] = best_angle
		port["harbor_type"] = "city_bay"
		break
	var decorated: Dictionary = _add_port_obstacles(_decorate_foreign_cities(result, home_id))
	return _clear_removed_user_asset_identity(decorated)


func _clear_removed_user_asset_identity(world: Dictionary) -> Dictionary:
	for raw_island in world.get("islands", []):
		var island: Dictionary = raw_island
		if str(island.get("world_asset_identity", "")) == "iland_obstacle":
			island.erase("world_asset_identity")
	return world

func _decorate_foreign_cities(world: Dictionary, home_id: String) -> Dictionary:
	var layout: Dictionary = GameData.read("res://data/world/home_base_visuals.json")
	var resolver = load("res://systems/world/port_faction_resolver.gd").new()
	var islands: Array = world.get("islands", [])
	for port in world.get("ports", {}).values():
		if str(port.get("id", "")) == home_id:
			continue
		port["owner_race_id"] = resolver.resolve(port, int(world.get("seed", 0)))
		var island_id: String = str(port.get("island_id", ""))
		var ports_on_island: int = 0
		for other_port in world.get("ports", {}).values():
			if str(other_port.get("island_id", "")) == island_id:
				ports_on_island += 1
		if ports_on_island != 1:
			continue
		for island in islands:
			if str(island.get("id", "")) != island_id or float(island.get("radius", 0.0)) < 450.0:
				continue
			var radius: float = minf(1800.0, float(island.radius))
			var angle: float = float(port.get("harbor_angle", 0.0))
			var forward := Vector2.from_angle(angle)
			var side := Vector2.from_angle(angle + PI * 0.5)
			var center: Vector2 = Vector2(port.position) - forward * radius * 0.70
			var fits := true
			for other in islands:
				if str(other.id) != island_id and center.distance_to(Vector2(other.position)) < radius * 1.16 + float(other.radius) + 80.0:
					fits = false
					break
			if not fits:
				continue
			var coast := PackedVector2Array()
			for raw in layout.get("coastline", []):
				coast.append(center + (side * float(raw[0]) + forward * float(raw[1])) * radius / 60.0)
			island.merge({"position": center, "radius": radius * 1.16, "visual_radius": radius,
				"coast_polygon": coast, "bay_angle": angle, "bay_width": 0.34,
				"reef_inner_radius": radius * 1.055, "reef_outer_radius": radius * 1.15,
				"port_city": true}, true)
	return world

func _add_port_obstacles(world: Dictionary) -> Dictionary:
	for island in world.get("islands", []):
		var obstacles: Array = []
		if bool(island.get("home_city", false)) or bool(island.get("port_city", false)):
			var center := Vector2(island.position)
			var forward := Vector2.from_angle(float(island.bay_angle))
			var side := Vector2.from_angle(float(island.bay_angle) + PI * 0.5)
			var scale_factor: float = float(island.visual_radius) / 60.0
			for handedness in [-1.0, 1.0]:
				for y in [24.0, 34.0, 44.0]:
					var x: float = handedness * (31.0 if y < 40 else 36.0)
					var mid_x: float = x - handedness * 6.525
					obstacles.append(_rectangle(center + (side * mid_x + forward * y) * scale_factor, side, forward, Vector2(6.3, 2.3) * scale_factor))
					obstacles.append(_rectangle(center + (side * x + forward * y) * scale_factor, side, forward, Vector2(7.5, 7.2) * scale_factor))
		else:
			for raw_port in world.get("ports", {}).values():
				if str(raw_port.get("island_id", "")) != str(island.get("id", "")):
					continue
				var forward := Vector2.from_angle(float(raw_port.get("harbor_angle", 0.0)))
				var side := forward.orthogonal()
				# The foreign district uses two lateral piers, leaving the saved anchor free.
				for sign_value in [-1.0, 1.0]:
					obstacles.append(_rectangle(Vector2(raw_port.position) + side * float(sign_value) * 125.0 + forward * 65.0, side, forward, Vector2(36.25, 180.0)))
		island["navigation_obstacles"] = obstacles
	return world

func _rectangle(center: Vector2, horizontal: Vector2, vertical: Vector2, size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(center + horizontal * corner.x * size.x * 0.5 + vertical * corner.y * size.y * 0.5)
	return points
