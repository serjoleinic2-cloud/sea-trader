extends "res://tests/test_base.gd"

var career = preload("res://systems/progression/career_system.gd").new()

func before_each() -> void:
	GameState.reset_to_defaults()
	career._ready()

func after_each() -> void:
	GameState.reset_to_defaults()

func after_all() -> void:
	career.free()

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

func test_new_career_curve_stretches_later_ranks() -> void:
	GameState.player_state.stats["total_deliveries"] = 90
	assert_eq(career.get_activity_score(), 450, "test activity score is stable")
	assert_lt(career.get_command_rank(), 21, "450 activity no longer reaches Navigator")
	GameState.player_state.stats["total_deliveries"] = 150
	assert_eq(career.get_command_rank(), 21, "Navigator begins at the retuned threshold")
	assert_eq(career.get_command_progress().get("next_activity", 0), 840, "next Navigator rank takes a longer step")

func test_legacy_rank_is_preserved_and_rewards_scale() -> void:
	GameState.player_state.stats["total_deliveries"] = 90
	GameState.progression_state["career"] = {"highest_rank": 21, "rank_floor_activity": 450, "highest_rewarded_rank": 20, "rank_rewards": [], "total_reward_coins": 0}
	assert_eq(career.get_command_rank(), 21, "retuning never removes an already earned rank")
	assert_eq(career.get_command_progress().get("next_activity", 0), 840, "legacy rank keeps the longer future milestone")
	assert_eq(career.get_rank_reward(2).get("coins", 0), 45, "early rank reward")
	assert_eq(career.get_rank_reward(10).get("coins", 0), 375, "ten-rank milestone adds a bonus")
	assert_eq(career.get_rank_reward(50).get("coins", 0), 775, "later rank rewards increase")
