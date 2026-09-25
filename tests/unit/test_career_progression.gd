extends "res://tests/test_base.gd"

var career = preload("res://systems/progression/career_system.gd").new()

func before_each() -> void:
	GameState.reset_to_defaults()
	career._ready()

func after_each() -> void:
	GameState.reset_to_defaults()

func test_large_cargo_has_diminishing_progress() -> void:
	var stats: Dictionary = GameState.player_state.stats
	stats["total_sales"] = 50
	stats["cargo_units_moved"] = 50
	var small_batch_score: int = career.get_activity_score()
	stats["total_sales"] = 900
	stats["cargo_units_moved"] = 900
	var large_batch_score: int = career.get_activity_score()
	assert_gt(large_batch_score, small_batch_score, "a larger completed sale still advances a captain")
	assert_lt(large_batch_score, small_batch_score * 4, "18 times the cargo must not award 18 times the career progress")
	assert_lt(large_batch_score, 150, "one large sale must not skip the first promotion")
