extends Node2D

## Ship scene root.
## Assembles ShipPhysics, ShipControl, InputAdapter, SensorInput.
## Owns Camera2D follow and debug HUD.
## See ARCHITECTURE.md Phase 03.


# Child nodes (assigned in _ready from scene tree)
@onready var _sprite: Polygon2D = $ShipVisual
@onready var _procedural_visual: Node2D = $ProceduralShipVisual
@onready var _camera: Camera2D = $Camera2D
@onready var _hud: CanvasLayer = $DebugHUD
@onready var _hud_label: Label = $DebugHUD/HUDLabel
@onready var _collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

# Systems (instantiated here; NOT autoloads)
var _physics: Node
var _control: Node
var _sensor: Node
var _adapter: Node
var _port_system: Node
var _anchor_prompt: Label

# Ship data loaded from JSON
var _ship_data: Dictionary = {}

# ============================================================================
# Lifecycle
# ============================================================================

func _ready() -> void:
	_load_ship_data()
	_init_systems()
	_position_ship()
	_hud.visible = false
	_create_anchor_prompt()

	# Connect collision
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.area_entered.connect(_on_area_entered)
	if not EventBus.active_ship_changed.is_connected(_on_active_ship_changed):
		EventBus.active_ship_changed.connect(_on_active_ship_changed)


func _physics_process(delta: float) -> void:
	_physics.physics_tick(delta)
	_sync_visual()
	_update_hud()
	_update_anchor_prompt()

func _create_anchor_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AnchorPromptLayer"
	layer.layer = 25
	add_child(layer)
	_anchor_prompt = Label.new()
	_anchor_prompt.name = "AnchorPrompt"
	_anchor_prompt.custom_minimum_size = Vector2(220, 42)
	_anchor_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_anchor_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anchor_prompt.add_theme_font_size_override("font_size", 15)
	_anchor_prompt.add_theme_color_override("font_color", Color("fff1cb"))
	_anchor_prompt.add_theme_color_override("font_outline_color", Color("182a31"))
	_anchor_prompt.add_theme_constant_override("outline_size", 3)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.09, 0.88)
	style.border_color = Color("d0ad63")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_anchor_prompt.add_theme_stylebox_override("normal", style)
	layer.add_child(_anchor_prompt)

func _update_anchor_prompt() -> void:
	if _anchor_prompt == null:
		return
	if _port_system == null or not is_instance_valid(_port_system):
		var systems: Array[Node] = get_tree().get_nodes_in_group("port_system")
		if not systems.is_empty():
			_port_system = systems[0]
	if _port_system == null:
		_anchor_prompt.hide()
		return
	var docked_id: String = str(GameState.ship_state.get("docked_port_id", ""))
	var nearby_id: String = str(_port_system.get_dock_candidate())
	if docked_id != "":
		_anchor_prompt.hide()
		return
	elif nearby_id != "":
		_anchor_prompt.text = "E  ·  БРОСИТЬ ЯКОРЬ\n%s" % str(_port_system.get_port_name(nearby_id))
	else:
		_anchor_prompt.hide()
		return
	var screen_position: Vector2 = get_global_transform_with_canvas() * Vector2(0, -38)
	_anchor_prompt.position = screen_position - Vector2(_anchor_prompt.custom_minimum_size.x * 0.5, 62)
	_anchor_prompt.show()

func set_navigation_collision_provider(provider: Callable) -> void:
	if _physics != null and _physics.has_method("set_collision_data_provider"):
		_physics.call("set_collision_data_provider", provider)


func is_navigation_move_blocked(current_pos: Vector2, proposed_pos: Vector2) -> bool:
	return bool(_physics.call("is_navigation_move_blocked", current_pos, proposed_pos)) if _physics != null else false


func get_navigation_speed(cruise_speed: float = 110.0) -> float:
	return cruise_speed * float(_physics.get_max_speed()) / maxf(1.0, float(_ship_data.get("base_speed", 120.0)))


# ============================================================================
# Init
# ============================================================================

func _load_ship_data() -> void:
	var ship_id: String = str(GameState.ship_state.get("ship_id", ""))
	if ship_id == "":
		ship_id = GameData.get_starter_ship_id()
	_ship_data = GameData.get_ship(ship_id)
	if _ship_data.is_empty():
		push_error("Ship: unknown saved ship ID " + ship_id)


func _init_systems() -> void:
	# SensorInput
	_sensor = preload("res://systems/input/sensor_input.gd").new()
	add_child(_sensor)

	# ShipPhysics
	_physics = preload("res://systems/ship/ship_physics.gd").new()
	add_child(_physics)
	_physics.setup(_ship_data, GameState.ship_state.get("ship_id", "") == "")
	_physics.ship_node = _procedural_visual

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

	global_position = start_pos
	_physics.setup_world_bounds(4096.0, 4096.0)

	# Restore velocity if resuming a saved voyage
	var saved_vel: Vector2 = GameState.ship_state.get("velocity", Vector2.ZERO)
	if saved_vel.length() > 0.1:
		_physics.restore_from_state()

	# Snap camera
	_camera.position = Vector2.ZERO   # Camera2D is child, position is relative


func _on_active_ship_changed(_ship_type_id: String) -> void:
	_load_ship_data()
	if _ship_data.is_empty():
		return
	_physics.setup(_ship_data, false)
	_physics.ship_node = _procedural_visual
	_position_ship()
	_sync_visual()
	_update_hud()


# ============================================================================
# Visual sync
# ============================================================================

func _sync_visual() -> void:
	# Move ship node to match physics position
	var pos: Vector2 = GameState.ship_state.get("position", Vector2.ZERO)
	global_position = pos
	if _procedural_visual.has_method("set_sailing_speed"):
		var velocity: Vector2 = GameState.ship_state.get("velocity", Vector2.ZERO)
		_procedural_visual.set_sailing_speed(velocity.length())

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
