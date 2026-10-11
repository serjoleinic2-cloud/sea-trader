extends Node

## Calculates player command licence from the complete trading activity record.

const CAREER_REWARD_TEST_FLAG := "res://work/career_reward_test.json"

var _config: Dictionary = {}
var _notification_hud: CanvasLayer
var _activity_check_elapsed: float = 0.0
var _last_observed_activity: int = 0
var _last_observed_rank: int = 1
var _career_reward_test_pending := false
var _career_reward_test_start_distance := 0.0
var _career_reward_test_distance := 2.0

func _ready() -> void:
	add_to_group("career_system")
	_config = GameData.read("res://data/progression/career_ladder.json")
	_initialize_career_awards()
	_last_observed_activity = get_activity_score()
	_last_observed_rank = get_command_rank()
	_arm_career_reward_test()
	if _notification_hud == null:
		_notification_hud = load("res://systems/ui/career_notification_hud.gd").new()
		_notification_hud.name = "CareerNotificationHUD"
		add_child(_notification_hud)
	# Older saves have no career-award ledger. Grant the current rank once as the
	# migration reward; don't replay every earlier promotion.
	var career_state: Dictionary = _career_state()
	var highest_rewarded: int = int(career_state.get("highest_rewarded_rank", 1))
	if _last_observed_rank > highest_rewarded:
		for reached_rank in range(highest_rewarded + 1, _last_observed_rank + 1):
			_award_rank(reached_rank, 0, false)

func get_activity_score() -> int:
	var stats: Dictionary = GameState.player_state.get("stats", {})
	var weights: Dictionary = _config.get("activity_weights", {})
	var score: float = 0.0
	# Sale and cargo totals are units, not actions. Diminishing returns prevent
	# a single large hold from skipping several career ranks.
	var bulk_scaling: Dictionary = weights.get("bulk_scaling", {})
	var sold_units: float = maxf(0.0, float(stats.get("total_sales", 0)))
	var moved_units: float = maxf(0.0, float(stats.get("cargo_units_moved", 0)))
	score += log(1.0 + sold_units) * float(bulk_scaling.get("sales_log_scale", 6.0)) * float(weights.get("total_sales", 0.0))
	score += float(stats.get("total_deliveries", 0)) * float(weights.get("total_deliveries", 0.0))
	score += floor(float(stats.get("total_distance", 0.0)) / maxf(1.0, float(weights.get("distance_unit", 1000.0)))) * float(weights.get("distance_weight", 0.0))
	score += float(stats.get("total_voyages", 0)) * float(weights.get("total_voyages", 0.0))
	score += sqrt(moved_units) * float(bulk_scaling.get("cargo_sqrt_scale", 2.0)) * float(weights.get("cargo_units_moved", 0.0))
	score += float(stats.get("safe_dockings", 0)) * float(weights.get("safe_dockings", 0.0))
	score += float(stats.get("ports_discovered", 0)) * float(weights.get("ports_discovered", 0.0))
	return int(score)

