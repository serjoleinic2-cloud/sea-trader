extends Node

## Visiting merchants either sell supplies to the base or buy listed warehouse goods.

var _offer_duration_seconds: int = 1200
var _next_offer_delay_seconds: int = 1200
var _offer_templates: Array = []
var _goods: Dictionary = {}
var _buyer_price_ceiling_multiplier: float = 1.15

func _ready() -> void:
	add_to_group("merchant_visit_system")
	var config: Dictionary = GameData.read("res://data/economy/merchant_visits.json")
	_offer_duration_seconds = int(config.get("offer_duration_seconds", 1200))
	_next_offer_delay_seconds = int(config.get("next_offer_delay_seconds", 1200))
	_buyer_price_ceiling_multiplier = float(config.get("buyer_price_ceiling_multiplier", 1.15))
	_offer_templates = config.get("offers", [])
	var catalog: Dictionary = GameData.read("res://data/resources/goods_catalog.json")
	for raw_good in catalog.get("resources", []):
		var good: Dictionary = raw_good
		_goods[str(good.get("id", ""))] = good

func _process(_delta: float) -> void:
	_update_offer()

func get_active_offer() -> Dictionary:
	var merchant: Dictionary = GameState.economy_state.get("merchant", {})
	var raw_offer: Variant = merchant.get("active_offer", {})
	return raw_offer if raw_offer is Dictionary else {}

func get_sell_orders() -> Array:
	var merchant: Dictionary = GameState.economy_state.get("merchant", {})
	var raw_orders: Variant = merchant.get("sell_orders", [])
	return raw_orders.duplicate(true) if raw_orders is Array else []

func get_reserved_quantity(resource_id: String, excluded_order_id: String = "") -> int:
	var total: int = 0
	for raw_order in get_sell_orders():
		var order: Dictionary = raw_order
		if str(order.get("status", "active")) == "active" and str(order.get("resource_id", "")) == resource_id and str(order.get("id", "")) != excluded_order_id:
			total += int(order.get("quantity_available", 0))
	return total

func get_available_home_inventory(resource_id: String) -> int:
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_id, {})
	var inventory: Dictionary = port.get("inventory", {})
	return maxi(0, int(inventory.get(resource_id, 0)) - get_reserved_quantity(resource_id))

func create_sell_order(resource_id: String, quantity: int, asking_price: float) -> Dictionary:
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_id == "" or str(GameState.ship_state.get("docked_port_id", "")) != home_id:
		return {"ok": false, "message": "Выставлять товар можно только в своём порту."}
	if not _goods.has(resource_id) or quantity < 1 or asking_price <= 0.0:
		return {"ok": false, "message": "Проверьте товар, количество и цену."}
	if get_available_home_inventory(resource_id) < quantity:
		return {"ok": false, "message": "Недостаточно свободного товара: часть уже зарезервирована другими заявками."}
	var merchant: Dictionary = _merchant_state()
	var orders: Array = merchant.get("sell_orders", [])
	var serial: int = int(merchant.get("sell_order_serial", 0)) + 1
	merchant["sell_order_serial"] = serial
	orders.append({
		"id": "sell_order_%03d" % serial,
		"resource_id": resource_id,
		"quantity_total": quantity,
		"quantity_available": quantity,
		"asking_price": snappedf(asking_price, 0.01),
		"status": "active",
		"created_at": _now(),
		"last_feedback": "Ожидает торговый корабль."
	})
	merchant["sell_orders"] = orders
	GameState.economy_state["merchant"] = merchant
	if not SaveSystem.save_game():
		return {"ok": false, "message": "Не удалось сохранить заявку."}
	return {"ok": true, "message": "Товар зарезервирован для торговцев."}

func cancel_sell_order(order_id: String) -> Dictionary:
	var merchant: Dictionary = _merchant_state()
	var kept: Array = []
	var found: bool = false
	for raw_order in merchant.get("sell_orders", []):
		var order: Dictionary = raw_order
		if str(order.get("id", "")) == order_id:
			found = true
			continue
		kept.append(order)
	if not found:
		return {"ok": false, "message": "Заявка не найдена."}
	merchant["sell_orders"] = kept
	var active: Dictionary = merchant.get("active_offer", {})
	if str(active.get("order_id", "")) == order_id:
		merchant["active_offer"] = {}
		merchant["next_offer_at"] = _now()
	GameState.economy_state["merchant"] = merchant
	SaveSystem.save_game()
	return {"ok": true, "message": "Заявка снята, товар снова свободен на складе."}

