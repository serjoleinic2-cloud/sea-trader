extends Node

## Automatic movement for the player's ship on already studied routes.

var _ship: Node2D
var _port_system: Node
var _destination_port_id: String = ""
var _active: bool = false

func _ready() -> void:
	add_to_group("active_route_autopilot_system")

func initialize(ship: Node2D, port_system: Node) -> void:
	_ship = ship
	_port_system = port_system

func start(destination_port_id: String) -> Dictionary:
	if _ship == null or _port_system == null or destination_port_id == "":
		return {"ok": false, "message": "Автопилот недоступен."}
	_destination_port_id = destination_port_id
	_active = true
	GameState.voyage_state["active_autopilot"] = true
	GameState.world_state["destination_port_id"] = destination_port_id
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_port_system.undock()
	SaveSystem.save_game()
	return {"ok": true, "message": "Автопилот ведёт корабль в " + _port_system.get_port_name(destination_port_id) + "."}

func _process(delta: float) -> void:
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
		_stop("Корабль прибыл в " + _port_system.get_port_name(_destination_port_id) + ".")
		return
	var speed: float = 110.0
	var next: Vector2 = current.move_toward(target, speed * delta)
	var traveled: float = current.distance_to(next)
	GameState.ship_state["position"] = next
	GameState.ship_state["velocity"] = (next - current) / maxf(delta, 0.001)
	GameState.ship_state["fuel"] = maxf(0.0, fuel - traveled * 0.003)
	_ship.global_position = next

func _stop(message: String) -> void:
	_active = false
	GameState.voyage_state["active_autopilot"] = false
	GameState.ship_state["velocity"] = Vector2.ZERO
	GameState.world_state["autopilot_notice"] = message
	SaveSystem.save_game()
