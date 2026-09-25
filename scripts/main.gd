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
var _world_ready: bool = false
var startup_error: String = ""
var _modules: RefCounted = preload("res://core/module_loader.gd").new()

const CAMERA_ZOOM_STEP: float = 0.08
const CAMERA_ZOOM_MIN: float = 0.15
const CAMERA_ZOOM_MAX: float = 2.0

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
	_approach_view.call("initialize", _world_data)
	_modules.start(self, {"$ship": _ship, "$ports": _world_data.ports, "$main": self})
	var window_coordinator: Node = load("res://systems/ui/window_coordinator.gd").new()
	window_coordinator.name = "WindowCoordinator"
	add_child(window_coordinator)
	window_coordinator.initialize(self)
	_world_ready = true
	if _is_new_game:
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
	elif GameState.world_state.get("world_gen_version", "") != generation_version:
		startup_error = "World generation version is unsupported. Loading stopped."
		return false
	var world_data: Dictionary = _world_generator.generate(world_seed)
	_world_data = world_data

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

	var old_cam: Node = get_node_or_null("Camera2D")
	if old_cam != null:
		old_cam.enabled = false

	print("Ship spawned at: %s" % str(GameState.ship_state.get("position", Vector2.ZERO)))


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