func purchase(quantity: int) -> Dictionary:
	var offer: Dictionary = get_active_offer()
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if str(offer.get("direction", "supplier")) != "supplier" or offer.is_empty() or home_port_id == "" or not GameState.port_state.has(home_port_id):
		return {"ok": false, "message": "Предложение уже недоступно."}
	var available_quantity: int = int(offer.get("quantity_available", 0))
	var unit_price: float = float(offer.get("unit_price", 0.0))
	if quantity < 1 or quantity > available_quantity:
		return {"ok": false, "message": "Укажите доступное количество."}
	var total_price: float = unit_price * quantity
	var money: float = float(GameState.player_state.get("money", 0.0))
	if money < total_price:
		return {"ok": false, "message": "Недостаточно денег."}
	GameState.player_state["money"] = money - total_price
	var port: Dictionary = GameState.port_state[home_port_id]
	var inventory: Dictionary = port.get("inventory", {})
	var resource_id: String = str(offer.get("resource_id", ""))
	inventory[resource_id] = int(inventory.get(resource_id, 0)) + quantity
	port["inventory"] = inventory
	GameState.port_state[home_port_id] = port
	offer["quantity_available"] = available_quantity - quantity
	var merchant: Dictionary = _merchant_state()
	merchant["active_offer"] = offer
	GameState.economy_state["merchant"] = merchant
	SaveSystem.save_game()
	return {"ok": true, "message": "Товар доставлен на склад базы."}

func sell_to_merchant(quantity: int) -> Dictionary:
	var offer: Dictionary = get_active_offer()
	if str(offer.get("direction", "")) != "buyer":
		return {"ok": false, "message": "Сейчас торговец ничего не закупает."}
	var order_id: String = str(offer.get("order_id", ""))
	var merchant: Dictionary = _merchant_state()
	var orders: Array = merchant.get("sell_orders", [])
	var order_index: int = -1
	for index in range(orders.size()):
		if str(orders[index].get("id", "")) == order_id:
			order_index = index
			break
	if order_index < 0:
		return {"ok": false, "message": "Заявка уже снята."}
	var order: Dictionary = orders[order_index]
	var available: int = mini(int(offer.get("quantity_available", 0)), int(order.get("quantity_available", 0)))
	if quantity < 1 or quantity > available:
		return {"ok": false, "message": "Торговец готов купить только %d ед." % available}
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	var port: Dictionary = GameState.port_state.get(home_id, {})
	var inventory: Dictionary = port.get("inventory", {})
	var resource_id: String = str(order.get("resource_id", ""))
	if int(inventory.get(resource_id, 0)) < quantity:
		return {"ok": false, "message": "На складе не хватает зарезервированного товара."}
	inventory[resource_id] = int(inventory.get(resource_id, 0)) - quantity
	port["inventory"] = inventory
	GameState.port_state[home_id] = port
	var revenue: float = float(offer.get("unit_price", 0.0)) * quantity
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + revenue
	var stats: Dictionary = GameState.player_state.get("stats", {})
	stats["total_sales"] = int(stats.get("total_sales", 0)) + quantity
	stats["total_earned"] = float(stats.get("total_earned", 0.0)) + revenue
	GameState.player_state["stats"] = stats
	order["quantity_available"] = int(order.get("quantity_available", 0)) - quantity
	order["last_feedback"] = "Корабль выкупил %d ед. по %.0f." % [quantity, float(offer.get("unit_price", 0.0))]
	if int(order.get("quantity_available", 0)) <= 0:
		orders.remove_at(order_index)
	else:
		orders[order_index] = order
	merchant["sell_orders"] = orders
	offer["quantity_available"] = int(offer.get("quantity_available", 0)) - quantity
	merchant["active_offer"] = offer
	GameState.economy_state["merchant"] = merchant
	SaveSystem.save_game()
	return {"ok": true, "message": "Торговец купил %d ед. за %.0f." % [quantity, revenue]}

