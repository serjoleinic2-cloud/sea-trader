extends Node

## Evaluates a manual trading route before the player spends money or fuel.

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

func evaluate(origin_port_id: String, destination_port_id: String, resource_id: String, quantity: int) -> Dictionary:
	if origin_port_id == "" or destination_port_id == "" or origin_port_id == destination_port_id:
		return {"ok": false, "message": "Выберите два разных известных порта."}
	var distance: float = _get_route_distance(origin_port_id, destination_port_id)
	if distance <= 0.0:
		return {"ok": false, "message": "Между этими портами ещё нет известного маршрута."}
	var amount: int = maxi(1, quantity)
	var buy_price: float = _get_buy_price(origin_port_id, resource_id)
	var sell_price: float = _get_sell_price(destination_port_id, resource_id)
	var fuel_needed: float = maxf(1.0, distance / 500.0)
	var fuel_cost: float = fuel_needed * 5.0
	var repair_reserve: float = ceil(distance / 1500.0) * 6.0
	var gross: float = (sell_price - buy_price) * amount
	var net: float = gross - fuel_cost - repair_reserve
	return {
		"ok": true,
		"buy_price": buy_price,
		"sell_price": sell_price,
		"distance": distance,
		"fuel_needed": fuel_needed,
		"fuel_cost": fuel_cost,
		"repair_reserve": repair_reserve,
		"gross": gross,
		"net": net
	}

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