func get_command_progress() -> Dictionary:
	var activity: int = get_activity_score()
	var result: Dictionary = {
		"stage_id": "sailor",
		"stage_name": "Матрос",
		"rank": 1,
		"next_activity": 25,
		"activity": activity
	}
	var raw_stages: Variant = _config.get("stages", [])
	if not (raw_stages is Array):
		return result
	for index in range(raw_stages.size()):
		var raw_stage: Variant = raw_stages[index]
		var stage: Dictionary = raw_stage
		var first_activity: int = int(stage.get("activity_at_first_rank", 0))
		if activity < first_activity:
			break
		var first_rank: int = int(stage.get("first_rank", 1))
		var last_rank: int = int(stage.get("last_rank", first_rank))
		var per_rank: int = maxi(1, int(stage.get("activity_per_rank", 1)))
		var rank: int = mini(last_rank, first_rank + int((activity - first_activity) / per_rank))
		result["stage_id"] = str(stage.get("id", "sailor"))
		result["stage_name"] = str(stage.get("name", "Матрос"))
		result["rank"] = rank
		result["stage_level"] = rank - first_rank + 1
	# Keep ranks already earned in older saves when the career curve is retuned.
	# This prevents a balance update from taking away ship/building access.
	var calculated_rank: int = int(result.get("rank", 1))
	var saved_career: Dictionary = GameState.progression_state.get("career", {})
	var earned_rank: int = maxi(calculated_rank, int(saved_career.get("highest_rank", 1)))
	var earned_stage: Dictionary = get_rank_stage(earned_rank)
	var earned_stage_index: int = 0
	for index in range(raw_stages.size()):
		var candidate_stage: Dictionary = raw_stages[index]
		if str(candidate_stage.get("id", "")) == str(earned_stage.get("id", "")):
			earned_stage_index = index
			break
	var earned_first: int = int(earned_stage.get("first_rank", 1))
	var earned_last: int = int(earned_stage.get("last_rank", 1))
	var earned_step: int = maxi(1, int(earned_stage.get("activity_per_rank", 1)))
	result["stage_id"] = str(earned_stage.get("id", "sailor"))
	result["stage_name"] = str(earned_stage.get("name", "Матрос"))
	result["rank"] = earned_rank
	result["stage_level"] = earned_rank - earned_first + 1
	if earned_rank < earned_last:
		var next_rank_activity: int = int(earned_stage.get("activity_at_first_rank", 0)) + (earned_rank - earned_first + 1) * earned_step
		result["next_activity"] = maxi(activity + 1, next_rank_activity)
	elif earned_stage_index + 1 < raw_stages.size():
		var next_stage: Dictionary = raw_stages[earned_stage_index + 1]
		result["next_activity"] = maxi(activity + 1, int(next_stage.get("activity_at_first_rank", 0)))
	else:
		result["next_activity"] = 0
	return result

func get_command_rank() -> int:
	return int(get_command_progress().get("rank", 1))

func get_hiring_rank_limit() -> int:
	return maxi(1, int(ceil(float(get_command_rank()) / 10.0)))

func get_rank_reward(rank: int) -> Dictionary:
	var rules: Dictionary = _config.get("rank_rewards", {})
	var first_rewarded: int = int(rules.get("first_rewarded_rank", 2))
	var coins: int = 0 if rank < first_rewarded else int(rules.get("base_coins", 25)) + rank * int(rules.get("coins_per_rank", 10))
	var milestone_every: int = maxi(1, int(rules.get("milestone_every", 10)))
	var milestone: bool = rank > 0 and rank % milestone_every == 0
	if milestone:
		coins += int(rules.get("milestone_bonus_coins", 250))
	return {"rank": rank, "coins": coins, "milestone": milestone}

func get_rank_stage(rank: int) -> Dictionary:
	for raw_stage in _config.get("stages", []):
		var stage: Dictionary = raw_stage
		if rank >= int(stage.get("first_rank", 1)) and rank <= int(stage.get("last_rank", 1)):
			return stage.duplicate(true)
	return {"id": "sailor", "name": "Матрос", "first_rank": 1, "last_rank": 10}

func get_reward_history() -> Array:
	return _career_state().get("rank_rewards", []).duplicate(true)

func _process(delta: float) -> void:
	if _career_reward_test_pending and _check_career_reward_test():
		return
	_activity_check_elapsed += delta
	if _activity_check_elapsed < 0.35:
		return
	_activity_check_elapsed = 0.0
	var activity: int = get_activity_score()
	var rank: int = get_command_rank()
	if activity <= _last_observed_activity and rank <= _last_observed_rank:
		return
	var activity_gain: int = maxi(0, activity - _last_observed_activity)
	_last_observed_activity = maxi(_last_observed_activity, activity)
	if rank > _last_observed_rank:
		for reached_rank in range(_last_observed_rank + 1, rank + 1):
			_award_rank(reached_rank, activity_gain if reached_rank == rank else 0, true)
	else:
		_notification_hud.enqueue_experience(activity_gain, activity)
	_last_observed_rank = maxi(_last_observed_rank, rank)
	_persist_career_state()

func _arm_career_reward_test() -> void:
	if not FileAccess.file_exists(CAREER_REWARD_TEST_FLAG):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAREER_REWARD_TEST_FLAG))
	if parsed is Dictionary:
		_career_reward_test_distance = maxf(0.1, float(parsed.get("distance", 2.0)))
	_career_reward_test_start_distance = float(GameState.player_state.get("stats", {}).get("total_distance", 0.0))
	_career_reward_test_pending = true
	print("CAREER REWARD TEST armed: sail %.1f m to receive one rank reward." % _career_reward_test_distance)

