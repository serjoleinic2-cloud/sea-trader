extends CanvasLayer

## Perspective close-up shown as the ship approaches an island. The 2D world
## remains authoritative; this viewport is a render-only camera transition.

const MAP_TO_METERS: float = 0.04
const TRANSITION_START_GAP: float = 560.0
const TRANSITION_CLOSE_GAP: float = 160.0

var _world_data: Dictionary = {}
var _viewport_container: SubViewportContainer
var _subviewport: SubViewport
var _scene_root: Node3D
var _camera: Camera3D
var _ship: Node3D
var _island_root: Node3D
var _island_id: String = ""
func _ready() -> void:
	layer = 1
	_build_viewport()
	_build_scene()


func initialize(world_data: Dictionary) -> void:
	_world_data = world_data


func _process(delta: float) -> void:
	if _world_data.is_empty() or _camera == null:
		return
	var ship_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var nearest: Dictionary = _find_nearest_island(ship_position)
	if nearest.is_empty():
		_set_transition(0.0, delta)
		return

	var island_position: Vector2 = Vector2(nearest.get("position", Vector2.ZERO))
	var island_radius: float = float(nearest.get("radius", 80.0))
	var center_distance: float = ship_position.distance_to(island_position)
	var coast_gap: float = maxf(0.0, center_distance - island_radius)
	var close_factor: float = 1.0 - smoothstep(TRANSITION_CLOSE_GAP, TRANSITION_START_GAP, coast_gap)
	_set_transition(close_factor, delta)
	_update_island(nearest)
	_update_camera(ship_position, island_position, close_factor, delta)


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.modulate.a = 0.0
	add_child(_viewport_container)

	_subviewport = SubViewport.new()
	_subviewport.size = Vector2i(get_viewport().get_visible_rect().size)
	_subviewport.own_world_3d = true
	_subviewport.transparent_bg = false
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_subviewport)


func _build_scene() -> void:
	_scene_root = Node3D.new()
	_scene_root.name = "ApproachWorld3D"
	_subviewport.add_child(_scene_root)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("7ca9bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9d5df")
	environment.ambient_light_energy = 0.65
	environment_node.environment = environment
	_scene_root.add_child(environment_node)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sunlight.light_energy = 1.25
	_scene_root.add_child(sunlight)

	_add_water()
	_ship = _make_ship()
	_scene_root.add_child(_ship)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 58.0
	_scene_root.add_child(_camera)


