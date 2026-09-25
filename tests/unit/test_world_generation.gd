extends "res://tests/test_base.gd"

var _gen: Node

func before_all() -> void:
	_gen = preload("res://systems/world/world_generator.gd").new()

func after_all() -> void:
	if is_instance_valid(_gen):
		_gen.free()

func test_same_seed_same_island_count() -> void:
	var a: Dictionary = _gen.generate(42)
	var b: Dictionary = _gen.generate(42)
	assert_eq(a.islands.size(), b.islands.size(), "same seed: island count must match")

func test_same_seed_same_port_count() -> void:
	var a: Dictionary = _gen.generate(42)
	var b: Dictionary = _gen.generate(42)
	assert_eq(a.ports.size(), b.ports.size(), "same seed: port count must match")

func test_same_seed_same_island_positions() -> void:
	var a: Dictionary = _gen.generate(42)
	var b: Dictionary = _gen.generate(42)
	for i in range(a.islands.size()):
		assert_eq(
			a.islands[i].position,
			b.islands[i].position,
			"same seed: island %d position must match" % i
		)

func test_different_seeds_differ() -> void:
	var a: Dictionary = _gen.generate(42)
	var b: Dictionary = _gen.generate(99)
	var differs: bool = false
	var n: int = mini(a.islands.size(), b.islands.size())
	for i in range(n):
		if a.islands[i].position != b.islands[i].position:
			differs = true
			break
	assert_true(
		differs or a.islands.size() != b.islands.size(),
		"different seeds should produce different worlds"
	)

func test_ports_unique_ids() -> void:
	var world: Dictionary = _gen.generate(123)
	var ids: Array = world.ports.keys()
	var seen: Array = []
	for id in ids:
		if not seen.has(id):
			seen.append(id)
	assert_eq(ids.size(), seen.size(), "all port IDs must be unique")

func test_ports_have_required_fields() -> void:
	var world: Dictionary = _gen.generate(456)
	for port_id in world.ports:
		var port: Dictionary = world.ports[port_id]
		assert_has(port, "id",         "port must have id")
		assert_has(port, "name",       "port must have name")
		assert_has(port, "position",   "port must have position")
		assert_has(port, "region",     "port must have region")
		assert_has(port, "level",      "port must have level")
		assert_has(port, "island_id",  "port must have island_id")
		assert_has(port, "buildings",  "port must have buildings")
		assert_false(port.has("discovered"), "generator must not produce player discovery")

func test_world_state_stores_seed() -> void:
	GameState.world_state["seed"] = 777
	assert_eq(int(GameState.world_state.get("seed", 0)), 777, "WorldState must store seed")

func test_regenerate_from_state_matches() -> void:
	GameState.world_state["seed"] = 888
	var a: Dictionary = _gen.generate(888)
	var b: Dictionary = _gen.regenerate_from_state()
	assert_eq(a.islands.size(), b.islands.size(), "regenerated world must have same island count")
	for i in range(a.islands.size()):
		assert_eq(
			a.islands[i].position,
			b.islands[i].position,
			"regenerated island %d position must match" % i
		)

func test_islands_within_bounds() -> void:
	var world: Dictionary = _gen.generate(100)
	var ws: Vector2i = world.world_size
	for island in world.islands:
		var pos: Vector2i = island.position
		assert_true(pos.x >= 0 and pos.x <= ws.x, "island x within world bounds")
		assert_true(pos.y >= 0 and pos.y <= ws.y, "island y within world bounds")

func test_v2_spreads_islands_across_all_sea_sectors_without_overlap() -> void:
	var world: Dictionary = _gen.generate(5150)
	var sector_counts: Array[int] = [0, 0, 0, 0]
	for island in world.islands:
		var position: Vector2 = Vector2(island.position)
		var sector_x: int = 0 if position.x < 2048.0 else 1
		var sector_y: int = 0 if position.y < 2048.0 else 1
		sector_counts[sector_y * 2 + sector_x] += 1
	for sector_count in sector_counts:
		assert_true(sector_count >= 2, "every sea sector should contain islands")
	for first_index in range(world.islands.size()):
		for second_index in range(first_index + 1, world.islands.size()):
			var first: Dictionary = world.islands[first_index]
			var second: Dictionary = world.islands[second_index]
			var coast_gap: float = Vector2(first.position).distance_to(Vector2(second.position)) - float(first.radius) - float(second.radius)
			assert_true(coast_gap >= 300.0, "island shorelines should have navigable water between them")

func test_v1_map_migration_preserves_port_identity_and_shore_offsets() -> void:
	var legacy: Dictionary = _gen.generate(7351, 1)
	var first_port_id: String = str(legacy.ports.keys()[0])
	var ship_position: Vector2 = Vector2(legacy.ports[first_port_id].position)
	var migrated: Dictionary = _gen.migrate_world_to_current(7351, 1, ship_position)
	assert_true(bool(migrated.get("ok", false)), "legacy map should migrate")
	var world: Dictionary = migrated.world_data
	assert_eq(world.ports.keys().size(), legacy.ports.keys().size(), "migration keeps all ports")
	for port_id in legacy.ports:
		assert_true(world.ports.has(port_id), "migration keeps port id %s" % port_id)
		assert_eq(world.ports[port_id].name, legacy.ports[port_id].name, "migration keeps port name")
		var old_island: Dictionary = {}
		var new_island: Dictionary = {}
		for island in legacy.islands:
			if island.id == legacy.ports[port_id].island_id:
				old_island = island
		for island in world.islands:
			if island.id == world.ports[port_id].island_id:
				new_island = island
		assert_eq(
			Vector2(world.ports[port_id].position) - Vector2(new_island.position),
			Vector2(legacy.ports[port_id].position) - Vector2(old_island.position),
			"port stays at the same point on its island"
		)

func test_ports_reference_valid_islands() -> void:
	var world: Dictionary = _gen.generate(200)
	var island_ids: Array = []
	for island in world.islands:
		island_ids.append(island.id)
	for port_id in world.ports:
		var port: Dictionary = world.ports[port_id]
		assert_true(
			island_ids.has(port.get("island_id", "")),
			"port %s must reference a valid island" % port_id
		)

func test_hazard_zones_inactive() -> void:
	var world: Dictionary = _gen.generate(300)
	assert_true(world.hazard_zones.size() > 0, "world should have hazard zones defined")
	for zone in world.hazard_zones:
		assert_has(zone, "active", "hazard zone must have active field")
		assert_eq(zone.get("active", true), false, "hazard zones should be inactive in Phase 02")
