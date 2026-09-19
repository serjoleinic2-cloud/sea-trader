extends Node

## Refuel and repair services. Home workshop can consume stored materials cheaply.

var _rules: Dictionary = {}
var _port_system: Node

func initialize(port_system: Node) -> void:
	_rules = GameData.read("res://data/ports/service_rules.json")
	_port_system = port_system

func get_service_text() -> String:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id == "":
		return "Сервис доступен только у причала."
	var is_home: bool = port_id == str(GameState.world_state.get("home_port_id", ""))
	if is_home:
		return "База: масло даёт топливо, запчасти ремонтируют корпус. Мастерская снижает денежную цену."
	return "Чужой порт: услуги оплачиваются деньгами."

func refuel(amount: float) -> Dictionary:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id == "":
		return {"ok": false, "message": "Сначала пришвартуйтесь."}
	var fuel: float = float(GameState.ship_state.get("fuel", 0.0))
	var fuel_max: float = float(GameState.ship_state.get("fuel_max", 0.0))
	var target: float = clampf(amount, 0.0, fuel_max - fuel)
	if target < 0.5:
		return {"ok": false, "message": "Топливный бак уже заполнен."}
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var is_home: bool = port_id == home_port_id
	if is_home:
		var port: Dictionary = GameState.port_state.get(port_id, {})
		var inventory: Dictionary = port.get("inventory", {})
		var oil_available: int = int(inventory.get("resource_oil", 0))
		var oil_needed: int = int(ceil(target / maxf(0.01, float(_rules.get("fuel_per_oil", 5.0)))))
		if oil_available >= oil_needed:
			inventory["resource_oil"] = oil_available - oil_needed
			port["inventory"] = inventory
			GameState.port_state[port_id] = port
			GameState.ship_state["fuel"] = minf(fuel_max, fuel + float(oil_needed) * float(_rules.get("fuel_per_oil", 5.0)))
			SaveSystem.save_game()
			return {"ok": true, "message": "Заправлено за масло со склада: %d ед." % oil_needed}
	var price_per_fuel: float = float(_rules.get("price_per_fuel", 5.0)) * _service_discount(port_id)
	var price: float = ceil(target * price_per_fuel)
	if float(GameState.player_state.get("money", 0.0)) < price:
		return {"ok": false, "message": "Недостаточно денег на заправку."}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - price
	GameState.ship_state["fuel"] = fuel + target
	SaveSystem.save_game()
	return {"ok": true, "message": "Заправлено %.0f топлива за %.0f." % [target, price]}

func repair(amount: float) -> Dictionary:
	var port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if port_id == "":
		return {"ok": false, "message": "Сначала пришвартуйтесь."}
	var hull: float = float(GameState.ship_state.get("hull", 100.0))
	var target: float = clampf(amount, 0.0, 100.0 - hull)
	if target < 0.5:
		return {"ok": false, "message": "Корпус уже в полном порядке."}
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	var is_home: bool = port_id == home_port_id
	if is_home:
		var port: Dictionary = GameState.port_state.get(port_id, {})
		var inventory: Dictionary = port.get("inventory", {})
		var parts_available: int = int(inventory.get("resource_parts", 0))
		var parts_needed: int = int(ceil(target / maxf(0.01, float(_rules.get("hull_per_parts", 10.0)))))
		if parts_available >= parts_needed:
			inventory["resource_parts"] = parts_available - parts_needed
			port["inventory"] = inventory
			GameState.port_state[port_id] = port
			GameState.ship_state["hull"] = minf(100.0, hull + float(parts_needed) * float(_rules.get("hull_per_parts", 10.0)))
			EventBus.ship_repaired.emit("hull", float(parts_needed) * float(_rules.get("hull_per_parts", 10.0)))
			SaveSystem.save_game()
			return {"ok": true, "message": "Корпус отремонтирован за запчасти со склада: %d ед." % parts_needed}
	var price_per_hull: float = float(_rules.get("price_per_hull", 6.0)) * _service_discount(port_id)
	var price: float = ceil(target * price_per_hull)
	if float(GameState.player_state.get("money", 0.0)) < price:
		return {"ok": false, "message": "Недостаточно денег на ремонт."}
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) - price
	GameState.ship_state["hull"] = hull + target
	EventBus.ship_repaired.emit("hull", target)
	SaveSystem.save_game()
	return {"ok": true, "message": "Корпус отремонтирован на %.0f за %.0f." % [target, price]}

func _service_discount(port_id: String) -> float:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if port_id != home_port_id:
		return 1.0
	var port: Dictionary = GameState.port_state.get(port_id, {})
	var buildings: Dictionary = port.get("buildings", {})
	var workshop: Dictionary = buildings.get("workshop", {})
	var level: int = int(workshop.get("level", 0))
	return maxf(float(_rules.get("minimum_price_factor", 0.55)), 1.0 - float(level) * float(_rules.get("workshop_discount_per_level", 0.05)))
