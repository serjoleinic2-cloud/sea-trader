extends Node

## Repeating fleet trade lines. Demand, stock and profitability can stop each line.

var _port_system: Node
var _fleet_system: Node
var _base_prices: Dictionary = {}

func _ready() -> void:
	add_to_group("trade_line_system")

func initialize(port_system: Node, fleet_system: Node) -> void:
	_port_system = port_system
	_fleet_system = fleet_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	for raw_good in catalog.get("resources", []):
		var good: Dictionary = raw_good
		_base_prices[str(good.get("id", ""))] = float(good.get("base_price", 0.0))

func get_lines() -> Array:
	var raw_lines: Variant = GameState.economy_state.get("trade_lines", [])
	return raw_lines if raw_lines is Array else []

func create_line(ship_id: String, origin_id: String, destination_id: String, resource_id: String, quantity: int, min_profit: float) -> Dictionary:
	if ship_id == "active_ship":
		return {"ok": false, "message": "Постоянные линии выполняют дополнительные корабли."}
	if _fleet_system == null or _get_route_key(origin_id, destination_id) == "":
		return {"ok": false, "message": "Нужен вручную изученный маршрут."}
	var ship: Dictionary = _get_ship(ship_id)
	if ship.is_empty() or str(ship.get("current_port_id", "")) != origin_id:
		return {"ok": false, "message": "Корабль должен стоять в начальном порту."}
	if quantity < 1 or quantity > int(ship.get("cargo_capacity", 0)):
		return {"ok": false, "message": "Количество не помещается в трюм."}
	var line_id: String = "line_%03d" % (get_lines().size() + 1)
	var line: Dictionary = {
		"id": line_id,
		"ship_id": ship_id,
		"origin_id": origin_id,
		"destination_id": destination_id,
		"resource_id": resource_id,
		"quantity": quantity,
		"min_profit": min_profit,
		"status": "Подготовка",
		"cycles": 0,
		"earned": 0.0,
		"last_message": ""
	}
	var result: Dictionary = _start_outbound(line)
	line["last_message"] = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		line["status"] = "В пути к покупателю"
	else:
		line["status"] = "Остановлена"
	var lines: Array = get_lines()
	lines.append(line)
	_set_lines(lines)
	SaveSystem.save_game()
	return result

func stop_line(line_id: String) -> void:
	var lines: Array = get_lines()
	for index in range(lines.size()):
		var line: Dictionary = lines[index]
		if str(line.get("id", "")) == line_id:
			line["status"] = "Остановлена игроком"
			lines[index] = line
	_set_lines(lines)
	SaveSystem.save_game()

func _process(_delta: float) -> void:
	var lines: Array = get_lines()
	var changed: bool = false
	for index in range(lines.size()):
		var line: Dictionary = lines[index]
		var status: String = str(line.get("status", ""))
		if status == "В пути к покупателю" and _ship_arrived(line, str(line.get("destination_id", ""))):
			_finish_sale(line)
			var return_result: Dictionary = _start_return(line)
			line["last_message"] = str(return_result.get("message", ""))
			line["status"] = "Возвращается" if bool(return_result.get("ok", false)) else "Остановлена"
			lines[index] = line
			changed = true
		elif status == "Возвращается" and _ship_arrived(line, str(line.get("origin_id", ""))):
			var next_result: Dictionary = _start_outbound(line)
			line["last_message"] = str(next_result.get("message", ""))
			line["status"] = "В пути к покупателю" if bool(next_result.get("ok", false)) else "Остановлена"
			lines[index] = line
			changed = true
	if changed:
		_set_lines(lines)
		SaveSystem.save_game()

