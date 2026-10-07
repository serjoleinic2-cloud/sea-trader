extends Node

## Owns player fleet data and autonomous-route state.

var _port_system: Node
var _hiring_system: Node
var _ship_types: Dictionary = {}
var _requirements: Dictionary = {}
var _goods_prices: Dictionary = {}
var _hazard_zones: Array = []
var _hazard_rules: Dictionary = {}
var _economy = preload("res://systems/economy/economy_model.gd").new()

func _ready() -> void:
	add_to_group("fleet_system")

func initialize(port_system: Node, hiring_system: Node = null) -> void:
	_port_system = port_system
	_hiring_system = hiring_system
	var raw_types: Variant = GameData.get_ships()
	if raw_types is Array:
		for raw_type in raw_types:
			var ship_type: Dictionary = raw_type
			_ship_types[str(ship_type.get("id", ""))] = ship_type
	_requirements = GameData.get_crew_requirements()
	_hazard_rules = GameData.read("res://data/world/hazard_rules.json")
	var goods_catalog: Dictionary = GameData.read("res://data/resources/goods_catalog.json")
	for raw_good in goods_catalog.get("resources", []):
		var good: Dictionary = raw_good
		_goods_prices[str(good.get("id", ""))] = float(good.get("base_price", 0.0))

func get_ship_types() -> Array:
	var result: Array = []
	for type_id in _ship_types:
		if not bool(_ship_types[type_id].get("premium", false)) and (not bool(_ship_types[type_id].get("warship", false)) or str(_ship_types[type_id].get("faction_id", "")) == str(GameState.player_state.get("origin_race_id", ""))):
			result.append(_ship_types[type_id])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tier", 0)) < int(b.get("tier", 0)))
	return result

func get_premium_ship_types() -> Array:
	var result: Array = []
	for type_id in _ship_types:
		if bool(_ship_types[type_id].get("premium", false)):
			result.append(_ship_types[type_id])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tier", 0)) < int(b.get("tier", 0)))
	return result

func get_auxiliary_ships() -> Array:
	return GameState.fleet_state

## A presentation-safe snapshot for the map and fleet UI. The journey itself
## remains time based, so it survives closing the application.
func get_auxiliary_voyage_status(ship_id: String, now: float = -1.0) -> Dictionary:
	var index: int = _find_auxiliary_index(ship_id)
	if index < 0:
		return {"found": false}
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var ship: Dictionary = GameState.fleet_state[index]
	var autopilot: Dictionary = ship.get("autopilot", {})
	var cargo_units: int = 0
	for raw_item in ship.get("cargo", []):
		var item: Dictionary = raw_item
		cargo_units += int(item.get("quantity", 0))
	if autopilot.is_empty():
		return {
			"found": true,
			"in_transit": false,
			"current_port_id": str(ship.get("current_port_id", "")),
			"cargo_units": cargo_units,
			"status": str(ship.get("status", "У причала"))
		}
	var duration: float = maxf(1.0, float(autopilot.get("duration_seconds", 1.0)))
	var elapsed: float = maxf(0.0, now - float(autopilot.get("started_at", now)))
	return {
		"found": true,
		"in_transit": true,
		"origin_port_id": str(autopilot.get("origin_port_id", "")),
		"destination_port_id": str(autopilot.get("destination_port_id", "")),
		"progress": clampf(elapsed / duration, 0.0, 1.0),
		"remaining_seconds": maxf(0.0, duration - elapsed),
		"cargo_units": cargo_units,
		"status": "В пути"
	}

func get_ship_type(ship_type_id: String) -> Dictionary:
	return _ship_types.get(ship_type_id, {})

func get_command_progress() -> Dictionary:
	var systems: Array[Node] = get_tree().get_nodes_in_group("career_system")
	if systems.is_empty():
		return {"stage_name": "Матрос", "rank": 1, "next_activity": 15}
	return systems[0].get_command_progress()

func get_ship_access(ship_type_id: String) -> Dictionary:
	var ship_type: Dictionary = get_ship_type(ship_type_id)
	if ship_type.is_empty():
		return {"ok": false, "message": "Проект корабля не найден."}
	if bool(ship_type.get("warship", false)) and str(ship_type.get("faction_id", "")) != str(GameState.player_state.get("origin_race_id", "")):
		return {"ok": false, "message": "Этот проект принадлежит другой расе."}
	var progress: Dictionary = get_command_progress()
	var current_rank: int = int(progress.get("rank", 1))
	var required_rank: int = int(ship_type.get("command_rank_required", 1))
	if current_rank >= required_rank:
		return {"ok": true, "required_rank": required_rank, "message": "Допуск открыт."}
	return {
		"ok": false,
		"required_rank": required_rank,
		"message": "Для проекта «%s» нужен ранг %d. Сейчас: %s, ранг %d." % [
			str(ship_type.get("name", "корабль")), required_rank,
			str(progress.get("stage_name", "Матрос")), current_rank
		]
	}

