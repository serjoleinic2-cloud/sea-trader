extends Node

## Guaranteed low-income recovery at a dock; no cargo can be stolen or sold.
var _port_system: Node
var _rules: Dictionary

func _ready() -> void:
	add_to_group("work_hire_system")
	_rules = GameData.read("res://data/economy/balance_rules.json").get("recovery", {})

func initialize(port_system: Node) -> void:
	_port_system = port_system

func get_contract() -> Dictionary:
	return GameState.economy_state.get("work_hire_contract", {})

func offer() -> Dictionary:
	var origin: String = str(GameState.ship_state.get("docked_port_id", ""))
	if origin == "" or _port_system == null:
		return {"ok": false, "message": "Работа доступна у причала."}
	var target: String = ""
	for id in GameState.player_state.get("discovered_port_ids", []):
		if str(id) != origin:
			target = str(id)
			break
	var fuel: float = 0.0
	if target != "":
		fuel = _port_system.get_port_position(origin).distance_to(_port_system.get_port_position(target)) * 0.006 + float(_rules.fuel_reserve)
	if target == "" or fuel > float(GameState.ship_state.get("fuel_max", 100.0)) or float(GameState.player_state.get("money", 0.0)) < 100.0 or float(GameState.economy_state.get("debt", 0.0)) > 0.0:
		target = origin
	var local: bool = target == origin
	return {"ok": true, "origin_port_id": origin, "target_port_id": target,
		"target_name": _port_system.get_port_name(target),
		"reward": float(_rules.debt_payment) if float(GameState.economy_state.get("debt", 0.0)) > 0.0 else float(_rules.reward), "local": local,
		"fuel": 0.0 if local else fuel,
		"message": "Работа у причала: 3 минуты, без своего груза." if local else "Курьерский рейс с документами. Оплата после швартовки и не раньше 3 минут."}

func accept() -> Dictionary:
	if not get_contract().is_empty():
		return {"ok": false, "message": "Сначала завершите текущую работу."}
	var job: Dictionary = offer()
	if not bool(job.get("ok", false)):
		return job
	job["ready_at"] = _now() + int(_rules.minimum_seconds)
	GameState.economy_state["work_hire_contract"] = job
	if not bool(job.local):
		GameState.ship_state["fuel"] = maxf(float(GameState.ship_state.get("fuel", 0.0)), float(job.fuel))
		GameState.ship_state["hull"] = maxf(float(GameState.ship_state.get("hull", 0.0)), float(_rules.hull_minimum))
	SaveSystem.save_game()
	return {"ok": true, "message": str(job.message)}

func _process(_delta: float) -> void:
	var job: Dictionary = get_contract()
	if job.is_empty():
		return
	# Old saves keep their job; payment now requires docking, never just entering a radius.
	if not job.has("ready_at"):
		job["ready_at"] = _now() + int(_rules.minimum_seconds)
	if _now() < int(job.ready_at) or str(GameState.ship_state.get("docked_port_id", "")) != str(job.get("target_port_id", "")):
		return
	var reward: float = minf(float(_rules.debt_payment), float(job.get("reward", _rules.reward)))
	var debt: float = maxf(0.0, float(GameState.economy_state.get("debt", 0.0)))
	var repayment: float = minf(debt, reward)
	GameState.economy_state["debt"] = debt - repayment
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + minf(float(_rules.reward), reward - repayment)
	GameState.economy_state["work_hire_contract"] = {}
	EventBus.contract_completed.emit("work_hire", reward)
	SaveSystem.save_game()

func _now() -> int:
	return int(Time.get_unix_time_from_system())
