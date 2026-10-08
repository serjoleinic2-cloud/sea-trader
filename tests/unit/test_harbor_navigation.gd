extends "res://tests/test_base.gd"

func test_indexed_shores_match_collision_queries_and_remote_piers() -> void:
	var indexed: Dictionary = load("res://systems/world/home_harbor_layout.gd").new().decorate(_fixture(), "home_port")
	var plain: Dictionary = indexed.duplicate(true)
	for island in plain.islands:
		for key in ["navigation_bounds", "navigation_obstacle_bounds", "navigation_coast_edge_bounds", "navigation_coast_cells"]:
			island.erase(key)
	var indexed_guard = load("res://systems/ship/ship_physics.gd").new()
	var plain_guard = load("res://systems/ship/ship_physics.gd").new()
	indexed_guard.set_collision_data_provider(func(): return indexed)
	plain_guard.set_collision_data_provider(func(): return plain)
	var center: Vector2 = Vector2(indexed.islands[0].position)
	var radius: float = float(indexed.islands[0].radius)
	var mismatch := ""
	for x in range(-4, 5):
		for y in range(-4, 5):
			var start := center + Vector2(x, y) * radius * 0.35
			for displacement in [Vector2(3, 0), Vector2(0, -3), Vector2(256, 256), Vector2(-256, -256), Vector2(radius * 2.4, 0), Vector2(0, -radius * 2.4)]:
				var finish: Vector2 = start + displacement
				if indexed_guard.is_navigation_move_blocked(start, finish) != plain_guard.is_navigation_move_blocked(start, finish):
					mismatch = "Collision changed for %s -> %s" % [start, finish]
	assert_eq(mismatch, "", "Indexed short and long moves preserve shore, reef and pier collisions: " + mismatch)
	# Piers may extend outside an island's circular radius; include them in bounds.
	var pier := PackedVector2Array([Vector2(400, -40), Vector2(500, -40), Vector2(500, 40), Vector2(400, 40)])
	var remote: Dictionary = preload("res://systems/navigation/navigation_collision_index.gd").prepare({"islands": [{"position": Vector2.ZERO, "radius": 20.0, "navigation_obstacles": [pier]}]})
	indexed_guard.set_collision_data_provider(func(): return remote)
	assert_true(indexed_guard.is_navigation_move_blocked(Vector2(300, 0), Vector2(600, 0)), "Index keeps piers beyond the island radius solid")
	indexed_guard.free()
	plain_guard.free()

func test_solid_piers_block_crossing_and_allow_legacy_escape() -> void:
	var world: Dictionary = load("res://systems/world/home_harbor_layout.gd").new().decorate(_fixture(), "home_port")
	var guard = load("res://systems/ship/ship_physics.gd").new()
	var pier: PackedVector2Array = world.islands[0].navigation_obstacles[0]
	var obstacles: Array = [{"radius": 0.0, "navigation_obstacles": [pier]}]
	guard.set_collision_data_provider(func(): return {"islands": obstacles})
	var center := (pier[0] + pier[2]) * 0.5
	var along := (pier[1] - pier[0]).normalized()
	var across := (pier[3] - pier[0]).normalized()
	assert_true(guard.is_navigation_move_blocked(center - across * 120, center + across * 120), "A long step cannot tunnel through a pier")
	assert_false(guard.is_navigation_move_blocked(center, center + across * 120), "Old saves inside a pier can escape toward water")
	assert_true(guard.is_navigation_move_blocked(center - across * 15, center + across * 120), "Escape cannot cross deeper into the pier first")
	assert_false(guard.is_navigation_move_blocked(center + across * 120 - along * 160, center + across * 120 + along * 160), "Ships can sail alongside a pier with clearance")
	var route: PackedVector2Array = load("res://systems/navigation/coast_route_planner.gd").new().plan(center - across * 120, center + across * 120, obstacles, Callable(guard, "is_navigation_move_blocked"))
	assert_gt(route.size(), 1, "Autopilot must route around solid pier geometry")
	guard.free()

func test_foreign_city_keeps_its_open_harbor_channel_and_port_range() -> void:
	var raw := _fixture()
	# Keep the fixture's spare island away from the foreign city's expanded footprint.
	raw.islands[1].position = Vector2(12000, 0)
	raw.islands.append({"id": "foreign", "position": Vector2(6000, 0), "radius": 1200.0})
	raw.ports["foreign_port"] = {"id": "foreign_port", "island_id": "foreign", "position": Vector2(6000, 840), "harbor_angle": PI * 0.5, "harbor_type": "coastal"}
	var world: Dictionary = load("res://systems/world/home_harbor_layout.gd").new().decorate(raw, "home_port")
	var harbor: Dictionary = world.islands[2]
	assert_true(bool(harbor.get("port_city", false)), "eligible island receives its port settlement")
	assert_almost_eq(float(harbor.get("bay_width", 0.0)), 0.34, 0.001, "foreign city entrance keeps its designed width")
	var guard = load("res://systems/ship/ship_physics.gd").new()
	guard.set_collision_data_provider(func(): return {"islands": world.islands})
	var anchor: Vector2 = world.ports.foreign_port.position
	var current: Vector2 = anchor + Vector2.from_angle(PI * 0.5) * 450.0
	for step in range(30):
		var next: Vector2 = current.move_toward(anchor, 15.0)
		assert_false(guard.is_navigation_move_blocked(current, next), "the straight marked approach is clear of land and fixed piers")
		current = next
	assert_lte(current.distance_to(anchor), 15.0, "the player can reach the dock interaction radius")
	guard.free()

