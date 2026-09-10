extends Node

## Paid remote supply orders delivered to the home warehouse.

var _port_system: Node
var _goods_prices: Dictionary = {}
const DELIVERY_SURCHARGE: float = 0.50
const DELIVERY_SECONDS: int = 120

func initialize(port_system: Node) -> void:
	_port_system = port_system
	var catalog: Dictionary = SaveSystem._read_json("res://data/resources/goods_catalog.json")
	for raw_resource in catalog.get("resources", []):
		var resource: Dictionary = raw_resource
		_goods_prices[str(resource.get("id", ""))] = float(resource.get("base_price", 0.0))

func get_quote(resource_id: String) -> Dictionary:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if _port_system == null or home_port_id == "":
		return {"ok": false, "message": "Сначала назначьте главный порт."}
	var source_port_id: String = str(_port_system.get_nearest_market_source(home_port_id, resource_id))
	if source_port_id == "":
		return {"ok": false, "message": "Нет известного порта с этим товаром."}
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

func place_order(resource_id: String, quantity: int) -> Dictionary:
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
	GameState.economy_state["supply_order"] = {
		"resource_id": resource_id,
		"quantity": quantity,
		"source_port_id": source_port_id,
		"arrives_at": int(Time.get_unix_time_from_system()) + DELIVERY_SECONDS
	}
	SaveSystem.save_game()
	return {"ok": true, "message": "Поставка отправлена к базе."}

func _process(_delta: float) -> void:
	var raw_order: Variant = GameState.economy_state.get("supply_order", {})
	if not (raw_order is Dictionary) or raw_order.is_empty():
		return
	var order: Dictionary = raw_order
	if int(Time.get_unix_time_from_system()) < int(order.get("arrives_at", 0)):
		return
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or not GameState.port_state.has(home_port_id):
		return
	var home_port: Dictionary = GameState.port_state[home_port_id]
	var inventory: Dictionary = home_port.get("inventory", {})
	var resource_id: String = str(order.get("resource_id", ""))
	inventory[resource_id] = int(inventory.get(resource_id, 0)) + int(order.get("quantity", 0))
	home_port["inventory"] = inventory
	GameState.port_state[home_port_id] = home_port
	GameState.economy_state["supply_order"] = {}
	SaveSystem.save_game()
