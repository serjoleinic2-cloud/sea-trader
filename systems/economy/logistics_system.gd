extends Node

## Evaluates a concrete ship's trading route before the player spends money or fuel.

var _port_system: Node
var _goods: Array = []

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = GameData.read("res://data/resources/goods_catalog.json")
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
	var markets: Array[Node] = get_tree().get_nodes_in_group("trade_line_system")
	if markets.is_empty():
		return {"ok": false, "message": "Рынок недоступен."}
	var purchase: Dictionary = {"ok": true, "cost": 0.0, "unit_price": 0.0}
	if origin_port_id != str(GameState.world_state.get("home_port_id", "")) and ship_id != "active_ship":
		purchase = markets[0].quote_purchase(origin_port_id, resource_id, amount)
	var sale: Dictionary = {"ok": true, "revenue": 0.0, "unit_price": 0.0}
	if destination_port_id != str(GameState.world_state.get("home_port_id", "")):
		sale = markets[0].quote_sale(destination_port_id, resource_id, amount)
	if not bool(purchase.get("ok", false)) or not bool(sale.get("ok", false)):
		return {"ok": false, "message": str(purchase.get("message", sale.get("message", "")))}
	var buy_price: float = float(purchase.get("unit_price", 0.0))
	var sell_price: float = float(sale.get("unit_price", 0.0))
	var fuel_needed: float = distance * 0.003
	var ready: Dictionary = {"ok": true, "message": ""}
	if ship_id == "active_ship":
		var systems: Array[Node] = get_tree().get_nodes_in_group("active_route_autopilot_system")
		if not systems.is_empty():
			fuel_needed = systems[0].fuel_needed(destination_port_id)
			ready = systems[0].validate_start(destination_port_id, resource_id, quantity)
	var services: Dictionary = GameData.read("res://data/ports/service_rules.json")
	var fuel_cost: float = fuel_needed * float(services.get("price_per_fuel", 5.0))
	var repair_reserve: float = ceil(distance / 1500.0) * float(services.get("price_per_hull", 6.0))
	var other_cost: float = 0.0
	var service_text: String = ""
	if ship_id != "active_ship":
		var fleet: Node = get_tree().get_first_node_in_group("fleet_system")
		var quote: Dictionary = fleet.quote_leg(ship_id, _get_route_key(origin_port_id, destination_port_id), amount)
		if not bool(quote.get("ok", false)):
			return quote
		fuel_cost = float(quote.fuel)
		repair_reserve = float(quote.repair)
		other_cost = float(quote.food) + float(quote.wages) + float(quote.prepaid_wages) + float(quote.port_fee)
		service_text = "Питание %.0f; зарплата %.0f (предоплачено %.0f); порт %.0f. Списать за рейс: %.0f." % [float(quote.food), float(quote.wages), float(quote.prepaid_wages), float(quote.port_fee), float(quote.cash)]
		if float(GameState.player_state.get("money", 0.0)) < float(quote.cash) + float(purchase.cost):
			ready = {"ok": false, "message": "Не хватает денег на закупку и обслуживание."}
	var gross: float = (sell_price - buy_price) * amount
	var net: float = gross - fuel_cost - repair_reserve - other_cost
	return {
		"ok": true,
		"can_start": bool(ready.get("ok", false)),
		"start_message": str(ready.get("message", "")),
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
		"auxiliary": ship_id != "active_ship",
		"service_text": service_text,
		"gross": gross,
		"net": net
	}

func start_route(ship_id: String, origin_port_id: String, destination_port_id: String, resource_id: String = "", quantity: int = 0) -> Dictionary:
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
		return systems[0].start(destination_port_id, resource_id, quantity)
	var fleets: Array[Node] = get_tree().get_nodes_in_group("fleet_system")
	if fleets.is_empty():
		return {"ok": false, "message": "Система флота недоступна."}
	var markets: Array[Node] = get_tree().get_nodes_in_group("trade_line_system")
	if markets.is_empty():
		return {"ok": false, "message": "Рынок недоступен."}
	return markets[0].start_single_trip(ship_id, origin_port_id, destination_port_id, resource_id, quantity)

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
	if port_id == str(GameState.world_state.get("home_port_id", "")):
		return 0.0
	var markets: Array[Node] = get_tree().get_nodes_in_group("trade_line_system")
	return float(markets[0].get_buy_price(port_id, resource_id)) if not markets.is_empty() else 0.0

func _get_sell_price(port_id: String, resource_id: String) -> float:
	if port_id == str(GameState.world_state.get("home_port_id", "")):
		return 0.0
	var markets: Array[Node] = get_tree().get_nodes_in_group("trade_line_system")
	return float(markets[0].get_sell_price(port_id, resource_id)) if not markets.is_empty() else 0.0
