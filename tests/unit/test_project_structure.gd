extends "res://tests/test_base.gd"

func before_each() -> void:
	GameState.reset_to_defaults()
	SaveSystem.delete_save()

func after_each() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_catalog_is_valid_and_returns_isolated_copies() -> void:
	assert_true(GameData.validate().is_empty())
	var ship: Dictionary = GameData.get_ship("ship_sloop")
	ship.cargo_capacity = -1
	ship.build_materials.clear()
	assert_gt(GameData.get_ship("ship_sloop").cargo_capacity, 0)
	assert_false(GameData.get_ship("ship_sloop").build_materials.is_empty())
	assert_true(GameData.get_ship("unknown").is_empty())

func test_validation_reports_duplicate_ids_bad_limits_and_unknown_materials() -> void:
	var ships: Dictionary = GameData.read(GameData.SHIPS)
	ships.ships.append(ships.ships[0].duplicate(true))
	ships.ships[0].cargo_capacity = -4
	ships.ships[0].min_crew = 30
	ships.ships[0].build_materials["resource_missing"] = 1
	var errors: Array[String] = load("res://core/config_validator.gd").new().validate(ships, GameData.read(GameData.GOODS), GameData.read("res://data/ports/building_catalog.json"), GameData.read("res://data/ports/production_recipes.json"))
	assert_gte(errors.size(), 4)
	assert_true("\n".join(errors).contains("duplicate"))
	assert_true("\n".join(errors).contains("unknown resource"))

func test_module_dependencies_are_sorted_and_cycles_rejected() -> void:
	var loader: RefCounted = load("res://core/module_loader.gd").new()
	var plan: Dictionary = loader.plan([{"id": "UI", "args": ["System"]}, {"id": "System", "args": ["$ship"]}])
	assert_true(plan.ok)
	assert_eq(plan.ordered[0].id, "System")
	assert_false(loader.plan([{"id": "A", "args": ["B"]}, {"id": "B", "args": ["A"]}]).ok)
	assert_false(loader.plan([{"id": "A", "args": ["missing"]}]).ok)
	assert_false(loader.plan([{"id": "A"}, {"id": "A"}]).ok)
	assert_false(loader.prepare([{"id": "Broken", "script": "res://systems/missing.gd"}]).ok)

func test_active_ship_uses_saved_type_and_preserves_saved_upgrades() -> void:
	GameState.ship_state.merge({"ship_id": "ship_barque", "cargo_capacity": 77, "fuel": 23.0, "hull": 48.0}, true)
	var ship: Node = load("res://scenes/game/ship/ship.tscn").instantiate()
	add_child(ship)
	assert_eq(ship._ship_data.id, "ship_barque")
	assert_eq(ship._ship_data.base_speed, GameData.get_ship("ship_barque").base_speed)
	assert_eq(GameState.ship_state.cargo_capacity, 77)
	assert_eq(GameState.ship_state.fuel, 23.0)
	assert_eq(GameState.ship_state.hull, 48.0)
	ship.free()

func test_unknown_saved_ship_stops_before_any_save_write() -> void:
	GameState.world_state.seed = 42
	GameState.world_state.world_gen_version = "1"
	GameState.ship_state.ship_id = "removed_ship"
	SaveSystem.save_game()
	var before: Dictionary = SaveSystem._read_json("user://saves/save_main.json")
	var main: Node = load("res://scenes/game/main.tscn").instantiate()
	add_child(main)
	assert_false(main._world_ready)
	assert_true(main.startup_error.contains("removed_ship"))
	assert_eq(SaveSystem._read_json("user://saves/save_main.json"), before)
	main.free()
