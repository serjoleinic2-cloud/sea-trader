extends "res://tests/test_base.gd"

func before_all() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func after_all() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_save_system_exists() -> void:
	assert_not_null(SaveSystem, "SaveSystem autoload should exist")

func test_save_returns_true() -> void:
	GameState.reset_to_defaults()
	GameState.player_state["money"] = 123.45
	var result: bool = SaveSystem.save_game()
	assert_true(result, "save_game() should return true")

func test_load_after_save_restores_money() -> void:
	GameState.reset_to_defaults()
	GameState.player_state["money"] = 123.45
	SaveSystem.save_game()
	GameState.reset_to_defaults()
	var ok: bool = SaveSystem.load_game()
	assert_true(ok, "load_game() should return true")
	assert_almost_eq(
		float(GameState.player_state.get("money", 0.0)),
		123.45, 0.001,
		"money should persist across save/load"
	)

func test_load_after_save_restores_level() -> void:
	GameState.reset_to_defaults()
	GameState.player_state["level"] = 5
	SaveSystem.save_game()
	GameState.reset_to_defaults()
	SaveSystem.load_game()
	assert_eq(int(GameState.player_state.get("level", 0)), 5, "level should persist")

func test_load_after_save_restores_vector2() -> void:
	GameState.reset_to_defaults()
	GameState.world_state["current_position"] = Vector2(100.0, 200.0)
	SaveSystem.save_game()
	GameState.reset_to_defaults()
	SaveSystem.load_game()
	assert_eq(
		GameState.world_state.get("current_position", Vector2.ZERO),
		Vector2(100.0, 200.0),
		"Vector2 position should persist"
	)

func test_migration_preserves_progress_and_settings() -> void:
	SaveSystem.save_game()
	var old_data: Dictionary = {
		"version": "0.0.0",
		"world_state": {"seed": 123},
		"player_state": {"money": 50.0, "level": 2},
		"settings_state": {"language": "ru"}
	}
	SaveSystem._write_json("user://saves/save_main.json", old_data)
	var ok: bool = SaveSystem.load_game()
	assert_true(ok, "load with migration should succeed")
	assert_eq(GameState.player_state.money, 50.0, "migration must preserve money")
	assert_eq(GameState.world_state.seed, 123, "migration must preserve seed")
	assert_eq(
		str(GameState.settings_state.get("language", "")),
		"ru",
		"language setting should survive migration fallback"
	)
