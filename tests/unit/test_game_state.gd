extends GutTest

func test_game_state_exists():
	assert_not_null(GameState, "GameState autoload should exist")

func test_default_player_state():
	assert_eq(GameState.player_state.level, 1, "Default player level should be 1")
	assert_eq(GameState.player_state.money, 0.0, "Default money should be 0")

func test_reset_to_defaults():
	GameState.player_state.money = 999.0
	GameState.reset_to_defaults()
	assert_eq(GameState.player_state.money, 0.0, "Reset should clear money")
	assert_eq(GameState.player_state.level, 1, "Reset should restore level")