func _check_career_reward_test() -> bool:
	var current_distance := float(GameState.player_state.get("stats", {}).get("total_distance", 0.0))
	if current_distance - _career_reward_test_start_distance < _career_reward_test_distance:
		return false
	var next_rank := get_command_rank() + 1
	var activity := get_activity_score()
	var gained_activity := maxi(0, activity - _last_observed_activity)
	if _award_rank(next_rank, gained_activity, true):
		_last_observed_activity = activity
		_last_observed_rank = next_rank
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAREER_REWARD_TEST_FLAG))
		print("CAREER REWARD TEST passed: rank %d reward granted after %.1f m." % [next_rank, current_distance - _career_reward_test_start_distance])
		return true
	return false

func _initialize_career_awards() -> void:
	var state: Dictionary = GameState.progression_state.get("career", {})
	var old_rank: int = _get_legacy_rank(get_activity_score())
	if state.is_empty():
		# Existing saves receive only their current promotion once, rather than
		# replaying a long chain of historical ceremonies on the first load.
		state = {"highest_rank": old_rank, "rank_floor_activity": get_activity_score(), "highest_rewarded_rank": maxi(1, old_rank - 1), "rank_rewards": [], "total_reward_coins": 0}
		GameState.progression_state["career"] = state
	elif not state.has("highest_rank"):
		state["highest_rank"] = old_rank
		state["rank_floor_activity"] = get_activity_score()
		GameState.progression_state["career"] = state

func _get_legacy_rank(activity: int) -> int:
	var legacy_stages: Array[Dictionary] = [
		{"first_rank": 1, "last_rank": 10, "activity": 0, "step": 15},
		{"first_rank": 11, "last_rank": 20, "activity": 150, "step": 30},
		{"first_rank": 21, "last_rank": 30, "activity": 450, "step": 55},
		{"first_rank": 31, "last_rank": 40, "activity": 1000, "step": 90},
		{"first_rank": 41, "last_rank": 50, "activity": 1900, "step": 140}
	]
	var rank: int = 1
	for stage in legacy_stages:
		var start: int = int(stage.activity)
		if activity < start:
			break
		rank = mini(int(stage.last_rank), int(stage.first_rank) + int((activity - start) / int(stage.step)))
	return rank

func _career_state() -> Dictionary:
	var state: Variant = GameState.progression_state.get("career", {})
	return state if state is Dictionary else {}

func _award_rank(rank: int, activity_gain: int, announce: bool) -> bool:
	var state: Dictionary = _career_state()
	var rewards: Array = state.get("rank_rewards", []).duplicate(true)
	var already_awarded: bool = false
	for record in rewards:
		if int(record.get("rank", 0)) == rank:
			already_awarded = true
			break
	if already_awarded:
		return false
	var before_money: float = float(GameState.player_state.get("money", 0.0))
	var before_state: Dictionary = state.duplicate(true)
	var reward: Dictionary = get_rank_reward(rank)
	var coins: int = int(reward.get("coins", 0))
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + coins
	var stage: Dictionary = get_rank_stage(rank)
	var record: Dictionary = {"rank": rank, "stage_id": str(stage.get("id", "sailor")), "stage_name": str(stage.get("name", "Матрос")), "coins": coins, "milestone": bool(reward.get("milestone", false)), "claimed_at": int(Time.get_unix_time_from_system())}
	rewards.append(record)
	state["rank_rewards"] = rewards
	state["highest_rank"] = maxi(int(state.get("highest_rank", 1)), rank)
	state["highest_rewarded_rank"] = maxi(int(state.get("highest_rewarded_rank", 1)), rank)
	state["total_reward_coins"] = int(state.get("total_reward_coins", 0)) + coins
	state["last_activity"] = get_activity_score()
	GameState.progression_state["career"] = state
	if not SaveSystem.save_game():
		GameState.player_state["money"] = before_money
		GameState.progression_state["career"] = before_state
		push_warning("Не удалось сохранить награду за ранг %d." % rank)
		return false
	if announce and _notification_hud != null:
		_notification_hud.enqueue_rank(rank, str(stage.get("name", "Матрос")), activity_gain, coins, bool(reward.get("milestone", false)))
	return true

func _persist_career_state() -> void:
	var state: Dictionary = _career_state()
	state["last_activity"] = _last_observed_activity
	GameState.progression_state["career"] = state
