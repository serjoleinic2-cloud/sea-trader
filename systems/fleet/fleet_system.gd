extends Node

## Owns player fleet data and autonomous-route state.

var _port_system: Node
var _ship_types: Dictionary = {}
var _requirements: Dictionary = {}
var _goods_prices: Dictionary = {}

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
	var goods_catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	for raw_good in goods_catalog.get("resources", []):
		var good: Dictionary = raw_good
		_goods_prices[str(good.get("id", ""))] = float(good.get("base_price", 0.0))

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

func build_ship(_ship_type_id: String) -> Dictionary:
	return {"ok": false, "message": "Корабли строятся через проект верфи из материалов склада."}

func complete_ship_from_shipyard(ship_type_id: String, ship_name: String) -> Dictionary:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or str(GameState.ship_state.get("docked_port_id", "")) != home_port_id:
		return {"ok": false, "message": "Спуск на воду возможен только на базе."}
	var ship_type: Dictionary = get_ship_type(ship_type_id)
	if ship_type.is_empty():
		return {"ok": false, "message": "Неизвестный проект корабля."}
	var required_rank: int = int(ship_type.get("command_rank_required", 1))
	if int(get_command_progress().get("rank", 1)) < required_rank:
		return {"ok": false, "message": "Недостаточный допуск для этого корабля."}
	var instance_id: String = "fleet_ship_%03d" % (GameState.fleet_state.size() + 1)
	var clean_name: String = ship_name.strip_edges()
	if clean_name == "":
		clean_name = str(ship_type.get("name", "Корабль")) + " №" + str(GameState.fleet_state.size() + 1)
	GameState.fleet_state.append({
		"instance_id": instance_id,
		"ship_type_id": ship_type_id,
		"name": clean_name,
		"current_port_id": home_port_id,
		"status": "У причала",
		"crew": [],
		"cargo": [],
		"cargo_capacity": int(ship_type.get("cargo_capacity", 0)),
		"autopilot": {}
	})
	EventBus.fleet_ship_added.emit(instance_id)
	SaveSystem.save_game()
	return {"ok": true, "message": "Корабль «" + clean_name + "» построен и спущен на воду."}

func assign_employee(employee_id: String, target_ship_id: String) -> Dictionary:
	if not _employee_exists(employee_id):
		return {"ok": false, "message": "Сотрудник не найден."}
	var source_id: String = str(get_employee(employee_id).get("assigned_to", "active_ship"))
	for vessel in GameState.fleet_state:
		if vessel.get("crew", []).has(employee_id):
			source_id = str(vessel.get("instance_id", ""))
	if _is_ship_sailing(source_id) or _is_ship_sailing(target_ship_id):
		return {"ok": false, "message": "Перевод экипажа доступен после завершения рейса."}
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

func start_autopilot(ship_id: String, route_key: String, freight_plan: Dictionary = {}, save_now: bool = true) -> Dictionary:
	var ship_index: int = _find_auxiliary_index(ship_id)
	if ship_index < 0:
		return {"ok": false, "message": "Автопилот доступен только дополнительному кораблю."}
	var route: Dictionary = GameState.known_routes_state.get(route_key, {})
	if route.is_empty():
		return {"ok": false, "message": "Этот маршрут ещё не изучен."}
	var ship: Dictionary = GameState.fleet_state[ship_index]
	if not ship.get("autopilot", {}).is_empty():
		return {"ok": false, "message": "Корабль уже в рейсе."}
	if not ship.get("cargo", []).is_empty():
		return {"ok": false, "message": "В трюме остался груз. Завершите предыдущую поставку."}
	if int(freight_plan.get("quantity", 0)) < 0 or int(freight_plan.get("quantity", 0)) > int(ship.get("cargo_capacity", 0)):
		return {"ok": false, "message": "Груз не помещается в трюм."}
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
	var freight: Dictionary = freight_plan if not freight_plan.is_empty() else _make_freight_contract(current_port_id, destination_port_id, int(ship.get("cargo_capacity", 0)))
	ship.erase("trade_receipt")
	ship["cargo"] = [{"resource_id": str(freight.get("resource_id", "")), "quantity": int(freight.get("quantity", 0))}] if int(freight.get("quantity", 0)) > 0 else []
	ship["status"] = "В пути"
	ship["autopilot"] = {
		"route_key": route_key,
		"origin_port_id": current_port_id,
		"destination_port_id": destination_port_id,
		"started_at": Time.get_unix_time_from_system(),
		"duration_seconds": duration,
		"freight": freight
	}
	GameState.fleet_state[ship_index] = ship
	if save_now:
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
	# Stopping a line cannot teleport a loaded ship back to its origin.
	return {"ok": false, "message": "Корабль завершит рейс. Повторение отключается в торговой линии."}

