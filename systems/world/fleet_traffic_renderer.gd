extends Node2D

## Draws the player's auxiliary ships at their actual saved voyage progress.
## It is deliberately only a view: FleetSystem remains the owner of movement,
## arrival and cargo settlement, including while the application is closed.

var _ports: Dictionary = {}

func initialize(world_data: Dictionary) -> void:
	var raw_ports: Variant = world_data.get("ports", {})
	if raw_ports is Dictionary:
		_ports = raw_ports
	queue_redraw()

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
			position = origin.lerp(destination, float(voyage.get("progress", 0.0)))
			heading = (destination - origin).normalized()
			if heading.length_squared() <= 0.001:
				heading = Vector2.UP
		else:
			position = _port_position(str(voyage.get("current_port_id", "")))
			var berth_angle: float = float(posmod(abs(hash(ship_id)), 5)) * 1.1
			position += Vector2(cos(berth_angle), sin(berth_angle)) * 24.0
		var tier: int = int(GameData.get_ship(str(ship.get("ship_type_id", ""))).get("tier", 1))
		snapshots.append({
			"id": ship_id,
			"position": position,
			"heading": heading,
			"length": 24.0 + float(tier) * 9.0,
			"color": Color(0.25, 0.88, 1.0, 1.0) if in_transit else Color(0.45, 0.76, 0.92, 1.0),
			"kind": "fleet"
		})
	return snapshots

func _draw() -> void:
	var fleet: Node = get_tree().get_first_node_in_group("fleet_system")
	if fleet == null:
		return
	var now: float = Time.get_unix_time_from_system()
	for raw_ship in GameState.fleet_state:
		var ship: Dictionary = raw_ship
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
