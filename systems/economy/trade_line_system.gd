extends Node

## Repeating fleet trade lines with demand, return cargo and clear stop reasons.

var _rules: Dictionary = {}
var _economy = preload("res://systems/economy/economy_model.gd").new()

var _port_system: Node
var _fleet_system: Node
var _base_prices: Dictionary = {}
var _good_names: Dictionary = {}

func _ready() -> void:
	add_to_group("trade_line_system")

func initialize(port_system: Node, fleet_system: Node) -> void:
	_rules = GameData.read("res://data/economy/market_rules.json")
	_port_system = port_system
	_fleet_system = fleet_system
	var catalog: Dictionary = GameData.read("res://data/resources/goods_catalog.json")
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
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var profile: Dictionary = _economy.profile(port_id, resource_id, _now())
	return {"accepted": profile.accepted, "demand": _get_demand(port_id, resource_id),
		"restores_in": int(_economy.rules.market.tick_seconds) - posmod(_now(), int(_economy.rules.market.tick_seconds)),
		"target": profile.target, "phase_seconds": profile.phase_seconds,
		"message": "Спрос зависит от запаса и потребления порта."}

func quote_sale(port_id: String, resource_id: String, quantity: int) -> Dictionary:
	_refresh_demand(port_id)
	return _economy.sale_quote(GameState.port_state.get(port_id, {}), port_id, resource_id, quantity, _now(), _sale_bonus())

func quote_purchase(port_id: String, resource_id: String, quantity: int) -> Dictionary:
	_refresh_demand(port_id)
	return _economy.purchase_quote(GameState.port_state.get(port_id, {}), port_id, resource_id, quantity, _now())

func try_sell_to_port(port_id: String, resource_id: String, quantity: int) -> Dictionary:
	if port_id == str(GameState.world_state.get("home_port_id", "")):
		return {"ok": false, "message": "На своей базе выгружайте товар на склад."}
	if not GameState.port_state.has(port_id):
		return {"ok": false, "message": "Неизвестный порт."}
	var quote: Dictionary = quote_sale(port_id, resource_id, quantity)
	if not bool(quote.get("ok", false)):
		return quote
	var port: Dictionary = GameState.port_state[port_id]
	var stock: Dictionary = port.get("market_stock", {})
	stock[resource_id] = int(stock.get(resource_id, 0)) + quantity
	port["market_stock"] = stock
	GameState.port_state[port_id] = port
	quote["message"] = "Продано по средней цене %.2f за ед." % float(quote.unit_price)
	return quote

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
		var cost: float = float(_fleet_system.quote_leg(str(line.get("ship_id", "")), _get_route_key(origin_id, destination_id), 0).get("cash", 0.0))
		if float(GameState.player_state.get("money", 0.0)) < cost:
			return {"ok": false, "message": "Не хватает денег на обратный рейс: %.0f." % cost}
		var empty_freight: Dictionary = {"resource_id": "", "quantity": 0, "reward": 0.0, "managed_trade": true, "line_id": str(line.get("id", ""))}
		var result: Dictionary = _fleet_system.start_autopilot(str(line.get("ship_id", "")), _get_route_key(origin_id, destination_id), empty_freight, false)
		if bool(result.get("ok", false)):
			line["spent"] = float(line.get("spent", 0.0)) + cost
		return result
	return _start_trade_leg(line, destination_id, origin_id, return_resource_id)

