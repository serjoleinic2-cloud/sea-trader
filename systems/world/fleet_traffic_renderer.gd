extends Node2D

## Draws the player's auxiliary ships at their actual saved voyage progress.
## It is deliberately only a view: FleetSystem remains the owner of movement,
## arrival and cargo settlement, including while the application is closed.

var _ports: Dictionary = {}
var _islands: Array = []
var _routes: Dictionary = {}
var _shown_positions: Dictionary = {}
var _berths: Dictionary = {}
var _guard = preload("res://systems/ship/ship_physics.gd").new()

func _ready() -> void:
	add_to_group("fleet_traffic_renderer")

func initialize(world_data: Dictionary) -> void:
	_guard.set_collision_data_provider(func(): return {"islands": _islands})
	set_navigation_world(world_data)
	var raw_ports: Variant = world_data.get("ports", {})
	if raw_ports is Dictionary:
		_ports = raw_ports
	queue_redraw()

func _exit_tree() -> void:
	_guard.free()

func set_navigation_world(world_data: Dictionary) -> void:
	_ports = world_data.get("ports", {})
	_islands = world_data.get("islands", [])
	_routes.clear()

func _safe_route_position(origin: Vector2, destination: Vector2, progress: float) -> Dictionary:
	var key := str(origin) + ":" + str(destination)
	if not _routes.has(key):
		var path := preload("res://systems/navigation/coast_route_planner.gd").new().plan(origin, destination, _islands, Callable(_guard, "is_navigation_move_blocked"))
		path.insert(0, origin)
		_routes[key] = path
	var path: PackedVector2Array = _routes[key]
	var total: float = 0
	for index in range(path.size() - 1):
		total += path[index].distance_to(path[index + 1])
	var remaining := clampf(progress, 0, 1) * total
	for index in range(path.size() - 1):
		var length := path[index].distance_to(path[index + 1])
		if remaining <= length:
			return {"position": path[index].lerp(path[index + 1], remaining / maxf(0.01, length)), "heading": (path[index + 1] - path[index]).normalized()}
		remaining -= length
	return {"position": path[-1], "heading": (path[-1] - path[-2]).normalized() if path.size() > 1 else Vector2.UP}

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func get_vessel_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var fleet: Node = get_tree().get_first_node_in_group("fleet_system")
	if fleet == null:
		return snapshots
	var now: float = Time.get_unix_time_from_system()
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
		if str(ship.get("ship_type_id","")) == "ship_combat_cutter" and ship.get("autopilot",{}).is_empty(): continue
		var ship_id: String = str(ship.get("instance_id", ""))
		var voyage: Dictionary = fleet.get_auxiliary_voyage_status(ship_id, now)
		if not bool(voyage.get("found", false)):
			continue
		var in_transit: bool = bool(voyage.get("in_transit", false))
		var position: Vector2
		var heading: Vector2 = Vector2.UP
		if in_transit:
			var origin: Vector2 = _port_position(str(voyage.get("origin_port_id", "")))
			var destination: Vector2 = _port_position(str(voyage.get("destination_port_id", "")))
			var safe: Dictionary = _safe_route_position(origin, destination, float(voyage.get("progress", 0.0)))
			position = safe.position
			heading = safe.heading
			if heading.length_squared() <= 0.001:
				heading = Vector2.UP
		else:
			position = _port_position(str(voyage.get("current_port_id", "")))
			var berth_angle: float = float(posmod(abs(hash(ship_id)), 5)) * 1.1
			position += Vector2(cos(berth_angle), sin(berth_angle)) * 24.0
		var ship_type_id: String = str(ship.get("ship_type_id", ""))
		var ship_type: Dictionary = GameData.get_ship(ship_type_id)
		var tier: int = int(ship_type.get("tier", 1))
		var length: float = float(GameData.read("res://data/world/ship_visuals.json").get("ships", {}).get(ship_type_id, {}).get("display_length", 3.48)) / 0.04
		var obstacles: Array = snapshots.duplicate()
		var traders: Node = get_tree().get_first_node_in_group("trader_traffic_renderer")
		if traders != null:
			obstacles.append_array(traders.get_vessel_snapshots())
		obstacles.append({"position": Vector2(GameState.ship_state.get("position", Vector2.ZERO)), "length": 120.0})
		if not in_transit:
			var berth_key: String = ship_id + ":" + str(voyage.get("current_port_id", ""))
			if not _berths.has(berth_key):
				_berths[berth_key] = _free_water_position(position, length, obstacles)
			position = _berths[berth_key]
		elif _shown_positions.has(ship_id):
			var previous: Vector2 = _shown_positions[ship_id]
			if not _clearance_segment(previous, position, length, obstacles) or _guard.is_navigation_move_blocked(previous, position):
				position = previous
		elif not _clearance_at(position, length, obstacles):
			position = _free_water_position(position, length, obstacles)
		_shown_positions[ship_id] = position
		snapshots.append({
			"id": ship_id,
			"name": str(ship.get("name", ship_type.get("name", "Корабль"))),
			"ship_type_id": ship_type_id,
			"port_id": "" if in_transit else str(voyage.get("current_port_id", "")),
			"in_transit": in_transit,
			"position": position,
			"heading": heading,
			"length": length,
			"color": Color(0.25, 0.88, 1.0, 1.0) if in_transit else Color(0.45, 0.76, 0.92, 1.0),
			"kind": "fleet"
		})
	var military: Node = get_tree().get_first_node_in_group("military_transport_system")
	if military != null: snapshots.append_array(military.get_vessel_snapshots())
	return snapshots

