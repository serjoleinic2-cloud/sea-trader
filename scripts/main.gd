extends Node

# main.gd — Phase 05
# ВАЖНО: WorldRenderer и PortSystem добавляются динамически если не найдены в сцене.
# Это значит файл работает даже если узлы ещё не добавлены в main.tscn вручную.

var world_renderer: Node2D = null
var port_system: Node      = null
var port_debug_hud: CanvasLayer = null
var ship_node: Node2D      = null


func _ready() -> void:
	_find_or_create_systems()
	_boot()


func _boot() -> void:
	if SaveSystem.has_save():
		SaveSystem.load_game()
	else:
		if GameState.world_state.get("seed", 0) == 0:
			GameState.world_state["seed"] = randi()
		SaveSystem.save_game()

	if world_renderer != null:
		world_renderer.render_world()

	if port_system != null and ship_node != null:
		port_system.initialize(ship_node)

	if port_debug_hud != null and port_system != null:
		port_debug_hud.initialize(port_system)


# ---------------------------------------------------------------------------
# Поиск узлов — сначала в сцене, иначе создаём динамически
# ---------------------------------------------------------------------------

func _find_or_create_systems() -> void:
	# Корабль — ищем по типичным именам Phase 03
	ship_node = _find_ship()

	# WorldRenderer
	world_renderer = get_node_or_null("WorldRenderer")
	if world_renderer == null:
		world_renderer = load("res://systems/rendering/world_renderer.gd").new()
		world_renderer.name = "WorldRenderer"
		add_child(world_renderer)
		# Переместить ниже корабля по дереву (первым дочерним)
		move_child(world_renderer, 0)

	# PortSystem
	port_system = get_node_or_null("PortSystem")
	if port_system == null:
		port_system = load("res://systems/ports/port_system.gd").new()
		port_system.name = "PortSystem"
		add_child(port_system)

	# PortDebugHUD
	port_debug_hud = get_node_or_null("PortDebugHUD")
	if port_debug_hud == null:
		port_debug_hud = load("res://systems/ports/port_debug_hud.gd").new()
		port_debug_hud.name = "PortDebugHUD"
		add_child(port_debug_hud)


func _find_ship() -> Node2D:
	# Пробуем типичные имена из Phase 03
	for name in ["Ship", "ship", "ShipNode", "Player", "PlayerShip"]:
		var n = get_node_or_null(name)
		if n != null and n is Node2D:
			return n
	# Ищем в детях по типу CharacterBody2D / RigidBody2D
	for child in get_children():
		if child is CharacterBody2D or child is RigidBody2D:
			return child as Node2D
	push_warning("main.gd Phase05: Ship node not found. PortSystem will not track position.")
	return null
