extends SubViewportContainer

## Embedded, read-only preview using the same model factory as the sailing world.
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _model: Node3D
var _ship_id := ""
var _yaw := 0.65
var _pitch := 0.30
var _zoom := 1.0
var _radius := 4.0
var _center := Vector3.ZERO
var _bounds := AABB()

func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(260, 160)
	gui_input.connect(_on_input)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_camera = Camera3D.new()
	_camera.fov = 38
	_camera.current = true
	_world.add_child(_camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0a202d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c0d3df")
	environment.environment.ambient_light_energy = 0.65
	_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -35, 0)
	light.light_energy = 0.9
	_world.add_child(light)

func show_ship(id: String) -> void:
	if _ship_id == id:
		return
	_ship_id = id
	if is_instance_valid(_model):
		_world.remove_child(_model)
		_model.queue_free()
	var definition: Dictionary = GameData.get_ship(id)
	var race: String = str(definition.get("faction_id", GameState.player_state.get("origin_race_id", "humans")))
	var visual: Dictionary = GameData.read("res://data/world/ship_visuals.json").get("ships", {}).get(id, {})
	var renderer = preload("res://systems/rendering/approach_3d_view.gd").new()
	renderer._asset_catalog = GameData.read("res://data/world/world_asset_catalog.json")
	_model = renderer._attach_catalog_scene(_world, "ships", id, float(visual.get("display_length", 4.0)), race)
	if _model != null:
		var style = preload("res://systems/rendering/faction_base_style.gd").new()
		style.apply_ship(_model, race)
		var bounds: Array[AABB] = []
		_collect_bounds(_model, bounds)
		var box := AABB()
		for index in bounds.size():
			box = bounds[index] if index == 0 else box.merge(bounds[index])
		_center = box.get_center()
		_bounds = box
		_radius = maxf(0.5, box.size.length() * 0.5)
	renderer.free()
	_yaw = 0.65
	_pitch = 0.30
	_zoom = 1.0

func _collect_bounds(node: Node, result: Array[AABB]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		result.append(node.global_transform * node.get_aabb())
	for child in node.get_children():
		_collect_bounds(child, result)

func _process(_delta: float) -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if not is_visible_in_tree():
		return
	var aspect: float = maxf(0.3, size.x / maxf(1, size.y))
	var direction := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	var right := Vector3.UP.cross(direction).normalized()
	var up := direction.cross(right).normalized()
	var tan_vertical: float = tan(deg_to_rad(_camera.fov) * 0.5)
	var distance := 0.5
	for index in 8:
		var point: Vector3 = _bounds.get_endpoint(index) - _center
		var depth: float = point.dot(direction)
		distance = maxf(distance, depth + absf(point.dot(right)) / (tan_vertical * aspect))
		distance = maxf(distance, depth + absf(point.dot(up)) / tan_vertical)
	_camera.position = _center + direction * distance * 1.1 * _zoom
	_camera.look_at(_center)

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)):
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.006, -0.25, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(0.6, _zoom * 0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(2.0, _zoom * 1.1)
		if event.double_click:
			_yaw = 0.65
			_pitch = 0.30
			_zoom = 1.0
	accept_event()
