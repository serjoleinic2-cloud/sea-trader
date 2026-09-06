extends Node2D

# WorldRenderer — Phase 05
# Отображает мир (океан, острова, порты) на основе WorldState.
# Не генерирует мир — только читает из GameState и рисует.

const ISLAND_COLOR := Color(0.3, 0.55, 0.2)       # placeholder зелёный
const PORT_COLOR   := Color(1.0, 0.85, 0.0)        # placeholder жёлтый
const OCEAN_COLOR  := Color(0.1, 0.3, 0.6)         # placeholder синий

const ISLAND_RADIUS := 24.0
const PORT_RADIUS   := 10.0
const PORT_LABEL_OFFSET := Vector2(12, -14)

var _island_nodes: Array = []
var _port_nodes: Array   = []
var _background: ColorRect = null

func _ready() -> void:
	_draw_ocean()
	render_world()
	# Подписываемся на обновление discovery портов
	if EventBus.has_signal("port_discovered"):
		EventBus.port_discovered.connect(_on_port_discovered)


# ---------------------------------------------------------------------------
# Публичный API
# ---------------------------------------------------------------------------

func render_world() -> void:
	_clear_nodes()
	_draw_islands()
	_draw_ports()


# ---------------------------------------------------------------------------
# Внутренние методы
# ---------------------------------------------------------------------------

func _draw_ocean() -> void:
	# Простой цветной фон размером с мир
	_background = ColorRect.new()
	var world_size: float = 4096.0
	_background.color = OCEAN_COLOR
	_background.size = Vector2(world_size, world_size)
	_background.position = Vector2(-world_size / 2.0, -world_size / 2.0)
	_background.z_index = -10
	add_child(_background)


func _draw_islands() -> void:
	var world_state = GameState.world_state
	if world_state == null:
		return
	var islands = world_state.get("islands", [])
	for island in islands:
		var node := _make_circle_node(
			Vector2(island.get("x", 0.0), island.get("y", 0.0)),
			island.get("radius", ISLAND_RADIUS),
			ISLAND_COLOR,
			-1
		)
		add_child(node)
		_island_nodes.append(node)


func _draw_ports() -> void:
	var port_state = GameState.port_state
	if port_state == null:
		return
	for port_id in port_state:
		var port = port_state[port_id]
		_create_port_node(port_id, port)


func _create_port_node(port_id: String, port: Dictionary) -> void:
	var pos := Vector2(port.get("x", 0.0), port.get("y", 0.0))
	var discovered: bool = port.get("discovered", false)

	# Маркер порта
	var marker := _make_circle_node(pos, PORT_RADIUS, PORT_COLOR, 0)
	marker.name = "port_marker_" + port_id
	add_child(marker)
	_port_nodes.append(marker)

	# Название порта (всегда видно после обнаружения)
	if discovered:
		_add_port_label(marker, port.get("name", port_id))


func _add_port_label(parent: Node2D, port_name: String) -> void:
	var lbl := Label.new()
	lbl.text = port_name
	lbl.position = PORT_LABEL_OFFSET
	lbl.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(lbl)


func _make_circle_node(pos: Vector2, radius: float, color: Color, z: int) -> Node2D:
	var node := Node2D.new()
	node.position = pos
	node.z_index = z

	# Рисуем через скрипт — простой DrawCircle через _draw
	var draw_node := _CircleDrawer.new()
	draw_node.radius = radius
	draw_node.color = color
	node.add_child(draw_node)
	return node


func _clear_nodes() -> void:
	for n in _island_nodes:
		if is_instance_valid(n):
			n.queue_free()
	for n in _port_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_island_nodes.clear()
	_port_nodes.clear()


# ---------------------------------------------------------------------------
# Callbacks
# ---------------------------------------------------------------------------

func _on_port_discovered(port_id: String) -> void:
	# Перерисовываем только порты чтобы добавить лейбл
	for node in _port_nodes:
		if is_instance_valid(node) and node.name == "port_marker_" + port_id:
			var port = GameState.port_state.get(port_id, {})
			_add_port_label(node, port.get("name", port_id))
			break


# ---------------------------------------------------------------------------
# Внутренний вспомогательный класс для отрисовки кружков
# ---------------------------------------------------------------------------

class _CircleDrawer:
	extends Node2D
	var radius: float = 16.0
	var color: Color = Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
