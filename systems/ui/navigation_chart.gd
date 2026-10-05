extends Control

## Full-screen sea chart, centered on the active ship with scalable islands and fleet labels.

const MIN_ZOOM: float = 0.035
const MAX_ZOOM: float = 1.25
const ZOOM_STEP: float = 1.22

var _port_system: Node
var _world_renderer: Node
var _fleet_traffic: Node
var _world_data: Dictionary = {}
var _map_zoom: float = 0.12
var _map_center: Vector2 = Vector2.ZERO
var _follow_active_ship: bool = true
var _dragging: bool = false
var _redraw_clock: float = 0.0

func initialize(port_system: Node) -> void:
	_port_system = port_system
	_world_renderer = get_tree().get_first_node_in_group("world_renderer")
	_fleet_traffic = get_tree().get_first_node_in_group("fleet_traffic_renderer")
	if _world_renderer != null and _world_renderer.has_method("get_world_map_data"):
		_world_data = _world_renderer.get_world_map_data()
	_map_center = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	queue_redraw()


func center_on_ship() -> void:
	_map_center = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	_follow_active_ship = true
	queue_redraw()


func _process(delta: float) -> void:
	_redraw_clock += delta
	if _redraw_clock >= 0.25:
		_redraw_clock = 0.0
		if _follow_active_ship:
			_map_center = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
		if _world_renderer != null and _world_renderer.has_method("get_world_map_data"):
			_world_data = _world_renderer.get_world_map_data()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_map_zoom = minf(MAX_ZOOM, _map_zoom * ZOOM_STEP)
			accept_event()
			queue_redraw()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_map_zoom = maxf(MIN_ZOOM, _map_zoom / ZOOM_STEP)
			accept_event()
			queue_redraw()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event
		_map_center += Vector2(-motion.relative.x / _map_zoom, motion.relative.y / _map_zoom)
		_follow_active_ship = false
		accept_event()
		queue_redraw()


func _draw() -> void:
	if size.x < 80.0 or size.y < 80.0:
		return
	var chart_rect := Rect2(Vector2.ZERO, size)
	draw_rect(chart_rect, Color("#12252a"), true)
	_draw_grid(chart_rect)
	_draw_islands(chart_rect)
	_draw_known_ports()
	_draw_route()
	_draw_active_ship()
	_draw_fleet_ships()
	_draw_chart_labels(chart_rect)


func _draw_grid(chart_rect: Rect2) -> void:
	var grid_color := Color(0.48, 0.67, 0.63, 0.14)
	var world_width: float = chart_rect.size.x / _map_zoom
	var world_height: float = chart_rect.size.y / _map_zoom
	var left: float = _map_center.x - world_width * 0.5
	var top: float = _map_center.y + world_height * 0.5
	var spacing: float = 500.0
	var first_x: int = floori(left / spacing)
	var last_x: int = ceili((left + world_width) / spacing)
	var first_y: int = floori((top - world_height) / spacing)
	var last_y: int = ceili(top / spacing)
	for grid_x in range(first_x, last_x + 1):
		var world_x: float = float(grid_x) * spacing
		var screen_x: float = chart_rect.get_center().x + (world_x - _map_center.x) * _map_zoom
		draw_line(Vector2(screen_x, 0.0), Vector2(screen_x, size.y), grid_color, 1.0)
	for grid_y in range(first_y, last_y + 1):
		var world_y: float = float(grid_y) * spacing
		var screen_y: float = chart_rect.get_center().y - (world_y - _map_center.y) * _map_zoom
		draw_line(Vector2(0.0, screen_y), Vector2(size.x, screen_y), grid_color, 1.0)
	draw_rect(chart_rect, Color("#79938a"), false, 2.0)


