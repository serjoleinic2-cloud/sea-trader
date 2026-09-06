extends Node

# PortSystem — Phase 05
# Отслеживает позицию корабля относительно портов.
# При входе в радиус:
#   - если порт не discovered → отмечает как discovered, эмитирует port_discovered
#   - если порт уже discovered → эмитирует port_entered
# Не генерирует порты. Не открывает UI. Только управляет состоянием discovery.

const DEFAULT_DISCOVERY_RADIUS := 150.0

# Набор id портов, в радиусе которых корабль находится прямо сейчас
var _ports_in_range: Dictionary = {}  # port_id → bool

var _ship_node: Node2D = null


func _ready() -> void:
	set_process(true)


func initialize(ship: Node2D) -> void:
	_ship_node = ship


func _process(_delta: float) -> void:
	if _ship_node == null:
		return
	if GameState.port_state == null:
		return

	var ship_pos: Vector2 = _ship_node.global_position

	for port_id in GameState.port_state:
		var port: Dictionary = GameState.port_state[port_id]
		var port_pos := Vector2(port.get("x", 0.0), port.get("y", 0.0))
		var radius: float = port.get("discovery_radius", DEFAULT_DISCOVERY_RADIUS)
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


func _on_enter_port_range(port_id: String, port: Dictionary) -> void:
	var already_discovered: bool = port.get("discovered", false)

	if not already_discovered:
		# Первое обнаружение
		GameState.port_state[port_id]["discovered"] = true
		SaveSystem.save_game()
		EventBus.emit_signal("port_discovered", port_id)
	else:
		# Повторный вход в известный порт
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
	for port_id in GameState.port_state:
		var port: Dictionary = GameState.port_state[port_id]
		total_port_count += 1
		if port.get("discovered", false):
			discovered_count += 1
		var port_pos := Vector2(port.get("x", 0.0), port.get("y", 0.0))
		var radius: float = port.get("discovery_radius", DEFAULT_DISCOVERY_RADIUS)
		var dist := ship_pos.distance_to(port_pos)
		if dist <= radius and dist < best_dist:
			best_dist = dist
			nearest_port_name = port.get("name", port_id)