func _update_offer() -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or _offer_templates.is_empty():
		return
	var now: int = _now()
	var merchant: Dictionary = _merchant_state()
	var active_offer: Dictionary = merchant.get("active_offer", {})
	if not active_offer.is_empty():
		if now < int(active_offer.get("expires_at", 0)) and int(active_offer.get("quantity_available", 0)) > 0:
			return
		merchant["active_offer"] = {}
		merchant["next_offer_at"] = now + _next_offer_delay_seconds
	if now < int(merchant.get("next_offer_at", now)):
		GameState.economy_state["merchant"] = merchant
		return
	var offer_index: int = int(merchant.get("offer_index", 0))
	var buyer: Dictionary = _find_buyer_order(merchant, offer_index)
	if not buyer.is_empty() and posmod(offer_index, 2) == 0:
		merchant["active_offer"] = _make_buyer_offer(buyer, offer_index, now)
	else:
		merchant["active_offer"] = _make_supplier_offer(offer_index, now)
	merchant["offer_index"] = offer_index + 1
	merchant["next_offer_at"] = now + _offer_duration_seconds + _next_offer_delay_seconds
	GameState.economy_state["merchant"] = merchant
	SaveSystem.save_game()

func _find_buyer_order(merchant: Dictionary, offer_index: int) -> Dictionary:
	var orders: Array = merchant.get("sell_orders", [])
	if orders.is_empty():
		return {}
	var start: int = posmod(offer_index, orders.size())
	for offset in range(orders.size()):
		var index: int = posmod(start + offset, orders.size())
		var order: Dictionary = orders[index]
		if str(order.get("status", "active")) != "active" or int(order.get("quantity_available", 0)) <= 0:
			continue
		var resource_id: String = str(order.get("resource_id", ""))
		var base_price: float = float(_goods.get(resource_id, {}).get("base_price", 0.0))
		var ceiling: float = base_price * (_buyer_price_ceiling_multiplier - float(posmod(offer_index + offset, 3)) * 0.05)
		if float(order.get("asking_price", 0.0)) <= ceiling:
			return order
		order["last_feedback"] = "Торговцы считают цену %.0f выше текущего предела %.0f." % [float(order.get("asking_price", 0.0)), ceiling]
		orders[index] = order
		merchant["sell_orders"] = orders
	return {}

func _make_supplier_offer(offer_index: int, now: int) -> Dictionary:
	var template: Dictionary = _offer_templates[posmod(offer_index, _offer_templates.size())]
	return _make_offer_base(offer_index, now, {
		"direction": "supplier",
		"resource_id": str(template.get("resource_id", "")),
		"quantity_available": int(template.get("quantity", 0)),
		"unit_price": float(template.get("unit_price", 0.0))
	})

func _make_buyer_offer(order: Dictionary, offer_index: int, now: int) -> Dictionary:
	var amount: int = mini(int(order.get("quantity_available", 0)), 6 + posmod(offer_index * 3, 10))
	return _make_offer_base(offer_index, now, {
		"direction": "buyer",
		"order_id": str(order.get("id", "")),
		"resource_id": str(order.get("resource_id", "")),
		"quantity_available": amount,
		"unit_price": float(order.get("asking_price", 0.0))
	})

func _make_offer_base(offer_index: int, now: int, offer: Dictionary) -> Dictionary:
	var trader_names: Array[String] = ["Капитан Марек", "Капитан Элина", "Капитан Рустам", "Капитан Нора", "Капитан Ивар", "Капитан Селин"]
	var vessel_classes: Array[String] = ["Шхуна «Ветер»", "Баркас «Север»", "Шхуна «Лазурь»", "Грузовой бот «Три волны»", "Каботажник «Маяк»", "Торговая лодка «Искра»"]
	var trader_index: int = posmod(offer_index, trader_names.size())
	offer["expires_at"] = now + _offer_duration_seconds
	offer["merchant_name"] = trader_names[trader_index]
	offer["vessel_name"] = vessel_classes[trader_index]
	offer["visitor_index"] = trader_index
	return offer

func _merchant_state() -> Dictionary:
	var merchant: Dictionary = GameState.economy_state.get("merchant", {})
	if merchant.is_empty():
		merchant = {"active_offer": {}, "next_offer_at": _now(), "offer_index": 0, "sell_orders": [], "sell_order_serial": 0}
	if not merchant.get("sell_orders", []) is Array:
		merchant["sell_orders"] = []
	return merchant

func _now() -> int:
	return int(Time.get_unix_time_from_system())
