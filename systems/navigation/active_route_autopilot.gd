extends Node

## Automatic movement and cargo operation for the player's ship on studied routes.

var _ship: Node2D
var _port_system: Node
var _destination_port_id: String = ""
var _cargo_resource_id: String = ""
var _cargo_quantity: int = 0
var _active: bool = false

func _ready() -> void:
	add_to_group("active_route_autopilot_system")
	process_physics_priority = 100

func initialize(ship: Node2D, port_system: Node) -> void:
	_ship = ship
	_port_system = port_system

func start(destination_port_id: String, resource_id: String = "", quantity: int = 0) -> Dictionary:
	if _ship == null or _port_system == null or destination_port_id == "":
		return {"ok": false, "message": "Автопилот недоступен."}
	_destination_port_id = destination_port_id
	_cargo_resource_id = resource_id
	_cargo_quantity = maxi(0, quantity)
	_active = true
	GameState.voyage_state["active_autopilot"] = true
	GameState.world_state["destination_port_id"] = destination_port_id
	GameState.world_state["autopilot_notice"] = "Автопилот запущен: " + _port_system.get_port_name(destination_port_id)
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_port_system.undock()
	SaveSystem.save_game()
	var cargo_text: String = ""
	if _cargo_resource_id != "" and _cargo_quantity > 0:
		cargo_text = " с грузом «%s» × %d" % [_cargo_resource_id.replace("resource_", "").capitalize(), _cargo_quantity]
	return {"ok": true, "message": "Автопилот ведёт корабль в %s%s." % [_port_system.get_port_name(destination_port_id), cargo_text]}

func _physics_process(delta: float) -> void:
	if not _active or _ship == null:
		return
	var fuel: float = float(GameState.ship_state.get("fuel", 0.0))
	if fuel <= 0.0:
		_stop("Автопилот остановлен: нет топлива.")
		return
	var target: Vector2 = _port_system.get_port_position(_destination_port_id)
	var current: Vector2 = GameState.ship_state.get("position", _ship.global_position)
	var distance: float = current.distance_to(target)
	if distance <= 12.0:
		_ship.global_position = target
		GameState.ship_state["position"] = target
		_port_system.dock(_destination_port_id)
		var operation_message: String = _resolve_cargo_operation()
		_stop("Корабль прибыл в %s. %s" % [_port_system.get_port_name(_destination_port_id), operation_message])
		return
	var speed: float = 110.0
	var next: Vector2 = current.move_toward(target, speed * delta)
	var traveled: float = current.distance_to(next)
	GameState.ship_state["position"] = next
	GameState.ship_state["velocity"] = (next - current) / maxf(delta, 0.001)
	GameState.ship_state["fuel"] = maxf(0.0, fuel - traveled * 0.003)
	_ship.global_position = next

func _resolve_cargo_operation() -> String:
	if _cargo_resource_id == "" or _cargo_quantity <= 0:
		return "Грузовая операция не назначена."
	var available: int = _get_cargo_quantity(_cargo_resource_id)
	var amount: int = mini(available, _cargo_quantity)
	if amount <= 0:
		return "В трюме нет назначенного товара; продажа не выполнена."
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if _destination_port_id == home_port_id:
		_remove_cargo(_cargo_resource_id, amount)
		var port: Dictionary = GameState.port_state.get(home_port_id, {})
		var inventory: Dictionary = port.get("inventory", {})
		inventory[_cargo_resource_id] = int(inventory.get(_cargo_resource_id, 0)) + amount
		port["inventory"] = inventory
		GameState.port_state[home_port_id] = port
		return "Автовыгрузка на склад: %s × %d." % [_cargo_resource_id.replace("resource_", "").capitalize(), amount]
	var systems: Array[Node] = get_tree().get_nodes_in_group("trade_line_system")
	if systems.is_empty():
		return "Рынок назначения недоступен; груз остался в трюме."
	var sale: Dictionary = systems[0].try_sell_to_port(_destination_port_id, _cargo_resource_id, amount)
	if not bool(sale.get("ok", false)):
		return "Автопродажа не выполнена: " + str(sale.get("message", "нет спроса."))
	_remove_cargo(_cargo_resource_id, amount)
	var revenue: float = float(sale.get("revenue", 0.0))
	GameState.player_state["money"] = float(GameState.player_state.get("money", 0.0)) + revenue
	var stats: Dictionary = GameState.player_state.get("stats", {})
	stats["total_sales"] = int(stats.get("total_sales", 0)) + amount
	stats["total_earned"] = float(stats.get("total_earned", 0.0)) + revenue
	GameState.player_state["stats"] = stats
	EventBus.cargo_delivered.emit(_cargo_resource_id, amount)
	return "Автопродажа: %s × %d, получено %.0f." % [_cargo_resource_id.replace("resource_", "").capitalize(), amount, revenue]

func _get_cargo_quantity(resource_id: String) -> int:
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array):
		return 0
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		if str(item.get("resource_id", "")) == resource_id:
			return int(item.get("quantity", 0))
	return 0

func _remove_cargo(resource_id: String, amount: int) -> void:
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array):
		return
	var cargo: Array = raw_cargo
	for index in range(cargo.size()):
		var item: Dictionary = cargo[index]
		if str(item.get("resource_id", "")) != resource_id:
			continue
		var remaining: int = int(item.get("quantity", 0)) - amount
		if remaining <= 0:
			cargo.remove_at(index)
		else:
			item["quantity"] = remaining
			cargo[index] = item
		break
	GameState.ship_state["cargo"] = cargo

func _stop(message: String) -> void:
	_active = false
	GameState.voyage_state["active_autopilot"] = false
	GameState.ship_state["velocity"] = Vector2.ZERO
	GameState.world_state["autopilot_notice"] = message
	SaveSystem.save_game()
