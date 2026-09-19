extends Node

## Three concurrent, opt-in challenges. Targets and rewards freeze on acceptance.
var _ports: Node
var _career: Node
var _rewards: Node
var _rules: Dictionary = {}
var _elapsed: float = 0.0

func _ready() -> void:
	add_to_group("challenge_system")
	_rules = GameData.read("res://data/challenges/challenge_rules.json")

func initialize(ports: Node, career: Node, rewards: Node) -> void:
	_ports = ports
	_career = career
	_rewards = rewards

func get_board() -> Array:
	var slots: Dictionary = GameState.economy_state.get("challenges", {}).get("slots", {})
	var result: Array = []
	for tier in _rules.get("tiers", []):
		var id: String = str(tier.id)
		var challenge: Dictionary = slots.get(id, {}).duplicate(true)
		if challenge.is_empty():
			challenge = _make_challenge(tier, 1)
		for goal in challenge.get("goals", []):
			goal["progress"] = _progress(challenge, goal)
			goal["name"] = str(_rules.get("stat_names", {}).get(str(goal.stat), str(goal.stat)))
		challenge["reward_text"] = _rewards.describe(challenge.get("reward", {}))
		challenge["renewal_remaining"] = maxi(0, int(challenge.get("next_available_at", 0)) - _now())
		result.append(challenge)
	return result

func accept(tier_id: String) -> Dictionary:
	var state: Dictionary = GameState.economy_state.get("challenges", {}).duplicate(true)
	var slots: Dictionary = state.get("slots", {})
	var previous: Dictionary = slots.get(tier_id, {})
	if str(previous.get("status", "")) in ["active", "complete"]:
		return {"ok": false, "message": "Сначала завершите активное задание и заберите награду."}
	if _now() < int(previous.get("next_available_at", 0)):
		return {"ok": false, "message": "Следующее задание этой категории ещё не доступно."}
	var tier: Dictionary = {}
	for definition in _rules.get("tiers", []):
		if str(definition.id) == tier_id:
			tier = definition
	if tier.is_empty():
		return {"ok": false, "message": "Неизвестный тип задания."}
	var serial: int = int(previous.get("serial", 0)) + 1
	var challenge: Dictionary = _make_challenge(tier, serial)
	challenge["baseline"] = GameState.player_state.get("stats", {}).duplicate(true)
	challenge["status"] = "active"
	challenge["started_at"] = _now()
	challenge["expires_at"] = _now() + int(challenge.duration_seconds)
	challenge["next_available_at"] = _now() + int(tier.get("renewal_seconds", challenge.duration_seconds))
	slots[tier_id] = challenge
	state["slots"] = slots
	return _save_state(state, "Задание принято. Учитываются действия после принятия.")

func claim(tier_id: String) -> Dictionary:
	_update_completion()
	var before: Dictionary = GameState.economy_state.duplicate(true)
	var state: Dictionary = GameState.economy_state.get("challenges", {}).duplicate(true)
	var slots: Dictionary = state.get("slots", {})
	var challenge: Dictionary = slots.get(tier_id, {})
	if str(challenge.get("status", "")) != "complete":
		return {"ok": false, "message": "Задание ещё не выполнено или награда уже получена."}
	var result: Dictionary = _rewards.grant_once(str(challenge.id), challenge.reward)
	if not bool(result.get("ok", false)):
		return result
	challenge["status"] = "claimed"
	slots[tier_id] = challenge
	state["slots"] = slots
	GameState.economy_state["challenges"] = state
	if not SaveSystem.save_game():
		GameState.economy_state = before
		return {"ok": false, "message": "Не удалось сохранить получение награды."}
	return result

func _make_challenge(tier: Dictionary, serial: int) -> Dictionary:
	var rank: int = int(_career.get_command_rank())
	var multiplier: float = minf(float(_rules.get("maximum_difficulty_multiplier", 2.5)), 1.0 + maxf(0.0, rank - 1) * float(_rules.get("rank_difficulty_step", 0.03)))
	var capacity: int = maxi(1, int(GameState.ship_state.get("cargo_capacity", 50)))
	var goals: Array = [{"stat": "total_distance", "target": int(ceil(float(tier.distance) * multiplier))}]
	var known: int = GameState.player_state.get("discovered_port_ids", []).size()
	var undiscovered: int = maxi(0, _ports.get_all_port_ids().size() - known)
	if known < 2 and undiscovered > 0:
		goals.append({"stat": "ports_discovered", "target": mini(2 - known, undiscovered)})
	else:
		goals.append({"stat": "total_sales", "target": maxi(1, int(ceil(capacity * float(tier.sales_per_capacity) * multiplier)))})
	if str(tier.id) != "short":
		goals.append({"stat": "total_voyages", "target": int(ceil(float(tier.voyages) * multiplier))})
	var durations: Array = tier.duration_hours
	var variant: int = posmod(hash(str(GameState.world_state.get("seed", 0)) + str(tier.id) + str(serial)), durations.size())
	return {"id": "challenge_%s_%s_%d" % [str(GameState.world_state.get("seed", 0)), str(tier.id), serial], "tier_id": str(tier.id), "name": str(tier.name), "serial": serial, "status": "available", "duration_seconds": int(durations[variant]) * 3600, "goals": goals, "reward": tier.reward.duplicate(true), "baseline": {}}

func _progress(challenge: Dictionary, goal: Dictionary) -> int:
	if str(challenge.get("status", "")) == "available":
		return 0
	if str(challenge.get("status", "")) in ["complete", "claimed"]:
		return int(goal.target)
	if str(challenge.get("status", "")) == "expired":
		return int(goal.get("expired_progress", 0))
	var stats: Dictionary = GameState.player_state.get("stats", {})
	var baseline: Dictionary = challenge.get("baseline", {})
	return clampi(int(float(stats.get(str(goal.stat), 0)) - float(baseline.get(str(goal.stat), 0))), 0, int(goal.target))

func _update_completion() -> void:
	var state: Dictionary = GameState.economy_state.get("challenges", {}).duplicate(true)
	var slots: Dictionary = state.get("slots", {})
	var changed: bool = false
	for challenge in slots.values():
		if str(challenge.get("status", "")) != "active":
			continue
		if _now() > int(challenge.expires_at):
			for goal in challenge.goals:
				goal["expired_progress"] = _progress(challenge, goal)
			challenge["status"] = "expired"
			changed = true
			continue
		var completed: bool = true
		for goal in challenge.goals:
			if _progress(challenge, goal) < int(goal.target):
				completed = false
		if completed:
			challenge["status"] = "complete"
			challenge["completed_at"] = _now()
			changed = true
	if changed:
		state["slots"] = slots
		_save_state(state, "")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.0:
		_elapsed = 0.0
		_update_completion()

func _save_state(state: Dictionary, message: String) -> Dictionary:
	var before: Dictionary = GameState.economy_state.get("challenges", {}).duplicate(true)
	GameState.economy_state["challenges"] = state
	if not SaveSystem.save_game():
		GameState.economy_state["challenges"] = before
		return {"ok": false, "message": "Не удалось сохранить задание."}
	return {"ok": true, "message": message}

func _now() -> int:
	return int(Time.get_unix_time_from_system())
