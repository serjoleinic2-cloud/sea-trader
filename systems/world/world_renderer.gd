extends Node2D

## WorldRenderer — placeholder visualization of the generated world.
## Draws ocean background, islands, ports, hazard zones.
## See DEVELOPMENT_PHASES.md Phase 02 + Phase 05.

@export var ocean_color: Color = Color("1a3a5c")
@export var island_color: Color = Color("2d5a27")
@export var island_border_color: Color = Color("1e3d1a")
@export var port_color: Color = Color("d4a017")
@export var port_border_color: Color = Color("8b6914")
@export var hazard_storm_color: Color = Color("4a6fa5")
@export var hazard_pirate_color: Color = Color("8b3a3a")
@export var grid_color: Color = Color("ffffff", 0.05)

var _world_data: Dictionary = {}
var _camera: Camera2D
var _last_home_port_id: String = ""


func _ready() -> void:
	EventBus.port_discovered.connect(_on_port_discovered)


func _process(_delta: float) -> void:
	var home_port_id: String = str(GameState.world_state.get("home_port_id", ""))
	if home_port_id != _last_home_port_id:
		_last_home_port_id = home_port_id
		queue_redraw()


func _on_port_discovered(_port_id: String) -> void:
	queue_redraw()

# ============================================================================
# Public API
# ============================================================================

func setup(world_data: Dictionary) -> void:
	_world_data = world_data
	queue_redraw()


func set_camera(cam: Camera2D) -> void:
	_camera = cam


# ============================================================================
# Drawing
# ============================================================================

func _draw() -> void:
	if _world_data.is_empty():
		return

	var world_size: Vector2i = _world_data.get("world_size", Vector2i(4096, 4096))

	# Ocean background
	draw_rect(Rect2(Vector2.ZERO, Vector2(world_size)), ocean_color, true)
	_draw_waves(world_size)

	# Grid lines (light, for orientation)
	_draw_grid(world_size)

	# Hazard zones (drawn first so they appear under islands)
	for zone in _world_data.get("hazard_zones", []):
		_draw_hazard_zone(zone)

	# Islands
	for island in _world_data.get("islands", []):
		_draw_island(island)

	# Ports
	for port_id in _world_data.get("ports", {}):
		var port: Dictionary = _world_data.ports[port_id]
		_draw_port(port)



func _draw_waves(world_size: Vector2i) -> void:
	# Only animate the camera view to keep the sea light enough for mobile.
	var center: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var zoom: Vector2 = Vector2.ONE
	if _camera != null and is_instance_valid(_camera):
		center = _camera.get_screen_center_position()
		zoom = _camera.zoom
	var view_size: Vector2 = get_viewport_rect().size / Vector2(maxf(zoom.x, 0.01), maxf(zoom.y, 0.01))
	var view_rect := Rect2(center - view_size * 0.65, view_size * 1.3)
	view_rect = view_rect.intersection(Rect2(Vector2.ZERO, Vector2(world_size)))
	if view_rect.size.x <= 0.0 or view_rect.size.y <= 0.0:
		return
	var spacing: float = 118.0
	var first_x: int = floori(view_rect.position.x / spacing)
	var last_x: int = ceili(view_rect.end.x / spacing)
	var first_y: int = floori(view_rect.position.y / spacing)
	var last_y: int = ceili(view_rect.end.y / spacing)
	for row in range(first_y, last_y + 1):
		for column in range(first_x, last_x + 1):
			var seed_value: float = sin(float(column * 127 + row * 311) * 12.9898) * 43758.5453
			var random_value: float = seed_value - floor(seed_value)
			if random_value < 0.28:
				continue
			var base_x: float = float(column) * spacing + random_value * 68.0
			var base_y: float = float(row) * spacing + fposmod(random_value * 137.0, spacing)
			var slide: float = sin(_wave_clock * 0.8 + float(row) * 0.73 + float(column)) * 7.0
			var start := Vector2(base_x + slide, base_y)
			var length: float = 18.0 + random_value * 31.0
			var wave_color := Color(0.62, 0.82, 0.91, 0.10 + random_value * 0.07)
			draw_line(start, start + Vector2(length, -2.0 - random_value * 3.0), wave_color, 1.5, true)
			var secondary_color := Color(wave_color.r, wave_color.g, wave_color.b, wave_color.a * 0.55)
			draw_line(start + Vector2(5.0, 4.0), start + Vector2(length * 0.67, 3.0), secondary_color, 1.0, true)


func _draw_grid(world_size: Vector2i) -> void:
	var step: int = 256
	for x in range(0, world_size.x + 1, step):
		draw_line(Vector2(x, 0), Vector2(x, world_size.y), grid_color, 1.0)
	for y in range(0, world_size.y + 1, step):
		draw_line(Vector2(0, y), Vector2(world_size.x, y), grid_color, 1.0)


func _draw_island(island: Dictionary) -> void:
	var pos: Vector2 = Vector2(island.position)
	var radius: float = float(island.radius)
	# Main island body
	draw_circle(pos, radius, island_color)
	# Border
	draw_arc(pos, radius, 0.0, TAU, 64, island_border_color, 3.0)


func _draw_port(port: Dictionary) -> void:
	# Geometry comes from the generator; visibility comes from saved knowledge.
	var pos: Vector2 = Vector2(port.position)
	var known: bool = GameState.player_state.get("visited_port_ids", []).has(port.id)
	if not known:
		# A neutral marker tells the player where exploration is possible but leaks
		# neither the port name nor economic information.
		draw_circle(pos, 8.0, Color(0.40, 0.45, 0.50, 0.72))
		draw_arc(pos, 8.0, 0.0, TAU, 16, Color(0.68, 0.72, 0.76, 0.88), 1.5)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		return
	var radius: float = 12.0
	# Port circle
	draw_circle(pos, radius, port_color)
	draw_arc(pos, radius, 0.0, TAU, 16, port_border_color, 2.0)
	if str(GameState.world_state.get("home_port_id", "")) == str(port.id):
		draw_arc(pos, radius + 10.0, 0.0, TAU, 32, Color("f5d142"), 3.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-18, -28), "БАЗА", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f5d142"))
	# Name label
	draw_string(
		ThemeDB.fallback_font,
		pos + Vector2(15, -10),
		port.name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color("ffffff")
	)


func _draw_hazard_zone(zone: Dictionary) -> void:
	var pos: Vector2 = Vector2(zone.position)
	var radius: float = float(zone.radius)
	var color: Color = hazard_storm_color if zone.type == "storm" else hazard_pirate_color
	# Semi-transparent fill
	draw_circle(pos, radius, Color(color, 0.15))
	# Dashed border effect (simplified: just a thin line)
	draw_arc(pos, radius, 0.0, TAU, 64, Color(color, 0.4), 2.0)