func get_buy_price(port_id: String, resource_id: String) -> float:
	var quote: Dictionary = quote_purchase(port_id, resource_id, 1)
	return float(quote.get("unit_price", 0.0))

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
	if source_id != home_id:
		_refresh_demand(source_id)
	var source: Dictionary = GameState.port_state.get(source_id, {})
	var stock_key: String = "inventory" if source_id == home_id else "market_stock"
	var stock: Dictionary = source.get(stock_key, {})
	var available_stock: int = int(stock.get(resource_id, 0))
	if source_id == home_id:
		available_stock -= _reserved_for_sale(resource_id)
	if available_stock < quantity:
		return {"ok": false, "message": "В источнике недостаточно «%s»." % _good_name(resource_id)}
	var purchase: Dictionary = {"ok": true, "cost": 0.0}
	if source_id != home_id:
		purchase = quote_purchase(source_id, resource_id, quantity)
	if not bool(purchase.get("ok", false)):
		return purchase
	var sale: Dictionary = {"ok": true, "revenue": 0.0}
	if not to_home:
		sale = quote_sale(target_id, resource_id, quantity)
	if not bool(sale.get("ok", false)):
		return sale
	var route_key: String = _get_route_key(source_id, target_id)
	var service: Dictionary = _fleet_system.quote_leg(str(line.get("ship_id", "")), route_key, quantity)
	if not bool(service.get("ok", false)):
		return service
	var return_cost: float = 0.0
	if str(line.get("id", "")) != "" and source_id == str(line.get("origin_id", "")):
		return_cost = float(_fleet_system.quote_leg(str(line.get("ship_id", "")), route_key, 0).get("economic_cost", 0.0))
	var production_cost: float = 0.0
	if source_id == home_id:
		for recipe in GameData.read("res://data/ports/production_recipes.json").get("recipes", []):
			if str(recipe.resource_id) == resource_id:
				production_cost = float(recipe.get("cash_per_unit", 0.0)) * quantity
	var predicted_profit: float = float(sale.get("revenue", 0.0)) - float(purchase.cost) - float(service.economic_cost) - return_cost - production_cost
	if not to_home and predicted_profit < float(line.get("min_profit", 0.0)):
		return {"ok": false, "message": "Результат с расходами и возвратом %.0f ниже минимума." % predicted_profit}
	var cost: float = float(purchase.cost) + float(service.cash)
	if float(GameState.player_state.get("money", 0.0)) < cost:
		return {"ok": false, "message": "Не хватает денег на товар и рейс: %.0f." % cost}
	var freight: Dictionary = {"resource_id": resource_id, "quantity": quantity,
		"reward": 0.0, "managed_trade": true, "line_id": str(line.get("id", ""))}
	# Fleet validates crew, cargo and busy state before any purchase is committed.
	var result: Dictionary = _fleet_system.start_autopilot(str(line.get("ship_id", "")), _get_route_key(source_id, target_id), freight, false)
	if not bool(result.get("ok", false)):
		return result
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - float(purchase.cost)
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
	return bool(_economy.profile(port_id, resource_id, _now()).accepted)

func _refresh_demand(port_id: String) -> void:
	if not GameState.port_state.has(port_id):
		return
	var port: Dictionary = GameState.port_state[port_id]
	_economy.refresh(port, port_id, _now())
	GameState.port_state[port_id] = port

func _get_demand(port_id: String, resource_id: String) -> int:
	_refresh_demand(port_id)
	return _economy.demand(GameState.port_state.get(port_id, {}), port_id, resource_id, _now())

func _sale_bonus() -> float:
	var rewards: Array[Node] = get_tree().get_nodes_in_group("reward_system")
	return float(rewards[0].get_bonus_percent("sale")) / 100.0 if not rewards.is_empty() else 0.0

func _sale_price(port_id: String, resource_id: String) -> float:
	var quote: Dictionary = quote_sale(port_id, resource_id, 1)
	return float(quote.get("unit_price", 0.0))

func _base_price(resource_id: String) -> float:
	return float(_base_prices.get(resource_id, 0.0))

func _good_name(resource_id: String) -> String:
	return str(_good_names.get(resource_id, resource_id))

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _set_lines(lines: Array) -> void:
	GameState.economy_state["trade_lines"] = lines

func _reserved_for_sale(resource_id: String) -> int:
	var merchants: Array[Node] = get_tree().get_nodes_in_group("merchant_visit_system")
	if merchants.is_empty():
		return 0
	return int(merchants[0].get_reserved_quantity(resource_id))
