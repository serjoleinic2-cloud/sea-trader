extends GutTest

func before_all():
	# Ensure clean state
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func after_all():
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func test_save_system_exists():
	assert_not_null(SaveSystem, "SaveSystem autoload should exist")

func test_save_and_load():
	# Modify state
	GameState.player_state.money = 123.45
	GameState.player_state.level = 5
	GameState.world_state.current_position = Vector2(100, 200)

	# Save
	var result := SaveSystem.save_game()
	assert_true(result, "Save should succeed")

	# Reset
	GameState.reset_to_defaults()
	assert_eq(GameState.player_state.money, 0.0, "State should be reset")
	assert_eq(GameState.world_state.current_position, Vector2.ZERO, "Position should be reset")

	# Load
	var load_result := SaveSystem.load_game()
	assert_true(load_result, "Load should succeed")
	assert_eq(GameState.player_state.money, 123.45, "Money should persist")
	assert_eq(GameState.player_state.level, 5, "Level should persist")
	assert_eq(GameState.world_state.current_position, Vector2(100, 200), "Vector2 should persist")

func test_migration_fallback():
	# Simulate old version save
	var old_data := {
		"version": "0.0.0",
		"player_state": {"money": 50.0, "level": 2},
		"settings_state": {"language": "ru"}
	}
	var file := FileAccess.open("user://saves/save_main.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(old_data))
	file.close()

	var meta := {"version": "0.0.0", "timestamp": 0}
	var mfile := FileAccess.open("user://saves/save_meta.json", FileAccess.WRITE)
	mfile.store_string(JSON.stringify(meta))
	mfile.close()

	var load_result := SaveSystem.load_game()
	assert_true(load_result, "Load with migration fallback should succeed")
	assert_eq(GameState.settings_state.language, "ru", "Settings should be preserved during fallback")
