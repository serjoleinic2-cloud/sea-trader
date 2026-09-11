extends Node

## Owns player fleet data and autonomous-route state.

var _port_system: Node
var _ship_types: Dictionary = {}
var _requirements: Dictionary = {}

func _ready() -> void:
	add_to_group("fleet_system")

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/ships/fleet_catalog.json")
	var raw_types: Variant = catalog.get("ship_types", [])
	if raw_types is Array:
		for raw_type in raw_types:
			var ship_type: Dictionary = raw_type
			_ship_types[str(ship_type.get("id", ""))] = ship_type
	var crew_config: Dictionary = SaveSystem._read_json("res://data/ships/crew_requirements.json")
	_requirements = crew_config.get("requirements", {})

func get_ship_types() -> Array:
	var result: Array = []
	for type_id in _ship_types:
		result.append(_ship_types[type_id])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tier", 0)) < int(b.get("tier", 0)))
	return result

func get_auxiliary_ships() -> Array:
	return GameState.fleet_state

func get_ship_type(ship_type_id: String) -> Dictionary:
	return _ship_types.get(ship_type_id, {})

func get_command_progress() -> Dictionary:
	var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
	if systems.is_empty():
		return {"stage_name": "Матрос", "rank": 1, "next_activity": 15}
	return systems[0].get_command_progress()

func build_ship(ship_type_id: String) -> Dictionary:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var docked_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if home_port_id == "" or docked_port_id != home_port_id:
		return {"ok": false, "message": "Строить корабли можно только на своей базе."}
	var ship_type: Dictionary = get_ship_type(ship_type_id)
	if ship_type.is_empty():
		return {"ok": false, "message": "Неизвестный проект корабля."}
	var required_rank: int = int(ship_type.get("command_rank_required", 1))
	var current_rank: int = int(get_command_progress().get("rank", 1))
	if current_rank < required_rank:
		return {"ok": false, "message": "Нужен допуск капитана %d ранга." % required_rank}
	var price: float = float(ship_type.get("price", 0.0))
	if float(GameState.player_state.get("money", 0.0)) < price:
		return {"ok": false, "message": "Недостаточно денег для постройки."}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - price
	var instance_id: String = "fleet_ship_%03d" % (GameState.fleet_state.size() + 1)
	GameState.fleet_state.append({
		"instance_id": instance_id,
		"ship_type_id": ship_type_id,
		"name": str(ship_type.get("name", "Корабль")) + " №" + str(GameState.fleet_state.size() + 1),
		"current_port_id": home_port_id,
		"status": "В порту",
		"crew": [],
		"cargo": [],
		"cargo_capacity": int(ship_type.get("cargo_capacity", 0)),
		"autopilot": {}
	})
	EventBus.fleet_ship_added.emit(instance_id)
	SaveSystem.save_game()
	return {"ok": true, "message": "Корабль построен и ждёт экипаж на базе."}

func assign_employee(employee_id: String, target_ship_id: String) -> Dictionary:
	if not _employee_exists(employee_id):
		return {"ok": false, "message": "Сотрудник не найден."}
	var target_limit: int = _get_ship_crew_limit(target_ship_id)
	var target_crew: Array = _get_ship_crew(target_ship_id)
	if target_limit <= 0:
		return {"ok": false, "message": "Корабль не найден."}
	if target_crew.has(employee_id):
		return {"ok": false, "message": "Сотрудник уже назначен на этот корабль."}
	if target_crew.size() >= target_limit:
		return {"ok": false, "message": "На корабле нет свободного места."}
	_remove_employee_from_all_ships(employee_id)
	target_crew.append(employee_id)
	_set_ship_crew(target_ship_id, target_crew)
	_update_employee_assignment(employee_id, target_ship_id)
	SaveSystem.save_game()
	return {"ok": true, "message": "Сотрудник назначен на корабль."}

func start_autopilot(ship_id: String, route_key: String) -> Dictionary:
	var ship_index: int = _find_auxiliary_index(ship_id)
	if ship_index < 0:
		return {"ok": false, "message": "Автопилот доступен только дополнительному кораблю."}
	var route: Dictionary = GameState.known_routes_state.get(route_key, {})
	if route.is_empty():
		return {"ok": false, "message": "Этот маршрут ещё не изучен."}
	var ship: Dictionary = GameState.fleet_state[ship_index]
	var current_port_id: String = str(ship.get("current_port_id", ""))
	var port_a_id: String = str(route.get("port_a_id", ""))
	var port_b_id: String = str(route.get("port_b_id", ""))
	var destination_port_id: String = ""
	if current_port_id == port_a_id:
		destination_port_id = port_b_id
	elif current_port_id == port_b_id:
		destination_port_id = port_a_id
	else:
		return {"ok": false, "message": "Корабль должен находиться в одном из портов маршрута."}
	var crew: Array = _get_ship_crew(ship_id)
	if crew.size() < _get_ship_min_crew(ship_id):
		return {"ok": false, "message": "Не хватает экипажа для выхода в море."}
	if not _ship_has_captain(crew):
		return {"ok": false, "message": "Для автопилота нужен капитан в экипаже."}
	var duration: float = maxf(45.0, float(route.get("distance", 0.0)) / 120.0)
	ship["status"] = "В пути"
	ship["autopilot"] = {
		"route_key": route_key,
		"origin_port_id": current_port_id,
		"destination_port_id": destination_port_id,
		"started_at": Time.get_unix_time_from_system(),
		"duration_seconds": duration
	}
	GameState.fleet_state[ship_index] = ship
	SaveSystem.save_game()
	return {"ok": true, "message": "Автопилот запущен: корабль идёт в " + _port_system.get_port_name(destination_port_id) + "."}