func _draw_islands(chart_rect: Rect2) -> void:
	var raw_islands: Variant = _world_data.get("islands", [])
	if not raw_islands is Array:
		return
	for raw_island in raw_islands:
		if not raw_island is Dictionary:
			continue
		var island: Dictionary = raw_island
		var world_position: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var center: Vector2 = _to_chart(world_position)
		var radius: float = float(island.get("radius", 0.0))
		var radius_px: float = radius * _map_zoom
		if radius <= 0.0 or not chart_rect.grow(radius_px + 8.0).has_point(center):
			continue
		if radius_px < 3.0:
			draw_circle(center, 3.0, Color("#829b79"))
			continue
		var seed_value: float = float(posmod(hash(str(island.get("id", world_position))), 997)) * 0.01
		var coastline := PackedVector2Array()
		var shared_coast: PackedVector2Array = island.get("coast_polygon", PackedVector2Array())
		for point in shared_coast:
			coastline.append(_to_chart(point))
		for point_index in range(49 if shared_coast.is_empty() else 0):
			var angle: float = TAU * float(point_index) / 48.0
			var irregularity: float = 1.0 + sin(angle * 3.0 + seed_value) * 0.07 + sin(angle * 5.0 - seed_value * 1.7) * 0.035
			var point_radius: float = radius_px * irregularity
			coastline.append(center + Vector2(cos(angle) * point_radius, -sin(angle) * point_radius))
		draw_colored_polygon(coastline, Color("#536d58"))
		draw_polyline(coastline, Color("#b3ae78"), 2.0, true)
		if not shared_coast.is_empty():
			var opening := float(island.get("bay_angle", 0.0))
			for index in range(40):
				var angle := float(index) * TAU / 40.0
				if absf(wrapf(angle - opening, -PI, PI)) < 0.34:
					continue
				draw_circle(_to_chart(world_position + Vector2.from_angle(angle) * float(island.get("reef_inner_radius", radius))), 2.0, Color("7ca9a2"))
			continue
		for contour_index in range(1, 4):
			var contour_radius: float = radius_px * (0.78 - float(contour_index - 1) * 0.18)
			if contour_radius > 5.0:
				draw_arc(center, contour_radius, 0.0, TAU, 48, Color(0.78, 0.75, 0.53, 0.32), 1.2, true)
		if radius_px > 44.0:
			var island_name: String = str(island.get("name", ""))
			if island_name != "":
				draw_string(ThemeDB.fallback_font, center + Vector2(-radius_px * 0.45, 5.0), island_name, HORIZONTAL_ALIGNMENT_LEFT, radius_px * 0.9, 15, Color("#e0d7a9"))


func _draw_known_ports() -> void:
	if _port_system == null:
		return
	var known_ids: Array = GameState.player_state.get("visited_port_ids", []).duplicate()
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_id != "" and not known_ids.has(home_id):
		known_ids.append(home_id)
	for raw_id in known_ids:
		var port_id: String = str(raw_id)
		if port_id == "":
			continue
		var point: Vector2 = _to_chart(_port_system.get_port_position(port_id))
		if not Rect2(Vector2.ZERO, size).grow(24.0).has_point(point):
			continue
		if port_id == home_id:
			draw_circle(point, 10.0, Color("#65d27d"))
			draw_arc(point, 17.0, 0.0, TAU, 32, Color("#ffec9a"), 2.0)
			_draw_label(point + Vector2(17.0, -10.0), "★ " + _port_system.get_port_name(port_id), Color("#ffe58a"))
		else:
			var state: Dictionary = GameState.port_state.get(port_id, {})
			var allied: bool = bool(state.get("captured_by_player", false)) or bool(state.get("tribute_active", false))
			var marker_color := Color("#65d27d") if allied else Color("#8fc9a1")
			draw_circle(point, 7.0 if allied else 6.0, marker_color)
			_draw_label(point + Vector2(11.0, 5.0), _port_system.get_port_name(port_id), Color("#a9f0ad") if allied else Color("#d5e5e6"))


func _draw_route() -> void:
	if _port_system == null:
		return
	# Draw only a route the player actually selected. Falling back to the home
	# port made a permanent yellow line appear from the active vessel.
	var target_id: String = str(GameState.world_state.get("destination_port_id", ""))
	if target_id == "":
		return
	var target: Vector2 = _to_chart(_port_system.get_port_position(target_id))
	var ship: Vector2 = _to_chart(Vector2(GameState.ship_state.get("position", Vector2.ZERO)))
	draw_line(ship, target, Color(0.94, 0.76, 0.31, 0.72), 2.0, true)


