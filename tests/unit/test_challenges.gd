extends "res://tests/test_base.gd"

class PortsStub extends Node:
	func get_all_port_ids() -> Array:
		return ["home", "remote", "third"]

var _ports: Node
var _career: Node
var _rewards: Node
var _challenges: Node

func before_each() -> void:
	SaveSystem.delete_save()
	GameState.reset_to_defaults()
	GameState.world_state.seed = 42
	GameState.player_state.discovered_port_ids = ["home", "remote"]
	GameState.player_state.stats = {"total_sales": 500, "total_distance": 9000, "total_voyages": 10}
	_ports = PortsStub.new()
	_career = load("res://systems/progression/career_system.gd").new()
	_rewards = load("res://systems/rewards/reward_system.gd").new()
	_challenges = load("res://systems/challenges/challenge_system.gd").new()
	for node in [_ports, _career, _rewards, _challenges]:
		add_child(node)
	_challenges.initialize(_ports, _career, _rewards)

func after_each() -> void:
	for node in [_challenges, _rewards, _career, _ports]:
		node.free()
	SaveSystem.delete_save()
	GameState.reset_to_defaults()

func _finish(id: String) -> void:
	var challenge: Dictionary = GameState.economy_state.challenges.slots[id]
	for goal in challenge.goals:
		GameState.player_state.stats[goal.stat] = float(challenge.baseline.get(goal.stat, 0)) + float(goal.target)
	_challenges._update_completion()

func test_three_tiers_have_expected_duration_and_reward() -> void:
	var board: Array = _challenges.get_board()
	assert_eq(board.size(), 3)
	assert_gte(board[0].duration_seconds, 3600)
	assert_lte(board[0].duration_seconds, 10800)
	assert_gte(board[1].duration_seconds, 86400)
	assert_lte(board[1].duration_seconds, 172800)
	assert_eq(board[0].reward.kind, "boost")
	assert_eq(board[1].reward.kind, "premium_days")
	assert_eq(board[2].reward.kind, "fragment")
	assert_gt(board[2].duration_seconds, 172800)

func test_baseline_freezes_and_reward_is_claimed_exactly_once() -> void:
	assert_true(_challenges.accept("short").ok)
	assert_false(_challenges.accept("short").ok)
	assert_false(_challenges.claim("short").ok)
	for goal in _challenges.get_board()[0].goals:
		assert_eq(goal.progress, 0)
	var goals: Array = GameState.economy_state.challenges.slots.short.goals.duplicate(true)
	GameState.player_state.stats.total_sales = 99999
	assert_eq(GameState.economy_state.challenges.slots.short.goals, goals)
	_finish("short")
	assert_true(_challenges.claim("short").ok)
	assert_false(_challenges.claim("short").ok)
	assert_eq(_rewards.get_state().boosts.fair_wind, 1)
	var old_id: String = GameState.economy_state.challenges.slots.short.id
	assert_false(_challenges.accept("short").ok)
	GameState.economy_state.challenges.slots.short.next_available_at = 0
	assert_true(_challenges.accept("short").ok)
	assert_ne(GameState.economy_state.challenges.slots.short.id, old_id)

func test_expiry_blocks_late_progress_but_completed_reward_waits() -> void:
	_challenges.accept("short")
	GameState.economy_state.challenges.slots.short.expires_at = 1
	_finish("short")
	assert_eq(GameState.economy_state.challenges.slots.short.status, "expired")
	assert_false(_challenges.claim("short").ok)
	_challenges.accept("daily")
	_finish("daily")
	GameState.economy_state.challenges.slots.daily.expires_at = 1
	assert_true(_challenges.claim("daily").ok)
	assert_eq(_rewards.get_state().premium_days, 1)
	assert_false(_rewards.get_state().has("premium_until"))

func test_reward_inventory_and_claim_ledger_survive_save_load() -> void:
	_challenges.accept("long")
	_finish("long")
	assert_true(_challenges.claim("long").ok)
	GameState.reset_to_defaults()
	assert_true(SaveSystem.load_game())
	assert_eq(_rewards.get_state().fragments.navigator_compass, 1)
	assert_false(_challenges.claim("long").ok)

func test_boost_changes_real_ship_speed_and_expires_by_play_time() -> void:
	_rewards.grant_once("test_boost", {"kind": "boost", "id": "fair_wind", "amount": 1})
	var ship: Node = load("res://scenes/game/ship/ship.tscn").instantiate()
	add_child(ship)
	var before: float = ship.get_navigation_speed()
	assert_true(_rewards.activate_boost("fair_wind").ok)
	assert_gt(ship.get_navigation_speed(), before)
	assert_false(_rewards.activate_boost("fair_wind").ok)
	_rewards._process(100.0)
	SaveSystem.save_game()
	GameState.reset_to_defaults()
	SaveSystem.load_game()
	assert_eq(_rewards.get_state().active_boost.seconds_remaining, 1700.0)
	_rewards._process(2000.0)
	assert_eq(_rewards.get_bonus_percent("speed"), 0.0)
	ship.free()

func test_premium_extends_and_fragments_craft_unique_local_items() -> void:
	_rewards.grant_once("premium", {"kind": "premium_days", "amount": 2})
	assert_true(_rewards.activate_premium().ok)
	var until: int = _rewards.get_state().premium_until
	assert_true(_rewards.activate_premium().ok)
	assert_eq(_rewards.get_state().premium_until, until + 86400)
	assert_eq(_rewards.get_bonus_percent("sale"), 5.0)
	assert_false(_rewards.activate_premium().ok)
	assert_false(_rewards.craft_artifact("navigator_compass").ok)
	_rewards.grant_once("parts", {"kind": "fragment", "id": "navigator_compass", "amount": 12})
	assert_true(_rewards.craft_artifact("navigator_compass").ok)
	assert_true(_rewards.craft_artifact("navigator_compass").ok)
	var items: Array = _rewards.get_state().artifacts
	assert_ne(items[0].instance_id, items[1].instance_id)
	assert_false(items[0].tradable)
	assert_true(_rewards.equip_artifact(items[0].instance_id).ok)
	assert_eq(_rewards.get_bonus_percent("speed"), 3.0)
	assert_true(_rewards.equip_artifact(items[1].instance_id).ok)
	assert_eq(_rewards.get_bonus_percent("speed"), 3.0)
	assert_false(_rewards.equip_artifact("missing").ok)

func test_unknown_reward_does_not_change_inventory() -> void:
	var before: Dictionary = _rewards.get_state()
	assert_false(_rewards.grant_once("unknown", {"kind": "boost", "id": "missing", "amount": 1}).ok)
	assert_eq(_rewards.get_state(), before)
