extends Node2D

## Main game scene root.
## Owns world identity and scene lifecycle. Modules are declared in data/config/game_modules.json.

@onready var _world: Node2D = $World
@onready var _world_renderer: Node2D = $World/WorldRenderer

var _world_generator: Node
var _trader_traffic: Node2D
var _fleet_traffic: Node2D
var _ship: Node2D
var _approach_view: Node
var _world_data: Dictionary = {}
var _is_new_game: bool = false
var _world_migrated: bool = false
var _world_ready: bool = false
var startup_error: String = ""
var _modules: RefCounted = preload("res://core/module_loader.gd").new()

const CAMERA_ZOOM_STEP: float = 0.08
const CAMERA_ZOOM_MIN: float = 0.15
const CAMERA_ZOOM_MAX: float = 2.0
var _chunk_size: float = 4096.0
var _loaded_chunks: Dictionary = {}
var _last_stream_center: Vector2i = Vector2i(2147483647, 2147483647)

# Phase 05
var _port_system: Node = null
var _ship_status_hud: CanvasLayer = null
var _captain_cabinet: CanvasLayer = null
var _map_status_hud: CanvasLayer = null
var _port_window: CanvasLayer = null
var _port_production_system: Node = null
var _building_project_system: Node = null
var _building_project_window: CanvasLayer = null
var _market_distribution_system: Node = null
var _merchant_visit_system: Node = null
var _merchant_offer_hud: CanvasLayer = null
var _supply_order_system: Node = null
var _supply_order_window: CanvasLayer = null
var _port_service_system: Node = null
var _port_service_window: CanvasLayer = null
var _world_event_system: Node = null
var _world_event_hud: CanvasLayer = null
var _work_hire_system: Node = null
var _work_hire_window: CanvasLayer = null
var _logistics_system: Node = null
var _logistics_window: CanvasLayer = null
var _trade_line_system: Node = null
var _trade_line_window: CanvasLayer = null
var _active_route_autopilot: Node = null
var _navigation_hud: CanvasLayer = null
var _hiring_system: Node = null
var _hiring_window: CanvasLayer = null
var _crew_window: CanvasLayer = null
var _career_system: Node = null
var _fleet_system: Node = null
var _fleet_window: CanvasLayer = null
var _shipyard_system: Node = null
var _shipyard_window: CanvasLayer = null


func _process(_delta: float) -> void:
	if _world_ready:
		_ensure_streamed_world()

func _ensure_streamed_world() -> void:
	if _world_generator == null or _world_data.is_empty():
		return
	var ship_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var center := Vector2i(
		floori(ship_position.x / _chunk_size),
		floori(ship_position.y / _chunk_size)
	)
	if center == _last_stream_center:
		return
	_last_stream_center = center
	var changed: bool = false
	for chunk_y in range(center.y - 1, center.y + 2):
		for chunk_x in range(center.x - 1, center.x + 2):
			if _load_stream_chunk(Vector2i(chunk_x, chunk_y)):
				changed = true
	if not changed:
		return
	if _approach_view != null and _approach_view.has_method("sync_generated_world"):
		_approach_view.call("sync_generated_world", _world_data)
	if _active_route_autopilot != null and _active_route_autopilot.has_method("set_hazard_zones"):
		_active_route_autopilot.call("set_hazard_zones", _world_data.get("hazard_zones", []))
	if _fleet_system != null and _fleet_system.has_method("set_hazard_zones"):
		_fleet_system.call("set_hazard_zones", _world_data.get("hazard_zones", []))
	if _world_event_system != null and _world_event_system.has_method("set_world_data"):
		_world_event_system.call("set_world_data", _world_data)