func get_routes_from_port(port_id: String) -> Array:
	var routes: Array = []
	for route_key in GameState.known_routes_state:
		var route: Dictionary = GameState.known_routes_state[route_key]
		if str(route.get("port_a_id", "")) == port_id or str(route.get("port_b_id", "")) == port_id:
			routes.append({"route_key": str(route_key), "route": route})
	return routes

func retry_trade(ship_id: String) -> Dictionary:
	var index: int = _find_auxiliary_index(ship_id)
	if index < 0:
		return {"ok": false, "message": "Корабль не найден."}
	var ship: Dictionary = GameState.fleet_state[index]
	var freight: Dictionary = ship.get("pending_trade", {})
	var markets: Array[Node] = get_tree().get_nodes_in_group("trade_line_system")
	if freight.is_empty() or markets.is_empty() or not ship.get("autopilot", {}).is_empty():
		return {"ok": false, "message": "Нет груза, ожидающего продажи."}
	var result: Dictionary = markets[0].settle_freight(ship, freight)
	ship["trade_receipt"] = result
	ship["status"] = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		ship.erase("pending_trade")
	GameState.fleet_state[index] = ship
	SaveSystem.save_game()
	return result

func _is_ship_sailing(ship_id: String) -> bool:
	if ship_id == "active_ship":
		return str(GameState.ship_state.get("docked_port_id", "")) == ""
	var index: int = _find_auxiliary_index(ship_id)
	return index >= 0 and not GameState.fleet_state[index].get("autopilot", {}).is_empty()

func _consume_crew_voyage(ship: Dictionary) -> void:
	var crew: Array = ship.get("crew", []).duplicate()
	var retained: Array = []
	for employee in GameState.employee_state:
		var employee_id: String = str(employee.get("employee_instance_id", ""))
		if crew.has(employee_id):
			employee["contract_voyages_remaining"] = maxi(0, int(employee.get("contract_voyages_remaining", 0)) - 1)
			if int(employee["contract_voyages_remaining"]) == 0:
				crew.erase(employee_id)
				continue
		retained.append(employee)
	ship["crew"] = crew
	GameState.employee_state = retained

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
			var freight: Dictionary = autopilot.get("freight", {})
			ship["current_port_id"] = str(autopilot.get("destination_port_id", ""))
			_consume_crew_voyage(ship)
			if bool(freight.get("managed_trade", false)) or str(freight.get("line_id", "")) != "":
				var markets: Array[Node] = get_tree().get_nodes_in_group("trade_line_system")
				var receipt: Dictionary = {"ok": false, "message": "Рынок недоступен. Груз в трюме."}
				if not markets.is_empty():
					receipt = markets[0].settle_freight(ship, freight)
				ship["trade_receipt"] = receipt
				if not bool(receipt.get("ok", false)):
					ship["pending_trade"] = freight
				else:
					ship.erase("pending_trade")
				ship["status"] = str(receipt.get("message", "В порту"))
				ship["autopilot"] = {}
				GameState.fleet_state[index] = ship
				changed = true
				continue
			var reward: float = float(freight.get("reward", 0.0))
			GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + reward
			var stats: Dictionary = GameState.player_state.get("stats", {})
			stats["total_deliveries"] = int(stats.get("total_deliveries", 0)) + 1
			stats["total_earned"] = float(stats.get("total_earned", 0.0)) + reward
			GameState.player_state["stats"] = stats
			ship["cargo"] = []
			ship["current_port_id"] = str(autopilot.get("destination_port_id", ""))
			ship["status"] = "В порту, рейс оплачен: %.0f" % reward
			ship["autopilot"] = {}
			GameState.fleet_state[index] = ship
			changed = true
	if changed:
		SaveSystem.save_game()

func _make_freight_contract(origin_port_id: String, destination_port_id: String, capacity: int) -> Dictionary:
	var origin: Dictionary = GameState.port_state.get(origin_port_id, {})
	var stock: Dictionary = origin.get("market_stock", {})
	var chosen_resource: String = ""
	var chosen_quantity: int = 0
	for resource_id in stock:
		var available: int = int(stock.get(resource_id, 0))
		if available > chosen_quantity:
			chosen_resource = str(resource_id)
			chosen_quantity = available
	var quantity: int = mini(maxi(1, capacity), maxi(1, chosen_quantity))
	var base_price: float = float(_goods_prices.get(chosen_resource, 10.0))
	var reward: float = round(base_price * float(quantity) * 1.45)
	return {
		"resource_id": chosen_resource,
		"quantity": quantity,
		"origin_port_id": origin_port_id,
		"destination_port_id": destination_port_id,
		"reward": reward
	}

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
