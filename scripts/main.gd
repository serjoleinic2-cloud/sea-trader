extends Node2D

## Main game scene root.
## Phase 01: Verifies autoloads.
## Phase 02: World generation and rendering.
## Phase 03: Ship spawn, Camera2D follows ship (Camera lives inside Ship scene).

@onready var _world: Node2D = $World
@onready var _world_renderer: Node2D = $World/WorldRenderer

var _world_generator: Node
var _ship: Node2D

func _ready() -> void:
	print("Sea Trader — Phase 03 Ship Physics")
	assert(GameState != null, "GameState autoload missing")
	assert(EventBus != null, "EventBus autoload missing")
	assert(SaveSystem != null, "SaveSystem autoload missing")
	print("All autoloads verified.")

	_initialize_world()
	_spawn_ship()


# ============================================================================
# World init (unchanged from Phase 02)
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
	GameState.port_state = world_data.ports.duplicate(true)

	if _world_renderer.has_method("setup"):
		_world_renderer.setup(world_data)

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
	print("Created new seed: %d" % new_seed)
	return new_seed


# ============================================================================
# Ship spawn (Phase 03)
# ============================================================================

func _spawn_ship() -> void:
	var ship_scene: PackedScene = preload("res://scenes/game/ship/ship.tscn")
	_ship = ship_scene.instantiate()
	add_child(_ship)

	# Camera2D is now inside Ship — no separate top-level camera needed.
	# Remove or disable the old debug Camera2D if it exists.
	var old_cam: Node = get_node_or_null("Camera2D")
	if old_cam != null:
		old_cam.enabled = false

	print("Ship spawned at: %s" % str(GameState.ship_state.get("position", Vector2.ZERO)))


# ============================================================================
# Input — Phase 02 debug camera kept for reference but disabled when ship active
# ============================================================================

func _input(event: InputEvent) -> void:
	# Phase 02 camera controls removed — Camera2D is now inside Ship.
	# Zoom shortcut kept for debug convenience.
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