func _load_stream_chunk(coordinate: Vector2i, requested_generation_version: int = -1) -> bool:
	var key: String = "%d:%d" % [coordinate.x, coordinate.y]
	if coordinate == Vector2i.ZERO or _loaded_chunks.has(key):
		return false
	var current_generation_version: int = int(GameData.read("res://data/world/world_gen_config.json").get("streaming", {}).get("version", 1))
	var generation_version: int = requested_generation_version if requested_generation_version > 0 else current_generation_version
	var chunk: Dictionary = _world_generator.call(
		"generate_chunk", int(GameState.world_state.get("seed", 0)), coordinate, generation_version
	)
	if chunk.is_empty():
		return false
	_loaded_chunks[key] = true
	var islands: Array = _world_data.get("islands", [])
	islands.append_array(chunk.get("islands", []))
	_world_data["islands"] = islands
	var hazards: Array = _world_data.get("hazard_zones", [])
	hazards.append_array(chunk.get("hazard_zones", []))
	_world_data["hazard_zones"] = hazards
	var ports: Dictionary = chunk.get("ports", {})
	var all_ports: Dictionary = _world_data.get("ports", {})
	all_ports.merge(ports, true)
	_world_data["ports"] = all_ports
	if _port_system != null and _port_system.has_method("register_world_ports"):
		_port_system.call("register_world_ports", ports)
	return true

func _ready() -> void:
	print("Sea Trader — modular runtime")
	assert(GameState != null, "GameState autoload missing")
	assert(EventBus != null, "EventBus autoload missing")
	assert(SaveSystem != null, "SaveSystem autoload missing")
	print("All autoloads verified.")

	get_tree().auto_accept_quit = false
	var config_errors: Array[String] = GameData.validate()
	if not config_errors.is_empty():
		_show_startup_error("Ошибка конфигурации:\n" + "\n".join(config_errors))
		return
	var manifest: Dictionary = GameData.read("res://data/config/game_modules.json")
	if not manifest.get("modules") is Array or manifest.modules.is_empty():
		_show_startup_error("Пустой или неверный список модулей.")
		return
	var prepared: Dictionary = _modules.prepare(manifest.modules)
	if not bool(prepared.get("ok", false)):
		_show_startup_error(str(prepared.get("message", "")))
		return
	if not _initialize_world():
		_show_startup_error(startup_error)
		return
	var saved_ship_id: String = str(GameState.ship_state.get("ship_id", ""))
	if saved_ship_id != "" and GameData.get_ship(saved_ship_id).is_empty():
		_show_startup_error("В каталоге нет сохранённого корабля: " + saved_ship_id)
		return
	_spawn_ship()
	_approach_view = load("res://systems/rendering/approach_3d_view.gd").new()
	_approach_view.name = "Approach3DView"
	add_child(_approach_view)
	_approach_view.call("initialize", _world_data, _world_renderer, _ship, _trader_traffic, _fleet_traffic)
	_modules.start(self, {"$ship": _ship, "$ports": _world_data.ports, "$main": self})
	if _active_route_autopilot != null and _active_route_autopilot.has_method("set_hazard_zones"):
		_active_route_autopilot.call("set_hazard_zones", _world_data.get("hazard_zones", []))
	if _fleet_system != null and _fleet_system.has_method("set_hazard_zones"):
		_fleet_system.call("set_hazard_zones", _world_data.get("hazard_zones", []))
	if _world_event_system != null and _world_event_system.has_method("initialize"):
		_world_event_system.call("initialize", _ship, _world_data)
	var window_coordinator: Node = load("res://systems/ui/window_coordinator.gd").new()
	window_coordinator.name = "WindowCoordinator"
	add_child(window_coordinator)
	window_coordinator.initialize(self)
	_world_ready = true
	if _is_new_game or _world_migrated:
		SaveSystem.save_game()


# ============================================================================
# World init (Phase 02, preserved)
# ============================================================================

