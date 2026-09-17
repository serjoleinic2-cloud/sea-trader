extends Node

## Evaluates a concrete ship's trading route before the player spends money or fuel.

var _port_system: Node
var _goods: Array = []

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	var raw_goods: Variant = catalog.get("resources", [])
	if raw_goods is Array:
		_goods = raw_goods

func get_goods() -> Array:
	return _goods

func get_known_ports() -> Array:
	var result: Array = []
	var raw_ids: Variant = GameState.player_state.get("discovered_port_ids", [])
	if not (raw_ids is Array):
		return result
	for raw_port_id in raw_ids:
		var port_id: String = str(raw_port_id)
		result.append({"id": port_id, "name": _port_system.get_port_name(port_id)})
	return result

func get_available_ships() -> Array:
	var ships: Array = [{
		"id": "active_ship",
		"name": "Ваш корабль",
		"current_port_id": str(GameState.ship_state.get("docked_port_id", "")),
		"cargo_capacity": int(GameState.ship_state.get("cargo_capacity", 0)),
		"fuel": float(GameState.ship_state.get("fuel", 0.0)),
		"status": "Под вашим управлением"
	}]
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
		if str(ship.get("status", "")) == "В пути":
			continue
		ships.append({
			"id": str(ship.get("instance_id", "")),
			"name": str(ship.get("name", "Корабль")),
			"current_port_id": str(ship.get("current_port_id", "")),
			"cargo_capacity": int(ship.get("cargo_capacity", 0)),
			"fuel": 100.0,
			"status": str(ship.get("status", "В порту"))
		})
	return ships

func get_ship(ship_id: String) -> Dictionary:
	for raw_ship in get_available_ships():
		var ship: Dictionary = raw_ship
		if str(ship.get("id", "")) == ship_id:
			return ship
	return {}

func evaluate(ship_id: String, origin_port_id: String, destination_port_id: String, resource_id: String, quantity: int) -> Dictionary:
	var ship: Dictionary = get_ship(ship_id)
	if ship.is_empty():
		return {"ok": false, "message": "Выберите доступный корабль."}
	if origin_port_id == "" or destination_port_id == "" or origin_port_id == destination_port_id:
		return {"ok": false, "message": "Выберите два разных известных порта."}
	if str(ship.get("current_port_id", "")) != origin_port_id:
		return {"ok": false, "message": "Корабль сейчас не находится в начальном порту маршрута."}
	var amount: int = maxi(1, quantity)
	var capacity: int = int(ship.get("cargo_capacity", 0))
	if amount > capacity:
		return {"ok": false, "message": "Выбранный объём больше трюма корабля (%d)." % capacity}
	var distance: float = _get_route_distance(origin_port_id, destination_port_id)
	if distance <= 0.0:
		return {"ok": false, "message": "Между этими портами ещё нет известного маршрута."}
	var buy_price: float = _get_buy_price(origin_port_id, resource_id)
	var sell_price: float = _get_sell_price(destination_port_id, resource_id)
	var fuel_needed: float = maxf(1.0, distance / 500.0)
	var fuel_cost: float = fuel_needed * 5.0
	var repair_reserve: float = ceil(distance / 1500.0) * 6.0
	var gross: float = (sell_price - buy_price) * amount
	var net: float = gross - fuel_cost - repair_reserve
	return {
		"ok": true,
		"ship_name": str(ship.get("name", "")),
		"ship_status": str(ship.get("status", "")),
		"capacity": capacity,
		"fuel_current": float(ship.get("fuel", 0.0)),
		"buy_price": buy_price,
		"sell_price": sell_price,
		"distance": distance,
		"fuel_needed": fuel_needed,
		"fuel_cost": fuel_cost,
		"repair_reserve": repair_reserve,
		"gross": gross,
		"net": net
	}

func start_route(ship_id: String, origin_port_id: String, destination_port_id: String) -> Dictionary:
	var ship: Dictionary = get_ship(ship_id)
	if ship.is_empty() or str(ship.get("current_port_id", "")) != origin_port_id:
		return {"ok": false, "message": "Выбранный корабль не готов в этом порту."}
	var route_key: String = _get_route_key(origin_port_id, destination_port_id)
	if route_key == "":
		return {"ok": false, "message": "Сначала изучите маршрут своим кораблём."}
	if ship_id == "active_ship":
		var systems: Array[Node] = get_tree().get_nodes_in_group("active_route_autopilot_system")
		if systems.is_empty():
			return {"ok": false, "message": "Автопилот основного корабля недоступен."}
		return systems[0].start(destination_port_id)
	var fleets: Array[Node] = get_tree().get_nodes_in_group("fleet_system")
	if fleets.is_empty():
		return {"ok": false, "message": "Система флота недоступна."}
	return fleets[0].start_autopilot(ship_id, route_key)

func _get_route_key(origin_id: String, destination_id: String) -> String:
	for route_key in GameState.known_routes_state:
		var route: Dictionary = GameState.known_routes_state[route_key]
		var a_id: String = str(route.get("port_a_id", ""))
		var b_id: String = str(route.get("port_b_id", ""))
		if (a_id == origin_id and b_id == destination_id) or (a_id == destination_id and b_id == origin_id):
			return str(route_key)
	return ""

func _get_route_distance(origin_id: String, destination_id: String) -> float:
	for route_key in GameState.known_routes_state:
		var route: Dictionary = GameState.known_routes_state[route_key]
		var a_id: String = str(route.get("port_a_id", ""))
		var b_id: String = str(route.get("port_b_id", ""))
		if (a_id == origin_id and b_id == destination_id) or (a_id == destination_id and b_id == origin_id):
			return float(route.get("distance", 0.0))
	return 0.0

func _get_buy_price(port_id: String, resource_id: String) -> float:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var multipliers: Dictionary = port.get("price_multipliers", {})
	return round(_get_base_price(resource_id) * 1.20 * float(multipliers.get(resource_id, 1.0)))

func _get_sell_price(port_id: String, resource_id: String) -> float:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var multipliers: Dictionary = port.get("price_multipliers", {})
	var demand: float = 2.0 - float(multipliers.get(resource_id, 1.0))
	return round(_get_base_price(resource_id) * 1.25 * demand)

func _get_base_price(resource_id: String) -> float:
	for raw_good in _goods:
		var good: Dictionary = raw_good
		if str(good.get("id", "")) == resource_id:
			return float(good.get("base_price", 0.0))
	return 0.0