func build_ship(_ship_type_id: String) -> Dictionary:
	return {"ok": false, "message": "Корабли строятся через проект верфи из материалов склада."}

func complete_ship_from_shipyard(ship_type_id: String, ship_name: String, persist: bool = true) -> Dictionary:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or str(GameState.ship_state.get("docked_port_id", "")) != home_port_id:
		return {"ok": false, "message": "Спуск на воду возможен только на базе."}
	var ship_type: Dictionary = get_ship_type(ship_type_id)
	if ship_type.is_empty():
		return {"ok": false, "message": "Неизвестный проект корабля."}
	if bool(ship_type.get("premium", false)):
		return {"ok": false, "message": "Премиальные корабли приобретаются через магазин."}
	var access: Dictionary = get_ship_access(ship_type_id)
	if not bool(access.get("ok", false)):
		return access
	var fleet_number: int = get_next_fleet_number()
	var instance_id: String = "fleet_ship_%03d" % fleet_number
	var clean_name: String = ship_name.strip_edges()
	if clean_name == "":
		clean_name = str(ship_type.get("name", "Корабль")) + " №" + str(fleet_number)
	GameState.fleet_state.append({
		"instance_id": instance_id,
		"ship_type_id": ship_type_id,
		"name": clean_name,
		"current_port_id": home_port_id,
		"status": "У причала",
		"crew": [],
		"cargo": [],
		"cargo_capacity": int(ship_type.get("cargo_capacity", 0)),
		"autopilot": {},
		"escort_enabled": false,
		"escort_state": {},
		"embarked_units": {}
	})
	if bool(ship_type.get("warship", false)):
		var navy: Node = get_tree().get_first_node_in_group("naval_combat_system")
		if navy != null: navy.normalize_ship(GameState.fleet_state[-1])
	if persist:
		if not SaveSystem.save_game():
			GameState.fleet_state.pop_back()
			return {"ok": false, "message": "Не удалось сохранить новый корабль."}
		EventBus.fleet_ship_added.emit(instance_id)
	return {"ok": true, "instance_id": instance_id, "message": "Корабль «" + clean_name + "» построен и спущен на воду."}


func get_take_control_status(ship_id: String) -> Dictionary:
	var index: int = _find_auxiliary_index(ship_id)
	if index < 0:
		return {"ok": false, "message": "Корабль флота не найден."}
	var candidate: Dictionary = GameState.fleet_state[index]
	if str(candidate.get("ship_type_id","")) == "ship_combat_cutter" or bool(GameData.get_ship(str(candidate.get("ship_type_id", ""))).get("warship", false)):
		return {"ok": false, "message": "Военный транспорт следует за вашим кораблём. Управляйте десантом в окне флота."}
	if not candidate.get("autopilot", {}).is_empty():
		return {"ok": false, "message": "Сначала дождитесь окончания рейса."}
	if not candidate.get("pending_trade", {}).is_empty():
		return {"ok": false, "message": "Сначала завершите продажу груза."}
	var active_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var candidate_port_id: String = str(candidate.get("current_port_id", ""))
	if active_port_id == "" or candidate_port_id != active_port_id:
		return {"ok": false, "message": "Для пересадки оба корабля должны стоять в одном порту."}
	var lines: Variant = GameState.economy_state.get("trade_lines", [])
	if lines is Array:
		for raw_line in lines:
			if raw_line is Dictionary and str(raw_line.get("ship_id", "")) == ship_id:
				return {"ok": false, "message": "Сначала снимите корабль с торговой линии."}
	return {"ok": true, "message": "Можно перейти на этот корабль."}