func _add_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(700.0, 700.0)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	uniform vec3 deep_water = vec3(0.035, 0.20, 0.30);
	uniform vec3 light_water = vec3(0.10, 0.36, 0.46);
	void vertex() {
		VERTEX.y += sin(VERTEX.x * 0.12 + TIME * 1.1) * 0.10;
		VERTEX.y += sin(VERTEX.z * 0.17 + TIME * 0.8) * 0.08;
	}
	void fragment() {
		float bands = sin((UV.x * 47.0 + UV.y * 23.0 + TIME * 0.15) * 6.28318);
		float glint = smoothstep(0.62, 0.96, bands) * 0.20;
		ALBEDO = mix(deep_water, light_water, glint);
		ROUGHNESS = 0.28;
		METALLIC = 0.08;
	}
	"""
	var water := MeshInstance3D.new()
	water.name = "AnimatedOcean"
	water.mesh = plane
	var water_material := ShaderMaterial.new()
	water_material.shader = shader
	water.material_override = water_material
	water.position.y = -0.18
	_scene_root.add_child(water)


func _make_ship() -> Node3D:
	var ship := Node3D.new()
	ship.name = "CloseViewShip"
	var hull_material := _material(Color("503629"), 0.72)
	var deck_material := _material(Color("b58955"), 0.82)
	var sail_material := _material(Color("eee3c8"), 0.9)

	_add_box(ship, Vector3(1.55, 0.62, 4.8), Vector3(0.0, 0.15, 0.15), hull_material)
	_add_box(ship, Vector3(1.28, 0.18, 3.55), Vector3(0.0, 0.54, 0.2), deck_material)
	_add_box(ship, Vector3(0.72, 0.52, 0.82), Vector3(0.0, 0.82, 1.25), _material(Color("d7c49c"), 0.88))
	_add_cylinder(ship, 0.09, 0.09, 4.0, Vector3(0.0, 2.3, -0.25), Color("594434"))
	_add_sail(ship, Vector2(1.55, 2.65), Vector3(0.0, 2.1, -0.2), sail_material)
	_add_sail(ship, Vector2(0.9, 1.65), Vector3(0.0, 1.55, -1.45), _material(Color("d9c9aa"), 0.94))
	return ship


func _add_sail(parent: Node3D, sail_size: Vector2, at: Vector3, material: StandardMaterial3D) -> void:
	var sail_mesh := QuadMesh.new()
	sail_mesh.size = sail_size
	var sail := MeshInstance3D.new()
	sail.mesh = sail_mesh
	sail.material_override = material
	sail.position = at
	parent.add_child(sail)


func _update_island(island: Dictionary) -> void:
	var current_id: String = str(island.get("id", ""))
	if current_id == _island_id:
		return
	if _island_root != null:
		_island_root.queue_free()
	_island_id = current_id
	_island_root = Node3D.new()
	_island_root.name = "ProceduralIsland"
	_scene_root.add_child(_island_root)

	var map_radius: float = float(island.get("radius", 90.0))
	var radius: float = clampf(map_radius * MAP_TO_METERS, 2.5, 9.0)
	_add_cylinder(_island_root, radius, radius * 0.78, 1.55, Vector3(0.0, 0.62, 0.0), Color("b99a69"))
	_add_cylinder(_island_root, radius * 0.79, radius * 0.73, 0.5, Vector3(0.0, 1.58, 0.0), Color("4f7851"))
	_add_cylinder(_island_root, radius * 0.34, 0.0, 2.9, Vector3(-radius * 0.18, 3.0, -radius * 0.08), Color("607d4c"))
	_add_cylinder(_island_root, radius * 0.24, 0.0, 2.1, Vector3(radius * 0.28, 2.65, radius * 0.12), Color("71865a"))

	var random_seed: int = abs(hash(current_id))
	for index in range(7):
		var angle: float = TAU * float(index) / 7.0 + float(random_seed % 31) * 0.01
		var distance: float = radius * (0.23 + float(index % 3) * 0.13)
		var tree_at := Vector3(cos(angle) * distance, 1.9, sin(angle) * distance)
		_add_cylinder(_island_root, 0.10, 0.08, 1.2, tree_at + Vector3(0.0, 0.55, 0.0), Color("73553b"))
		_add_cylinder(_island_root, 0.85, 0.04, 1.45, tree_at + Vector3(0.0, 1.7, 0.0), Color("326747"))

	var port: Dictionary = _find_port_for_island(current_id)
	if not port.is_empty():
		_build_port(port, Vector2(island.get("position", Vector2.ZERO)), radius)
	else:
		# Uninhabited islands get a small exposed rock outcrop instead of port buildings.
		_add_cylinder(_island_root, radius * 0.16, radius * 0.05, 1.5, Vector3(radius * 0.42, 2.1, -radius * 0.35), Color("8a8272"))


func _find_port_for_island(island_id: String) -> Dictionary:
	for raw_port in _world_data.get("ports", {}).values():
		var port: Dictionary = raw_port
		if str(port.get("island_id", "")) == island_id:
			return port
	return {}


func _build_port(port: Dictionary, island_position: Vector2, island_radius: float) -> void:
	var port_position: Vector2 = Vector2(port.get("position", island_position))
	var local_port: Vector2 = (port_position - island_position) * MAP_TO_METERS
	var outward_2d: Vector2 = local_port.normalized()
	if outward_2d.length_squared() < 0.01:
		outward_2d = Vector2.RIGHT
	var outward := Vector3(outward_2d.x, 0.0, outward_2d.y)
	var pier_yaw: float = atan2(outward.x, outward.z)
	var pier_right := Vector3(outward.z, 0.0, -outward.x)
	var dock_start: Vector3 = Vector3(local_port.x, 0.12, local_port.y) + outward * 1.1
	var pier := _add_box(_island_root, Vector3(1.45, 0.24, 7.2), dock_start + outward * 3.2, _material(Color("765238"), 0.95))
	pier.rotation.y = pier_yaw
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		for distance_value in [0.8, 3.5, 6.1]:
			var distance: float = float(distance_value)
			var piling_at: Vector3 = dock_start + outward * distance + pier_right * side * 0.58 + Vector3(0.0, -0.12, 0.0)
			_add_cylinder(_island_root, 0.12, 0.12, 0.95, piling_at, Color("4b3829"))

	# Warehouses and small port buildings sit between the beach and the pier.
	var landward: Vector3 = -outward
	var settlement_center: Vector3 = Vector3(local_port.x, 0.0, local_port.y) + landward * 1.8
	var wall := _material(Color("d8c8a0"), 0.93)
	var roof := _material(Color("9c4939"), 0.9)
	_add_box(_island_root, Vector3(2.6, 1.25, 1.7), settlement_center + Vector3(0.0, 0.85, 0.0), wall)
	var warehouse_roof := _add_box(_island_root, Vector3(2.9, 0.2, 1.95), settlement_center + Vector3(0.0, 1.57, 0.0), roof)
	warehouse_roof.rotation.z = deg_to_rad(-4.0)
	_add_box(_island_root, Vector3(0.85, 0.7, 0.7), settlement_center + landward * 2.0 + Vector3(0.0, 0.55, 0.0), wall)
	_add_box(_island_root, Vector3(1.0, 0.16, 0.85), settlement_center + landward * 2.0 + Vector3(0.0, 0.98, 0.0), _material(Color("bd7650"), 0.92))

	# A low-poly lighthouse marks the harbour approach; its body is built from
	# alternating painted sections so it remains recognizable at phone scale.
	var lighthouse_at: Vector3 = settlement_center + landward * (island_radius * 0.12)
	_add_cylinder(_island_root, 0.58, 0.38, 2.5, lighthouse_at + Vector3(0.0, 1.4, 0.0), Color("e6dfc9"))
	_add_cylinder(_island_root, 0.43, 0.43, 0.35, lighthouse_at + Vector3(0.0, 2.75, 0.0), Color("a74935"))
	_add_cylinder(_island_root, 0.38, 0.34, 0.22, lighthouse_at + Vector3(0.0, 3.02, 0.0), Color("f2d789"))


func _update_camera(ship_position: Vector2, island_position: Vector2, close_factor: float, delta: float) -> void:
	var velocity: Vector2 = Vector2(GameState.ship_state.get("velocity", Vector2.ZERO))
	var heading: float = velocity.angle() if velocity.length_squared() > 1.0 else  -PI * 0.5
	var yaw: float = heading + PI * 0.5
	_ship.rotation.y = lerp_angle(_ship.rotation.y, yaw, 1.0 - exp(-delta * 5.0))

	var forward := Vector3(cos(heading), 0.0, sin(heading))
	var camera_back: float = lerpf(5.0, 14.0, close_factor)
	var camera_height: float = lerpf(18.0, 4.4, close_factor)
	var desired_camera_position: Vector3 = -forward * camera_back + Vector3.UP * camera_height
	_camera.position = _camera.position.lerp(desired_camera_position, 1.0 - exp(-delta * 3.5))
	var look_distance: float = lerpf(1.0, 7.0, close_factor)
	_camera.look_at(forward * look_distance + Vector3.UP * 0.8, Vector3.UP)

	var island_offset: Vector2 = island_position - ship_position
	_island_root.position = Vector3(island_offset.x * MAP_TO_METERS, 0.0, island_offset.y * MAP_TO_METERS)


func _find_nearest_island(ship_position: Vector2) -> Dictionary:
	var closest: Dictionary = {}
	var best_gap: float = INF
	for island in _world_data.get("islands", []):
		var island_position: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var radius: float = float(island.get("radius", 0.0))
		var gap: float = maxf(0.0, ship_position.distance_to(island_position) - radius)
		if gap < best_gap:
			best_gap = gap
			closest = island
	return closest


func _set_transition(target: float, delta: float) -> void:
	var current: float = _viewport_container.modulate.a
	_viewport_container.modulate.a = lerpf(current, target, 1.0 - exp(-delta * 2.4))


func _add_box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, bottom_radius: float, top_radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom_radius
	cylinder.top_radius = top_radius
	cylinder.height = height
	cylinder.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.material_override = _material(color, 0.92)
	instance.position = at
	parent.add_child(instance)
	return instance


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
