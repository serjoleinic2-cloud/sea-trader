extends "res://tests/test_base.gd"

var _main: Node


func before_each() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	_main = null


func after_each() -> void:
	if is_instance_valid(_main):
		_main.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()


func _seed_progress() -> void:
	GameState.world_state.seed = 42
	GameState.world_state.world_gen_version = "1"
	GameState.world_state.current_position = Vector2(321, 654)
	GameState.world_state.current_region = "eastern_archipelago"
	GameState.world_state.explored_region_ids = ["eastern_archipelago"]
	GameState.world_state.destination_port_id = "port_b"
	GameState.player_state.discovered_port_ids = ["port_a", "port_b"]
	GameState.port_state = {"port_a": {"discovered": true, "level": 3,
		"buildings": {"dock": {"level": 2, "damage_hp": 71}}, "relationship": 8.0}}
	GameState.known_routes_state = {"port_a--port_b": {
		"port_a_id": "port_a", "port_b_id": "port_b", "distance": 1200.0,
		"risk_level": "low", "discovered_timestamp": 1234, "times_traveled": 2}}
	GameState.voyage_state.merge({"active": true, "route": ["port_a", "port_b"],
		"current_leg": 0, "start_port_id": "port_a", "destination_port_id": "port_b",
		"elapsed_time_seconds": 17.5, "total_distance": 350.0,
		"cargo": [{"resource_id": "resource_timber", "quantity": 5}],
		"fuel_at_start": 90.0, "hull_at_start": 85.0,
		"contract_id": "test_contract", "status": "sailing"}, true)
	GameState.ship_state.merge({"ship_id": "ship_sloop", "position": Vector2.ZERO,
		"velocity": Vector2(3, 4), "fuel": 37.0, "hull": 61.0,
		"engine": 80.0, "steering": 75.0, "cargo_hold": 70.0,
		"cargo": [{"resource_id": "resource_timber", "quantity": 5}]}, true)


func _launch() -> void:
	_main = preload("res://scenes/game/main.tscn").instantiate()
	add_child(_main)


func test_new_game_initializes_and_saves_identity() -> void:
	_launch()
	assert_true(_main._world_ready)
	assert_true(_main._is_new_game)
	assert_ne(GameState.world_state.seed, 0)
	assert_eq(GameState.world_state.world_gen_version, "1")
	assert_true(SaveSystem.has_save())
	assert_true(GameState.port_state.is_empty())
	assert_true(GameState.known_routes_state.is_empty())
	assert_false(GameState.voyage_state.active)


func test_full_save_load_round_trip() -> void:
	_seed_progress()
	var snapshot: Dictionary = SaveSystem._serialize_game_state()
	assert_true(SaveSystem.save_game())
	GameState.reset_to_defaults()
	assert_true(SaveSystem.load_game())
	var restored: Dictionary = SaveSystem._serialize_game_state()
	# Timestamp intentionally records this save, not the previous session.
	snapshot.world_state.last_session_timestamp = restored.world_state.last_session_timestamp
	assert_eq(restored, snapshot, "all state survives JSON round trip")
	assert_gt(int(GameState.world_state.last_session_timestamp), 0)


func test_real_launch_preserves_knowledge_voyage_and_ship() -> void:
	_seed_progress()
	SaveSystem.save_game()
	var ports: Dictionary = GameState.port_state.duplicate(true)
	var routes: Dictionary = GameState.known_routes_state.duplicate(true)
	var voyage: Dictionary = GameState.voyage_state.duplicate(true)
	var ship: Dictionary = GameState.ship_state.duplicate(true)
	GameState.reset_to_defaults()
	_launch()
	assert_true(_main._world_ready)
	assert_false(_main._is_new_game)
	assert_eq(GameState.world_state.seed, 42)
	assert_eq(GameState.world_state.current_position, Vector2(321, 654))
	assert_eq(GameState.world_state.current_region, "eastern_archipelago")
	assert_eq(GameState.port_state, ports)
	assert_eq(GameState.known_routes_state, routes)
	assert_eq(GameState.voyage_state, voyage)
	assert_eq(GameState.ship_state, ship, "spawn must not refill fuel, repair or erase velocity")
	assert_almost_eq(_main._ship._physics.get_speed(), 5.0, 0.001)


func test_empty_saved_knowledge_and_zero_seed_are_valid() -> void:
	_seed_progress()
	GameState.world_state.seed = 0
	GameState.port_state = {}
	GameState.player_state.discovered_port_ids = []
	SaveSystem.save_game()
	_launch()
	assert_true(_main._world_ready)
	assert_false(_main._is_new_game)
	assert_eq(GameState.world_state.seed, 0)
	assert_true(GameState.port_state.is_empty(), "empty saved knowledge must not be repopulated")
	assert_true(GameState.player_state.discovered_port_ids.is_empty())