func take_control(ship_id: String) -> Dictionary:
	var status: Dictionary = get_take_control_status(ship_id)
	if not bool(status.get("ok", false)):
		return status
	var index: int = _find_auxiliary_index(ship_id)
	var candidate: Dictionary = GameState.fleet_state[index]
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var previous_state: Dictionary = GameState.ship_state.duplicate(true)
	var previous_ship_type_id: String = str(previous_state.get("ship_id", GameData.get_starter_ship_id()))
	var previous_data: Dictionary = get_ship_type(previous_ship_type_id)
	var previous_name: String = str(previous_data.get("name", "Корабль"))
	var new_active_name: String = str(candidate.get("name", "Корабль"))
	var previous_id: String = _next_fleet_instance_id()
	var previous_crew: Array = previous_state.get("crew", []).duplicate()
	var previous_cargo: Array = previous_state.get("cargo", []).duplicate(true)
	var active_state: Dictionary = candidate.get("vessel_state", {}).duplicate(true)
	if active_state.is_empty():
		var ship_data: Dictionary = get_ship_type(str(candidate.get("ship_type_id", "")))
		if ship_data.is_empty():
			return {"ok": false, "message": "Не удалось загрузить характеристики выбранного судна."}
		var port_position: Vector2 = _port_system.get_port_position(port_id) if _port_system != null else Vector2.ZERO
		active_state = {
			"ship_id": str(candidate.get("ship_type_id", "")),
			"position": port_position,
			"velocity": Vector2.ZERO,
			"heading": -PI / 2.0,
			"docked_port_id": port_id,
			"hull": float(ship_data.get("hull_max", 100.0)),
			"engine": float(ship_data.get("engine_max", 100.0)),
			"steering": float(ship_data.get("steering_max", 100.0)),
			"cargo_hold": float(ship_data.get("cargo_hold_max", 100.0)),
			"fuel": float(ship_data.get("fuel_capacity", 100.0)),
			"fuel_max": float(ship_data.get("fuel_capacity", 100.0)),
			"cargo_capacity": int(candidate.get("cargo_capacity", ship_data.get("cargo_capacity", 50))),
			"reverse_gear": false
		}
	active_state["ship_id"] = str(candidate.get("ship_type_id", active_state.get("ship_id", "")))
	active_state["docked_port_id"] = port_id
	active_state["velocity"] = Vector2.ZERO
	active_state["cargo"] = candidate.get("cargo", []).duplicate(true)
	active_state["crew"] = candidate.get("crew", []).duplicate()
	active_state["cargo_capacity"] = int(candidate.get("cargo_capacity", active_state.get("cargo_capacity", 50)))
	candidate["instance_id"] = previous_id
	candidate["vessel_state"] = {}
	candidate["crew"] = previous_crew
	candidate["cargo"] = previous_cargo
	candidate["cargo_capacity"] = int(previous_state.get("cargo_capacity", 50))
	for state_key in ["hull", "engine", "steering", "cargo_hold", "fuel", "fuel_max", "position", "velocity", "heading"]:
		candidate[state_key] = previous_state.get(state_key, candidate.get(state_key))
	candidate["ship_type_id"] = previous_ship_type_id
	candidate["name"] = previous_name + " (бывший основной)"
	candidate["current_port_id"] = port_id
	candidate["status"] = "У причала"
	candidate["autopilot"] = {}
	candidate["vessel_state"] = previous_state
	GameState.fleet_state[index] = candidate
	GameState.ship_state = active_state
	for employee_id in previous_crew:
		_update_employee_assignment(str(employee_id), previous_id)
	for employee_id in active_state.get("crew", []):
		_update_employee_assignment(str(employee_id), "active_ship")
	GameState.world_state["current_position"] = Vector2(active_state.get("position", Vector2.ZERO))
	EventBus.active_ship_changed.emit(str(active_state.get("ship_id", "")))
	SaveSystem.save_game()
	return {"ok": true, "message": "Теперь вы управляете кораблём «%s»." % new_active_name}


func get_next_fleet_number() -> int:
	var highest_number: int = 0
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
		var ship_id: String = str(ship.get("instance_id", ""))
		if not ship_id.begins_with("fleet_ship_"):
			continue
		var suffix: String = ship_id.trim_prefix("fleet_ship_")
		highest_number = maxi(highest_number, int(suffix))
	return highest_number + 1


func _next_fleet_instance_id() -> String:
	return "fleet_ship_%03d" % get_next_fleet_number()

func assign_employee(employee_id: String, target_ship_id: String) -> Dictionary:
	if not _employee_exists(employee_id):
		return {"ok": false, "message": "Сотрудник не найден."}
	var source_id: String = str(get_employee(employee_id).get("assigned_to", "active_ship"))
	for vessel in GameState.fleet_state:
		if vessel.get("crew", []).has(employee_id):
			source_id = str(vessel.get("instance_id", ""))
	var source_port: String = _get_ship_port_id(source_id)
	var target_port: String = _get_ship_port_id(target_ship_id)
	if source_port == "" or source_port != target_port:
		return {"ok": false, "message": "Перевод возможен, только когда оба корабля стоят в одном порту."}
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

