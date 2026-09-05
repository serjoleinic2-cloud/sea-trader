extends Node2D

## Ship scene root.
## Assembles ShipPhysics, ShipControl, InputAdapter, SensorInput.
## Owns Camera2D follow and debug HUD.
## See ARCHITECTURE.md Phase 03.

const SHIP_DATA_PATH: String = "res://data/ships/ship_sloop.json"

# Child nodes (assigned in _ready from scene tree)
@onready var _sprite: Polygon2D = $ShipVisual
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: CanvasLayer = $DebugHUD
@onready var _hud_label: Label = $DebugHUD/HUDLabel
@onready var _collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

# Systems (instantiated here; NOT autoloads)
var _physics: Node
var _control: Node
var _sensor: Node
var _adapter: Node

# Ship data loaded from JSON
var _ship_data: Dictionary = {}

# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	_load_ship_data()
	_init_systems()
	_position_ship()

	# Connect collision
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_physics.physics_tick(delta)
	_sync_visual()
	_update_hud()


# ============================================================================
# Init
# ============================================================================

func _load_ship_data() -> void:
	var file: FileAccess = FileAccess.open(SHIP_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Ship: Cannot open " + SHIP_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_ship_data = parsed
	else:
		push_error("Ship: Invalid JSON in " + SHIP_DATA_PATH)


func _init_systems() -> void:
	# SensorInput
	_sensor = preload("res://systems/input/sensor_input.gd").new()
	add_child(_sensor)

	# ShipPhysics
	_physics = preload("res://systems/ship/ship_physics.gd").new()
	add_child(_physics)
	_physics.setup(_ship_data)
	_physics.ship_node = _sprite

	# ShipControl
	_control = preload("res://systems/ship/ship_control.gd").new()
	add_child(_control)
	_control.setup(_physics)

	# InputAdapter
	_adapter = preload("res://systems/input/input_adapter.gd").new()
	add_child(_adapter)
	_adapter.setup(_sensor, _control)


func _position_ship() -> void:
	# Place ship at a sea position (center of world, offset from islands)
	var start_pos: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	if start_pos == Vector2.ZERO:
		var world_w: float = 4096.0
		var world_h: float = 4096.0
		# Check WorldState for seed-based world size (fallback to 4096)
		start_pos = Vector2(world_w * 0.25, world_h * 0.25)
		GameState.ship_state["position"] = start_pos

	global_position = start_pos
	_physics.setup_world_bounds(4096.0, 4096.0)

	# Restore velocity if resuming a saved voyage
	var saved_vel: Vector2 = GameState.ship_state.get("velocity", Vector2.ZERO)
	if saved_vel.length() > 0.1:
		_physics.restore_from_state()

	# Snap camera
	_camera.position = Vector2.ZERO   # Camera2D is child, position is relative


# ============================================================================
# Visual sync
# ============================================================================

func _sync_visual() -> void:
	# Move ship node to match physics position
	var pos: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	global_position = pos

	# Rotation + visual roll applied inside ShipPhysics._update_visual_roll
	# via ship_node reference — nothing extra needed here


# ============================================================================
# HUD
# ============================================================================

func _update_hud() -> void:
	if _hud_label == null:
		return

	var speed: float = _physics.get_speed()
	var fuel: float = float(GameState.ship_state.get("fuel", 0.0))
	var fuel_max: float = float(GameState.ship_state.get("fuel_max", 100.0))
	var hull: float = float(GameState.ship_state.get("hull", 0.0))
	var hull_max: float = float(_ship_data.get("hull_max", 100.0))
	var cargo: int = GameState.ship_state.get("cargo", []).size()
	var cargo_cap: int = int(GameState.ship_state.get("cargo_capacity", 50))

	_hud_label.text = (
		"SPEED: %d\nFUEL: %d/%d\nHULL: %d/%d\nCARGO: %d/%d" % [
			int(speed), int(fuel), int(fuel_max),
			int(hull), int(hull_max),
			cargo, cargo_cap
		]
	)


# ============================================================================
# Collision foundation
# ============================================================================

func _on_body_entered(body: Node) -> void:
	## Phase 09 will implement full DamageSystem here.
	## Foundation: detect collision with StaticBody2D (islands/obstacles).
	if body.is_in_group("obstacle"):
		EventBus.ship_damaged.emit("hull", 0.0)   # placeholder — damage TBD
		push_warning("Ship: collision with obstacle '%s' (damage TBD Phase 09)" % body.name)


func _on_area_entered(area: Area2D) -> void:
	## Foundation: detect hazard zone overlap.
	if area.is_in_group("hazard_zone"):
		push_warning("Ship: entered hazard zone '%s'" % area.name)