func test_fleet_finds_free_water_when_port_anchor_is_occupied() -> void:
	var fleet = load("res://systems/world/fleet_traffic_renderer.gd").new()
	add_child(fleet)
	fleet.initialize(_fixture())
	var obstacles: Array = [{"position": Vector2(0, 175), "length": 180.0}]
	var berth: Vector2 = fleet._free_water_position(Vector2(0, 175), 180.0, obstacles)
	assert_true(fleet._clearance_at(berth, 180.0, obstacles), "Anchored fleet ships need free water and hull clearance")
	assert_false(fleet._clearance_segment(Vector2(-500, 175), Vector2(500, 175), 180.0, obstacles), "A movement cannot pass through a vessel between its endpoints")
	fleet.free()

func _fixture() -> Dictionary:
	return {"seed": 41, "islands": [{"id": "home", "position": Vector2.ZERO, "radius": 250.0}, {"id": "other", "position": Vector2(6000, 0), "radius": 200.0}], "ports": {"home_port": {"id": "home_port", "island_id": "home", "position": Vector2(0, 175), "harbor_angle": PI * 0.5}}}

func test_city_layout_preserves_anchors_and_has_one_safe_entrance() -> void:
	var raw := _fixture()
	var before := raw.duplicate(true)
	var layout = load("res://systems/world/home_harbor_layout.gd").new()
	var world: Dictionary = layout.decorate(raw, "home_port")
	assert_eq(raw, before, "Presentation cannot rewrite generated data")
	assert_eq(world.ports.home_port.position, raw.ports.home_port.position)
	assert_eq(world.seed, raw.seed)
	assert_eq(world, layout.decorate(raw, "home_port"), "City layout must be deterministic")
	var home: Dictionary = world.islands[0]
	assert_gte(float(home.visual_radius), 1000.0, "Capital footprint must be much larger than a starter ship")
	var guard = load("res://systems/ship/ship_physics.gd").new()
	guard.set_collision_data_provider(func(): return {"islands": world.islands})
	var center := Vector2(home.position)
	var radius := float(home.visual_radius)
	var forward := Vector2.from_angle(float(home.bay_angle))
	var side := forward.orthogonal()
	var port := Vector2(world.ports.home_port.position)
	assert_false(guard.is_navigation_move_blocked(center + forward * radius * 1.4, port), "Wide marked entrance reaches the saved port")
	assert_true(guard.is_navigation_move_blocked(center - forward * radius * 1.4, port), "Rear cliffs cannot be crossed")
	assert_true(guard.is_navigation_move_blocked(center + side * radius * 1.3, center + side * radius * 1.02), "Outer reefs block lateral entry")
	var start := center - forward * radius * 1.4
	var path: PackedVector2Array = load("res://systems/navigation/coast_route_planner.gd").new().plan(start, port, world.islands, Callable(guard, "is_navigation_move_blocked"))
	assert_gt(path.size(), 1, "A ship arriving from behind must go around the island")
	for point in path:
		assert_false(guard.is_navigation_move_blocked(start, point), "Every planned leg must avoid land and reef")
		start = point
	guard.free()

func test_ambient_traders_have_large_distinct_hulls_and_never_cross_shore() -> void:
	var saved_world := GameState.world_state.duplicate(true)
	var saved_ship := GameState.ship_state.duplicate(true)
	GameState.world_state.home_port_id = "home_port"
	GameState.ship_state.position = Vector2(-10000, -10000)
	GameState.ship_state.ship_id = "ship_tanker"
	var world: Dictionary = load("res://systems/world/home_harbor_layout.gd").new().decorate(_fixture(), "home_port")
	var traffic = load("res://systems/world/trader_traffic_renderer.gd").new()
	add_child(traffic)
	traffic.initialize(world)
	var guard = load("res://systems/ship/ship_physics.gd").new()
	guard.set_collision_data_provider(func(): return {"islands": world.islands})
	var types: Dictionary = {}
	var minimum: float = float(GameData.read("res://data/world/ship_visuals.json").ships.ship_tanker.display_length) / 0.04
	for snapshot in traffic.get_vessel_snapshots():
		types[snapshot.ship_type_id] = true
		assert_gte(float(snapshot.length), minimum, "Merchants must not look like toy boats beside the player")
	assert_gt(types.size(), 3, "Merchant hulls must differ")
	var moved := false
	var entered := false
	var safe := true
	var spaced := true
	var capacity_respected := true
	for step in range(160):
		var before: Array = traffic.get_vessel_snapshots()
		traffic._process(0.5)
		var after: Array = traffic.get_vessel_snapshots()
		for index in range(6):
			for other in range(index + 1, 6):
				if Vector2(after[index].position).distance_to(after[other].position) < float(after[index].length) + float(after[other].length):
					spaced = false
			if guard.is_navigation_move_blocked(before[index].position, after[index].position):
				safe = false
			moved = moved or Vector2(before[index].position).distance_to(after[index].position) > 0.1
			entered = entered or Vector2(after[index].position).distance_to(world.ports.home_port.position) < float(world.islands[0].visual_radius) * 0.4
		capacity_respected = capacity_respected and traffic._reserved_berths() <= traffic.MAX_HARBOR_SHIPS
	assert_true(moved, "Merchants must actually sail")
	assert_true(safe, "All simulated merchant steps must avoid land and reefs")
	assert_true(spaced, "Ships must retain a hull-sized safety gap throughout harbor traffic")
	assert_true(entered, "Merchants must reach the harbor through its entrance")
	assert_true(capacity_respected, "Only the configured number of ships can reserve harbor berths")
	guard.free()
	traffic.free()
	GameState.world_state = saved_world
	GameState.ship_state = saved_ship
