extends Node

## WorldGenerator -- deterministic world generation from seed.
## See ARCHITECTURE.md, SYSTEM_MAP.md, DEVELOPMENT_PHASES.md.
## Dependencies: data/world/world_gen_config.json, GameState.WorldState

const CONFIG_PATH: String = "res://data/world/world_gen_config.json"
const LEGACY_V1_CONFIG_PATH: String = "res://data/world/world_gen_config_v1.json"

var _config: Dictionary = {}
var _legacy_v1_config: Dictionary = {}
var _rng: RandomNumberGenerator
var _world_seed: int = 0


func get_generation_version() -> String:
	_load_config()
	return str(int(_config.get("version", 0)))

# ============================================================================
# Public API
# ============================================================================

func supports_generation_version(version: String) -> bool:
	_load_config()
	return version == "1" or version == str(int(_config.get("version", 0)))


func generate(world_seed: int, requested_version: int = -1) -> Dictionary:
	"""Generate a complete deterministic world from seed.
	Returns world data dictionary. Does NOT write to GameState directly."""
	_load_config()
	var current_config: Dictionary = _config
	var generation_version: int = requested_version
	if generation_version < 0:
		generation_version = int(_config.get("version", 0))
	if generation_version == 2:
		var legacy_world: Dictionary = generate(world_seed, 1)
		if legacy_world.is_empty():
			return {}
		var relayout: Dictionary = _relayout_legacy_world(world_seed, legacy_world, Vector2.ZERO)
		return relayout.get("world_data", {})
	if generation_version == 1:
		_config = _legacy_v1_config
	elif generation_version != int(_config.get("version", 0)):
		return {}
	_rng = RandomNumberGenerator.new()
	_rng.seed = world_seed
	_world_seed = world_seed

	var world_data: Dictionary = {
		"seed": world_seed,
		"world_size": Vector2i(
			_config.world_size[0],
			_config.world_size[1]
		),
		"islands": [],
		"ports": {},
		"hazard_zones": [],
		"regions": {}
	}

	world_data.regions = _generate_regions()
	world_data.islands = _generate_islands()
	world_data.ports = _generate_ports(world_data.islands)
	world_data.hazard_zones = _generate_hazard_zones()

	_config = current_config
	return world_data


func regenerate_from_state() -> Dictionary:
	"""Regenerate world using seed from GameState.WorldState."""
	var version_text: String = str(GameState.world_state.get("world_gen_version", ""))
	if version_text == "":
		version_text = get_generation_version()
	var version: int = int(version_text)
	return generate(int(GameState.world_state.seed), version)


func migrate_world_to_current(world_seed: int, source_version: int, ship_position: Vector2) -> Dictionary:
	"""Spread a legacy map while preserving island and port IDs and player progress."""
	if source_version != 1 or int(get_generation_version()) != 2:
		return {"ok": false, "message": "Для этой версии карты нет безопасного переноса."}
	var world: Dictionary = generate(world_seed, source_version)
	if world.is_empty():
		return {"ok": false, "message": "Старая карта не собралась."}
	return _relayout_legacy_world(world_seed, world, ship_position)


