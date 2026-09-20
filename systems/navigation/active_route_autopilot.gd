extends Node

## Automatic movement and cargo operation for the player's ship on studied routes.

var _ship: Node2D
var _port_system: Node
var _destination_port_id: String = ""
var _cargo_resource_id: String = ""
var _cargo_quantity: int = 0
var _active: bool = false
var _rules: Dictionary = {}
var _goods: Dictionary = {}

func _ready() -> void:
	add_to_group("active_route_autopilot_system")
	process_physics_priority = -100

func initialize(ship: Node2D, port_system: Node) -> void:
	_ship = ship
	_port_system = port_system
	_rules = GameData.read("res://data/economy/logistics_rules.json")
	for good in GameData.read("res://data/resources/goods_catalog.json").get("resources", []):
		_goods[str(good.get("id", ""))] = str(good.get("display_name", ""))
	if bool(GameState.voyage_state.get("active_autopilot", false)):
		_destination_port_id = str(GameState.voyage_state.get("autopilot_destination_id", GameState.world_state.get("destination_port_id", "")))
		_cargo_resource_id = str(GameState.voyage_state.get("autopilot_resource_id", ""))
		_cargo_quantity = int(GameState.voyage_state.get("autopilot_quantity", 0))
		if _port_system.get_all_port_ids().has(_destination_port_id) and str(GameState.ship_state.get("docked_port_id", "")) == "":
			_active = true
			GameState.world_state["autopilot_notice"] = "Рейс восстановлен: " + _port_system.get_port_name(_destination_port_id)
		else:
			_stop("Сохранённый рейс недоступен. Выберите маршрут заново.")

func fuel_needed(destination_id: String) -> float:
	var current: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	return current.distance_to(_port_system.get_port_position(destination_id)) * _fuel_rate()

func _fuel_rate() -> float:
	var bonus: float = 0.0
	for employee in GameState.employee_state:
		if GameState.ship_state.get("crew", []).has(employee.get("employee_instance_id", "")):
			bonus += float(employee.get("stats", {}).get("fuel", 0.0))
			bonus += float(employee.get("skill_stats", {}).get("fuel", 0.0))
	return float(_rules.get("fuel_per_distance", 0.003)) * maxf(0.25, 1.0 - bonus / 100.0)

func validate_start(destination_id: String, resource_id: String = "", quantity: int = 0) -> Dictionary:
	if _ship == null or _port_system == null or not _port_system.get_all_port_ids().has(destination_id):
		return {"ok": false, "message": "Порт назначения недоступен."}
	if _active:
		return {"ok": false, "message": "Корабль уже выполняет рейс."}
	var origin_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	if origin_id == "" or origin_id == destination_id:
		return {"ok": false, "message": "Выберите другой порт, находясь у причала."}
	var known: bool = false
	for route in GameState.known_routes_state.values():
		var a: String = str(route.get("port_a_id", ""))
		var b: String = str(route.get("port_b_id", ""))
		if (a == origin_id and b == destination_id) or (b == origin_id and a == destination_id):
			known = true
	if not known:
		return {"ok": false, "message": "Сначала пройдите этот маршрут вручную."}
	var needed: float = maxf(0.01, fuel_needed(destination_id))
	if float(GameState.ship_state.get("fuel", 0.0)) < needed:
		return {"ok": false, "message": "Не хватает топлива: нужно %.1f, в баке %.1f. Заправьтесь в сервисе порта." % [needed, float(GameState.ship_state.get("fuel", 0.0))]}
	if float(GameState.ship_state.get("hull", 0.0)) <= 0.0 or float(GameState.ship_state.get("engine", 0.0)) <= 0.0:
		return {"ok": false, "message": "Перед выходом требуется ремонт корабля."}
	if quantity < 0 or (quantity > 0 and (resource_id == "" or _get_cargo_quantity(resource_id) < quantity)):
		return {"ok": false, "message": "Выбранный груз ещё не загружен в трюм. Откройте «Ресурсы»."}
	return {"ok": true, "message": ""}

