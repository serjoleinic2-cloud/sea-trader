extends Node

## Calculates player command licence from the complete trading activity record.

var _config: Dictionary = {}

func _ready() -> void:
	add_to_group("career_system")
	_config = SaveSystem._read_json("res://data/progression/career_ladder.json")

func get_activity_score() -> int:
	var stats: Dictionary = GameState.player_state.get("stats", {})
	var weights: Dictionary = _config.get("activity_weights", {})
	var score: float = 0.0
	score += float(stats.get("total_sales", 0)) * float(weights.get("total_sales", 0.0))
	score += float(stats.get("total_deliveries", 0)) * float(weights.get("total_deliveries", 0.0))
	score += floor(float(stats.get("total_distance", 0.0)) / maxf(1.0, float(weights.get("distance_unit", 1000.0)))) * float(weights.get("distance_weight", 0.0))
	score += float(stats.get("total_voyages", 0)) * float(weights.get("total_voyages", 0.0))
	score += float(stats.get("cargo_units_moved", 0)) * float(weights.get("cargo_units_moved", 0.0))
	score += float(stats.get("safe_dockings", 0)) * float(weights.get("safe_dockings", 0.0))
	score += float(stats.get("ports_discovered", 0)) * float(weights.get("ports_discovered", 0.0))
	return int(score)

func get_command_progress() -> Dictionary:
	var activity: int = get_activity_score()
	var result: Dictionary = {
		"stage_id": "sailor",
		"stage_name": "Матрос",
		"rank": 1,
		"next_activity": 15
	}
	var raw_stages: Variant = _config.get("stages", [])
	if not (raw_stages is Array):
		return result
	for raw_stage in raw_stages:
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
		if rank < last_rank:
			result["next_activity"] = first_activity + (rank - first_rank + 1) * per_rank
		else:
			result["next_activity"] = 0
	return result

func get_command_rank() -> int:
	return int(get_command_progress().get("rank", 1))

func get_hiring_rank_limit() -> int:
	return maxi(1, int(ceil(float(get_command_rank()) / 10.0)))
