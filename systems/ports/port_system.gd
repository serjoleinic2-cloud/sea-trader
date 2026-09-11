extends Node

# PortSystem — Phase 05
# Отслеживает позицию корабля относительно портов.
# При входе в радиус:
#   - если порт не discovered → отмечает как discovered, эмитирует port_discovered
#   - если порт уже discovered → эмитирует port_entered
# Не генерирует порты. Не открывает UI. Только управляет состоянием discovery.

var _discovery_radius: float = 0.0
var _world_ports: Dictionary = {}

# Набор id портов, в радиусе которых корабль находится прямо сейчас
var _ports_in_range: Dictionary = {}  # port_id → bool

var _ship_node: Node2D = null


func _ready() -> void:
	set_process(true)


func initialize(ship: Node2D, world_ports: Dictionary) -> void:
	_ship_node = ship
	_world_ports = world_ports
	_ports_in_range.clear()
	var config: Dictionary = SaveSystem._read_json("res://data/ports/port_template.json")
	_discovery_radius = float(config.get("discovery_radius", 0.0))


func _process(_delta: float) -> void:
	if _ship_node == null:
		return
	if GameState.port_state == null:
		return

	var ship_pos: Vector2 = _ship_node.global_position

	for port_id in _world_ports:
		var port: Dictionary = GameState.port_state.get(port_id, {})
		var port_pos := Vector2(_world_ports[port_id].position)
		var radius: float = _discovery_radius
		var dist: float = ship_pos.distance_to(port_pos)
		var in_range: bool = dist <= radius
		var was_in_range: bool = _ports_in_range.get(port_id, false)

		if in_range and not was_in_range:
			# Вошли в зону
			_ports_in_range[port_id] = true
			_on_enter_port_range(port_id, port)
		elif not in_range and was_in_range:
			# Вышли из зоны
			_ports_in_range[port_id] = false
			EventBus.emit_signal("port_exited", port_id)

	_update_nearest_port_debug(ship_pos)


func _on_enter_port_range(port_id: String, _port: Dictionary) -> void:
	# Seeing a port is not a visit. Player knowledge is recorded only after docking.
	EventBus.emit_signal("port_entered", port_id)

# ---------------------------------------------------------------------------
# Debug helper — имя ближайшего порта в радиусе
# ---------------------------------------------------------------------------

var nearest_port_name: String = ""
var discovered_count: int = 0
var total_port_count: int = 0

func _update_nearest_port_debug(ship_pos: Vector2) -> void:
	nearest_port_name = ""
	discovered_count = 0
	total_port_count = 0

	var best_dist := INF
	for port_id in _world_ports:
		var port: Dictionary = GameState.port_state.get(port_id, {})
		total_port_count += 1
		if port.get("discovered", false):
			discovered_count += 1
		var port_pos := Vector2(_world_ports[port_id].position)
		var radius: float = _discovery_radius
		var dist := ship_pos.distance_to(port_pos)
		if dist <= radius and dist < best_dist:
			best_dist = dist
			nearest_port_name = _world_ports[port_id].get("name", port_id)


func get_dock_candidate() -> String:
	if _ship_node == null:
		return ""
	var best_id: String = ""
	var best_distance: float = INF
	for port_id in _world_ports:
		var distance: float = _ship_node.global_position.distance_to(Vector2(_world_ports[port_id].position))
		if distance <= _discovery_radius and distance < best_distance:
			best_distance = distance
			best_id = port_id
	return best_id


