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

func test_migration_fallback_preserves_settings() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var old_data: Dictionary = {
		"version": "0.0.0",
		"player_state": {"money": 50.0, "level": 2},
		"settings_state": {"language": "ru"}
	}
	var f: FileAccess = FileAccess.open("user://saves/save_main.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(old_data))
		f.close()
	var mf: FileAccess = FileAccess.open("user://saves/save_meta.json", FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify({"version": "0.0.0", "timestamp": 0}))
		mf.close()
	var ok: bool = SaveSystem.load_game()
	assert_true(ok, "load with migration should succeed")
	assert_eq(
		str(GameState.settings_state.get("language", "")),
		"ru",
		"language setting should survive migration fallback"
	)
