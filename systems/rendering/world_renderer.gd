extends Node2D

# WorldRenderer — Phase 05
# Читает данные из GameState и рисует мир через _draw().
# Острова: GameState.world_state["islands"] — поле "position" типа Vector2i
# Порты:   GameState.port_state — поля "x", "y" типа float

const OCEAN_COLOR  := Color(0.10, 0.28, 0.55, 1.0)
const ISLAND_COLOR := Color(0.25, 0.50, 0.18, 1.0)
const PORT_UNDISCOVERED_COLOR := Color(1.00, 0.85, 0.00, 0.6)
const PORT_DISCOVERED_COLOR   := Color(1.00, 1.00, 1.00, 1.0)

const WORLD_SIZE    := 4096.0
const ISLAND_RADIUS := 24.0
const PORT_RADIUS   := 10.0

var _islands: Array = []
var _ports: Array   = []


func _ready() -> void:
	z_index = -100
	if EventBus.has_signal("port_discovered"):
		EventBus.port_discovered.connect(_on_port_discovered)


func render_world() -> void:
	_islands.clear()
	_ports.clear()

	# Острова — поле "position" это Vector2i
	var islands_raw: Array = GameState.world_state.get("islands", [])
	for island in islands_raw:
		var pos: Vector2
		if island.has("position"):
			var p = island["position"]
			pos = Vector2(float(p.x), float(p.y))
		elif island.has("x"):
			pos = Vector2(float(island["x"]), float(island["y"]))
		else:
			continue
		_islands.append({
			"pos": pos,
			"radius": float(island.get("radius", ISLAND_RADIUS))
		})

	# Порты — поля "x", "y" (записаны в _apply_port_state в main.gd)
	for port_id in GameState.port_state:
		var p: Dictionary = GameState.port_state[port_id]
		_ports.append({
			"pos": Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))),
			"name": p.get("name", port_id),
			"discovered": p.get("discovered", false)
		})

	queue_redraw()


func _draw() -> void:
	var half := WORLD_SIZE / 2.0
	draw_rect(Rect2(-half, -half, WORLD_SIZE, WORLD_SIZE), OCEAN_COLOR)

	for island in _islands:
		draw_circle(island["pos"], island["radius"], ISLAND_COLOR)

	for port in _ports:
		var col := PORT_DISCOVERED_COLOR if port["discovered"] else PORT_UNDISCOVERED_COLOR
		draw_circle(port["pos"], PORT_RADIUS, col)


func _on_port_discovered(_port_id: String) -> void:
	render_world()