func test_generator_determinism_and_no_knowledge_writes() -> void:
	_seed_progress()
	var snapshot: Dictionary = SaveSystem._serialize_game_state()
	var generator: Node = preload("res://systems/world/world_generator.gd").new()
	var first: Dictionary = generator.generate(42)
	var second: Dictionary = generator.generate(42)
	assert_eq(first, second, "all geometry, names, resources and hazards must match")
	assert_eq(SaveSystem._serialize_game_state(), snapshot, "generation cannot mutate state")
	generator.free()


func test_legacy_migration_keeps_progress_and_removes_geometry() -> void:
	_seed_progress()
	var legacy: Dictionary = SaveSystem._serialize_game_state()
	legacy.version = "0.1.0"
	legacy.world_state.erase("world_gen_version")
	legacy.erase("known_routes_state")
	legacy.erase("voyage_state")
	legacy.player_state.discovered_port_ids = []
	legacy.port_state.port_a.merge({"x": 1.0, "y": 2.0, "name": "Old Port",
		"discovery_radius": 150.0}, true)
	SaveSystem.save_game()
	SaveSystem._write_json("user://saves/save_main.json", legacy)
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.world_state.seed, 42)
	assert_eq(GameState.world_state.world_gen_version, "1")
	assert_eq(GameState.port_state.port_a.level, 3)
	assert_eq(GameState.port_state.port_a.buildings.dock.damage_hp, 71)
	assert_eq(GameState.port_state.port_a.relationship, 8.0)
	assert_eq(GameState.player_state.discovered_port_ids, ["port_a"])
	assert_false(GameState.port_state.port_a.has("x"))
	assert_false(GameState.port_state.port_a.has("name"))
	assert_true(GameState.known_routes_state.is_empty())
	assert_eq(GameState.voyage_state, GameState.default_voyage_state())


func test_corrupt_main_uses_backup_without_destroying_it() -> void:
	_seed_progress()
	SaveSystem.save_game()
	SaveSystem.save_game()
	var backup: Dictionary = SaveSystem._read_json("user://saves/save_backup.json")
	SaveSystem._write_json("user://saves/save_main.json", {"broken": true})
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.world_state.seed, 42)
	assert_true(SaveSystem.save_game())
	assert_eq(SaveSystem._read_json("user://saves/save_backup.json"), backup)


func test_unsupported_save_version_does_not_reset_or_overwrite() -> void:
	_seed_progress()
	SaveSystem.save_game()
	var future: Dictionary = SaveSystem._serialize_game_state()
	future.version = "99.0.0"
	SaveSystem._write_json("user://saves/save_main.json", future)
	var snapshot: Dictionary = SaveSystem._serialize_game_state()
	_launch()
	assert_false(_main._world_ready)
	assert_false(_main._is_new_game)
	assert_eq(SaveSystem._serialize_game_state(), snapshot)
	assert_eq(SaveSystem._read_json("user://saves/save_main.json"), future)


func test_backup_only_is_an_existing_game() -> void:
	_seed_progress()
	SaveSystem.save_game()
	var backup: Dictionary = SaveSystem._serialize_game_state()
	SaveSystem.delete_save()
	SaveSystem._write_json("user://saves/save_backup.json", backup)
	_launch()
	assert_true(_main._world_ready)
	assert_false(_main._is_new_game)
	assert_eq(GameState.world_state.seed, 42)


func test_both_invalid_saves_stop_without_creating_new_game() -> void:
	_seed_progress()
	SaveSystem.save_game()
	SaveSystem._write_json("user://saves/save_main.json", {"broken": true})
	SaveSystem._write_json("user://saves/save_backup.json", {"broken": true})
	_launch()
	assert_false(_main._world_ready)
	assert_false(_main._is_new_game)
	assert_eq(GameState.world_state.seed, 42)
	assert_eq(SaveSystem._read_json("user://saves/save_main.json"), {"broken": true})


func test_unsupported_world_version_stops_before_spawn_and_save() -> void:
	_seed_progress()
	GameState.world_state.world_gen_version = "999"
	SaveSystem.save_game()
	var saved: Dictionary = SaveSystem._read_json("user://saves/save_main.json")
	_launch()
	assert_false(_main._world_ready)
	assert_eq(_main._ship, null)
	assert_eq(GameState.world_state.world_gen_version, "999")
	assert_eq(SaveSystem._read_json("user://saves/save_main.json"), saved)


func test_pause_saves_current_voyage() -> void:
	_seed_progress()
	SaveSystem.save_game()
	_launch()
	GameState.voyage_state.elapsed_time_seconds = 99.5
	GameState.ship_state.position = Vector2(10, 20)
	_main._notification(NOTIFICATION_APPLICATION_PAUSED)
	GameState.reset_to_defaults()
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.voyage_state.elapsed_time_seconds, 99.5)
	assert_eq(GameState.ship_state.position, Vector2(10, 20))