func _relayout_legacy_world(world_seed: int, world: Dictionary, ship_position: Vector2) -> Dictionary:
	world = world.duplicate(true)
	var islands: Array = world.get("islands", [])
	if islands.is_empty():
		return {"ok": true, "world_data": world, "ship_position": ship_position}
	var world_size: Vector2i = Vector2i(world.get("world_size", Vector2i(4096, 4096)))
	var new_positions: Array[Vector2i] = _make_spread_positions(world_seed, islands.size(), world_size)
	var shifts: Dictionary = {}
	var old_islands_by_id: Dictionary = {}
	for index in range(islands.size()):
		var island: Dictionary = islands[index]
		var island_id: String = str(island.get("id", ""))
		var old_position: Vector2i = Vector2i(island.get("position", Vector2i.ZERO))
		var new_position: Vector2i = new_positions[index]
		var shift: Vector2i = new_position - old_position
		island["position"] = new_position
		island["region"] = _get_region_for_position(new_position)
		islands[index] = island
		shifts[island_id] = shift
		old_islands_by_id[island_id] = {"position": old_position, "radius": int(island.get("radius", 0))}
	world["islands"] = islands
	world["regions"] = _generate_regions()

	var ports: Dictionary = world.get("ports", {})
	for port_id in ports:
		var port: Dictionary = ports[port_id]
		var island_id: String = str(port.get("island_id", ""))
		var shift: Vector2i = Vector2i(shifts.get(island_id, Vector2i.ZERO))
		port["position"] = Vector2i(port.get("position", Vector2i.ZERO)) + shift
		if shifts.has(island_id):
			var island_index: int = _find_island_index(islands, island_id)
			if island_index >= 0:
				port["region"] = str(islands[island_index].get("region", "unknown"))
		ports[port_id] = port
	world["ports"] = ports

	var hazards: Array = world.get("hazard_zones", [])
	var hazard_types: Array = _config.get("hazard_types", ["storm", "pirate"])
	var hazard_rng := RandomNumberGenerator.new()
	hazard_rng.seed = absi(world_seed) + 918_271
	for index in range(hazards.size()):
		var hazard: Dictionary = hazards[index]
		var hazard_position: Vector2i = Vector2i(hazard.get("position", Vector2i.ZERO))
		var closest_island_id: String = _nearest_island_id(hazard_position, old_islands_by_id)
		hazard["position"] = hazard_position + Vector2i(shifts.get(closest_island_id, Vector2i.ZERO))
		if not hazard_types.is_empty():
			hazard["type"] = str(hazard_types[hazard_rng.randi_range(0, hazard_types.size() - 1)])
		hazard["active"] = true
		hazards[index] = hazard
	world["hazard_zones"] = hazards

	var nearest_ship_island: String = _nearest_island_id(ship_position, old_islands_by_id)
	var moved_ship_position: Vector2 = ship_position + Vector2(shifts.get(nearest_ship_island, Vector2i.ZERO))
	moved_ship_position.x = clampf(moved_ship_position.x, 0.0, float(world_size.x))
	moved_ship_position.y = clampf(moved_ship_position.y, 0.0, float(world_size.y))
	return {"ok": true, "world_data": world, "ship_position": moved_ship_position}


# ============================================================================
# Config Loading
# ============================================================================

func _load_config() -> void:
	if _config.is_empty():
		_config = GameData.read(CONFIG_PATH)
	if _legacy_v1_config.is_empty():
		_legacy_v1_config = GameData.read(LEGACY_V1_CONFIG_PATH)


# ============================================================================
# Region Generation
# ============================================================================

func _generate_regions() -> Dictionary:
	var regions: Dictionary = {}
	var region_list: Array = _config.get("regions", [])
	for region_data in region_list:
		var region_id: String = region_data.id
		regions[region_id] = {
			"id": region_id,
			"bounds": Rect2i(
				region_data.bounds[0], region_data.bounds[1],
				region_data.bounds[2], region_data.bounds[3]
			),
			"center": Vector2i(region_data.center[0], region_data.center[1]),
			"resources": region_data.get("resources", []),
			"hazard_density": region_data.get("hazard_density", 0.0)
		}
	return regions


# ============================================================================
# Island Generation
# ============================================================================

func _generate_islands() -> Array:
	var islands: Array = []
	var count: int = _rng.randi_range(
		_config.island_count_min,
		_config.island_count_max
	)
	var world_w: int = _config.world_size[0]
	var world_h: int = _config.world_size[1]
	var margin: int = 100

	var attempts: int = 0
	var max_attempts: int = count * 50

	while islands.size() < count and attempts < max_attempts:
		attempts += 1
		var pos: Vector2i = Vector2i(
			_rng.randi_range(margin, world_w - margin),
			_rng.randi_range(margin, world_h - margin)
		)
		var radius: int = _rng.randi_range(
			_config.island_min_radius,
			_config.island_max_radius
		)

		var too_close: bool = false
		for existing in islands:
			var dist: float = pos.distance_to(existing.position)
			if dist < _config.island_min_distance:
				too_close = true
				break

		if too_close:
			continue

		var island: Dictionary = {
			"id": "island_%03d" % islands.size(),
			"position": pos,
			"radius": radius,
			"region": _get_region_for_position(pos)
		}
		islands.append(island)

	return islands