func get_employee_assignment_status(employee_id: String, target_ship_id: String) -> Dictionary:
	if not _employee_exists(employee_id):
		return {"ok": false, "message": "Сотрудник не найден."}
	var source_id: String = str(get_employee(employee_id).get("assigned_to", "active_ship"))
	for vessel in GameState.fleet_state:
		if vessel.get("crew", []).has(employee_id):
			source_id = str(vessel.get("instance_id", ""))
	if source_id == target_ship_id:
		return {"ok": false, "message": "Сотрудник уже в этом экипаже."}
	if _is_ship_sailing(source_id) or _is_ship_sailing(target_ship_id):
		return {"ok": false, "message": "Перевод экипажа доступен после завершения рейса."}
	if _get_ship_port_id(source_id) == "" or _get_ship_port_id(source_id) != _get_ship_port_id(target_ship_id):
		return {"ok": false, "message": "Перевод возможен, только когда оба корабля стоят в одном порту."}
	var target_crew: Array = _get_ship_crew(target_ship_id)
	if target_crew.size() >= _get_ship_crew_limit(target_ship_id):
		return {"ok": false, "message": "На корабле нет свободной ячейки."}
	return {"ok": true, "message": "Можно посадить сотрудника."}

func get_assignable_employees(target_ship_id: String) -> Array:
	var result: Array = []
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		var status: Dictionary = get_employee_assignment_status(str(employee.get("employee_instance_id", "")), target_ship_id)
		if bool(status.get("ok", false)):
			result.append(employee)
	return result

func _get_ship_port_id(ship_id: String) -> String:
	if ship_id == "active_ship":
		return str(GameState.ship_state.get("docked_port_id", ""))
	var index: int = _find_auxiliary_index(ship_id)
	if index < 0:
		return ""
	var ship: Dictionary = GameState.fleet_state[index]
	return "" if not ship.get("autopilot", {}).is_empty() else str(ship.get("current_port_id", ""))

func quote_leg(ship_id: String, route_key: String, quantity: int) -> Dictionary:
	var index: int = _find_auxiliary_index(ship_id)
	var route: Dictionary = GameState.known_routes_state.get(route_key, {})
	if index < 0 or route.is_empty():
		return {"ok": false, "message": "Корабль или маршрут не найден."}
	var ship: Dictionary = GameState.fleet_state[index]
	if str(ship.get("ship_type_id","")) == "ship_combat_cutter" or bool(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("warship", false)):
		return {"ok": false, "message": "Военный транспорт перевозит десант и не назначается на торговые рейсы."}
	var quote: Dictionary = _economy.voyage_quote(ship, get_ship_type(str(ship.get("ship_type_id", ""))), GameState.employee_state, float(route.get("distance", 0.0)), quantity)
	quote["ok"] = true
	return quote