func _start_outbound(line: Dictionary) -> Dictionary:
	var origin_id: String = str(line.get("origin_id", ""))
	var destination_id: String = str(line.get("destination_id", ""))
	var resource_id: String = str(line.get("resource_id", ""))
	var quantity: int = int(line.get("quantity", 0))
	if not _port_accepts(destination_id, resource_id):
		return {"ok": false, "message": "Этот порт не принимает данный товар."}
	var demand: int = _get_demand(destination_id, resource_id)
	if demand < quantity:
		return {"ok": false, "message": "Спрос покупателя исчерпан. Нужна другая линия."}
	var origin: Dictionary = GameState.port_state.get(origin_id, {})
	var stock: Dictionary = origin.get("market_stock", {})
	if int(stock.get(resource_id, 0)) < quantity:
		return {"ok": false, "message": "В порту-источнике нет нужного запаса."}
	var buy_price: float = _base_price(resource_id) * 1.20
	var sale_price: float = _sale_price(destination_id, resource_id)
	var fuel_reserve: float = 12.0
	var predicted_profit: float = (sale_price - buy_price) * quantity - fuel_reserve
	if predicted_profit < float(line.get("min_profit", 0.0)):
		return {"ok": false, "message": "Прибыль ниже установленного минимума."}
	var purchase_cost: float = buy_price * quantity
	if float(GameState.player_state.get("money", 0.0)) < purchase_cost:
		return {"ok": false, "message": "Недостаточно денег для закупки."}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - purchase_cost
	stock[resource_id] = int(stock.get(resource_id, 0)) - quantity
	origin["market_stock"] = stock
	GameState.port_state[origin_id] = origin
	var freight: Dictionary = {
		"resource_id": resource_id,
		"quantity": quantity,
		"reward": sale_price * quantity,
		"line_id": str(line.get("id", ""))
	}
	return _fleet_system.start_autopilot(str(line.get("ship_id", "")), _get_route_key(origin_id, destination_id), freight)

func _start_return(line: Dictionary) -> Dictionary:
	var empty_freight: Dictionary = {"resource_id": "", "quantity": 0, "reward": 0.0, "line_id": str(line.get("id", ""))}
	return _fleet_system.start_autopilot(str(line.get("ship_id", "")), _get_route_key(str(line.get("origin_id", "")), str(line.get("destination_id", ""))), empty_freight)

func _finish_sale(line: Dictionary) -> void:
	var destination_id: String = str(line.get("destination_id", ""))
	var resource_id: String = str(line.get("resource_id", ""))
	var quantity: int = int(line.get("quantity", 0))
	_set_demand(destination_id, resource_id, maxi(0, _get_demand(destination_id, resource_id) - quantity))
	line["cycles"] = int(line.get("cycles", 0)) + 1
	line["earned"] = float(line.get("earned", 0.0)) + _sale_price(destination_id, resource_id) * quantity

func _ship_arrived(line: Dictionary, port_id: String) -> bool:
	var ship: Dictionary = _get_ship(str(line.get("ship_id", "")))
	var autopilot: Dictionary = ship.get("autopilot", {})
	return not ship.is_empty() and autopilot.is_empty() and str(ship.get("current_port_id", "")) == port_id

func _get_ship(ship_id: String) -> Dictionary:
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
		if str(ship.get("instance_id", "")) == ship_id:
			return ship
	return {}

func _get_route_key(origin_id: String, destination_id: String) -> String:
	for route_key in GameState.known_routes_state:
		var route: Dictionary = GameState.known_routes_state[route_key]
		var a_id: String = str(route.get("port_a_id", ""))
		var b_id: String = str(route.get("port_b_id", ""))
		if (a_id == origin_id and b_id == destination_id) or (a_id == destination_id and b_id == origin_id):
			return str(route_key)
	return ""

func _port_accepts(port_id: String, resource_id: String) -> bool:
	return posmod(hash(port_id + resource_id), 5) != 0

func _get_demand(port_id: String, resource_id: String) -> int:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var demand: Dictionary = port.get("market_demand", {})
	if not demand.has(resource_id):
		demand[resource_id] = 30 + posmod(hash(port_id + resource_id), 31)
		port["market_demand"] = demand
		GameState.port_state[port_id] = port
	return int(demand.get(resource_id, 0))

func _set_demand(port_id: String, resource_id: String, amount: int) -> void:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var demand: Dictionary = port.get("market_demand", {})
	demand[resource_id] = amount
	port["market_demand"] = demand
	GameState.port_state[port_id] = port

func _sale_price(port_id: String, resource_id: String) -> float:
	var demand_factor: float = 0.75 + float(_get_demand(port_id, resource_id)) / 100.0
	return _base_price(resource_id) * 1.25 * demand_factor

func _base_price(resource_id: String) -> float:
	return float(_base_prices.get(resource_id, 0.0))

func _set_lines(lines: Array) -> void:
	GameState.economy_state["trade_lines"] = lines
