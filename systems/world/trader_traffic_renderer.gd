extends Node2D

## Sparse ambient merchant traffic plus the real visiting merchant at the home port.

var _world_size: Vector2 = Vector2(4096, 4096)
var _vessels: Array = []
var _ports: Dictionary = {}

func initialize(world_data: Dictionary) -> void:
	var raw_size: Variant = world_data.get("world_size", Vector2(4096, 4096))
	if raw_size is Vector2 or raw_size is Vector2i:
		_world_size = Vector2(raw_size)
	var raw_ports: Variant = world_data.get("ports", {})
	if raw_ports is Dictionary:
		_ports = raw_ports
	var ship_sizes: Array[float] = [7.0, 10.0, 14.0, 9.0, 18.0, 11.0]
	var ship_colors: Array[Color] = [
		Color(0.9, 0.9, 0.82, 1.0),
		Color(0.75, 0.72, 0.55, 1.0),
		Color(0.8, 0.45, 0.22, 1.0),
		Color(0.65, 0.85, 0.95, 1.0),
		Color(0.55, 0.58, 0.62, 1.0),
		Color(0.95, 0.72, 0.30, 1.0)
	]
	for index in range(ship_sizes.size()):
		var start: Vector2 = Vector2(
			fposmod(320.0 + index * 643.0, _world_size.x),
			fposmod(510.0 + index * 389.0, _world_size.y)
		)
		var destination: Vector2 = Vector2(
			fposmod(2100.0 + index * 287.0, _world_size.x),
			fposmod(1200.0 + index * 521.0, _world_size.y)
		)
		_vessels.append({
			"position": start,
			"destination": destination,
			"speed": 18.0 + index * 3.0,
			"size": ship_sizes[index],
			"color": ship_colors[index]
		})
	queue_redraw()

func _process(delta: float) -> void:
	for index in range(_vessels.size()):
		var vessel: Dictionary = _vessels[index]
		var position: Vector2 = vessel.get("position", Vector2.ZERO)
		var destination: Vector2 = vessel.get("destination", Vector2.ZERO)
		var speed: float = float(vessel.get("speed", 20.0))
		var candidate: Vector2 = position.move_toward(destination, speed * delta)
		var player_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
		var clearance: float = float(vessel.get("size", 8.0)) * 0.9 + 30.0
		var blocked: bool = candidate.distance_to(player_position) < clearance
		for other_index in range(_vessels.size()):
			if other_index == index:
				continue
			var other: Dictionary = _vessels[other_index]
			var other_position: Vector2 = Vector2(other.get("position", Vector2.ZERO))
			var other_clearance: float = (float(vessel.get("size", 8.0)) + float(other.get("size", 8.0))) * 0.55
			if candidate.distance_to(other_position) < other_clearance:
				blocked = true
				break
		if blocked:
			vessel["position"] = position
		elif position.distance_to(destination) <= speed * delta:
			vessel["position"] = destination
			vessel["destination"] = Vector2(
				fposmod(destination.x + 1177.0 + index * 73.0, _world_size.x),
				fposmod(destination.y + 809.0 + index * 131.0, _world_size.y)
			)
		else:
			vessel["position"] = candidate
		_vessels[index] = vessel
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	for vessel in _vessels:
		_draw_ambient_vessel(vessel)
	_draw_visiting_merchant()


func get_vessel_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for index in range(_vessels.size()):
		var vessel: Dictionary = _vessels[index]
		var position: Vector2 = Vector2(vessel.get("position", Vector2.ZERO))
		var destination: Vector2 = Vector2(vessel.get("destination", position + Vector2.UP))
		var direction: Vector2 = (destination - position).normalized()
		if direction.length_squared() < 0.001:
			direction = Vector2.UP
		snapshots.append({
			"id": "ambient_%02d" % index,
			"position": position,
			"heading": direction,
			"length": float(vessel.get("size", 8.0)) * 2.0,
			"color": vessel.get("color", Color.WHITE),
			"kind": "merchant"
		})
	var merchant: Dictionary = GameState.economy_state.get("merchant", {})
	var offer: Dictionary = merchant.get("active_offer", {})
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if not offer.is_empty() and int(offer.get("quantity_available", 0)) > 0 and _ports.has(home_port_id):
		var port: Dictionary = _ports[home_port_id]
		var port_position: Vector2 = Vector2(port.get("position", Vector2.ZERO))
		var visitor_index: int = int(offer.get("visitor_index", 0))
		var size: float = 17.0 + float(visitor_index % 3) * 4.0
		snapshots.append({
			"id": "visiting_merchant",
			"position": port_position + Vector2(42.0, -38.0 + sin(float(Time.get_ticks_msec()) / 550.0) * 2.0),
			"heading": Vector2(1.0, 0.25).normalized(),
			"length": size * 2.0,
			"color": Color(0.18, 0.86, 0.38, 1.0),
			"kind": "visiting_merchant"
		})
	return snapshots

func _draw_ambient_vessel(vessel: Dictionary) -> void:
	var position: Vector2 = vessel.get("position", Vector2.ZERO)
	var destination: Vector2 = vessel.get("destination", Vector2.ZERO)
	var size: float = float(vessel.get("size", 8.0))
	var color: Color = vessel.get("color", Color.WHITE)
	var direction: Vector2 = (destination - position).normalized()
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var points: PackedVector2Array = PackedVector2Array([
		position + direction * size,
		position - direction * size * 0.7 + side * size * 0.55,
		position - direction * size * 0.7 - side * size * 0.55
	])
	draw_colored_polygon(points, color)

func _draw_visiting_merchant() -> void:
	var merchant: Dictionary = GameState.economy_state.get("merchant", {})
	var raw_offer: Variant = merchant.get("active_offer", {})
	if not (raw_offer is Dictionary):
		return
	var offer: Dictionary = raw_offer
	if offer.is_empty() or int(offer.get("quantity_available", 0)) <= 0:
		return
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id == "" or not _ports.has(home_port_id):
		return
	var port: Dictionary = _ports[home_port_id]
	var port_position: Vector2 = Vector2(port.get("position", Vector2.ZERO))
	var visitor_index: int = int(offer.get("visitor_index", 0))
	var size: float = 17.0 + float(visitor_index % 3) * 4.0
	var bob: float = sin(float(Time.get_ticks_msec()) / 550.0) * 2.0
	var position: Vector2 = port_position + Vector2(42.0, -38.0 + bob)
	var direction: Vector2 = Vector2(1.0, 0.25).normalized()
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var hull: PackedVector2Array = PackedVector2Array([
		position + direction * size,
		position - direction * size * 0.85 + side * size * 0.62,
		position - direction * size * 0.85 - side * size * 0.62
	])
	draw_colored_polygon(hull, Color(0.18, 0.86, 0.38, 1.0))
	draw_polyline(hull, Color(0.84, 1.0, 0.78, 1.0), 2.0, true)
	draw_line(position, position - direction * size * 0.35 + side * size * 1.15, Color(0.95, 0.9, 0.65, 1.0), 2.0)
	draw_string(ThemeDB.fallback_font, position + Vector2(-38.0, -size - 11.0), "ТОРГОВЕЦ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.65, 1.0, 0.70, 1.0))
