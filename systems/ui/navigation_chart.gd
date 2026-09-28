extends Control

## A small navigational chart of visited ports, the home port, and the current ship.
var _port_system: Node
var _redraw_clock: float = 0.0

func initialize(port_system: Node) -> void:
	_port_system = port_system
	queue_redraw()

func _process(delta: float) -> void:
	_redraw_clock += delta
	if _redraw_clock >= 0.5:
		_redraw_clock = 0.0
		queue_redraw()

func _draw() -> void:
	var background := Rect2(Vector2.ZERO, size)
	draw_rect(background, Color("#0a202a"), true)
	draw_rect(background, Color("#466c78"), false, 2.0)
	if _port_system == null or size.x < 80.0 or size.y < 80.0:
		return

	var ship_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var home_id: String = str(GameState.world_state.get("home_port_id", ""))
	var home_position: Vector2 = Vector2.ZERO
	var has_home: bool = home_id != ""
	if has_home:
		home_position = _port_system.get_port_position(home_id)

	var ports: Array[Dictionary] = []
	var min_x: float = ship_position.x
	var max_x: float = ship_position.x
	var min_y: float = ship_position.y
	var max_y: float = ship_position.y
	var known_ids: Array = GameState.player_state.get("discovered_port_ids", []).duplicate()
	if has_home and not known_ids.has(home_id):
		known_ids.append(home_id)
	for raw_id in known_ids:
		var port_id: String = str(raw_id)
		if port_id == "":
			continue
		var position: Vector2 = _port_system.get_port_position(port_id)
		ports.append({"id": port_id, "position": position})
		min_x = minf(min_x, position.x)
		max_x = maxf(max_x, position.x)
		min_y = minf(min_y, position.y)
		max_y = maxf(max_y, position.y)

	var span_x: float = maxf(400.0, max_x - min_x)
	var span_y: float = maxf(400.0, max_y - min_y)
	var pad_x: float = span_x * 0.12
	var pad_y: float = span_y * 0.12
	min_x -= pad_x
	max_x += pad_x
	min_y -= pad_y
	max_y += pad_y

	var chart_rect := Rect2(Vector2(24.0, 30.0), size - Vector2(48.0, 60.0))
	if chart_rect.size.x <= 0.0 or chart_rect.size.y <= 0.0:
		return
	for grid_index in range(1, 4):
		var x: float = chart_rect.position.x + chart_rect.size.x * float(grid_index) / 4.0
		var y: float = chart_rect.position.y + chart_rect.size.y * float(grid_index) / 4.0
		draw_line(Vector2(x, chart_rect.position.y), Vector2(x, chart_rect.end.y), Color(0.32, 0.52, 0.57, 0.35), 1.0)
		draw_line(Vector2(chart_rect.position.x, y), Vector2(chart_rect.end.x, y), Color(0.32, 0.52, 0.57, 0.35), 1.0)
	draw_rect(chart_rect, Color("#6b9094"), false, 1.0)

	var ship_point: Vector2 = _to_chart(ship_position, chart_rect, min_x, max_x, min_y, max_y)
	var home_point: Vector2 = _to_chart(home_position, chart_rect, min_x, max_x, min_y, max_y)
	if has_home:
		draw_line(ship_point, home_point, Color(0.93, 0.75, 0.28, 0.7), 2.0)
	for port in ports:
		var port_id: String = str(port.get("id", ""))
		var point: Vector2 = _to_chart(Vector2(port.get("position", Vector2.ZERO)), chart_rect, min_x, max_x, min_y, max_y)
		if port_id == home_id:
			draw_circle(point, 11.0, Color("#f0c84b"))
			draw_arc(point, 17.0, 0.0, TAU, 32, Color("#ffe58a"), 2.5)
			draw_string(ThemeDB.fallback_font, point + Vector2(15.0, -12.0), "★ ДОМ", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffe58a"))
		else:
			draw_circle(point, 7.0, Color("#8fc9a1"))
			draw_string(ThemeDB.fallback_font, point + Vector2(11.0, 5.0), _port_system.get_port_name(port_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#d5e5e6"))

	draw_circle(ship_point, 8.0, Color("#64d8f0"))
	draw_arc(ship_point, 13.0, 0.0, TAU, 24, Color("#a8f1ff"), 2.0)
	draw_string(ThemeDB.fallback_font, ship_point + Vector2(14.0, 23.0), "ВАШ КОРАБЛЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#a8f1ff"))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 22.0), "КАРТА ИЗВЕДАННЫХ ПОРТОВ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d5e5e6"))

func _to_chart(world_point: Vector2, chart_rect: Rect2, min_x: float, max_x: float, min_y: float, max_y: float) -> Vector2:
	var x_ratio: float = (world_point.x - min_x) / maxf(1.0, max_x - min_x)
	var y_ratio: float = (world_point.y - min_y) / maxf(1.0, max_y - min_y)
	return Vector2(
		chart_rect.position.x + x_ratio * chart_rect.size.x,
		chart_rect.end.y - y_ratio * chart_rect.size.y
	)
