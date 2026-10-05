extends RefCounted

## Presentation overlay only: seed, island identities and saved port anchors stay intact.
func decorate(world: Dictionary, home_id: String) -> Dictionary:
	var result: Dictionary = world.duplicate(true)
	var catalog: Dictionary = GameData.read("res://data/world/faction_harbors.json")
	var variants: Dictionary = catalog.get("variants", {})
	var resolver = load("res://systems/world/port_faction_resolver.gd").new()
	var islands: Array = result.get("islands", [])
	for port in result.get("ports", {}).values():
		var home: bool = str(port.id) == home_id
		var race: String = str(GameState.player_state.get("origin_race_id", "humans")) if home else resolver.resolve(port, int(world.get("seed", 0)))
		if GameData.get_faction(race).is_empty(): race = "humans"
		port["owner_race_id"] = race
		var count: int = 0
		for other in result.get("ports", {}).values():
			if str(other.island_id) == str(port.island_id): count += 1
		if count != 1: continue
		for island in islands:
			if str(island.id) != str(port.island_id): continue
			var mini: bool = not home and float(island.radius) < 450.0
			var key: String = race + ("_outpost" if mini else "")
			var spec: Dictionary = variants.get(key, {})
			if spec.is_empty(): continue
			var anchor := Vector2(port.position)
			var radius: float = 1500.0 if home else minf(1800.0, float(island.radius))
			var preferred: float = float(port.get("harbor_angle", 0.0))
			var fitted: bool = false
			var center := Vector2(island.position)
			var angle: float = preferred
			for shrink in [1.0, 0.8, 0.6, 0.4, 0.3, 0.2]:
				for turn in range(16):
					angle = preferred + float(turn) * TAU / 16.0
					center = anchor - Vector2.from_angle(angle) * radius * float(shrink) * 0.12
					var fits: bool = true
					for other in islands:
						if str(other.id) != str(island.id) and center.distance_to(Vector2(other.position)) < radius * float(shrink) * 1.16 + float(other.radius) + 80.0:
							fits = false
							break
					if fits:
						radius *= float(shrink)
						fitted = true
						break
				if fitted: break
			# Preserve the old coast where no safe footprint exists (e.g. tightly packed legacy maps).
			if not fitted: continue
			var forward := Vector2.from_angle(angle)
			var right := Vector2(forward.y, -forward.x)
			var factor: float = radius / float(spec.reference_radius)
			var outline: PackedVector2Array = _points(spec.coastline, center, right, forward, factor)
			var piers: Array = []
			for polygon in spec.piers:
				piers.append(_points(polygon, center, right, forward, factor))
			island.merge({"position": center, "radius": radius * 1.16, "visual_radius": radius,
				"coast_polygon": outline, "bay_angle": angle, "bay_width": 0.55 if mini else 0.34,
				"reef_inner_radius": radius * 1.055, "reef_outer_radius": radius * 1.15,
				"home_city": home, "port_city": not home, "harbor_variant": key,
				"navigation_obstacles": piers}, true)
			port["harbor_angle"] = angle
			port["harbor_type"] = "outpost_bay" if mini else "city_bay"
	for island in islands:
		if str(island.get("world_asset_identity", "")) == "iland_obstacle": island.erase("world_asset_identity")
		if not island.has("harbor_variant"):
			var obstacles: Array = []
			for port in result.get("ports", {}).values():
				if str(port.island_id) != str(island.id): continue
				var forward := Vector2.from_angle(float(port.get("harbor_angle",0.0)))
				var side := forward.orthogonal()
				for sign_value in [-1.0,1.0]:
					var center: Vector2 = Vector2(port.position)+side*float(sign_value)*125.0+forward*65.0
					obstacles.append(_points([[-18.125,-90],[18.125,-90],[18.125,90],[-18.125,90]],center,side,forward,1.0))
			island["navigation_obstacles"] = obstacles
	return result

func _points(points: Array, center: Vector2, right: Vector2, forward: Vector2, scale_factor: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for p in points:
		polygon.append(center + (right * float(p[0]) + forward * float(p[1])) * scale_factor)
	return polygon
