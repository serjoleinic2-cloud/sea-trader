extends RefCounted

## Identical deterministic positions for the research interaction and 3D markers.
static func generate(world: Dictionary, seed_value: int, home_id: String) -> Array:
	var result: Array = []
	var rules: Dictionary = GameData.read("res://data/world/drift_debris_rules.json")
	var world_size := Vector2(world.get("world_size", Vector2i(4096, 4096)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:drift-foundations:v1" % seed_value)
	var islands: Array = world.get("islands", [])
	var ports: Dictionary = world.get("ports", {})
	for index in int(rules.get("count", 22)):
		var position := Vector2.ZERO
		var valid: bool = false
		for attempt in int(rules.get("attempts", 40)):
			position = Vector2(rng.randf_range(180.0, maxf(181.0, world_size.x - 180.0)), rng.randf_range(180.0, maxf(181.0, world_size.y - 180.0)))
			valid = true
			for island in islands:
				if position.distance_to(Vector2(island.get("position", Vector2.ZERO))) < float(island.get("radius", 0)) + float(rules.island_clearance): valid = false; break
			if not valid: continue
			for port in ports.values():
				if position.distance_to(Vector2(port.get("position", Vector2.ZERO))) < float(rules.port_clearance): valid = false; break
			if valid: break
		if not valid: continue
		var kinds: Array[String] = ["Ящик", "Бочка", "Обломки"]
		result.append({"id": "drift_%03d" % index, "position": position, "kind": kinds[rng.randi_range(0, kinds.size() - 1)]})
	var home: Dictionary = ports.get(home_id, {})
	if bool(rules.get("home_marker", true)) and not home.is_empty(): result.append({"id": "drift_home_00", "position": Vector2(home.get("position", Vector2.ZERO)) + Vector2(260, 0), "kind": "Ящик"})
	return result
