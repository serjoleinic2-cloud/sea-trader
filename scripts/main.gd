extends Node

# main.gd — Phase 05
# Вызывает WorldGenerator, записывает результат в GameState,
# затем инициализирует WorldRenderer и PortSystem.

var world_renderer: Node2D      = null
var port_system: Node           = null
var port_debug_hud: CanvasLayer = null
var ship_node: Node2D           = null

# WorldGenerator — ищем как дочерний узел или в autoloads
var _world_gen = null


func _ready() -> void:
	_find_world_generator()
	_find_or_create_systems()
	_boot()


func _boot() -> void:
	if SaveSystem.has_save():
		SaveSystem.load_game()
		# Мир восстанавливается из сохранения — не перегенерируем port_state
		# Но геометрию (острова) можно перегенерировать из seed для рендеринга
		if _world_gen != null and GameState.world_state.get("seed", 0) != 0:
			var world_data: Dictionary = _world_gen.generate(GameState.world_state["seed"])
			_apply_world_geometry(world_data)
			# port_state НЕ перезаписываем — загружен из сохранения
	else:
		# Новая игра
		var new_seed: int = randi()
		GameState.world_state["seed"] = new_seed

		if _world_gen != null:
			var world_data: Dictionary = _world_gen.generate(new_seed)
			_apply_world_geometry(world_data)
			_apply_port_state(world_data)  # только для новой игры
		
		SaveSystem.save_game()

	if world_renderer != null:
		world_renderer.render_world()

	if port_system != null and ship_node != null:
		port_system.initialize(ship_node)

	if port_debug_hud != null and port_system != null:
		port_debug_hud.initialize(port_system)


# ---------------------------------------------------------------------------
# Применить геометрию мира (острова) — для рендеринга
# НЕ трогает port_state
# ---------------------------------------------------------------------------
func _apply_world_geometry(world_data: Dictionary) -> void:
	# Сохраняем острова в world_state для рендерера
	GameState.world_state["islands"] = world_data.get("islands", [])


# ---------------------------------------------------------------------------
# Применить порты в port_state — ТОЛЬКО для новой игры
# ---------------------------------------------------------------------------
func _apply_port_state(world_data: Dictionary) -> void:
	var ports: Dictionary = world_data.get("ports", {})
	GameState.port_state.clear()
	for port_id in ports:
		var p = ports[port_id]
		var pos = p.get("position", Vector2i.ZERO)
		GameState.port_state[port_id] = {
			"id": port_id,
			"name": p.get("name", port_id),
			"x": float(pos.x),
			"y": float(pos.y),
			"discovered": false,
			"discovery_radius": 150.0,
			"region": p.get("region", ""),
			"level": p.get("level", 1)
		}


# ---------------------------------------------------------------------------
# Поиск WorldGenerator
# ---------------------------------------------------------------------------
func _find_world_generator() -> void:
	# Сначала как autoload
	if Engine.has_singleton("WorldGenerator"):
		_world_gen = Engine.get_singleton("WorldGenerator")
		return
	# Потом как дочерний узел
	_world_gen = get_node_or_null("WorldGenerator")
	if _world_gen != null:
		return
	# Потом ищем среди детей по имени скрипта
	for child in get_children():
		if child.get_script() != null:
			var path: String = child.get_script().resource_path
			if "world_generator" in path.to_lower():
				_world_gen = child
				return
	# Создаём динамически
	var script = load("res://systems/world/world_generator.gd")
	if script == null:
		# Пробуем альтернативный путь
		script = load("res://core/world_generator.gd")
	if script != null:
		_world_gen = script.new()
		_world_gen.name = "WorldGenerator"
		add_child(_world_gen)
	else:
		push_error("main.gd: WorldGenerator script not found. Ports and islands will be empty.")


# ---------------------------------------------------------------------------
# Поиск и создание систем Phase 05
# ---------------------------------------------------------------------------
func _find_or_create_systems() -> void:
	ship_node = _find_ship()

	world_renderer = get_node_or_null("WorldRenderer")
	if world_renderer == null:
		world_renderer = load("res://systems/rendering/world_renderer.gd").new()
		world_renderer.name = "WorldRenderer"
		add_child(world_renderer)
		move_child(world_renderer, 0)

	port_system = get_node_or_null("PortSystem")
	if port_system == null:
		port_system = load("res://systems/ports/port_system.gd").new()
		port_system.name = "PortSystem"
		add_child(port_system)

	port_debug_hud = get_node_or_null("PortDebugHUD")
	if port_debug_hud == null:
		port_debug_hud = load("res://systems/ports/port_debug_hud.gd").new()
		port_debug_hud.name = "PortDebugHUD"
		add_child(port_debug_hud)


func _find_ship() -> Node2D:
	for ship_name in ["Ship", "ship", "ShipNode", "Player", "PlayerShip"]:
		var n = get_node_or_null(ship_name)
		if n != null and n is Node2D:
			return n
	for child in get_children():
		if child is CharacterBody2D or child is RigidBody2D:
			return child as Node2D
	push_warning("main.gd Phase05: Ship node not found.")
	return null