func start_autopilot(ship_id: String, route_key: String, freight_plan: Dictionary = {}, save_now: bool = true) -> Dictionary:
	var ship_index: int = _find_auxiliary_index(ship_id)
	if ship_index < 0:
		return {"ok": false, "message": "Автопилот доступен только дополнительному кораблю."}
	var route: Dictionary = GameState.known_routes_state.get(route_key, {})
	if route.is_empty():
		return {"ok": false, "message": "Этот маршрут ещё не изучен."}
	var ship: Dictionary = GameState.fleet_state[ship_index]
	if str(ship.get("ship_type_id","")) == "ship_combat_cutter" or bool(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("warship", false)):
		return {"ok": false, "message": "Военный транспорт перевозит десант и не назначается на торговые рейсы."}
	if not ship.get("autopilot", {}).is_empty():
		return {"ok": false, "message": "Корабль уже в рейсе."}
	if not ship.get("cargo", []).is_empty():
		return {"ok": false, "message": "В трюме остался груз. Завершите предыдущую поставку."}
	var cargo_items: Array = []
	var planned_items: Variant = freight_plan.get("items", [])
	if planned_items is Array and not planned_items.is_empty():
		for raw_item in planned_items:
			if not raw_item is Dictionary:
				return {"ok": false, "message": "Состав груза заполнен неверно."}
			var item: Dictionary = raw_item
			var item_quantity: int = int(item.get("quantity", 0))
			var item_resource: String = str(item.get("resource_id", ""))
			if item_resource == "" or item_quantity <= 0:
				return {"ok": false, "message": "Для каждого товара укажите количество."}
			cargo_items.append({"resource_id": item_resource, "quantity": item_quantity})
	else:
		var legacy_quantity: int = int(freight_plan.get("quantity", 0))
		if legacy_quantity > 0:
			cargo_items.append({"resource_id": str(freight_plan.get("resource_id", "")), "quantity": legacy_quantity})
	var total_quantity: int = 0
	for cargo_item in cargo_items:
		total_quantity += int(cargo_item.get("quantity", 0))
	if total_quantity > int(ship.get("cargo_capacity", 0)):
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
	var freight: Dictionary = freight_plan.duplicate(true) if not freight_plan.is_empty() else {"managed_trade": true, "resource_id": "", "quantity": 0}
	freight["items"] = cargo_items.duplicate(true)
	freight["quantity"] = total_quantity
	var quote: Dictionary = quote_leg(ship_id, route_key, total_quantity)
	if float(GameState.player_state.get("money", 0.0)) < float(quote.cash):
		return {"ok": false, "message": "Рейс стоит %.0f: топливо, обслуживание, питание и зарплата." % float(quote.cash)}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - float(quote.cash)
	var duration: float = float(quote.duration)
	ship["last_service"] = quote.duplicate(true)
	ship.erase("trade_receipt")
	ship["cargo"] = cargo_items.duplicate(true)
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
	var hiring_systems: Array[Node] = get_tree().get_nodes_in_group("hiring_system")
	if not hiring_systems.is_empty():
		var actions: Array[String] = ["navigation", "speed", "fuel"]
		if not ship.get("cargo", []).is_empty():
			actions.append("loading")
		hiring_systems[0].record_crew_voyage_actions(crew, actions)
	if _hiring_system != null:
		ship["crew"] = _hiring_system.complete_voyage(crew)
		return
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
			var hazard_message: String = _resolve_voyage_hazard(ship, str(autopilot.get("origin_port_id", "")), str(autopilot.get("destination_port_id", "")))
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
				if hazard_message != "":
					ship["status"] += " " + hazard_message
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
			if hazard_message != "":
				ship["status"] += " " + hazard_message
			ship["autopilot"] = {}
			GameState.fleet_state[index] = ship
			changed = true
	if changed:
		SaveSystem.save_game()

func set_hazard_zones(zones: Array) -> void:
	_hazard_zones = zones.duplicate(true)

func _resolve_voyage_hazard(ship: Dictionary, origin_id: String, destination_id: String) -> String:
	if _port_system == null or _hazard_zones.is_empty():
		return ""
	var start: Vector2 = _port_system.get_port_position(origin_id)
	var finish: Vector2 = _port_system.get_port_position(destination_id)
	for raw_zone in _hazard_zones:
		var zone: Dictionary = raw_zone
		if not bool(zone.get("active", false)):
			continue
		var center: Vector2 = Vector2(zone.get("position", Vector2.ZERO))
		var radius: float = float(zone.get("radius", 0.0))
		if not _segment_touches_circle(start, finish, center, radius):
			continue
		var zone_type: String = str(zone.get("type", "storm"))
		var effects: Dictionary = _hazard_rules.get("types", {})
		var effect: Dictionary = effects.get(zone_type, effects.get("storm", {}))
		var losses: Array[String] = []
		for component in ["hull", "engine", "steering"]:
			var damage_key: String = component + "_damage"
			var damage: float = float(effect.get(damage_key, 0.0))
			if damage <= 0.0:
				continue
			var current: float = float(ship.get(component, 100.0))
			var next_value: float = maxf(10.0, current - damage)
			if next_value < current:
				ship[component] = next_value
				losses.append("%s −%.0f" % [component, current - next_value])
		if bool(effect.get("steal_one_cargo", false)) and _steal_one_unsealed_unit(ship):
			losses.append("пираты забрали 1 ед. груза")
		var result: String = str(effect.get("name", "Опасная зона"))
		if not losses.is_empty():
			result += ": " + ", ".join(losses)
		else:
			result += ": без потерь"
		return result
	return ""

func _segment_touches_circle(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var segment: Vector2 = finish - start
	var denominator: float = segment.length_squared()
	var factor: float = 0.0
	if denominator > 0.0001:
		factor = clampf((center - start).dot(segment) / denominator, 0.0, 1.0)
	return start.lerp(finish, factor).distance_to(center) <= radius

func _steal_one_unsealed_unit(ship: Dictionary) -> bool:
	var cargo: Array = ship.get("cargo", [])
	for index in range(cargo.size() - 1, -1, -1):
		var item: Dictionary = cargo[index]
		if str(item.get("contract_id", "")) != "":
			continue
		var quantity: int = int(item.get("quantity", 0))
		if quantity <= 0:
			continue
		if quantity == 1:
			cargo.remove_at(index)
		else:
			item["quantity"] = quantity - 1
			cargo[index] = item
		ship["cargo"] = cargo
		return true
	return false

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
