extends CanvasLayer

## Renders the strategic map and the close view from one shared 3D world.
## On approach, only the camera moves from overhead to behind the ship.

const MAP_TO_METERS: float = 0.04
const TRANSITION_START_GAP: float = 560.0
const TRANSITION_CLOSE_GAP: float = 160.0
const FOG_RADIUS_CHUNKS: int = 6
const FOG_HEIGHT: float = 28.0

var _world_data: Dictionary = {}
var _map_world: CanvasItem
var _map_ship: CanvasItem
var _viewport_container: SubViewportContainer
var _subviewport: SubViewport
var _scene_root: Node3D
var _camera: Camera3D
var _ship: Node3D
var _trader_traffic: Node
var _fleet_traffic: Node
var _water: MeshInstance3D
var _island_nodes: Dictionary = {}
var _hazard_nodes: Dictionary = {}
var _rendered_island_data: Dictionary = {}
var _traffic_models: Dictionary = {}
var _fog_tiles: Dictionary = {}
var _fog_center: Vector2i = Vector2i(2147483647, 2147483647)
var _fog_explored_count: int = -1
var _asset_catalog: Dictionary = {}
var _transition_factor: float = 0.0
var _chunk_size: float = 4096.0
var _camera_initialized: bool = false


func _ready() -> void:
	# Render the shared 3D world beneath the strategic map and the game UI.
	layer = -1
	_asset_catalog = GameData.read("res://data/world/world_asset_catalog.json")
	_build_viewport()
	_build_scene()


func initialize(world_data: Dictionary, map_world: CanvasItem, map_ship: CanvasItem, trader_traffic: Node = null, fleet_traffic: Node = null) -> void:
	_world_data = world_data
	_asset_catalog = GameData.read("res://data/world/world_asset_catalog.json")
	_chunk_size = float(world_data.get("chunk_size", 4096.0))
	_map_world = map_world
	_map_ship = map_ship
	_trader_traffic = trader_traffic
	_fleet_traffic = fleet_traffic
	# The strategy view is 3D from the start. Keep the 2D camera active so zoom
	# and movement still use the existing systems; traffic markers remain above it.
	_map_world.visible = false
	_map_world.set_process(false)
	var ship_sprite: CanvasItem = _map_ship.get_node_or_null("ShipVisual") as CanvasItem
	if ship_sprite != null:
		ship_sprite.visible = false
	var procedural_visual: CanvasItem = _map_ship.get_node_or_null("ProceduralShipVisual") as CanvasItem
	if procedural_visual != null:
		procedural_visual.visible = false
	for renderer in [_trader_traffic, _fleet_traffic]:
		if renderer is CanvasItem:
			renderer.visible = false
	if _trader_traffic != null:
		_trader_traffic.set_process(true)
	if _fleet_traffic != null:
		_fleet_traffic.set_process(false)
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sync_generated_world(_world_data)


func _process(delta: float) -> void:
	if _world_data.is_empty() or _camera == null:
		return
	var ship_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var nearest: Dictionary = _find_nearest_island(ship_position)
	if nearest.is_empty():
		_set_transition(0.0, delta)
		_sync_fog(ship_position)
		return

	var island_position: Vector2 = Vector2(nearest.get("position", Vector2.ZERO))
	var island_radius: float = float(nearest.get("radius", 80.0))
	var center_distance: float = ship_position.distance_to(island_position)
	var coast_gap: float = maxf(0.0, center_distance - island_radius)
	var close_factor: float = 1.0 - smoothstep(TRANSITION_CLOSE_GAP, TRANSITION_START_GAP, coast_gap)
	_set_transition(close_factor, delta)
	_update_camera(ship_position, _transition_factor, delta)
	if _water != null:
		_water.position.x = ship_position.x * MAP_TO_METERS
		_water.position.z = ship_position.y * MAP_TO_METERS
	_sync_fog(ship_position)
	_sync_traffic(_trader_traffic, "trader")
	_sync_traffic(_fleet_traffic, "fleet")


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the shared 3D world below HUD CanvasLayers.
	_viewport_container.modulate.a = 1.0
	add_child(_viewport_container)

	_subviewport = SubViewport.new()
	_subviewport.size = Vector2i(get_viewport().get_visible_rect().size)
	_subviewport.own_world_3d = true
	_subviewport.transparent_bg = false
	_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport_container.add_child(_subviewport)