func _make_spread_positions(world_seed: int, count: int, world_size: Vector2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if count <= 0:
		return positions
	var cells_by_quadrant: Array = [[], [], [], []]
	for row in range(4):
		for column in range(4):
			var quadrant: int = floori(float(row) / 2.0) * 2 + floori(float(column) / 2.0)
			cells_by_quadrant[quadrant].append(Vector2i(column, row))
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = absi(world_seed) + 741_281
	var quadrant_order: Array = [0, 1, 2, 3]
	_shuffle_with_rng(quadrant_order, layout_rng)
	var base_count: int = floori(float(count) / 4.0)
	var counts: Array[int] = [base_count, base_count, base_count, base_count]
	for index in range(count % 4):
		counts[int(quadrant_order[index])] += 1
	var cell_size: Vector2 = Vector2(float(world_size.x) / 4.0, float(world_size.y) / 4.0)
	var max_radius: float = float(_config.get("island_max_radius", 250))
	var minimum_coast_gap: float = float(_config.get("island_min_coast_distance", 320))
	var safe_jitter_x: float = maxf(0.0, (cell_size.x - max_radius * 2.0 - minimum_coast_gap) * 0.5)
	var safe_jitter_y: float = maxf(0.0, (cell_size.y - max_radius * 2.0 - minimum_coast_gap) * 0.5)
	var jitter: Vector2i = Vector2i(
		mini(roundi(cell_size.x * 0.08), floori(safe_jitter_x)),
		mini(roundi(cell_size.y * 0.08), floori(safe_jitter_y))
	)
	for quadrant_value in quadrant_order:
		var quadrant: int = int(quadrant_value)
		var cells: Array = cells_by_quadrant[quadrant].duplicate()
		_shuffle_with_rng(cells, layout_rng)
		for index in range(counts[quadrant]):
			var cell: Vector2i = cells[index]
			var center := Vector2(
				(float(cell.x) + 0.5) * cell_size.x,
				(float(cell.y) + 0.5) * cell_size.y
			)
			positions.append(Vector2i(
				roundi(center.x) + layout_rng.randi_range(-jitter.x, jitter.x),
				roundi(center.y) + layout_rng.randi_range(-jitter.y, jitter.y)
			))
	return positions


func _shuffle_with_rng(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var value: Variant = items[index]
		items[index] = items[swap_index]
		items[swap_index] = value


func _find_island_index(islands: Array, island_id: String) -> int:
	for index in range(islands.size()):
		if str(islands[index].get("id", "")) == island_id:
			return index
	return -1


func _nearest_island_id(position: Vector2, islands_by_id: Dictionary) -> String:
	var nearest_id: String = ""
	var nearest_distance: float = INF
	for island_id in islands_by_id:
		var island: Dictionary = islands_by_id[island_id]
		var distance: float = position.distance_to(Vector2(island.get("position", Vector2.ZERO)))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = str(island_id)
	return nearest_id


func get_region_for_position(position: Vector2) -> String:
	_load_config()
	return _get_region_for_position(Vector2i(roundi(position.x), roundi(position.y)))


func _get_region_for_position(pos: Vector2i) -> String:
	var regions: Array = _config.get("regions", [])
	for region_data in regions:
		var bounds: Array = region_data.get("bounds", [0, 0, 0, 0])
		var rect: Rect2i = Rect2i(bounds[0], bounds[1], bounds[2], bounds[3])
		if rect.has_point(pos):
			return region_data.id
	return "unknown"


# ============================================================================
# Port Generation
# ============================================================================

func _generate_ports(islands: Array) -> Dictionary:
	var ports: Dictionary = {}
	var names_pool: Array = _config.get("port_names_pool", []).duplicate()
	_names_shuffle(names_pool)
	var name_index: int = 0

	for island in islands:
		if _rng.randf() > _config.port_per_island_chance:
			continue

		var port_id: String = "port_%s" % island.id
		var port_name: String = names_pool[name_index % names_pool.size()] if names_pool.size() > 0 else "Unknown Port"
		name_index += 1

		var angle: float = _rng.randf() * TAU
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * (island.radius * 0.7)
		var port_pos: Vector2i = Vector2i(island.position.x + int(offset.x), island.position.y + int(offset.y))

		ports[port_id] = {
			"id": port_id,
			"name": port_name,
			"position": port_pos,
			"region": island.region,
			"level": 1,
			"island_id": island.id,
			"buildings": {
				"dock": {"level": 1, "damage_hp": 100},
				"warehouse": {"level": 1, "damage_hp": 100}
			}
		}

	return ports


func _names_shuffle(arr: Array) -> void:
	"""Fisher-Yates shuffle using _rng."""
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ============================================================================
# Hazard Zones (defined, not active)
# ============================================================================

func _generate_hazard_zones() -> Array:
	var zones: Array = []
	var count: int = _rng.randi_range(
		_config.hazard_zone_count_min,
		_config.hazard_zone_count_max
	)
	var world_w: int = _config.world_size[0]
	var world_h: int = _config.world_size[1]
	var margin: int = 200

	for i in range(count):
		var pos: Vector2i = Vector2i(
			_rng.randi_range(margin, world_w - margin),
			_rng.randi_range(margin, world_h - margin)
		)
		var radius: int = _rng.randi_range(
			_config.hazard_zone_min_radius,
			_config.hazard_zone_max_radius
		)
		var hazard_type: String = "storm" if _rng.randf() < 0.5 else "pirate"

		zones.append({
			"id": "hazard_%03d" % i,
			"position": pos,
			"radius": radius,
			"type": hazard_type,
			"active": false
		})

	return zones