func stop_autopilot(ship_id: String) -> Dictionary:
	var ship_index: int = _find_auxiliary_index(ship_id)
	if ship_index < 0:
		return {"ok": false, "message": "Корабль не найден."}
	var ship: Dictionary = GameState.fleet_state[ship_index]
	var autopilot: Dictionary = ship.get("autopilot", {})
	if autopilot.is_empty():
		return {"ok": false, "message": "Корабль не в пути."}
	ship["status"] = "Ожидает приказ"
	ship["autopilot"] = {}
	GameState.fleet_state[ship_index] = ship
	SaveSystem.save_game()
	return {"ok": true, "message": "Автопилот остановлен."}

func get_routes_from_port(port_id: String) -> Array:
	var routes: Array = []
	for route_key in GameState.known_routes_state:
		var route: Dictionary = GameState.known_routes_state[route_key]
		if str(route.get("port_a_id", "")) == port_id or str(route.get("port_b_id", "")) == port_id:
			routes.append({"route_key": str(route_key), "route": route})
	return routes

func get_employee(employee_id: String) -> Dictionary:
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		if str(employee.get("employee_instance_id", "")) == employee_id:
			return employee
	return {}

func get_ship_crew(ship_id: String) -> Array:
	return _get_ship_crew(ship_id)

func _process(_delta: float) -> void:
	var changed: bool = false
	var now: float = Time.get_unix_time_from_system()
	for index in range(GameState.fleet_state.size()):
		var ship: Dictionary = GameState.fleet_state[index]
		var autopilot: Dictionary = ship.get("autopilot", {})
		if autopilot.is_empty():
			continue
		var elapsed: float = now - float(autopilot.get("started_at", now))
		var duration: float = maxf(1.0, float(autopilot.get("duration_seconds", 1.0)))
		if elapsed >= duration:
			ship["current_port_id"] = str(autopilot.get("destination_port_id", ""))
			ship["status"] = "В порту"
			ship["autopilot"] = {}
			GameState.fleet_state[index] = ship
			changed = true
	if changed:
		SaveSystem.save_game()

func _find_auxiliary_index(ship_id: String) -> int:
	for index in range(GameState.fleet_state.size()):
		var ship: Dictionary = GameState.fleet_state[index]
		if str(ship.get("instance_id", "")) == ship_id:
			return index
	return -1

func _get_ship_crew(ship_id: String) -> Array:
	if ship_id == "active_ship":
		var raw_active_crew: Variant = GameState.ship_state.get("crew", [])
		return raw_active_crew if raw_active_crew is Array else []
	var ship_index: int = _find_auxiliary_index(ship_id)
	if ship_index < 0:
		return []
	var ship: Dictionary = GameState.fleet_state[ship_index]
	var raw_crew: Variant = ship.get("crew", [])
	return raw_crew if raw_crew is Array else []

func _set_ship_crew(ship_id: String, crew: Array) -> void:
	if ship_id == "active_ship":
		GameState.ship_state["crew"] = crew
		return
	var ship_index: int = _find_auxiliary_index(ship_id)
	if ship_index < 0:
		return
	var ship: Dictionary = GameState.fleet_state[ship_index]
	ship["crew"] = crew
	GameState.fleet_state[ship_index] = ship

func _get_ship_crew_limit(ship_id: String) -> int:
	var type_id: String = str(GameState.ship_state.get("ship_id", "ship_sloop"))
	if ship_id != "active_ship":
		var ship_index: int = _find_auxiliary_index(ship_id)
		if ship_index < 0:
			return 0
		var ship: Dictionary = GameState.fleet_state[ship_index]
		type_id = str(ship.get("ship_type_id", "ship_sloop"))
	var limits: Dictionary = _requirements.get(type_id, _requirements.get("default", {}))
	return int(limits.get("max_crew", 1))

func _get_ship_min_crew(ship_id: String) -> int:
	var type_id: String = "ship_sloop"
	var ship_index: int = _find_auxiliary_index(ship_id)
	if ship_index >= 0:
		var ship: Dictionary = GameState.fleet_state[ship_index]
		type_id = str(ship.get("ship_type_id", type_id))
	var limits: Dictionary = _requirements.get(type_id, _requirements.get("default", {}))
	return int(limits.get("min_crew", 1))

func _employee_exists(employee_id: String) -> bool:
	return not get_employee(employee_id).is_empty()

func _remove_employee_from_all_ships(employee_id: String) -> void:
	var active_crew: Array = _get_ship_crew("active_ship")
	active_crew.erase(employee_id)
	_set_ship_crew("active_ship", active_crew)
	for index in range(GameState.fleet_state.size()):
		var ship: Dictionary = GameState.fleet_state[index]
		var crew: Array = ship.get("crew", [])
		crew.erase(employee_id)
		ship["crew"] = crew
		GameState.fleet_state[index] = ship

func _update_employee_assignment(employee_id: String, ship_id: String) -> void:
	for index in range(GameState.employee_state.size()):
		var employee: Dictionary = GameState.employee_state[index]
		if str(employee.get("employee_instance_id", "")) == employee_id:
			employee["assigned_to"] = ship_id
			GameState.employee_state[index] = employee
			return

func _ship_has_captain(crew: Array) -> bool:
	for employee_id in crew:
		var employee: Dictionary = get_employee(str(employee_id))
		if str(employee.get("role_id", "")) == "captain":
			return true
	return false
