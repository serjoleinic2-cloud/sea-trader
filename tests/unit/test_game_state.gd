extends "res://tests/test_base.gd"

func test_game_state_exists() -> void:
	assert_not_null(GameState, "GameState autoload should exist")

func test_default_player_level() -> void:
	GameState.reset_to_defaults()
	assert_eq(GameState.player_state.get("level", 0), 1, "Default player level should be 1")

func test_default_money() -> void:
	GameState.reset_to_defaults()
	assert_eq(GameState.player_state.get("money", -1.0), 0.0, "Default money should be 0")

func test_reset_clears_money() -> void:
	GameState.player_state["money"] = 999.0
	GameState.reset_to_defaults()
	assert_eq(GameState.player_state.get("money", -1.0), 0.0, "Reset should clear money")

func test_reset_restores_level() -> void:
	GameState.player_state["level"] = 99
	GameState.reset_to_defaults()
	assert_eq(GameState.player_state.get("level", 0), 1, "Reset should restore level to 1")

func test_ship_state_has_fuel_max() -> void:
	GameState.reset_to_defaults()
	assert_true(GameState.ship_state.has("fuel_max"), "ship_state must have fuel_max")

func test_ship_state_has_cargo_capacity() -> void:
	GameState.reset_to_defaults()
	assert_true(GameState.ship_state.has("cargo_capacity"), "ship_state must have cargo_capacity")