func dock(port_id: String) -> bool:
	if port_id == "" or get_dock_candidate() != port_id:
		return false
	var previous_port_id: String = str(GameState.world_state.get("last_docked_port_id", ""))
	if not GameState.port_state.has(port_id):
		var generated: Dictionary = _world_ports.get(port_id, {})
		GameState.port_state[port_id] = {
			"discovered": true,
			"level": generated.get("level", 1),
			"buildings": {}
		}
	else:
		GameState.port_state[port_id]["discovered"] = true
	if not GameState.player_state.discovered_port_ids.has(port_id):
		GameState.player_state.discovered_port_ids.append(port_id)
		GameState.player_state.stats["ports_discovered"] = int(GameState.player_state.stats.get("ports_discovered", 0)) + 1
	if previous_port_id != "" and previous_port_id != port_id and _world_ports.has(previous_port_id):
		_register_manual_route(previous_port_id, port_id)
		_consume_active_crew_voyage()
	GameState.world_state["last_docked_port_id"] = port_id
	GameState.ship_state["docked_port_id"] = port_id
	if str(GameState.world_state.get("home_port_id", "")) == "":
		GameState.world_state["home_port_id"] = port_id
	GameState.ship_state["velocity"] = Vector2.ZERO
	GameState.player_state.stats["safe_dockings"] = int(GameState.player_state.stats.get("safe_dockings", 0)) + 1
	return SaveSystem.save_game()

func _consume_active_crew_voyage() -> void:
	var raw_crew: Variant = GameState.ship_state.get("crew", [])
	var crew_ids: Array = raw_crew if raw_crew is Array else []
	var retained_employees: Array = []
	var retained_crew_ids: Array = []
	for raw_employee in GameState.employee_state:
		var employee: Dictionary = raw_employee
		var employee_id: String = str(employee.get("employee_instance_id", ""))
		if crew_ids.has(employee_id):
			var remaining: int = int(employee.get("contract_voyages_remaining", 0)) - 1
			if remaining > 0:
				employee["contract_voyages_remaining"] = remaining
				retained_employees.append(employee)
				retained_crew_ids.append(employee_id)
			else:
				continue
		else:
			retained_employees.append(employee)
	GameState.employee_state = retained_employees
	GameState.ship_state["crew"] = retained_crew_ids

func _register_manual_route(port_a_id: String, port_b_id: String) -> void:
	var ordered_ids: Array[String] = [port_a_id, port_b_id]
	ordered_ids.sort()
	var route_key: String = ordered_ids[0] + "--" + ordered_ids[1]
	var distance: float = Vector2(_world_ports[port_a_id].position).distance_to(Vector2(_world_ports[port_b_id].position))
	var route: Dictionary = GameState.known_routes_state.get(route_key, {})
	if route.is_empty():
		route = {
			"port_a_id": ordered_ids[0],
			"port_b_id": ordered_ids[1],
			"distance": distance,
			"risk_level": "low",
			"discovered_timestamp": int(Time.get_unix_time_from_system()),
			"times_traveled": 0
		}
	route["times_traveled"] = int(route.get("times_traveled", 0)) + 1
	GameState.known_routes_state[route_key] = route

func undock() -> bool:
	if str(GameState.ship_state.get("docked_port_id", "")) == "":
		return false
	GameState.ship_state["docked_port_id"] = ""
	GameState.ship_state["velocity"] = Vector2.ZERO
	GameState.player_state.stats["total_voyages"] = int(GameState.player_state.stats.get("total_voyages", 0)) + 1
	return SaveSystem.save_game()


func get_port_name(port_id: String) -> String:
	if not _world_ports.has(port_id):
		return port_id
	return str(_world_ports[port_id].get("name", port_id))


func get_nearest_market_source(from_port_id: String, resource_id: String) -> String:
	if not _world_ports.has(from_port_id):
		return ""
	var origin: Vector2 = Vector2(_world_ports[from_port_id].position)
	var best_port_id: String = ""
	var best_distance: float = INF
	for port_id in _world_ports:
		if port_id == from_port_id:
			continue
		var state: Dictionary = GameState.port_state.get(port_id, {})
		var raw_stock: Variant = state.get("market_stock", {})
		if not (raw_stock is Dictionary) or int(raw_stock.get(resource_id, 0)) <= 0:
			continue
		var distance: float = origin.distance_to(Vector2(_world_ports[port_id].position))
		if distance < best_distance:
			best_distance = distance
			best_port_id = port_id
	return best_port_id


func get_port_position(port_id: String) -> Vector2:
	if not _world_ports.has(port_id):
		return Vector2.ZERO
	return Vector2(_world_ports[port_id].position)
