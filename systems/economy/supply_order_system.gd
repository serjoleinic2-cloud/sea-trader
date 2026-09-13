extends Node

## Multiple paid remote supply orders, each delivered to the home warehouse.

var _port_system: Node
var _goods_prices: Dictionary = {}
var _goods_names: Dictionary = {}
const DELIVERY_SURCHARGE: float = 0.50
const DELIVERY_SECONDS: int = 120

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	for raw_resource in catalog.get("resources", []):
		var resource: Dictionary = raw_resource
		var resource_id: String = str(resource.get("id", ""))
		_goods_prices[resource_id] = float(resource.get("base_price", 0.0))
		_goods_names[resource_id] = str(resource.get("display_name", resource_id))
	_migrate_legacy_order()

func _migrate_legacy_order() -> void:
	var raw_orders: Variant = GameState.economy_state.get("supply_orders", [])
	if raw_orders is Array:
		return
	var legacy: Variant = GameState.economy_state.get("supply_order", {})
	var legacy_order: Dictionary = legacy if legacy is Dictionary else {}
	var orders: Array = []
	if not legacy_order.is_empty():
		orders.append(legacy_order)
	GameState.economy_state["supply_orders"] = orders
	GameState.economy_state.erase("supply_order")

func get_available_goods() -> Array:
	var goods: Array = []
	for resource_id in _goods_names:
		goods.append({
			"id": str(resource_id),
			"display_name": str(_goods_names[resource_id])
		})
	return goods

func get_goods_name(resource_id: String) -> String:
	return str(_goods_names.get(resource_id, resource_id))

func get_quote(resource_id: String) -> Dictionary:
	if not _goods_prices.has(resource_id):
		return {"ok": false, "message": "Неизвестный товар."}
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if _port_system == null or home_port_id == "":
		return {"ok": false, "message": "Сначала назначьте главный порт."}
	var source_port_id: String = str(_port_system.get_nearest_market_source(home_port_id, resource_id))
	if source_port_id == "":
		return {"ok": false, "message": "Нет известного порта с этим товаром. Откройте новые порты или привезите товар сами."}
	var source_price: float = float(_goods_prices.get(resource_id, 0.0)) * 1.20
	return {
		"ok": true,
		"resource_id": resource_id,
		"source_port_id": source_port_id,
		"source_name": _port_system.get_port_name(source_port_id),
		"source_price": source_price,
		"delivery_price": source_price * (1.0 + DELIVERY_SURCHARGE),
		"delivery_seconds": DELIVERY_SECONDS
	}

func get_delivery_capacity() -> int:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_port_id, {})
	var buildings: Dictionary = port.get("buildings", {})
	var market: Dictionary = buildings.get("market", {})
	var dock: Dictionary = buildings.get("dock", {})
	var market_slots: int = mini(3, int(market.get("level", 0)))
	var dock_slots: int = mini(3, int(dock.get("level", 0)) / 5)
	return 2 + market_slots + dock_slots

func place_order(resource_id: String, quantity: int) -> Dictionary:
	var orders: Array = get_active_orders()
	var capacity: int = get_delivery_capacity()
	if orders.size() >= capacity:
		return {"ok": false, "message": "Все %d торговых места заняты. Улучшите рынок или причал." % capacity}
	var quote: Dictionary = get_quote(resource_id)
	if not bool(quote.get("ok", false)):
		return quote
	var source_port_id: String = str(quote.get("source_port_id", ""))
	var source: Dictionary = GameState.port_state.get(source_port_id, {})
	var stock: Dictionary = source.get("market_stock", {})
	if quantity < 1 or quantity > int(stock.get(resource_id, 0)):
		return {"ok": false, "message": "У поставщика недостаточно товара."}
	var total_price: float = float(quote.get("delivery_price", 0.0)) * quantity
	if float(GameState.player_state.get("money", 0.0)) < total_price:
		return {"ok": false, "message": "Недостаточно денег."}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - total_price
	stock[resource_id] = int(stock.get(resource_id, 0)) - quantity
	source["market_stock"] = stock
	GameState.port_state[source_port_id] = source
	orders.append({
		"resource_id": resource_id,
		"quantity": quantity,
		"source_port_id": source_port_id,
		"arrives_at": int(Time.get_unix_time_from_system()) + DELIVERY_SECONDS
	})
	_set_active_orders(orders)
	SaveSystem.save_game()
	return {"ok": true, "message": "Торговец с грузом отправлен к базе."}

func get_active_orders() -> Array:
	var raw_orders: Variant = GameState.economy_state.get("supply_orders", [])
	if raw_orders is Array:
		return raw_orders
	return []

func _process(_delta: float) -> void:
	var orders: Array = get_active_orders()
	if orders.is_empty():
		return
	var remaining: Array = []
	var changed: bool = false
	for raw_order in orders:
		var order: Dictionary = raw_order
		if int(Time.get_unix_time_from_system()) >= int(order.get("arrives_at", 0)):
			_deliver_order(order)
			changed = true
		else:
			remaining.append(order)
	if changed:
		_set_active_orders(remaining)
		SaveSystem.save_game()

func _deliver_order(order: Dictionary) -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or not GameState.port_state.has(home_port_id):
		return
	var home_port: Dictionary = GameState.port_state[home_port_id]
	var inventory: Dictionary = home_port.get("inventory", {})
	var resource_id: String = str(order.get("resource_id", ""))
	inventory[resource_id] = int(inventory.get(resource_id, 0)) + int(order.get("quantity", 0))
	home_port["inventory"] = inventory
	GameState.port_state[home_port_id] = home_port

func _set_active_orders(orders: Array) -> void:
	GameState.economy_state["supply_orders"] = orders