func _build_scene() -> void:
	_scene_root = Node3D.new()
	_scene_root.name = "ApproachWorld3D"
	_subviewport.add_child(_scene_root)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("7ca9bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9d5df")
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	_scene_root.add_child(environment_node)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sunlight.light_energy = 1.25
	_scene_root.add_child(sunlight)

	_add_water()
	_ship = _make_ship()
	_scene_root.add_child(_ship)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 58.0
	_scene_root.add_child(_camera)


func _add_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400.0, 2400.0)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	uniform vec3 deep_water = vec3(0.035, 0.20, 0.30);
	uniform vec3 light_water = vec3(0.10, 0.36, 0.46);
	void vertex() {
		VERTEX.y += sin(VERTEX.x * 0.12 + TIME * 1.1) * 0.10;
		VERTEX.y += sin(VERTEX.z * 0.17 + TIME * 0.8) * 0.08;
	}
	void fragment() {
		float bands = sin((UV.x * 47.0 + UV.y * 23.0 + TIME * 0.15) * 6.28318);
		float glint = smoothstep(0.62, 0.96, bands) * 0.20;
		ALBEDO = mix(deep_water, light_water, glint);
		ROUGHNESS = 0.28;
		METALLIC = 0.08;
	}
	"""
	_water = MeshInstance3D.new()
	_water.name = "AnimatedOcean"
	_water.mesh = plane
	var water_material := ShaderMaterial.new()
	water_material.shader = shader
	_water.material_override = water_material
	_water.position.y = -0.18
	_scene_root.add_child(_water)


func _make_ship() -> Node3D:
	var ship_id: String = str(GameState.ship_state.get("ship_id", "ship_sloop"))
	var registered_ship: Node3D = _attach_catalog_scene(_scene_root, "ships", ship_id, 3.48)
	if registered_ship != null:
		registered_ship.name = "CloseViewShip"
		return registered_ship
	var ship := Node3D.new()
	ship.name = "CloseViewShip"
	var hull_material := _material(Color("503629"), 0.72)
	var deck_material := _material(Color("b58955"), 0.82)
	var sail_material := _material(Color("eee3c8"), 0.9)

	# The map hull is 87 world units long; at MAP_TO_METERS this hull is the
	# same apparent size when the camera crosses from the map into 3D.
	_add_box(ship, Vector3(1.04, 0.50, 3.48), Vector3(0.0, 0.15, 0.12), hull_material)
	_add_box(ship, Vector3(0.90, 0.16, 2.84), Vector3(0.0, 0.49, 0.14), deck_material)
	_add_box(ship, Vector3(0.72, 0.52, 0.82), Vector3(0.0, 0.82, 1.25), _material(Color("d7c49c"), 0.88))
	_add_cylinder(ship, 0.09, 0.09, 4.0, Vector3(0.0, 2.3, -0.25), Color("594434"))
	_add_sail(ship, Vector2(1.55, 2.65), Vector3(0.0, 2.1, -0.2), sail_material)
	_add_sail(ship, Vector2(0.9, 1.65), Vector3(0.0, 1.55, -1.45), _material(Color("d9c9aa"), 0.94))
	return ship


func _add_sail(parent: Node3D, sail_size: Vector2, at: Vector3, material: StandardMaterial3D) -> void:
	var sail_mesh := QuadMesh.new()
	sail_mesh.size = sail_size
	var sail := MeshInstance3D.new()
	sail.mesh = sail_mesh
	sail.material_override = material
	sail.position = at
	parent.add_child(sail)


func sync_generated_world(world_data: Dictionary) -> void:
	_world_data = world_data
	_sync_generated_world(_world_data)

func _sync_generated_world(world_data: Dictionary) -> void:
	var ship_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var center_chunk := Vector2i(floori(ship_position.x / _chunk_size), floori(ship_position.y / _chunk_size))
	var keep_islands: Dictionary = {}
	var visible_islands: Dictionary = {}
	for raw_island in world_data.get("islands", []):
		var island: Dictionary = raw_island
		var map_position: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var chunk_x: int = floori(map_position.x / _chunk_size)
		var chunk_y: int = floori(map_position.y / _chunk_size)
		if abs(chunk_x - center_chunk.x) > 1 or abs(chunk_y - center_chunk.y) > 1:
			continue
		var island_id: String = str(island.get("id", ""))
		if island_id == "":
			continue
		keep_islands[island_id] = true
		visible_islands[island_id] = island
		if _island_nodes.has(island_id):
			continue
		var island_root := Node3D.new()
		island_root.name = island_id
		island_root.position = Vector3(map_position.x * MAP_TO_METERS, 0.0, map_position.y * MAP_TO_METERS)
		_scene_root.add_child(island_root)
		_build_island(island_root, island)
		_island_nodes[island_id] = island_root
	_rendered_island_data = visible_islands
	for island_id in _island_nodes.keys():
		if keep_islands.has(island_id):
			continue
		(_island_nodes[island_id] as Node3D).queue_free()
		_island_nodes.erase(island_id)

	var keep_hazards: Dictionary = {}
	for raw_zone in world_data.get("hazard_zones", []):
		var zone: Dictionary = raw_zone
		if not bool(zone.get("active", false)):
			continue
		var map_position: Vector2 = Vector2(zone.get("position", Vector2.ZERO))
		var chunk_x: int = floori(map_position.x / _chunk_size)
		var chunk_y: int = floori(map_position.y / _chunk_size)
		if abs(chunk_x - center_chunk.x) > 1 or abs(chunk_y - center_chunk.y) > 1:
			continue
		var hazard_id: String = str(zone.get("id", ""))
		if hazard_id == "":
			continue
		keep_hazards[hazard_id] = true
		if _hazard_nodes.has(hazard_id):
			continue
		var zone_type: String = str(zone.get("type", "storm"))
		var color: Color = Color("4a9fae")
		match zone_type:
			"tornado": color = Color("e67935")
			"pirate": color = Color("a43d49")
			"anomaly": color = Color("935ed6")
		var radius: float = maxf(2.0, float(zone.get("radius", 150.0)) * MAP_TO_METERS)
		var disk := CylinderMesh.new()
		disk.top_radius = radius
		disk.bottom_radius = radius
		disk.height = 0.025
		disk.radial_segments = 48
		var marker := MeshInstance3D.new()
		marker.name = "Hazard_" + hazard_id
		marker.mesh = disk
		marker.position = Vector3(map_position.x * MAP_TO_METERS, 0.015, map_position.y * MAP_TO_METERS)
		var material := _material(Color(color.r, color.g, color.b, 0.22), 0.4)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = material
		_scene_root.add_child(marker)
		_hazard_nodes[hazard_id] = marker
	for hazard_id in _hazard_nodes.keys():
		if keep_hazards.has(hazard_id):
			continue
		(_hazard_nodes[hazard_id] as Node3D).queue_free()
		_hazard_nodes.erase(hazard_id)

func _build_island(island_root: Node3D, island: Dictionary) -> void:
	var current_id: String = str(island.get("id", ""))
	var map_radius: float = float(island.get("radius", 90.0))
	var radius: float = map_radius * MAP_TO_METERS
	var landform: String = str(island.get("landform", "small_island"))
	var custom_model: Node3D = _attach_catalog_scene(island_root, "islands", current_id, radius * 2.0)
	if custom_model == null:
		# Schematic coast footprint stays aligned to navigation coordinates.
		_add_cylinder(island_root, radius, radius * 0.94, 1.55, Vector3(0.0, 0.62, 0.0), Color("b99a69"))
		_add_cylinder(island_root, radius * 0.94, radius * 0.84, 0.5, Vector3(0.0, 1.58, 0.0), Color("4f7851"))
		if landform == "great_island":
			var peak_seed: int = abs(hash(current_id))
			for peak_index in range(11):
				var peak_angle: float = TAU * float(peak_index) / 11.0 + float(peak_seed % 79) * 0.01
				var peak_distance: float = radius * (0.18 + float((peak_index * 7 + peak_seed) % 48) / 100.0)
				var peak_height: float = 8.0 + float((peak_index * 13 + peak_seed) % 150) / 10.0
				var peak_radius: float = radius * (0.07 + float(peak_index % 4) * 0.018)
				var peak_at := Vector3(cos(peak_angle) * peak_distance, peak_height * 0.5, sin(peak_angle) * peak_distance)
				_add_cylinder(island_root, peak_radius, peak_radius * 0.06, peak_height, peak_at, Color("718269") if peak_index % 3 else Color("797c75"))
			_add_cylinder(island_root, radius * 0.20, 0.0, 28.0, Vector3(-radius * 0.14, 14.0, -radius * 0.12), Color("747e70"))
		else:
			_add_cylinder(island_root, radius * 0.34, 0.0, 2.9, Vector3(-radius * 0.18, 3.0, -radius * 0.08), Color("607d4c"))
			_add_cylinder(island_root, radius * 0.24, 0.0, 2.1, Vector3(radius * 0.28, 2.65, radius * 0.12), Color("71865a"))
		var random_seed: int = abs(hash(current_id))
		var tree_count: int = 5 if landform == "great_island" else 7
		for index in range(tree_count):
			var angle: float = TAU * float(index) / float(tree_count) + float(random_seed % 31) * 0.01
			var distance: float = radius * (0.23 + float(index % 3) * 0.13)
			var tree_at := Vector3(cos(angle) * distance, 1.9, sin(angle) * distance)
			_add_cylinder(island_root, 0.10, 0.08, 1.2, tree_at + Vector3(0.0, 0.55, 0.0), Color("73553b"))
			_add_cylinder(island_root, 0.85, 0.04, 1.45, tree_at + Vector3(0.0, 1.7, 0.0), Color("326747"))

	var port: Dictionary = _find_port_for_island(current_id)
	if not port.is_empty():
		_build_port(island_root, port, Vector2(island.get("position", Vector2.ZERO)), radius)
	elif custom_model == null:
		_add_cylinder(island_root, radius * 0.16, radius * 0.05, 1.5, Vector3(radius * 0.42, 2.1, -radius * 0.35), Color("8a8272"))



func _attach_catalog_scene(parent: Node3D, category: String, identity: String, target_size_m: float) -> Node3D:
	var categories: Dictionary = _asset_catalog.get("categories", {})
	var entries: Array = categories.get(category, [])
	if entries.is_empty() or identity == "":
		return null
	var available: Array[Dictionary] = []
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var scene_path: String = str(entry.get("scene", ""))
		if scene_path != "" and ResourceLoader.exists(scene_path):
			available.append(entry)
	if available.is_empty():
		return null
	var chosen: Dictionary = available[posmod(abs(hash("%d:%s" % [int(GameState.world_state.get("seed", 0)), identity])), available.size())]
	var packed_scene: PackedScene = load(str(chosen.get("scene", ""))) as PackedScene
	if packed_scene == null:
		return null
	var instance: Node = packed_scene.instantiate()
	var wrapper := Node3D.new()
	wrapper.name = "Asset_" + identity.replace("/", "_").replace(":", "_")
	parent.add_child(wrapper)
	wrapper.add_child(instance)
	var reference_size: float = maxf(0.01, float(chosen.get("reference_size_m", target_size_m)))
	var asset_scale: float = target_size_m / reference_size * float(chosen.get("scale", 1.0))
	wrapper.scale = Vector3.ONE * asset_scale
	wrapper.rotation_degrees.y = float(chosen.get("rotation_y_degrees", 0.0))
	var offset: Array = chosen.get("offset_m", [0.0, 0.0, 0.0])
	if offset.size() >= 3:
		wrapper.position = Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
	return wrapper


func _find_port_for_island(island_id: String) -> Dictionary:
	for raw_port in _world_data.get("ports", {}).values():
		var port: Dictionary = raw_port
		if str(port.get("island_id", "")) == island_id:
			return port
	return {}


func _build_port(island_root: Node3D, port: Dictionary, island_position: Vector2, island_radius: float) -> void:
	var port_position: Vector2 = Vector2(port.get("position", island_position))
	var local_port: Vector2 = (port_position - island_position) * MAP_TO_METERS
	var outward_2d: Vector2 = Vector2.from_angle(float(port.get("harbor_angle", local_port.angle())))
	if outward_2d.length_squared() < 0.01:
		outward_2d = Vector2.RIGHT
	var outward := Vector3(outward_2d.x, 0.0, outward_2d.y)
	var registered_port: Node3D = _attach_catalog_scene(island_root, "ports", str(port.get("id", "port")), 8.0)
	if registered_port != null:
		registered_port.position += Vector3(local_port.x, 0.0, local_port.y)
		registered_port.rotation.y = atan2(outward.x, outward.z)
		return
	var pier_yaw: float = atan2(outward.x, outward.z)
	var pier_right := Vector3(outward.z, 0.0, -outward.x)
	var bay_radius: float = maxf(2.0, float(port.get("harbor_radius", island_radius * 0.18)) * MAP_TO_METERS)
	var bay_water := CylinderMesh.new()
	bay_water.top_radius = bay_radius
	bay_water.bottom_radius = bay_radius
	bay_water.height = 0.035
	bay_water.radial_segments = 32
	var bay_surface := MeshInstance3D.new()
	bay_surface.name = "NaturalHarborWater"
	bay_surface.mesh = bay_water
	bay_surface.material_override = _material(Color("247b91"), 0.35)
	bay_surface.position = Vector3(local_port.x, 0.05, local_port.y)
	island_root.add_child(bay_surface)
	var dock_start: Vector3 = Vector3(local_port.x, 0.12, local_port.y) + outward * 1.1
	var pier := _add_box(island_root, Vector3(1.45, 0.24, 7.2), dock_start + outward * 3.2, _material(Color("765238"), 0.95))
	pier.rotation.y = pier_yaw
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		for distance_value in [0.8, 3.5, 6.1]:
			var distance: float = float(distance_value)
			var piling_at: Vector3 = dock_start + outward * distance + pier_right * side * 0.58 + Vector3(0.0, -0.12, 0.0)
			_add_cylinder(island_root, 0.12, 0.12, 0.95, piling_at, Color("4b3829"))

	# Warehouses and small port buildings sit between the beach and the pier.
	var landward: Vector3 = -outward
	var settlement_center: Vector3 = Vector3(local_port.x, 0.0, local_port.y) + landward * 1.8
	var registered_building: Node3D = _attach_catalog_scene(island_root, "buildings", str(port.get("id", "port")) + "_warehouse", 2.6)
	if registered_building != null:
		registered_building.position += settlement_center + landward * 2.0 + Vector3(0.0, 1.0, 0.0)
	else:
		var wall := _material(Color("d8c8a0"), 0.93)
		var roof := _material(Color("9c4939"), 0.9)
		_add_box(island_root, Vector3(2.6, 1.25, 1.7), settlement_center + Vector3(0.0, 2.46, 0.0), wall)
		var warehouse_roof := _add_box(island_root, Vector3(2.9, 0.2, 1.95), settlement_center + Vector3(0.0, 3.18, 0.0), roof)
		warehouse_roof.rotation.z = deg_to_rad(-4.0)
		_add_box(island_root, Vector3(0.85, 0.7, 0.7), settlement_center + landward * 2.0 + Vector3(0.0, 2.18, 0.0), wall)
		_add_box(island_root, Vector3(1.0, 0.16, 0.85), settlement_center + landward * 2.0 + Vector3(0.0, 2.61, 0.0), _material(Color("bd7650"), 0.92))

	# A low-poly lighthouse marks the harbour approach; its body is built from
	# alternating painted sections so it remains recognizable at phone scale.
	var lighthouse_at: Vector3 = settlement_center + landward * (island_radius * 0.12)
	_add_cylinder(island_root, 0.58, 0.38, 2.5, lighthouse_at + Vector3(0.0, 1.4, 0.0), Color("e6dfc9"))
	_add_cylinder(island_root, 0.43, 0.43, 0.35, lighthouse_at + Vector3(0.0, 2.75, 0.0), Color("a74935"))
	_add_cylinder(island_root, 0.38, 0.34, 0.22, lighthouse_at + Vector3(0.0, 3.02, 0.0), Color("f2d789"))


func _sync_fog(ship_position: Vector2) -> void:
	var center := Vector2i(floori(ship_position.x / _chunk_size), floori(ship_position.y / _chunk_size))
	var explored_chunks: Dictionary = GameState.world_state.get("explored_chunks", {})
	if center == _fog_center and explored_chunks.size() == _fog_explored_count:
		for tile in _fog_tiles.values():
			(tile as Node3D).visible = _transition_factor < 0.35
		return
	_fog_center = center
	_fog_explored_count = explored_chunks.size()
	var keep_tiles: Dictionary = {}
	for chunk_y in range(center.y - FOG_RADIUS_CHUNKS, center.y + FOG_RADIUS_CHUNKS + 1):
		for chunk_x in range(center.x - FOG_RADIUS_CHUNKS, center.x + FOG_RADIUS_CHUNKS + 1):
			var chunk_key: String = "%d:%d" % [chunk_x, chunk_y]
			if explored_chunks.has(chunk_key):
				continue
			keep_tiles[chunk_key] = true
			var fog_tile: Node3D = _fog_tiles.get(chunk_key) as Node3D
			if fog_tile == null or not is_instance_valid(fog_tile):
				fog_tile = _create_fog_tile(chunk_x, chunk_y)
				_scene_root.add_child(fog_tile)
				_fog_tiles[chunk_key] = fog_tile
			fog_tile.visible = _transition_factor < 0.35
	for raw_key in _fog_tiles.keys():
		var chunk_key: String = str(raw_key)
		if keep_tiles.has(chunk_key):
			continue
		var stale_tile: Node3D = _fog_tiles[chunk_key] as Node3D
		if stale_tile != null and is_instance_valid(stale_tile):
			stale_tile.queue_free()
		_fog_tiles.erase(chunk_key)


func _create_fog_tile(chunk_x: int, chunk_y: int) -> Node3D:
	var tile := MeshInstance3D.new()
	tile.name = "UnknownSea_%d_%d" % [chunk_x, chunk_y]
	var plane := PlaneMesh.new()
	plane.size = Vector2(_chunk_size * MAP_TO_METERS, _chunk_size * MAP_TO_METERS)
	tile.mesh = plane
	var fog_material := StandardMaterial3D.new()
	fog_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fog_material.albedo_color = Color(0.035, 0.085, 0.13, 0.92)
	tile.material_override = fog_material
	tile.position = Vector3(
		(float(chunk_x) + 0.5) * _chunk_size * MAP_TO_METERS,
		FOG_HEIGHT,
		(float(chunk_y) + 0.5) * _chunk_size * MAP_TO_METERS
	)
	return tile


func _sync_traffic(traffic_renderer: Node, traffic_group: String) -> void:
	if traffic_renderer == null or not traffic_renderer.has_method("get_vessel_snapshots"):
		return
	var raw_snapshots: Variant = traffic_renderer.call("get_vessel_snapshots")
	if not (raw_snapshots is Array):
		return

	var keep_models: Dictionary = {}
	for raw_snapshot in raw_snapshots:
		if not (raw_snapshot is Dictionary):
			continue
		var vessel: Dictionary = raw_snapshot
		var vessel_id: String = str(vessel.get("id", ""))
		if vessel_id == "":
			continue
		var model_key: String = traffic_group + ":" + vessel_id
		keep_models[model_key] = true
		var model: Node3D = _traffic_models.get(model_key) as Node3D
		if model == null or not is_instance_valid(model):
			var identity: String = str(vessel.get("ship_type_id", vessel.get("kind", "merchant")))
			var target_length: float = maxf(0.6, float(vessel.get("length", 24.0)) * MAP_TO_METERS)
			model = _attach_catalog_scene(_scene_root, "ships", identity, target_length)
			if model == null:
				model = _make_traffic_ship(vessel)
				_scene_root.add_child(model)
			model.name = "Traffic_" + model_key.replace(":", "_").replace("/", "_")
			_traffic_models[model_key] = model
		var position: Vector2 = Vector2(vessel.get("position", Vector2.ZERO))
		var heading: Vector2 = Vector2(vessel.get("heading", Vector2.UP))
		if heading.length_squared() < 0.001:
			heading = Vector2.UP
		model.position = Vector3(position.x * MAP_TO_METERS, 0.12, position.y * MAP_TO_METERS)
		model.rotation.y = -heading.angle() - PI * 0.5

	for raw_model_key in _traffic_models.keys():
		var model_key: String = str(raw_model_key)
		if not model_key.begins_with(traffic_group + ":") or keep_models.has(model_key):
			continue
		var stale_model: Node3D = _traffic_models[model_key] as Node3D
		if stale_model != null and is_instance_valid(stale_model):
			stale_model.queue_free()
		_traffic_models.erase(model_key)


func _make_traffic_ship(vessel: Dictionary) -> Node3D:
	var length: float = maxf(0.6, float(vessel.get("length", 24.0)) * MAP_TO_METERS)
	var width: float = length * 0.28
	var accent: Color = vessel.get("color", Color("6da9bd"))
	var ship := Node3D.new()
	var hull_color: Color = Color("503629") if str(vessel.get("kind", "")) != "fleet" else Color("344a58")
	_add_box(ship, Vector3(width, 0.22, length), Vector3(0.0, 0.16, 0.0), _material(hull_color, 0.78))
	_add_box(ship, Vector3(width * 0.82, 0.10, length * 0.72), Vector3(0.0, 0.32, 0.02), _material(Color("b58955"), 0.84))
	_add_box(ship, Vector3(width * 0.48, 0.28, length * 0.20), Vector3(0.0, 0.49, length * 0.18), _material(accent.darkened(0.25), 0.8))
	var mast_height: float = maxf(0.7, length * 0.55)
	_add_cylinder(ship, maxf(0.025, length * 0.012), maxf(0.025, length * 0.012), mast_height, Vector3(0.0, mast_height * 0.5 + 0.42, -length * 0.04), Color("594434"))
	_add_sail(ship, Vector2(width * 0.82, mast_height * 0.62), Vector3(0.0, mast_height * 0.70 + 0.42, -length * 0.04), _material(Color("eee3c8").lerp(accent, 0.18), 0.92))
	return ship


func _update_camera(ship_position: Vector2, close_factor: float, delta: float) -> void:
	var velocity: Vector2 = Vector2(GameState.ship_state.get("velocity", Vector2.ZERO))
	var heading: float = float(GameState.ship_state.get(
		"heading",
		velocity.angle() if velocity.length_squared() > 1.0 else -PI * 0.5
	))
	# Godot's 3D ship points along local -Z. This yaw maps that nose to the same
	# direction as the 2D velocity vector (x right, y down).
	var yaw: float = -heading - PI * 0.5
	_ship.rotation.y = lerp_angle(_ship.rotation.y, yaw, 1.0 - exp(-delta * 5.0))
	var ship_world_position := Vector3(ship_position.x * MAP_TO_METERS, 0.0, ship_position.y * MAP_TO_METERS)
	_ship.position = ship_world_position

	var forward := Vector3(cos(heading), 0.0, sin(heading))
	var map_zoom: Vector2 = Vector2.ONE
	var map_camera: Camera2D = get_viewport().get_camera_2d()
	if map_camera != null:
		map_zoom = map_camera.zoom
	var map_view_height: float = get_viewport().get_visible_rect().size.y / maxf(map_zoom.y, 0.01) * MAP_TO_METERS
	var start_fov: float = 18.0
	var top_down_height: float = map_view_height / (2.0 * tan(deg_to_rad(start_fov * 0.5)))
	var camera_back: float = lerpf(0.0, 14.0, close_factor)
	var camera_height: float = lerpf(top_down_height, 4.4, close_factor)
	var desired_camera_position: Vector3 = ship_world_position - forward * camera_back + Vector3.UP * camera_height
	if _camera_initialized:
		_camera.position = _camera.position.lerp(desired_camera_position, 1.0 - exp(-delta * 3.5))
	else:
		_camera.position = desired_camera_position
		_camera_initialized = true
	var look_distance: float = lerpf(0.0, 7.0, close_factor)
	var focus: Vector3 = ship_world_position + forward * look_distance + Vector3.UP * (0.8 * close_factor)
	var map_up := Vector3(0.0, 0.0, -1.0)
	_camera.look_at(focus, map_up.lerp(Vector3.UP, close_factor).normalized())
	_camera.fov = lerpf(start_fov, 58.0, close_factor)



func _find_nearest_island(ship_position: Vector2) -> Dictionary:
	var closest: Dictionary = {}
	var best_gap: float = INF
	for island in _rendered_island_data.values():
		var island_position: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var radius: float = float(island.get("radius", 0.0))
		var gap: float = maxf(0.0, ship_position.distance_to(island_position) - radius)
		if gap < best_gap:
			best_gap = gap
			closest = island
	return closest


func _set_transition(target: float, delta: float) -> void:
	_transition_factor = lerpf(_transition_factor, target, 1.0 - exp(-delta * 1.7))
	# The transition changes only the camera: both the map view and close view
	# are rendered from this same 3D scene at the same world coordinates.
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _add_box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, bottom_radius: float, top_radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom_radius
	cylinder.top_radius = top_radius
	cylinder.height = height
	cylinder.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.material_override = _material(color, 0.92)
	instance.position = at
	parent.add_child(instance)
	return instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
