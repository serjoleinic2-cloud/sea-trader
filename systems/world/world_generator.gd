extends Node

## WorldGenerator -- deterministic world generation from seed.
## See ARCHITECTURE.md, SYSTEM_MAP.md, DEVELOPMENT_PHASES.md.
## Dependencies: data/world/world_gen_config.json, GameState.WorldState

const CONFIG_PATH: String = "res://data/world/world_gen_config.json"

var _config: Dictionary = {}
var _rng: RandomNumberGenerator

# ============================================================================
# Public API
# ============================================================================

func generate(world_seed: int) -> Dictionary:
	"""Generate a complete deterministic world from seed.
	Returns world data dictionary. Does NOT write to GameState directly."""
	_load_config()
	_rng = RandomNumberGenerator.new()
	_rng.seed = world_seed

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

	return world_data


func regenerate_from_state() -> Dictionary:
	"""Regenerate world using seed from GameState.WorldState."""
	return generate(GameState.world_state.seed)


# ============================================================================
# Config Loading
# ============================================================================

func _load_config() -> void:
	if not _config.is_empty():
		return
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("WorldGenerator: Cannot open " + CONFIG_PATH)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_config = parsed
	else:
		push_error("WorldGenerator: Invalid JSON in " + CONFIG_PATH)


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
			"discovered": false,
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
