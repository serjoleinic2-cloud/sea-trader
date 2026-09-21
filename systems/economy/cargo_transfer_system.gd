extends Node

## Sole entry point for active-ship cargo transfers and port purchases/sales.
## UI and autopilot call the same rules; quantities and balances live in GameState.
var _market: Node

func _ready() -> void:
	add_to_group("cargo_transfer_system")

func initialize(market: Node) -> void:
	_market = market

func cargo_quantity(resource_id: String) -> int:
	var amount: int = 0
	for item in GameState.ship_state.get("cargo", []):
		if str(item.get("resource_id", "")) == resource_id:
			amount += int(item.get("quantity", 0))
	return amount

func cargo_total() -> int:
	var amount: int = 0
	for item in GameState.ship_state.get("cargo", []):
		amount += int(item.get("quantity", 0))
	return amount

func buy_price(port_id: String, resource_id: String) -> float:
	return float(_market.get_buy_price(port_id, resource_id))

func sell_price(port_id: String, resource_id: String) -> float:
	return float(_market.get_sell_price(port_id, resource_id))

func execute(action: String, resource_id: String, quantity: int) -> Dictionary:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var home: bool = port_id == str(GameState.world_state.get("home_port_id", ""))
	var good: Dictionary = GameData.get_good(resource_id)
	if port_id == "" or not GameState.port_state.has(port_id):
		return _failure("Сначала пришвартуйтесь в порту.")
	if quantity <= 0 or good.is_empty() or action not in ["load", "unload", "buy", "sell"]:
		return _failure("Некорректный товар, количество или действие.")
	if (action in ["load", "unload"]) != home:
		return _failure("На базе используйте склад. Покупка и продажа доступны в других портах.")
	if action in ["load", "buy"] and quantity > int(GameState.ship_state.get("cargo_capacity", 0)) - cargo_total():
		return _failure("В трюме недостаточно места.")
	if action in ["unload", "sell"] and cargo_quantity(resource_id) < quantity:
		return _failure("В трюме нет выбранного количества товара.")
	_market.get_market_info(port_id, resource_id)
	var port: Dictionary = GameState.port_state[port_id]
	var storage: String = "inventory" if home else "market_stock"
	var stock: Dictionary = port.get(storage, {})
	var available_stock: int = int(stock.get(resource_id, 0))
	if home and action == "load":
		available_stock -= _reserved_for_sale(resource_id)
	if action in ["load", "buy"] and available_stock < quantity:
		return _failure("В порту недостаточно товара. Дождитесь производства или поставки.")
	var price: float = 0.0
	if action == "buy":
		var quote: Dictionary = _market.quote_purchase(port_id, resource_id, quantity)
		if not bool(quote.get("ok", false)):
			return quote
		price = float(quote.cost)
	if price > float(GameState.player_state.get("money", 0.0)):
		return _failure("Недостаточно денег для покупки.")
	# Roll back in-memory mutations if sale validation or persistence fails.
	var snapshot: Dictionary = {"ship": GameState.ship_state.duplicate(true), "ports": GameState.port_state.duplicate(true), "player": GameState.player_state.duplicate(true)}
	var revenue: float = 0.0
	if action == "sell":
		var sale: Dictionary = _market.try_sell_to_port(port_id, resource_id, quantity)
		if not bool(sale.get("ok", false)):
			_restore(snapshot)
			return sale
		revenue = float(sale.get("revenue", 0.0))
	if action in ["load", "buy"]:
		stock[resource_id] = int(stock.get(resource_id, 0)) - quantity
		_change_cargo(resource_id, quantity)
	elif action == "unload":
		stock[resource_id] = int(stock.get(resource_id, 0)) + quantity
		_change_cargo(resource_id, -quantity)
	else:
		_change_cargo(resource_id, -quantity)
	if action != "sell":
		port[storage] = stock
		GameState.port_state[port_id] = port
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - price + revenue
	var stats: Dictionary = GameState.player_state.get("stats", {})
	if action == "sell":
		stats["total_sales"] = int(stats.get("total_sales", 0)) + quantity
		stats["total_earned"] = float(stats.get("total_earned", 0.0)) + revenue
	elif action == "unload":
		var credit: int = mini(quantity, int(GameState.ship_state.get("delivery_credit_remaining", 0)))
		GameState.ship_state["delivery_credit_remaining"] = int(GameState.ship_state.get("delivery_credit_remaining", 0)) - credit
		stats["cargo_units_moved"] = int(stats.get("cargo_units_moved", 0)) + credit
	GameState.player_state["stats"] = stats
	if not SaveSystem.save_game():
		_restore(snapshot)
		return _failure("Не удалось сохранить операцию. Проверьте доступное место и повторите.")
	if action == "load":
		EventBus.cargo_loaded.emit(resource_id, quantity)
	elif action in ["unload", "sell"]:
		EventBus.cargo_delivered.emit(resource_id, quantity)
	var verbs: Dictionary = {"load": "В трюм загружено", "unload": "На склад выгружено", "buy": "Куплено", "sell": "Продано"}
	var message: String = "%s: %s × %d." % [str(verbs[action]), str(good.get("display_name", resource_id)), quantity]
	if action == "sell":
		message += " Получено %.0f." % revenue
	return {"ok": true, "message": message, "revenue": revenue}

func _change_cargo(resource_id: String, delta: int) -> void:
	var cargo: Array = GameState.ship_state.get("cargo", [])
	# Merge duplicate legacy stacks while retaining unrelated cargo.
	var amount: int = cargo_quantity(resource_id) + delta
	var retained: Array = []
	for item in cargo:
		if str(item.get("resource_id", "")) != resource_id:
			retained.append(item)
	if amount > 0:
		retained.append({"resource_id": resource_id, "quantity": amount})
	GameState.ship_state["cargo"] = retained

func _restore(snapshot: Dictionary) -> void:
	GameState.ship_state = snapshot.ship
	GameState.port_state = snapshot.ports
	GameState.player_state = snapshot.player

func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func _reserved_for_sale(resource_id: String) -> int:
	var merchants: Array[Node] = get_tree().get_nodes_in_group("merchant_visit_system")
	if merchants.is_empty():
		return 0
	return int(merchants[0].get_reserved_quantity(resource_id))
