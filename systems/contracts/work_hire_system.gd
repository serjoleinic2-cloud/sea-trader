extends Node

## Safe work-for-hire voyages. They can repay debt without trapping the player.

var _port_system: Node

func _ready() -> void:
	add_to_group("work_hire_system")
	EventBus.port_entered.connect(_on_port_entered)

func initialize(port_system: Node) -> void:
	_port_system = port_system

func get_contract() -> Dictionary:
	var raw_contract: Variant = GameState.economy_state.get("work_hire_contract", {})
	return raw_contract if raw_contract is Dictionary else {}

func offer() -> Dictionary:
	var current_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if current_port_id == "" or _port_system == null:
		return {"ok": false, "message": "Контракт можно взять только в порту."}
	var known_ports: Array = GameState.player_state.get("discovered_port_ids", [])
	var target_port_id: String = ""
	for raw_port_id in known_ports:
		var port_id: String = str(raw_port_id)
		if port_id != current_port_id:
			target_port_id = port_id
			break
	if target_port_id == "":
		return {"ok": false, "message": "Сначала откройте ещё один порт для рейса в найм."}
	var debt: float = float(GameState.economy_state.get("debt", 0.0))
	var reward: float = 180.0 if debt <= 0.0 else minf(220.0, debt)
	return {
		"ok": true,
		"origin_port_id": current_port_id,
		"target_port_id": target_port_id,
		"target_name": _port_system.get_port_name(target_port_id),
		"reward": reward
	}

func accept() -> Dictionary:
	if not get_contract().is_empty():
		return {"ok": false, "message": "Уже выполняется рейс в найм."}
	var job: Dictionary = offer()
	if not bool(job.get("ok", false)):
		return job
	GameState.ship_state["fuel"] = minf(float(GameState.ship_state.get("fuel_max", 0.0)), float(GameState.ship_state.get("fuel", 0.0)) + 35.0)
	GameState.ship_state["hull"] = minf(100.0, float(GameState.ship_state.get("hull", 0.0)) + 20.0)
	GameState.economy_state["work_hire_contract"] = job
	SaveSystem.save_game()
	return {"ok": true, "message": "Рейс принят. Идите в порт «%s»." % str(job.get("target_name", ""))}

func _on_port_entered(port_id: String) -> void:
	var job: Dictionary = get_contract()
	if job.is_empty() or str(job.get("target_port_id", "")) != port_id:
		return
	var reward: float = float(job.get("reward", 0.0))
	var debt: float = float(GameState.economy_state.get("debt", 0.0))
	if debt > 0.0:
		GameState.economy_state["debt"] = maxf(0.0, debt - reward)
	else:
		GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + reward
	GameState.economy_state["work_hire_contract"] = {}
	EventBus.contract_completed.emit("work_hire", reward)
	SaveSystem.save_game()
