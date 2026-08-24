extends Node2D

## Main game scene root.
## Phase 01: Verifies autoloads are present.
## Phase 02: Initializes world generation and rendering.

@onready var _camera: Camera2D = $Camera2D
@onready var _world: Node2D = $World
@onready var _world_renderer: Node2D = $World/WorldRenderer

var _world_generator: Node

func _ready() -> void:
	print("Sea Trader -- Phase 02 World Generation")
	assert(GameState != null, "GameState autoload missing")
	assert(EventBus != null, "EventBus autoload missing")
	assert(SaveSystem != null, "SaveSystem autoload missing")
	print("All autoloads verified.")

	# Initialize world
	_initialize_world()


func _initialize_world() -> void:
	# Load or create world seed
	var world_seed: int = _get_or_create_seed()
	GameState.world_state.seed = world_seed
	print("World seed: %d" % world_seed)

	# Generate world
	_world_generator = preload("res://systems/world/world_generator.gd").new()
	var world_data: Dictionary = _world_generator.generate(world_seed)

	# Store in GameState
	GameState.world_state.current_position = Vector2(
		world_data.world_size.x / 2.0,
		world_data.world_size.y / 2.0
	)
	GameState.world_state.current_region = "starting_region"
	GameState.port_state = world_data.ports.duplicate(true)

	# Setup camera
	_camera.position = GameState.world_state.current_position
	_camera.zoom = Vector2(0.25, 0.25)

	# Setup world renderer
	if _world_renderer.has_method("setup"):
		_world_renderer.setup(world_data)
	if _world_renderer.has_method("set_camera"):
		_world_renderer.set_camera(_camera)

	print("World generated: %d islands, %d ports, %d hazard zones" % [
		world_data.islands.size(),
		world_data.ports.size(),
		world_data.hazard_zones.size()
	])


func _get_or_create_seed() -> int:
	# If save exists and has seed, use it
	if SaveSystem.has_save():
		var loaded: bool = SaveSystem.load_game()
		if loaded and GameState.world_state.seed != 0:
			print("Loaded existing seed: %d" % GameState.world_state.seed)
			return GameState.world_state.seed

	# Generate new seed
	var new_seed: int = int(Time.get_unix_time_from_system()) + randi()
	GameState.reset_to_defaults()
	GameState.world_state.seed = new_seed
	print("Created new seed: %d" % new_seed)
	return new_seed


func _input(event: InputEvent) -> void:
	# Debug camera controls (keyboard only, for Phase 02 testing)
	var move_speed: float = 50.0
	var zoom_speed: float = 0.05

	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_W:
					_camera.position.y -= move_speed
				KEY_S:
					_camera.position.y += move_speed
				KEY_A:
					_camera.position.x -= move_speed
				KEY_D:
					_camera.position.x += move_speed
				KEY_EQUAL:
					_camera.zoom += Vector2(zoom_speed, zoom_speed)
				KEY_MINUS:
					_camera.zoom -= Vector2(zoom_speed, zoom_speed)
					_camera.zoom = _camera.zoom.clamp(Vector2(0.05, 0.05), Vector2(2.0, 2.0))