func _clearance_at(point: Vector2, length: float, obstacles: Array) -> bool:
	for other in obstacles:
		if point.distance_to(Vector2(other.position)) < length + float(other.get("length", 100.0)):
			return false
	return not _guard.is_navigation_move_blocked(point + Vector2(0.1, 0), point) and not _guard.is_navigation_move_blocked(point - Vector2(0.1, 0), point)

func _clearance_segment(start: Vector2, finish: Vector2, length: float, obstacles: Array) -> bool:
	for other in obstacles:
		if Geometry2D.get_closest_point_to_segment(Vector2(other.position), start, finish).distance_to(Vector2(other.position)) < length + float(other.get("length", 100.0)):
			return false
	return _clearance_at(finish, length, obstacles)

func _free_water_position(anchor: Vector2, length: float, obstacles: Array) -> Vector2:
	for radius in [200.0, 400.0, 700.0, 1100.0, 1800.0, 2800.0, 4200.0]:
		for index in range(24):
			var point: Vector2 = anchor + Vector2.from_angle(float(index) * TAU / 24.0) * float(radius)
			if _clearance_at(point, length, obstacles):
				return point
	return anchor

func _draw() -> void:
	var fleet: Node = get_tree().get_first_node_in_group("fleet_system")
	if fleet == null:
		return
	var now: float = Time.get_unix_time_from_system()
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
		if str(ship.get("ship_type_id","")) == "ship_combat_cutter" and ship.get("autopilot",{}).is_empty(): continue
		var ship_id: String = str(ship.get("instance_id", ""))
		var voyage: Dictionary = fleet.get_auxiliary_voyage_status(ship_id, now)
		if not bool(voyage.get("found", false)):
			continue
		_draw_ship(ship, voyage)

func _draw_ship(ship: Dictionary, voyage: Dictionary) -> void:
	var in_transit: bool = bool(voyage.get("in_transit", false))
	var position: Vector2
	var heading: Vector2 = Vector2.UP
	if in_transit:
		var origin: Vector2 = _port_position(str(voyage.get("origin_port_id", "")))
		var destination: Vector2 = _port_position(str(voyage.get("destination_port_id", "")))
		var progress: float = float(voyage.get("progress", 0.0))
		position = origin.lerp(destination, progress)
		heading = (destination - origin).normalized()
		if heading.length_squared() <= 0.001:
			heading = Vector2.UP
		draw_dashed_line(origin, destination, Color(0.35, 0.9, 1.0, 0.32), 1.5, 8.0)
	else:
		position = _port_position(str(voyage.get("current_port_id", "")))
		var berth_offset: float = 24.0 + float(posmod(abs(hash(str(ship.get("instance_id", "")))), 5)) * 5.0
		position += Vector2(cos(berth_offset), sin(berth_offset)) * berth_offset
	var tier: int = int(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("tier", 1))
	var size: float = 7.0 + float(tier) * 2.0
	var side: Vector2 = Vector2(-heading.y, heading.x)
	var hull: PackedVector2Array = PackedVector2Array([
		position + heading * size,
		position - heading * size * 0.75 + side * size * 0.62,
		position - heading * size * 0.75 - side * size * 0.62
	])
	var fill: Color = Color(0.25, 0.88, 1.0, 1.0) if in_transit else Color(0.45, 0.76, 0.92, 1.0)
	draw_colored_polygon(hull, fill)
	draw_polyline(hull, Color(0.9, 1.0, 1.0, 1.0), 1.5, true)
	if in_transit:
		draw_circle(position, size + 5.0, Color(0.25, 0.9, 1.0, 0.12))
		draw_string(ThemeDB.fallback_font, position + Vector2(-26.0, -size - 9.0), "ВАШ РЕЙС", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.70, 0.96, 1.0, 1.0))

func _port_position(port_id: String) -> Vector2:
	var port: Dictionary = _ports.get(port_id, {})
	return Vector2(port.get("position", Vector2.ZERO))
