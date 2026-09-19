extends Node

## Repeating fleet trade lines with demand, return cargo and clear stop reasons.

const DEMAND_MAX: int = 60
const DEMAND_RECOVERY_SECONDS: int = 120
const DEMAND_RECOVERY_AMOUNT: int = 8

var _port_system: Node
var _fleet_system: Node
var _base_prices: Dictionary = {}
var _good_names: Dictionary = {}

func _ready() -> void:
	add_to_group("trade_line_system")

func initialize(port_system: Node, fleet_system: Node) -> void:
	_port_system = port_system
	_fleet_system = fleet_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	var raw_goods: Variant = catalog.get("resources", [])
	if raw_goods is Array:
		for raw_good in raw_goods:
			var good: Dictionary = raw_good
			var resource_id: String = str(good.get("id", ""))
			_base_prices[resource_id] = float(good.get("base_price", 0.0))
			_good_names[resource_id] = str(good.get("display_name", resource_id.replace("resource_", "").capitalize()))

func get_lines() -> Array:
	var raw_lines: Variant = GameState.economy_state.get("trade_lines", [])
	return raw_lines if raw_lines is Array else []

func get_known_ports() -> Array:
	var ports: Array = []
	if _port_system == null:
		return ports
	for raw_port_id in _port_system.get_all_port_ids():
		var port_id: String = str(raw_port_id)
		if GameState.player_state.discovered_port_ids.has(port_id):
			ports.append({"id": port_id, "name": _port_system.get_port_name(port_id)})
	return ports

func get_goods() -> Array:
	var goods: Array = []
	for resource_id in _base_prices:
		goods.append({"id": str(resource_id), "name": str(_good_names.get(resource_id, resource_id))})
	return goods

func get_market_info(port_id: String, resource_id: String) -> Dictionary:
	_refresh_demand(port_id)
	if not _port_accepts(port_id, resource_id):
		return {"accepted": false, "demand": 0, "restores_in": 0, "message": "Порт не принимает этот товар."}
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var recovery_at: int = int(port.get("market_demand_recovery_at", 0))
	var restores_in: int = maxi(0, recovery_at - _now())
	return {
		"accepted": true,
		"demand": _get_demand(port_id, resource_id),
		"restores_in": restores_in,
		"message": "Спрос восстановится через %d сек." % restores_in
	}

func try_sell_to_port(port_id: String, resource_id: String, quantity: int) -> Dictionary:
	if quantity <= 0 or not _base_prices.has(resource_id) or not GameState.port_state.has(port_id):
		return {"ok": false, "message": "Некорректный товар или количество."}
	if port_id == str(GameState.world_state.get("home_port_id", "")):
		return {"ok": false, "message": "На своей базе выгружайте товар на склад."}
	var amount: int = quantity
	var info: Dictionary = get_market_info(port_id, resource_id)
	if not bool(info.get("accepted", false)):
		return {"ok": false, "message": str(info.get("message", "Порт не принимает этот товар."))}
	var demand: int = int(info.get("demand", 0))
	if demand < amount:
		return {"ok": false, "message": "Спрос порта: %d ед. Ждите восстановления спроса." % demand}
	var unit_price: float = _sale_price(port_id, resource_id)
	_set_demand(port_id, resource_id, demand - amount)
	return {
		"ok": true,
		"unit_price": unit_price,
		"revenue": unit_price * amount,
		"message": "Продано по цене %.0f за ед." % unit_price
	}