func start(destination_port_id: String, resource_id: String = "", quantity: int = 0) -> Dictionary:
	var validation: Dictionary = validate_start(destination_port_id, resource_id, quantity)
	if not bool(validation.get("ok", false)):
		GameState.world_state["autopilot_notice"] = str(validation.get("message", ""))
		return validation
	_destination_port_id = destination_port_id
	_cargo_resource_id = resource_id
	_cargo_quantity = maxi(0, quantity)
	_active = true
	GameState.voyage_state["active_autopilot"] = true
	GameState.voyage_state["autopilot_destination_id"] = destination_port_id
	GameState.voyage_state["autopilot_resource_id"] = resource_id
	GameState.voyage_state["autopilot_quantity"] = quantity
	GameState.world_state["destination_port_id"] = destination_port_id
	GameState.world_state["autopilot_notice"] = "Автопилот запущен: " + _port_system.get_port_name(destination_port_id)
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		if not _port_system.undock():
			_stop("Не удалось сохранить выход из порта.")
			return {"ok": false, "message": "Не удалось сохранить выход из порта."}
	SaveSystem.save_game()
	var cargo_text: String = ""
	if _cargo_resource_id != "" and _cargo_quantity > 0:
		cargo_text = " с грузом «%s» × %d" % [str(_goods.get(_cargo_resource_id, _cargo_resource_id)), _cargo_quantity]
	return {"ok": true, "message": "Автопилот ведёт корабль в %s%s." % [_port_system.get_port_name(destination_port_id), cargo_text]}

func _physics_process(delta: float) -> void:
	if not _active or _ship == null or delta <= 0.0:
		return
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_stop("Автопилот остановлен: корабль пришвартован.")
		return
	var fuel: float = float(GameState.ship_state.get("fuel", 0.0))
	var target: Vector2 = _port_system.get_port_position(_destination_port_id)
	var current: Vector2 = GameState.ship_state.get("position", _ship.global_position)
	var distance: float = current.distance_to(target)
	if distance <= float(_rules.get("arrival_distance", 2.0)):
		_ship.global_position = target
		GameState.ship_state["position"] = target
		if not _port_system.dock(_destination_port_id):
			_stop("Швартовка не подтверждена. Груз остался в трюме.")
			return
		var operation_message: String = _resolve_cargo_operation()
		_stop("Корабль прибыл в %s. %s" % [_port_system.get_port_name(_destination_port_id), operation_message])
		return
	if fuel <= 0.0:
		_stop("Рейс остановлен: закончилось топливо. Груз сохранён.")
		return
	var speed: float = float(_rules.get("autopilot_speed", 110.0))
	if _ship.has_method("get_navigation_speed"):
		speed = float(_ship.get_navigation_speed(speed))
	if speed <= 0.0:
		_stop("Рейс остановлен: двигатель не работает.")
		return
	var rate: float = _fuel_rate()
	var next: Vector2 = current.move_toward(target, minf(speed * delta, fuel / maxf(rate, 0.000001)))
	var traveled: float = current.distance_to(next)
	GameState.ship_state["position"] = next
	GameState.ship_state["velocity"] = (next - current) / maxf(delta, 0.001)
	GameState.ship_state["fuel"] = maxf(0.0, fuel - traveled * rate)
	GameState.world_state["current_position"] = next
	var stats: Dictionary = GameState.player_state.get("stats", {})
	stats["total_distance"] = float(stats.get("total_distance", 0.0)) + traveled
	GameState.player_state["stats"] = stats
	_ship.global_position = next

func _resolve_cargo_operation() -> String:
	if _cargo_resource_id == "" or _cargo_quantity <= 0:
		return "Грузовая операция не назначена."
	var systems: Array[Node] = get_tree().get_nodes_in_group("cargo_transfer_system")
	if systems.is_empty():
		return "Система груза недоступна; товар остался в трюме."
	var action: String = "unload" if _destination_port_id == str(GameState.world_state.get("home_port_id", "")) else "sell"
	var result: Dictionary = systems[0].execute(action, _cargo_resource_id, _cargo_quantity)
	return str(result.get("message", ""))

func _get_cargo_quantity(resource_id: String) -> int:
	var raw_cargo: Variant = GameState.ship_state.get("cargo", [])
	if not (raw_cargo is Array):
		return 0
	var total: int = 0
	for raw_item in raw_cargo:
		var item: Dictionary = raw_item
		if str(item.get("resource_id", "")) == resource_id:
			total += int(item.get("quantity", 0))
	return total

func _stop(message: String) -> void:
	_active = false
	GameState.voyage_state["active_autopilot"] = false
	GameState.ship_state["velocity"] = Vector2.ZERO
	GameState.world_state["current_position"] = GameState.ship_state.get("position", Vector2.ZERO)
	GameState.world_state["autopilot_notice"] = message
	SaveSystem.save_game()

func cancel() -> void:
	_stop("Ручное управление. Груз сохранён.")
