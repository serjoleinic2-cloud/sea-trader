extends Node2D

## Main game scene root.
## Phase 01: Verifies autoloads.
## Phase 02: World generation and rendering.
## Phase 03: Ship spawn, Camera2D follows ship (Camera lives inside Ship scene).
## Phase 05: PortSystem discovery + PortDebugHUD.

@onready var _world: Node2D = $World
@onready var _world_renderer: Node2D = $World/WorldRenderer

var _world_generator: Node
var _ship: Node2D

# Phase 05
var _port_system: Node = null
var _port_debug_hud: CanvasLayer = null


func _ready() -> void:
	print("Sea Trader — Phase 05 World Rendering + Ports")
	assert(GameState != null, "GameState autoload missing")
	assert(EventBus != null, "EventBus autoload missing")
	assert(SaveSystem != null, "SaveSystem autoload missing")
	print("All autoloads verified.")

	_initialize_world()
	_spawn_ship()
	_initialize_port_systems()  # Phase 05


# ============================================================================
# World init (Phase 02, preserved)
# ============================================================================

func _initialize_world() -> void:
	var world_seed: int = _get_or_create_seed()
	GameState.world_state.seed = world_seed
	print("World seed: %d" % world_seed)

	_world_generator = preload("res://systems/world/world_generator.gd").new()
	var world_data: Dictionary = _world_generator.generate(world_seed)

	GameState.world_state.current_position = Vector2(
		world_data.world_size.x / 2.0,
		world_data.world_size.y / 2.0
	)
	GameState.world_state.current_region = "starting_region"

	# Phase 05: port_state заполняем только для новой игры
	# При загрузке — уже восстановлен из SaveSystem.load_game()
	if not SaveSystem.has_save() or GameState.port_state.is_empty():
		_apply_port_state(world_data)

	if _world_renderer.has_method("setup"):
		_world_renderer.setup(world_data)
	if _world_renderer.has_method("set_camera"):
		_world_renderer.set_camera(null)

	print("World generated: %d islands, %d ports, %d hazard zones" % [
		world_data.islands.size(),
		world_data.ports.size(),
		world_data.hazard_zones.size()
	])


func _get_or_create_seed() -> int:
	if SaveSystem.has_save():
		var loaded: bool = SaveSystem.load_game()
		if loaded and GameState.world_state.seed != 0:
			print("Loaded existing seed: %d" % GameState.world_state.seed)
			return GameState.world_state.seed

	var new_seed: int = int(Time.get_unix_time_from_system()) + randi()
	GameState.reset_to_defaults()
	GameState.world_state.seed = new_seed
	return new_seed


# Phase 05: записываем port_state из world_data в формате x/y
func _apply_port_state(world_data: Dictionary) -> void:
	GameState.port_state.clear()
	for port_id in world_data.ports:
		var p: Dictionary = world_data.ports[port_id]
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
	print("Phase 05: port_state populated with %d ports" % GameState.port_state.size())


# ============================================================================
# Ship spawn (Phase 03, preserved)
# ============================================================================

func _spawn_ship() -> void:
	var ship_scene: PackedScene = preload("res://scenes/game/ship/ship.tscn")
	_ship = ship_scene.instantiate()
	add_child(_ship)

	var old_cam: Node = get_node_or_null("Camera2D")
	if old_cam != null:
		old_cam.enabled = false

	print("Ship spawned at: %s" % str(GameState.ship_state.get("position", Vector2.ZERO)))


# ============================================================================
# Phase 05: PortSystem + PortDebugHUD
# ============================================================================

func _initialize_port_systems() -> void:
	# PortSystem
	_port_system = get_node_or_null("PortSystem")
	if _port_system == null:
		_port_system = load("res://systems/ports/port_system.gd").new()
		_port_system.name = "PortSystem"
		add_child(_port_system)

	if _ship != null:
		_port_system.initialize(_ship)
	else:
		push_warning("main.gd: _ship is null, PortSystem cannot track position")

	# PortDebugHUD
	_port_debug_hud = get_node_or_null("PortDebugHUD")
	if _port_debug_hud == null:
		_port_debug_hud = load("res://systems/ports/port_debug_hud.gd").new()
		_port_debug_hud.name = "PortDebugHUD"
		add_child(_port_debug_hud)

	_port_debug_hud.initialize(_port_system)
	print("Phase 05: PortSystem and PortDebugHUD initialized")


# ============================================================================
# Input (Phase 03, preserved)
# ============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_EQUAL:
				var cam: Camera2D = _get_ship_camera()
				if cam:
					cam.zoom += Vector2(0.05, 0.05)
			KEY_MINUS:
				var cam: Camera2D = _get_ship_camera()
				if cam:
					cam.zoom = (cam.zoom - Vector2(0.05, 0.05)).clamp(
						Vector2(0.05, 0.05), Vector2(2.0, 2.0)
					)


func _get_ship_camera() -> Camera2D:
	if _ship == null:
		return null
	return _ship.get_node_or_null("Camera2D")