func create_line(ship_id: String, origin_id: String, destination_id: String, resource_id: String, return_resource_id: String, quantity: int, min_profit: float) -> Dictionary:
	if ship_id == "active_ship":
		return {"ok": false, "message": "Постоянные линии выполняют дополнительные корабли."}
	if origin_id == "" or destination_id == "" or origin_id == destination_id or _get_route_key(origin_id, destination_id) == "":
		return {"ok": false, "message": "Нужен вручную изученный маршрут между разными портами."}
	var ship: Dictionary = _get_ship(ship_id)
	if ship.is_empty() or str(ship.get("current_port_id", "")) != origin_id:
		return {"ok": false, "message": "Корабль должен стоять в начальном порту."}
	if quantity < 1 or quantity > int(ship.get("cargo_capacity", 0)):
		return {"ok": false, "message": "Количество не помещается в трюм."}
	for existing in get_lines():
		if str(existing.get("ship_id", "")) == ship_id:
			return {"ok": false, "message": "Корабль уже закреплён за линией. Используйте «Повторить»."}
	var line_id: String = "line_%03d" % (get_lines().size() + 1)
	var line: Dictionary = {
		"id": line_id,
		"ship_id": ship_id,
		"origin_id": origin_id,
		"destination_id": destination_id,
		"resource_id": resource_id,
		"return_resource_id": return_resource_id,
		"quantity": quantity,
		"min_profit": min_profit,
		"status": "Подготовка",
		"cycles": 0,
		"earned": 0.0,
		"last_message": ""
	}
	var result: Dictionary = _start_outbound(line)
	line["last_message"] = str(result.get("message", ""))
	line["status"] = "В пути к покупателю" if bool(result.get("ok", false)) else "Остановлена"
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
			line["last_message"] = "После текущего рейса линия больше не запускается."
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
			var sale_result: Dictionary = _finish_sale(line, str(line.get("destination_id", "")), str(line.get("resource_id", "")), false)
			if not bool(sale_result.get("ok", false)):
				line["status"] = "Остановлена"
				line["last_message"] = str(sale_result.get("message", "Продажа не состоялась."))
			else:
				line = sale_result.get("line", line)
				var return_result: Dictionary = _start_return(line)
				line["last_message"] = str(return_result.get("message", ""))
				line["status"] = "В пути с обратным грузом" if bool(return_result.get("ok", false)) else "Остановлена"
			lines[index] = line
			changed = true
		elif status in ["В пути с обратным грузом", "Возвращается"] and _ship_arrived(line, str(line.get("origin_id", ""))):
			var return_resource_id: String = str(line.get("return_resource_id", ""))
			if return_resource_id != "":
				var return_sale: Dictionary = _finish_sale(line, str(line.get("origin_id", "")), return_resource_id, true)
				if not bool(return_sale.get("ok", false)):
					line["status"] = "Остановлена"
					line["last_message"] = str(return_sale.get("message", "Продажа обратного груза не состоялась."))
					lines[index] = line
					changed = true
					continue
				line = return_sale.get("line", line)
			else:
				line["cycles"] = int(line.get("cycles", 0)) + 1
			var next_result: Dictionary = _start_outbound(line)
			line["last_message"] = str(next_result.get("message", ""))
			line["status"] = "В пути к покупателю" if bool(next_result.get("ok", false)) else "Остановлена"
			lines[index] = line
			changed = true
	if changed:
		_set_lines(lines)
		SaveSystem.save_game()

func _start_outbound(line: Dictionary) -> Dictionary:
	return _start_trade_leg(
		line,
		str(line.get("origin_id", "")),
		str(line.get("destination_id", "")),
		str(line.get("resource_id", ""))
	)

func _start_return(line: Dictionary) -> Dictionary:
	var return_resource_id: String = str(line.get("return_resource_id", ""))
	var origin_id: String = str(line.get("origin_id", ""))
	var destination_id: String = str(line.get("destination_id", ""))
	if return_resource_id == "":
		var rules: Dictionary = SaveSystem._read_json("res://data/economy/logistics_rules.json")
		var cost: float = float(rules.get("fleet_leg_service_cost", 12.0))
		if float(GameState.player_state.get("money", 0.0)) < cost:
			return {"ok": false, "message": "Не хватает денег на обратный рейс: %.0f." % cost}
		var empty_freight: Dictionary = {"resource_id": "", "quantity": 0, "reward": 0.0, "managed_trade": true, "line_id": str(line.get("id", ""))}
		var result: Dictionary = _fleet_system.start_autopilot(str(line.get("ship_id", "")), _get_route_key(origin_id, destination_id), empty_freight, false)
		if bool(result.get("ok", false)):
			GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - cost
			line["spent"] = float(line.get("spent", 0.0)) + cost
		return result
	return _start_trade_leg(line, destination_id, origin_id, return_resource_id)

func get_buy_price(port_id: String, resource_id: String) -> float:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	return round(_base_price(resource_id) * 1.20 * float(port.get("price_multipliers", {}).get(resource_id, 1.0)))

func get_sell_price(port_id: String, resource_id: String) -> float:
	return _sale_price(port_id, resource_id)

