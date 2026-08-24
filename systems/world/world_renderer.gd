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
	# ID label (small)
	draw_string(
		ThemeDB.fallback_font,
		pos + Vector2(-20, 5),
		island.id,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		12,
		Color("ffffff", 0.5)
	)


func _draw_port(port: Dictionary) -> void:
	var pos: Vector2 = Vector2(port.position)
	var radius: float = 12.0
	# Port circle
	draw_circle(pos, radius, port_color)
	draw_arc(pos, radius, 0.0, TAU, 16, port_border_color, 2.0)
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
