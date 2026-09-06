extends Node2D

# WorldRenderer — Phase 05
# Читает WorldState из GameState и рисует мир.
# НЕ трогает корабль, камеру, физику.
# Рисует: фон океана, острова, маркеры портов.
# Всё через draw_* в _draw() — без ColorRect и UI-узлов.

const OCEAN_COLOR  := Color(0.10, 0.28, 0.55, 1.0)
const ISLAND_COLOR := Color(0.25, 0.50, 0.18, 1.0)
const PORT_COLOR   := Color(1.00, 0.85, 0.00, 1.0)
const PORT_DISC_COLOR := Color(1.00, 1.00, 1.00, 1.0)

const WORLD_SIZE   := 4096.0
const ISLAND_RADIUS := 24.0
const PORT_RADIUS   := 10.0

# Кэш данных для _draw()
var _islands: Array = []
var _ports: Array   = []   # Array of {pos, name, discovered}


func _ready() -> void:
	z_index = -100   # гарантированно ниже корабля и всего остального
	render_world()

	if EventBus.has_signal("port_discovered"):
		EventBus.port_discovered.connect(_on_port_discovered)


# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

func render_world() -> void:
	_islands.clear()
	_ports.clear()

	# Острова
	var world_state = GameState.world_state
	if world_state != null:
		for island in world_state.get("islands", []):
			_islands.append({
				"pos": Vector2(island.get("x", 0.0), island.get("y", 0.0)),
				"radius": float(island.get("radius", ISLAND_RADIUS))
			})

	# Порты
	if GameState.port_state != null:
		for port_id in GameState.port_state:
			var p = GameState.port_state[port_id]
			_ports.append({
				"pos": Vector2(p.get("x", 0.0), p.get("y", 0.0)),
				"name": p.get("name", port_id),
				"discovered": p.get("discovered", false)
			})

	queue_redraw()


# ---------------------------------------------------------------------------
# Отрисовка
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Фон океана — большой прямоугольник позади всего
	var half := WORLD_SIZE / 2.0
	draw_rect(Rect2(-half, -half, WORLD_SIZE, WORLD_SIZE), OCEAN_COLOR)

	# Острова
	for island in _islands:
		draw_circle(island["pos"], island["radius"], ISLAND_COLOR)

	# Порты
	for port in _ports:
		var col := PORT_DISC_COLOR if port["discovered"] else PORT_COLOR
		draw_circle(port["pos"], PORT_RADIUS, col)


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_port_discovered(_port_id: String) -> void:
	# Обновляем данные и перерисовываем
	render_world()