func start_single_trip(ship_id: String, source_id: String, target_id: String, resource_id: String, quantity: int) -> Dictionary:
	var plan: Dictionary = {"ship_id": ship_id, "id": "", "quantity": quantity, "min_profit": -INF}
	var result: Dictionary = _start_trade_leg(plan, source_id, target_id, resource_id)
	if bool(result.get("ok", false)):
		SaveSystem.save_game()
	return result

func _start_trade_leg(line: Dictionary, source_id: String, target_id: String, resource_id: String) -> Dictionary:
	var quantity: int = int(line.get("quantity", 0))
	if quantity <= 0 or not _base_prices.has(resource_id):
		return {"ok": false, "message": "Выберите товар и положительное количество."}
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	var to_home: bool = target_id == home_id
	if not to_home:
		var info: Dictionary = get_market_info(target_id, resource_id)
		if not bool(info.get("accepted", false)):
			return {"ok": false, "message": "Порт не принимает «%s»." % _good_name(resource_id)}
		if int(info.get("demand", 0)) < quantity:
			return {"ok": false, "message": "Спрос: %d ед. Повторите после восстановления." % int(info.get("demand", 0))}
	var source: Dictionary = GameState.port_state.get(source_id, {})
	var stock_key: String = "inventory" if source_id == home_id else "market_stock"
	var stock: Dictionary = source.get(stock_key, {})
	if int(stock.get(resource_id, 0)) < quantity:
		return {"ok": false, "message": "В источнике недостаточно «%s»." % _good_name(resource_id)}
	var buy_price: float = 0.0 if source_id == home_id else get_buy_price(source_id, resource_id)
	var sale_price: float = 0.0 if to_home else _sale_price(target_id, resource_id)
	var rules: Dictionary = SaveSystem._read_json("res://data/economy/logistics_rules.json")
	var service_cost: float = float(rules.get("fleet_leg_service_cost", 12.0))
	var predicted_profit: float = (sale_price - buy_price) * quantity - service_cost
	if not to_home and predicted_profit < float(line.get("min_profit", 0.0)):
		return {"ok": false, "message": "Ожидаемый результат %.0f ниже минимума." % predicted_profit}
	var cost: float = buy_price * quantity + service_cost
	if float(GameState.player_state.get("money", 0.0)) < cost:
		return {"ok": false, "message": "Не хватает денег на закупку и обслуживание рейса: %.0f." % cost}
	var freight: Dictionary = {"resource_id": resource_id, "quantity": quantity,
		"reward": 0.0, "managed_trade": true, "line_id": str(line.get("id", ""))}
	# Fleet validates crew, cargo and busy state before any purchase is committed.
	var result: Dictionary = _fleet_system.start_autopilot(str(line.get("ship_id", "")), _get_route_key(source_id, target_id), freight, false)
	if not bool(result.get("ok", false)):
		return result
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - cost
	stock[resource_id] = int(stock.get(resource_id, 0)) - quantity
	source[stock_key] = stock
	GameState.port_state[source_id] = source
	line["spent"] = float(line.get("spent", 0.0)) + cost
	return result

func settle_freight(ship: Dictionary, freight: Dictionary) -> Dictionary:
	var resource_id: String = str(freight.get("resource_id", ""))
	var quantity: int = int(freight.get("quantity", 0))
	var target_id: String = str(ship.get("current_port_id", ""))
	if quantity == 0:
		return {"ok": true, "revenue": 0.0, "message": "Возврат без груза."}
	var available: int = 0
	for item in ship.get("cargo", []):
		if str(item.get("resource_id", "")) == resource_id:
			available += int(item.get("quantity", 0))
	if available < quantity:
		return {"ok": false, "message": "Недостаточно груза в трюме."}
	var result: Dictionary
	if target_id == str(GameState.world_state.get("home_port_id", "")):
		var port: Dictionary = GameState.port_state.get(target_id, {})
		var inventory: Dictionary = port.get("inventory", {})
		inventory[resource_id] = int(inventory.get(resource_id, 0)) + quantity
		port["inventory"] = inventory
		GameState.port_state[target_id] = port
		result = {"ok": true, "revenue": 0.0, "message": "Груз выгружен на склад базы."}
	else:
		result = try_sell_to_port(target_id, resource_id, quantity)
	if bool(result.get("ok", false)):
		ship["cargo"] = []
		var revenue: float = float(result.get("revenue", 0.0))
		GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + revenue
		var stats: Dictionary = GameState.player_state.get("stats", {})
		stats["total_earned"] = float(stats.get("total_earned", 0.0)) + revenue
		stats["cargo_units_moved"] = int(stats.get("cargo_units_moved", 0)) + quantity
		if revenue > 0.0:
			stats["total_sales"] = int(stats.get("total_sales", 0)) + quantity
		GameState.player_state["stats"] = stats
	return result

