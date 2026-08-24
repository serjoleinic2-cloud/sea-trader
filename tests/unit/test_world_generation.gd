extends GutTest

## Phase 02 World Generation tests.
## Requires GUT addon. See tests/README.md for setup.

var _world_generator: Node

func before_all() -> void:
	_world_generator = preload("res://systems/world/world_generator.gd").new()


func test_same_seed_same_result() -> void:
	"""Deterministic: identical seed produces identical world."""
	var seed_val: int = 42
	var world_a: Dictionary = _world_generator.generate(seed_val)
	var world_b: Dictionary = _world_generator.generate(seed_val)

	assert_eq(world_a.seed, world_b.seed, "Seed should match")
	assert_eq(world_a.islands.size(), world_b.islands.size(), "Island count should match")
	assert_eq(world_a.ports.size(), world_b.ports.size(), "Port count should match")
	assert_eq(world_a.hazard_zones.size(), world_b.hazard_zones.size(), "Hazard count should match")

	# Check island positions match exactly
	for i in range(world_a.islands.size()):
		assert_eq(world_a.islands[i].position, world_b.islands[i].position,
			"Island %d position should match" % i)
		assert_eq(world_a.islands[i].radius, world_b.islands[i].radius,
			"Island %d radius should match" % i)


func test_different_seed_different_result() -> void:
	"""Different seeds should produce different worlds (with high probability)."""
	var world_a: Dictionary = _world_generator.generate(42)
	var world_b: Dictionary = _world_generator.generate(99)

	# At least one island position should differ
	var any_differs: bool = false
	var min_size: int = mini(world_a.islands.size(), world_b.islands.size())
	for i in range(min_size):
		if world_a.islands[i].position != world_b.islands[i].position:
			any_differs = true
			break

	assert_true(any_differs or world_a.islands.size() != world_b.islands.size(),
		"Different seeds should produce different island layouts")


func test_ports_have_unique_ids() -> void:
	"""All generated ports must have unique IDs."""
	var world: Dictionary = _world_generator.generate(123)
	var ids: Array = world.ports.keys()
	var unique_ids: Array = []
	for id in ids:
		if not unique_ids.has(id):
			unique_ids.append(id)
	assert_eq(ids.size(), unique_ids.size(), "All port IDs must be unique")


func test_ports_have_required_fields() -> void:
	"""Each port must have id, name, position, region, level, island_id, discovered, buildings."""
	var world: Dictionary = _world_generator.generate(456)
	for port_id in world.ports:
		var port: Dictionary = world.ports[port_id]
		assert_has(port, "id", "Port must have id")
		assert_has(port, "name", "Port must have name")
		assert_has(port, "position", "Port must have position")
		assert_has(port, "region", "Port must have region")
		assert_has(port, "level", "Port must have level")
		assert_has(port, "island_id", "Port must have island_id")
		assert_has(port, "discovered", "Port must have discovered")
		assert_has(port, "buildings", "Port must have buildings")
		assert_eq(port.discovered, false, "New ports should be undiscovered")


func test_world_state_receives_seed() -> void:
	"""GameState.WorldState must store the seed used for generation."""
	var test_seed: int = 777
	GameState.world_state.seed = test_seed
	assert_eq(GameState.world_state.seed, test_seed, "WorldState should store seed")


func test_regenerate_from_state() -> void:
	"""Regenerating from stored seed should produce identical world."""
	var original_seed: int = 888
	GameState.world_state.seed = original_seed

	var world_a: Dictionary = _world_generator.generate(original_seed)
	var world_b: Dictionary = _world_generator.regenerate_from_state()

	assert_eq(world_a.islands.size(), world_b.islands.size(),
		"Regenerated world should have same island count")
	for i in range(world_a.islands.size()):
		assert_eq(world_a.islands[i].position, world_b.islands[i].position,
			"Regenerated island %d position should match" % i)


func test_islands_within_world_bounds() -> void:
	"""All islands must be within world_size bounds."""
	var world: Dictionary = _world_generator.generate(100)
	var world_size: Vector2i = world.world_size
	for island in world.islands:
		var pos: Vector2i = island.position
		assert_true(pos.x >= 0 and pos.x <= world_size.x,
			"Island x position within bounds")
		assert_true(pos.y >= 0 and pos.y <= world_size.y,
			"Island y position within bounds")


func test_ports_on_islands() -> void:
	"""Each port must reference a valid island."""
	var world: Dictionary = _world_generator.generate(200)
	var island_ids: Array = []
	for island in world.islands:
		island_ids.append(island.id)

	for port_id in world.ports:
		var port: Dictionary = world.ports[port_id]
		assert_true(island_ids.has(port.island_id),
			"Port %s must reference a valid island" % port_id)


func test_hazard_zones_defined_not_active() -> void:
	"""Hazard zones should exist but be inactive in Phase 02."""
	var world: Dictionary = _world_generator.generate(300)
	assert_true(world.hazard_zones.size() > 0,
		"World should have hazard zones defined")
	for zone in world.hazard_zones:
		assert_has(zone, "active", "Hazard zone must have active field")
		assert_eq(zone.active, false, "Hazard zones should be inactive in Phase 02")