func _initialize_world() -> bool:
	if not _load_or_create_state():
		return false
	var world_seed: int = int(GameState.world_state.seed)
	print("World seed: %d" % world_seed)

	_world_generator = preload("res://systems/world/world_generator.gd").new()
	add_child(_world_generator)
	var generation_version: String = _world_generator.get_generation_version()
	if _is_new_game:
		GameState.world_state.world_gen_version = generation_version
		_world_data = _world_generator.generate(world_seed, int(generation_version))
	else:
		var saved_version: String = str(GameState.world_state.get("world_gen_version", "1"))
		if saved_version == "":
			saved_version = "1"
		if not _world_generator.supports_generation_version(saved_version):
			startup_error = "World generation version is unsupported. Loading stopped."
			return false
		if saved_version != generation_version:
			var migration: Dictionary = _world_generator.migrate_world_to_current(
				world_seed,
				int(saved_version),
				Vector2(GameState.ship_state.get("position", Vector2.ZERO))
			)
			if not bool(migration.get("ok", false)):
				startup_error = str(migration.get("message", "Не удалось перенести карту."))
				return false
			_world_data = migration.get("world_data", {})
			var migrated_ship_position: Vector2 = Vector2(migration.get("ship_position", Vector2.ZERO))
			var docked_port_id: String = str(GameState.ship_state.get("docked_port_id", ""))
			if docked_port_id != "" and _world_data.ports.has(docked_port_id):
				migrated_ship_position = Vector2(_world_data.ports[docked_port_id].get("position", migrated_ship_position))
			GameState.ship_state["position"] = migrated_ship_position
			GameState.world_state["current_position"] = GameState.ship_state.position
			GameState.world_state["current_region"] = _world_generator.get_region_for_position(GameState.ship_state.position)
			GameState.world_state["world_gen_version"] = generation_version
			_world_migrated = true
			_migrate_known_route_distances(_world_data.ports)
		else:
			_world_data = _world_generator.generate(world_seed, int(saved_version))
	var world_data: Dictionary = _world_data
	_chunk_size = float(world_data.get("chunk_size", 4096.0))
	_loaded_chunks.clear()
	_loaded_chunks["0:0"] = true
	if not GameState.world_state.has("chunk_generation_version"):
		GameState.world_state["chunk_generation_version"] = 1
	var saved_chunks: Variant = GameState.world_state.get("known_port_chunks", [])
	if saved_chunks is Array:
		for raw_key in saved_chunks:
			var coordinates: PackedStringArray = str(raw_key).split(":")
			if coordinates.size() >= 2:
				var saved_chunk_version: int = int(coordinates[2]) if coordinates.size() >= 3 else 1
				_load_stream_chunk(Vector2i(int(coordinates[0]), int(coordinates[1])), saved_chunk_version)

	if _is_new_game:
		GameState.ship_state.position = Vector2(world_data.world_size) * 0.25
		GameState.world_state.current_position = GameState.ship_state.position
		GameState.world_state.current_region = "starting_region"
	# PortState is player knowledge, including a legitimately empty saved map.
	# Generated port geometry is handed to consumers, never copied over progress.

	if _world_renderer.has_method("setup"):
		_world_renderer.setup(world_data)
	_initialize_trader_traffic(world_data)
	_initialize_fleet_traffic(world_data)
	if _world_renderer.has_method("set_camera"):
		_world_renderer.set_camera(null)

	print("World generated: %d islands, %d ports, %d hazard zones" % [
		world_data.islands.size(),
		world_data.ports.size(),
		world_data.hazard_zones.size()
	])
	return true


func _migrate_known_route_distances(ports: Dictionary) -> void:
	for route_key in GameState.known_routes_state:
		var route: Dictionary = GameState.known_routes_state[route_key]
		var port_a: Dictionary = ports.get(str(route.get("port_a_id", "")), {})
		var port_b: Dictionary = ports.get(str(route.get("port_b_id", "")), {})
		if port_a.is_empty() or port_b.is_empty():
			continue
		route["distance"] = Vector2(port_a.get("position", Vector2.ZERO)).distance_to(Vector2(port_b.get("position", Vector2.ZERO)))
		GameState.known_routes_state[route_key] = route


