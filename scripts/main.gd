extends Node2D

## Main game scene root.
## Phase 01: Verifies autoloads.
## Phase 02: World generation and rendering.
## Phase 03: Ship spawn, Camera2D follows ship (Camera lives inside Ship scene).
## Phase 05: PortSystem discovery + PortDebugHUD.

@onready var _world: Node2D = $World
@onready var _world_renderer: Node2D = $World/WorldRenderer

var _world_generator: Node
var _trader_traffic: Node2D
var _ship: Node2D
var _world_data: Dictionary = {}
var _is_new_game: bool = false
var _world_ready: bool = false
var startup_error: String = ""

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
var _market_distribution_system: Node = null
var _merchant_visit_system: Node = null
var _merchant_offer_hud: CanvasLayer = null
var _supply_order_system: Node = null
var _supply_order_window: CanvasLayer = null
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
	print("Sea Trader — Phase 05 World Rendering + Ports")
	assert(GameState != null, "GameState autoload missing")
	assert(EventBus != null, "EventBus autoload missing")
	assert(SaveSystem != null, "SaveSystem autoload missing")
	print("All autoloads verified.")

	get_tree().auto_accept_quit = false
	if not _initialize_world():
		var error_label := Label.new()
		error_label.text = startup_error + "\nSave files were not changed."
		add_child(error_label)
		return
	_spawn_ship()
	_initialize_port_systems()  # Phase 05
	_initialize_market_distribution()
	_initialize_ship_status_hud()
	_initialize_captain_cabinet()
	_initialize_map_status_hud()
	_initialize_port_window()
	_initialize_port_production_system()
	_initialize_merchant_visit_system()
	_initialize_merchant_offer_hud()
	_initialize_supply_orders()
	_initialize_navigation_hud()
	_initialize_career_system()
	_initialize_hiring_system()
	_initialize_crew_window()
	_initialize_fleet_system()
	_initialize_fleet_window()
	_initialize_shipyard()
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
		_port_system.initialize(_ship, _world_data.ports)
	else:
		push_warning("main.gd: _ship is null, PortSystem cannot track position")

	print("Phase 05: PortSystem initialized")


func _initialize_market_distribution() -> void:
	_market_distribution_system = load("res://systems/economy/market_distribution_system.gd").new()
	_market_distribution_system.name = "MarketDistributionSystem"
	add_child(_market_distribution_system)
	_market_distribution_system.initialize(_port_system)

func _initialize_ship_status_hud() -> void:
	_ship_status_hud = get_node_or_null("ShipStatusHUD")
	if _ship_status_hud == null:
		_ship_status_hud = load("res://systems/ui/ship_status_hud.gd").new()
		_ship_status_hud.name = "ShipStatusHUD"
		add_child(_ship_status_hud)

	_ship_status_hud.initialize(_port_system)


func _initialize_captain_cabinet() -> void:
	_captain_cabinet = load("res://systems/ui/captain_cabinet.gd").new()
	_captain_cabinet.name = "CaptainCabinet"
	add_child(_captain_cabinet)
	_captain_cabinet.initialize(_port_system)


func _initialize_map_status_hud() -> void:
	_map_status_hud = load("res://systems/ui/map_status_hud.gd").new()
	_map_status_hud.name = "MapStatusHUD"
	add_child(_map_status_hud)
	_map_status_hud.initialize(_port_system)


func _initialize_port_window() -> void:
	_port_window = load("res://systems/ui/port_window.gd").new()
	_port_window.name = "PortWindow"
	add_child(_port_window)
	_port_window.initialize(_port_system)


func _initialize_port_production_system() -> void:
	_port_production_system = load("res://systems/ports/port_production_system.gd").new()
	_port_production_system.name = "PortProductionSystem"
	add_child(_port_production_system)


func _initialize_merchant_visit_system() -> void:
	_merchant_visit_system = load("res://systems/economy/merchant_visit_system.gd").new()
	_merchant_visit_system.name = "MerchantVisitSystem"
	add_child(_merchant_visit_system)

func _initialize_merchant_offer_hud() -> void:
	_merchant_offer_hud = load("res://systems/ui/merchant_offer_hud.gd").new()
	_merchant_offer_hud.name = "MerchantOfferHUD"
	add_child(_merchant_offer_hud)
	_merchant_offer_hud.initialize(_merchant_visit_system)


func _initialize_supply_orders() -> void:
	_supply_order_system = load("res://systems/economy/supply_order_system.gd").new()
	_supply_order_system.name = "SupplyOrderSystem"
	add_child(_supply_order_system)
	_supply_order_system.initialize(_port_system)
	_supply_order_window = load("res://systems/ui/supply_order_window.gd").new()
	_supply_order_window.name = "SupplyOrderWindow"
	add_child(_supply_order_window)
	_supply_order_window.initialize(_supply_order_system)


func _initialize_navigation_hud() -> void:
	_navigation_hud = load("res://systems/ui/navigation_hud.gd").new()
	_navigation_hud.name = "NavigationHUD"
	add_child(_navigation_hud)
	_navigation_hud.initialize(_port_system)


func _initialize_career_system() -> void:
	_career_system = load("res://systems/progression/career_system.gd").new()
	_career_system.name = "CareerSystem"
	add_child(_career_system)

func _initialize_hiring_system() -> void:
	_hiring_system = load("res://systems/employees/hiring_system.gd").new()
	_hiring_system.name = "HiringSystem"
	add_child(_hiring_system)
	_hiring_system.initialize(_port_system)
	_hiring_window = load("res://systems/ui/hiring_window.gd").new()
	_hiring_window.name = "HiringWindow"
	add_child(_hiring_window)
	_hiring_window.initialize(_hiring_system)


func _initialize_crew_window() -> void:
	_crew_window = load("res://systems/ui/crew_window.gd").new()
	_crew_window.name = "CrewWindow"
	add_child(_crew_window)

func _initialize_fleet_system() -> void:
	_fleet_system = load("res://systems/fleet/fleet_system.gd").new()
	_fleet_system.name = "FleetSystem"
	add_child(_fleet_system)
	_fleet_system.initialize(_port_system)

func _initialize_fleet_window() -> void:
	_fleet_window = load("res://systems/ui/fleet_window.gd").new()
	_fleet_window.name = "FleetWindow"
	add_child(_fleet_window)
	_fleet_window.initialize(_fleet_system)

func _initialize_shipyard() -> void:
	_shipyard_system = load("res://systems/shipyard/shipyard_system.gd").new()
	_shipyard_system.name = "ShipyardSystem"
	add_child(_shipyard_system)
	_shipyard_system.initialize(_fleet_system)
	_shipyard_window = load("res://systems/ui/shipyard_window.gd").new()
	_shipyard_window.name = "ShipyardWindow"
	add_child(_shipyard_window)
	_shipyard_window.initialize(_shipyard_system)


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