func _finish_sale(line: Dictionary, _target_id: String, _resource_id: String, completed_cycle: bool) -> Dictionary:
	var ship: Dictionary = _get_ship(str(line.get("ship_id", "")))
	var result: Dictionary = ship.get("trade_receipt", {})
	if result.is_empty():
		return {"ok": false, "message": "Нет подтверждения продажи; груз не списан повторно."}
	if not bool(result.get("ok", false)):
		return result
	line["earned"] = float(line.get("earned", 0.0)) + float(result.get("revenue", 0.0))
	ship.erase("trade_receipt")
	if completed_cycle:
		line["cycles"] = int(line.get("cycles", 0)) + 1
	return {"ok": true, "line": line, "message": str(result.get("message", ""))}

func resume_line(line_id: String) -> Dictionary:
	var lines: Array = get_lines()
	for line in lines:
		if str(line.get("id", "")) != line_id:
			continue
		var ship: Dictionary = _get_ship(str(line.get("ship_id", "")))
		if not ship.get("autopilot", {}).is_empty():
			return {"ok": false, "message": "Дождитесь завершения текущего рейса."}
		if ship.has("pending_trade"):
			var receipt: Dictionary = settle_freight(ship, ship["pending_trade"])
			ship["trade_receipt"] = receipt
			if not bool(receipt.get("ok", false)):
				line["last_message"] = str(receipt.get("message", ""))
				SaveSystem.save_game()
				return receipt
			ship.erase("pending_trade")
		var at_origin: bool = str(ship.get("current_port_id", "")) == str(line.get("origin_id", ""))
		if ship.has("trade_receipt"):
			line["status"] = "В пути с обратным грузом" if at_origin else "В пути к покупателю"
		else:
			var result: Dictionary = _start_outbound(line) if at_origin else _start_return(line)
			line["status"] = ("В пути к покупателю" if at_origin else "В пути с обратным грузом") if bool(result.get("ok", false)) else "Остановлена"
			line["last_message"] = str(result.get("message", ""))
		_set_lines(lines)
		SaveSystem.save_game()
		return {"ok": not str(line["status"]).begins_with("Остановлена"), "message": str(line.get("last_message", ""))}
	return {"ok": false, "message": "Линия не найдена."}

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

func _refresh_demand(port_id: String) -> void:
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var now: int = _now()
	var recovery_at: int = int(port.get("market_demand_recovery_at", 0))
	if recovery_at == 0:
		port["market_demand_recovery_at"] = now + DEMAND_RECOVERY_SECONDS
		GameState.port_state[port_id] = port
		return
	if now < recovery_at:
		return
	var steps: int = maxi(1, int((now - recovery_at) / DEMAND_RECOVERY_SECONDS) + 1)
	var demand: Dictionary = port.get("market_demand", {})
	for resource_id in demand:
		demand[resource_id] = mini(DEMAND_MAX, int(demand[resource_id]) + DEMAND_RECOVERY_AMOUNT * steps)
	port["market_demand"] = demand
	port["market_demand_recovery_at"] = recovery_at + DEMAND_RECOVERY_SECONDS * steps
	GameState.port_state[port_id] = port

func _get_demand(port_id: String, resource_id: String) -> int:
	_refresh_demand(port_id)
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
	demand[resource_id] = clampi(amount, 0, DEMAND_MAX)
	port["market_demand"] = demand
	GameState.port_state[port_id] = port

func _sale_price(port_id: String, resource_id: String) -> float:
	var demand_factor: float = 0.75 + float(_get_demand(port_id, resource_id)) / 100.0
	return round(_base_price(resource_id) * 1.25 * demand_factor)

func _base_price(resource_id: String) -> float:
	return float(_base_prices.get(resource_id, 0.0))

func _good_name(resource_id: String) -> String:
	return str(_good_names.get(resource_id, resource_id))

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _set_lines(lines: Array) -> void:
	GameState.economy_state["trade_lines"] = lines