func _initialize_trader_traffic(world_data: Dictionary) -> void:
	_trader_traffic = load("res://systems/world/trader_traffic_renderer.gd").new()
	_trader_traffic.name = "TraderTraffic"
	_world.add_child(_trader_traffic)
	_trader_traffic.initialize(world_data)

func _initialize_fleet_traffic(world_data: Dictionary) -> void:
	_fleet_traffic = load("res://systems/world/fleet_traffic_renderer.gd").new()
	_fleet_traffic.name = "FleetTraffic"
	_world.add_child(_fleet_traffic)
	_fleet_traffic.initialize(world_data)

func _load_or_create_state() -> bool:
	_is_new_game = false
	if SaveSystem.has_save():
		if not SaveSystem.load_game():
			startup_error = "Cannot load saved game. Loading stopped."
			return false
		return true  # Zero is also a valid saved seed.

	var new_seed: int = int(Time.get_unix_time_from_system()) + randi()
	GameState.reset_to_defaults()
	GameState.world_state.seed = new_seed
	_is_new_game = true
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _world_ready and not SaveSystem.save_game():
			push_error("Could not save game. Close cancelled; retry when storage is available.")
			return
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()


# ============================================================================
# Ship spawn (Phase 03, preserved)
# ============================================================================

func _spawn_ship() -> void:
	var ship_scene: PackedScene = preload("res://scenes/game/ship/ship.tscn")
	_ship = ship_scene.instantiate()
	add_child(_ship)
	if _ship.has_method("set_navigation_collision_provider"):
		_ship.call("set_navigation_collision_provider", Callable(self, "_get_navigation_collision_data"))

	var old_cam: Node = get_node_or_null("Camera2D")
	if old_cam != null:
		old_cam.enabled = false

	print("Ship spawned at: %s" % str(GameState.ship_state.get("position", Vector2.ZERO)))



func _get_navigation_collision_data() -> Dictionary:
	var vessels: Array[Dictionary] = []
	for renderer in [_trader_traffic, _fleet_traffic]:
		if renderer != null and renderer.has_method("get_vessel_snapshots"):
			var snapshots: Array = renderer.call("get_vessel_snapshots")
			for snapshot in snapshots:
				if snapshot is Dictionary:
					vessels.append(snapshot)
	return {"islands": _world_data.get("islands", []), "vessels": vessels}

func get_module(module_id: String) -> Node:
	return _modules.services.get(module_id)

func _show_startup_error(message: String) -> void:
	startup_error = message
	var label: Label = Label.new()
	label.text = message + "\nСохранения не изменены."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(900, 600)
	add_child(label)


# ============================================================================
# Input (Phase 03, preserved)
# ============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			_handle_dock_key()
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_EQUAL:
				_zoom_ship_camera(CAMERA_ZOOM_STEP)
			KEY_MINUS:
				_zoom_ship_camera(-CAMERA_ZOOM_STEP)

	if event is InputEventMouseButton and event.pressed:
		if get_viewport().gui_get_hovered_control() != null:
			return # Let scroll containers consume wheel input over UI.
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_ship_camera(CAMERA_ZOOM_STEP)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_ship_camera(-CAMERA_ZOOM_STEP)
				get_viewport().set_input_as_handled()


func _handle_dock_key() -> void:
	if _port_system == null:
		return
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_port_system.undock()
		return
	var candidate: String = str(_port_system.get_dock_candidate())
	if candidate != "":
		_port_system.dock(candidate)


func _zoom_ship_camera(delta: float) -> void:
	var cam: Camera2D = _get_ship_camera()
	if cam == null:
		return
	var next_zoom: float = clamp(cam.zoom.x + delta, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	cam.zoom = Vector2(next_zoom, next_zoom)


func _get_ship_camera() -> Camera2D:
	if _ship == null:
		return null
	return _ship.get_node_or_null("Camera2D")