func _draw_active_ship() -> void:
	var position: Vector2 = _to_chart(Vector2(GameState.ship_state.get("position", Vector2.ZERO)))
	var heading: float = float(GameState.ship_state.get("heading", -PI * 0.5))
	var forward := Vector2(cos(heading), -sin(heading)).normalized()
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		position + forward * 17.0,
		position - forward * 10.0 + side * 9.0,
		position - forward * 10.0 - side * 9.0
	])
	draw_colored_polygon(points, Color("#54d7ea"))
	draw_polyline(points, Color("#d8fbff"), 2.0, true)
	draw_arc(position, 22.0, 0.0, TAU, 32, Color(0.42, 0.9, 1.0, 0.68), 2.0)
	var ship_type: Dictionary = GameData.get_ship(str(GameState.ship_state.get("ship_id", "")))
	var ship_name: String = str(ship_type.get("name", "Ваш корабль"))
	_draw_label(position + Vector2(20.0, 28.0), "ВЫ · " + ship_name, Color("#a8f1ff"))


func _draw_fleet_ships() -> void:
	if _fleet_traffic == null or not _fleet_traffic.has_method("get_vessel_snapshots"):
		return
	var snapshots: Variant = _fleet_traffic.call("get_vessel_snapshots")
	if not snapshots is Array:
		return
	var dock_counts: Dictionary = {}
	for raw_snapshot in snapshots:
		if not raw_snapshot is Dictionary:
			continue
		var vessel: Dictionary = raw_snapshot
		var position: Vector2 = _to_chart(Vector2(vessel.get("position", Vector2.ZERO)))
		if not Rect2(Vector2.ZERO, size).grow(32.0).has_point(position):
			continue
		var dock_index: int = 0
		var port_id: String = str(vessel.get("port_id", ""))
		if port_id != "":
			dock_index = int(dock_counts.get(port_id, 0))
			dock_counts[port_id] = dock_index + 1
		var column: int = dock_index % 2
		var row: int = floori(float(dock_index) / 2.0)
		var visual_position: Vector2 = position
		var label_offset: Vector2 = Vector2(14.0, 22.0)
		if port_id != "":
			visual_position += Vector2(float(column) * 12.0, float(row) * 12.0)
			label_offset = Vector2(18.0 + float(column) * 90.0, 20.0 + float(row) * 22.0)
		var heading: Vector2 = Vector2(vessel.get("heading", Vector2.UP))
		var forward := Vector2(heading.x, -heading.y).normalized()
		if forward.length_squared() < 0.001:
			forward = Vector2.UP
		var side := Vector2(-forward.y, forward.x)
		var points := PackedVector2Array([
			visual_position + forward * 13.0,
			visual_position - forward * 8.0 + side * 7.0,
			visual_position - forward * 8.0 - side * 7.0
		])
		var color: Color = vessel.get("color", Color("#62cdeb"))
		draw_colored_polygon(points, color)
		draw_polyline(points, Color("#e7fbff"), 1.5, true)
		_draw_label(visual_position + label_offset, str(vessel.get("name", "Корабль")), Color("#b9eaff"))


func _draw_label(position: Vector2, text: String, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 16
	var label_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var background := Rect2(position + Vector2(-4.0, -font_size - 3.0), label_size + Vector2(8.0, font_size + 7.0))
	draw_rect(background, Color(0.025, 0.055, 0.065, 0.88), true)
	draw_rect(background, Color(0.52, 0.71, 0.68, 0.48), false, 1.0)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_chart_labels(chart_rect: Rect2) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 25.0), "МОРСКАЯ КАРТА  ·  масштаб %.2f" % _map_zoom, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#d6dfbe"))
	draw_string(ThemeDB.fallback_font, Vector2(chart_rect.end.x - 30.0, 34.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f0d779"))
	var bar_world: float = 500.0
	var bar_width: float = bar_world * _map_zoom
	if bar_width > 24.0 and bar_width < size.x * 0.35:
		var bar_start := Vector2(20.0, size.y - 22.0)
		draw_line(bar_start, bar_start + Vector2(bar_width, 0.0), Color("#e1d7a5"), 3.0, true)
		draw_line(bar_start + Vector2(0.0, -5.0), bar_start + Vector2(0.0, 5.0), Color("#e1d7a5"), 2.0)
		draw_line(bar_start + Vector2(bar_width, -5.0), bar_start + Vector2(bar_width, 5.0), Color("#e1d7a5"), 2.0)
		draw_string(ThemeDB.fallback_font, bar_start + Vector2(bar_width + 8.0, 5.0), "500 м", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e1d7a5"))


func _to_chart(world_point: Vector2) -> Vector2:
	var middle: Vector2 = size * 0.5
	return middle + Vector2(world_point.x - _map_center.x, -world_point.y + _map_center.y) * _map_zoom
