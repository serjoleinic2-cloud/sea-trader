extends CanvasLayer

## Renders the strategic map and the close view from one shared 3D world.
## On approach, only the camera moves from overhead to behind the ship.

const MAP_TO_METERS: float = 0.04
const TRANSITION_START_GAP: float = 560.0
const TRANSITION_CLOSE_GAP: float = 160.0
const FOG_RADIUS_CHUNKS: int = 6
const FOG_HEIGHT: float = 28.0
const DAY_CYCLE_SECONDS: float = 300.0
const SEA_LEVEL: float = -0.18
const RenderVisibility = preload("res://systems/rendering/render_visibility.gd")

var _world_data: Dictionary = {}
var _map_world: CanvasItem
var _map_ship: CanvasItem
var _viewport_container: SubViewportContainer
var _subviewport: SubViewport
var _scene_root: Node3D
var _camera: Camera3D
var _ship: Node3D
var _trader_traffic: Node
var _fleet_traffic: Node
var _water: MeshInstance3D
var _sailing_gulls: Node3D
var _island_nodes: Dictionary = {}
var _hazard_nodes: Dictionary = {}
var _rendered_island_data: Dictionary = {}
var _traffic_models: Dictionary = {}
var _fog_tiles: Dictionary = {}
var _fog_center: Vector2i = Vector2i(2147483647, 2147483647)
var _fog_explored_count: int = -1
var _asset_catalog: Dictionary = {}
var _transition_factor: float = 0.0
var _chunk_size: float = 4096.0
var _camera_initialized: bool = false
var _environment: Environment
var _sky_material: ShaderMaterial
var _sunlight: DirectionalLight3D
var _day_clock: float = 0.0
var _animation_clock: float = 0.0
var _orbit_dragging: bool = false
var _manual_close_view: bool = false
var _battle_camera_was_active: bool = false
var _camera_orbit_yaw: float = 0.0
var _camera_orbit_pitch: float = 0.0
var _touch_points: Dictionary = {}
var _last_touch_distance: float = 0.0


func _ready() -> void:
	# Render the shared 3D world beneath the strategic map and the game UI.
	layer = -1
	_asset_catalog = GameData.read("res://data/world/world_asset_catalog.json")
	_build_viewport()
	_build_scene()
	if not EventBus.active_ship_changed.is_connected(_on_active_ship_changed):
		EventBus.active_ship_changed.connect(_on_active_ship_changed)


func _on_active_ship_changed(_ship_type_id: String) -> void:
	if _scene_root == null:
		return
	if is_instance_valid(_ship):
		_ship.queue_free()
	_ship = _make_ship()
	_scene_root.add_child(_ship)


func initialize(world_data: Dictionary, map_world: CanvasItem, map_ship: CanvasItem, trader_traffic: Node = null, fleet_traffic: Node = null) -> void:
	_world_data = world_data
	_asset_catalog = GameData.read("res://data/world/world_asset_catalog.json")
	_chunk_size = float(world_data.get("chunk_size", 4096.0))
	_map_world = map_world
	_map_ship = map_ship
	_trader_traffic = trader_traffic
	_fleet_traffic = fleet_traffic
	# Pin the planet to one world bearing at the horizon; it does not follow the camera.
	var home: Dictionary = world_data.get("ports", {}).get(str(GameState.world_state.get("home_port_id", "")), {})
	var planet_bearing: float = float(home.get("harbor_angle", 0.0)) + PI + 0.32
	var planet_direction := Vector3(cos(planet_bearing), 0.015, sin(planet_bearing))
	_sky_material.set_shader_parameter("jupiter_direction", planet_direction)
	# The strategy view is 3D from the start. Keep the 2D camera active so zoom
	# and movement still use the existing systems; traffic markers remain above it.
	_map_world.visible = false
	_map_world.set_process(false)
	var ship_sprite: CanvasItem = _map_ship.get_node_or_null("ShipVisual") as CanvasItem
	if ship_sprite != null:
		ship_sprite.visible = false
	var procedural_visual: CanvasItem = _map_ship.get_node_or_null("ProceduralShipVisual") as CanvasItem
	if procedural_visual != null:
		procedural_visual.visible = false
	for renderer in [_trader_traffic, _fleet_traffic]:
		if renderer is CanvasItem:
			renderer.visible = false
	if _trader_traffic != null:
		_trader_traffic.set_process(true)
	if _fleet_traffic != null:
		_fleet_traffic.set_process(false)
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.msaa_3d = Viewport.MSAA_2X
	_sync_generated_world(_world_data)


func _process(delta: float) -> void:
	_animation_clock += delta
	_day_clock = fposmod(_day_clock + delta, DAY_CYCLE_SECONDS)
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_viewport_container.hide()
		_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_viewport_container.show()
	if _world_data.is_empty() or _camera == null:
		return
	var ship_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var nearest: Dictionary = _find_nearest_island(ship_position)
	var coast_factor: float = 0.0
	if not nearest.is_empty():
		var island_position: Vector2 = Vector2(nearest.get("position", Vector2.ZERO))
		var island_radius: float = float(nearest.get("radius", 80.0))
		var coast_gap: float = maxf(0.0, ship_position.distance_to(island_position) - island_radius)
		coast_factor = 1.0 - smoothstep(TRANSITION_CLOSE_GAP, TRANSITION_START_GAP, coast_gap)

	# High zoom can enter the same 3D sailing view even far from land.
	var map_camera: Camera2D = get_viewport().get_camera_2d()
	var zoom_factor: float = 0.0
	if map_camera != null:
		zoom_factor = smoothstep(0.72, 1.20, map_camera.zoom.x)
	if map_camera != null and map_camera.zoom.x < 0.62:
		_manual_close_view = false
		_camera_orbit_yaw = 0.0
		_camera_orbit_pitch = 0.0
	var close_factor: float = maxf(coast_factor, zoom_factor)
	if _manual_close_view:
		close_factor = 1.0
	_set_transition(close_factor, delta)
	var battle_camera_active: bool=_battle_camera_requested()
	if battle_camera_active:
		# Combat framing overrides an earlier close camera gesture so both fleets remain in frame.
		_orbit_dragging=false
		_update_battle_camera(ship_position,delta)
	else:
		if _battle_camera_was_active:
			# Keep the 3D sailing layer visible while the battle continues so the
			# player can immediately zoom and orbit after collapsing the panel.
			_manual_close_view=true
		_update_camera(ship_position, _transition_factor, delta)
	_battle_camera_was_active=battle_camera_active
	if _water != null:
		_water.position.x = ship_position.x * MAP_TO_METERS
		_water.position.z = ship_position.y * MAP_TO_METERS
	_sync_fog(ship_position)
	_sync_traffic(_trader_traffic, "trader")
	_sync_traffic(_fleet_traffic, "fleet")
	_cull_visuals()
	_update_ambience(delta)


func _battle_camera_requested() -> bool:
	if not bool(GameState.combat_state.get("naval_battle",{}).get("active",false)): return false
	var hud: Node=get_parent().get_node_or_null("NavalBattleHUD")
	return hud==null or not hud.has_method("tactical_view_open") or bool(hud.tactical_view_open())


func _cull_visuals() -> void:
	var planes: Array[Plane] = _camera.get_frustum()
	var inside := _camera.global_position - _camera.global_basis.z * (_camera.near + 1.0)
	for root in _island_nodes.values():
		if not root.has_meta("visual_world_bounds"):
			root.set_meta("visual_world_bounds", RenderVisibility.bounds_for(root))
		root.visible = RenderVisibility.intersects_frustum(root.get_meta("visual_world_bounds"), planes, inside)
		root.process_mode = Node.PROCESS_MODE_INHERIT if root.visible else Node.PROCESS_MODE_DISABLED
	for model in _traffic_models.values():
		var model_key: String = str(model.name)
		if model_key.begins_with("Traffic_combat_"):
			var battle: Dictionary = GameState.combat_state.get("naval_battle",{})
			var vessel_id: String = model_key.trim_prefix("Traffic_combat_")
			var battle_ids: Array = battle.get("enemy_ids",[]) if bool(battle.get("active",false)) else []
			if battle_ids.has(vessel_id):
				model.visible = true
				continue
		if not model.has_meta("visual_local_bounds"):
			model.set_meta("visual_local_bounds", model.global_transform.affine_inverse() * RenderVisibility.bounds_for(model))
		var bounds: AABB = model.global_transform * (model.get_meta("visual_local_bounds") as AABB)
		model.visible = RenderVisibility.intersects_frustum(bounds, planes, inside)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		_orbit_dragging=false

func _unhandled_input(event: InputEvent) -> void:
	# GUI receives the gesture first: dragging the tactical map must not orbit
	# the sailing camera or consume its right-button press.
	var inspection: Node = get_tree().get_first_node_in_group("ship_inspection_window")
	if inspection != null and bool(inspection.get("_is_open")):
		_orbit_dragging = false
		return
	if str(GameState.ship_state.get("docked_port_id", "")) != "":
		_orbit_dragging = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_orbit_dragging = event.pressed
		if event.pressed:
			_manual_close_view = true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _orbit_dragging:
		_camera_orbit_yaw = wrapf(_camera_orbit_yaw - event.relative.x * 0.006, -TAU, TAU)
		_camera_orbit_pitch = clampf(_camera_orbit_pitch + event.relative.y * 0.004, -0.48, 0.62)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
			if _touch_points.size() == 2:
				var touch_ids: Array = _touch_points.keys()
				_last_touch_distance = Vector2(_touch_points[touch_ids[0]]).distance_to(Vector2(_touch_points[touch_ids[1]]))
		else:
			_touch_points.erase(event.index)
			if _touch_points.size() < 2:
				_last_touch_distance = 0.0
	elif event is InputEventScreenDrag and _touch_points.has(event.index):
		_touch_points[event.index] = event.position
		if _touch_points.size() >= 2:
			var touch_ids: Array = _touch_points.keys()
			var first_touch: Vector2 = Vector2(_touch_points[touch_ids[0]])
			var second_touch: Vector2 = Vector2(_touch_points[touch_ids[1]])
			var touch_distance: float = first_touch.distance_to(second_touch)
			if _last_touch_distance > 1.0 and touch_distance > 1.0:
				var map_camera: Camera2D = get_viewport().get_camera_2d()
				if map_camera != null:
					var zoom_value: float = clampf(map_camera.zoom.x * touch_distance / _last_touch_distance, 0.15, 2.0)
					map_camera.zoom = Vector2.ONE * zoom_value
					_manual_close_view = true
			_last_touch_distance = touch_distance
			if event.index == 0:
				_manual_close_view = true
				_camera_orbit_yaw = wrapf(_camera_orbit_yaw - event.relative.x * 0.006, -TAU, TAU)
				_camera_orbit_pitch = clampf(_camera_orbit_pitch + event.relative.y * 0.004, -0.48, 0.62)


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the shared 3D world below HUD CanvasLayers.
	_viewport_container.modulate.a = 1.0
	add_child(_viewport_container)

	_subviewport = SubViewport.new()
	_subviewport.size = Vector2i(get_viewport().get_visible_rect().size)
	_subviewport.own_world_3d = true
	_subviewport.audio_listener_enable_3d = true
	_subviewport.transparent_bg = false
	_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport_container.add_child(_subviewport)


func _build_scene() -> void:
	_scene_root = Node3D.new()
	_scene_root.name = "ApproachWorld3D"
	_subviewport.add_child(_scene_root)

	var environment_node := WorldEnvironment.new()
	_environment = Environment.new()
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = load("res://assets/world/materials/tropical_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("b9d5df")
	_environment.ambient_light_energy = 0.65
	environment_node.environment = _environment
	_scene_root.add_child(environment_node)

	_sunlight = DirectionalLight3D.new()
	_sunlight.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	_sunlight.light_energy = 1.25
	# Keep directional lighting without the expensive shadow pass.
	_sunlight.shadow_enabled = false
	_scene_root.add_child(_sunlight)

	_add_water()
	_ship = _make_ship()
	_scene_root.add_child(_ship)
	_sailing_gulls = load("res://systems/rendering/seabird_flock.gd").new()
	_sailing_gulls.periodic = true
	_sailing_gulls.name = "SailingGulls"
	_scene_root.add_child(_sailing_gulls)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 58.0
	_scene_root.add_child(_camera)


func _add_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400.0, 2400.0)
	_water = MeshInstance3D.new()
	_water.name = "PlainOcean"
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.mesh = plane
	# Diagnostic baseline: two triangles, opaque colour, no waves, depth
	# sampling, reflection, glints, foam, transparency, or lighting effects.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("247c88")
	material.roughness = 1.0
	_water.material_override = material
	_water.position.y = SEA_LEVEL
	_scene_root.add_child(_water)


func _update_ambience(_delta: float) -> void:
	var phase: float = _day_clock / DAY_CYCLE_SECONDS
	# Sunrise begins at cycle wrap; sunset begins at 75% of the cycle.
	# That gives the prototype a 3:1 daylight-to-night ratio.
	var night: float = smoothstep(0.75, 0.87, phase) * (1.0 - smoothstep(0.94, 1.0, phase))
	_update_ship_lanterns(night)
	for root in _island_nodes.values():
		if not root.visible:
			continue
		var base: Node = root.get_node_or_null("FactionHarbor")
		if base == null: base = root.get_node_or_null("HomeBase3D")
		if base != null:
			base.set_night_strength(smoothstep(0.08, 0.55, night))
		for district in root.get_children():
			if district.name.begins_with("NpcPortDistrict"):
				district.set_night_strength(smoothstep(0.08, 0.55, night))
	var dusk: float = _cyclic_pulse(phase, 0.75, 0.01, 0.085)
	var dawn: float = _cyclic_pulse(phase, 0.0, 0.01, 0.085)
	var twilight: float = maxf(dusk, dawn)
	if _sky_material != null:
		_sky_material.set_shader_parameter("night_amount", night)
		_sky_material.set_shader_parameter("twilight_amount", twilight)
	if _environment != null:
		_environment.ambient_light_color = Color("b9d5df").lerp(Color("293955"), night).lerp(Color("e6a879"), twilight * 0.42)
		_environment.ambient_light_energy = lerpf(0.65, 0.22, night) + twilight * 0.06
	if _sunlight != null:
		_sunlight.light_energy = lerpf(1.25, 0.10, night) + twilight * 0.12
		_sunlight.light_color = Color("fff0d2").lerp(Color("91a9d0"), night).lerp(Color("f6a36f"), twilight)
		var solar_elevation: float
		if phase < 0.75:
			solar_elevation = sin(PI * phase / 0.75)
		else:
			solar_elevation = -sin(PI * (phase - 0.75) / 0.25)
		_sunlight.rotation_degrees = Vector3(-90.0 + 58.0 * solar_elevation, -28.0 + phase * 360.0, 0.0)


func _cyclic_pulse(phase: float, center: float, core: float, fade: float) -> float:
	var wrapped_distance: float = absf(wrapf(phase - center, -0.5, 0.5))
	return 1.0 - smoothstep(core, core + fade, wrapped_distance)

func _add_ship_lanterns(ship: Node3D, positions: Array = [], cast_light: bool = true) -> void:
	var brass := _material(Color("806132"), 0.5)
	if positions.is_empty():
		positions = [[0.45, 1.38, 2.64], [-0.58, 0.94, -1.9]]
	for coordinates in positions:
		var at := Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
		var lantern := Node3D.new()
		lantern.name = "KeroseneLantern"
		lantern.position = at
		ship.add_child(lantern)
		_add_box(lantern, Vector3(0.18, 0.035, 0.18), Vector3(0, -0.105, 0), brass)
		_add_box(lantern, Vector3(0.20, 0.05, 0.20), Vector3(0, 0.12, 0), brass)
		for x in [-0.075, 0.075]:
			for z in [-0.075, 0.075]:
				_add_box(lantern, Vector3(0.015, 0.22, 0.015), Vector3(x, 0, z), brass)
		var glow := _material(Color("efb765"), 0.45)
		glow.emission_enabled = true
		glow.emission = Color("ffad42")
		var flame := _add_box(lantern, Vector3(0.08, 0.16, 0.08), Vector3.ZERO, glow)
		flame.name = "WarmFlame"
		var light := OmniLight3D.new()
		light.name = "WarmLight"
		light.light_color = Color("ffb65c")
		light.omni_range = 4.0
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		if cast_light:
			lantern.add_child(light)
		else:
			light.free()


func _update_ship_lanterns(night: float) -> void:
	if not is_instance_valid(_ship):
		return
	_update_lanterns_for(_ship, night)
	for model in _traffic_models.values():
		if is_instance_valid(model) and model.visible:
			_update_lanterns_for(model, night)

func _update_lanterns_for(ship: Node3D, night: float) -> void:
	var strength: float = smoothstep(0.08, 0.55, night)
	var flicker: float = 1.0 + sin(_animation_clock * 9.1) * 0.025 + sin(_animation_clock * 13.7) * 0.015
	for lantern in ship.get_children():
		if not str(lantern.name).begins_with("KeroseneLantern"):
			continue
		var light: OmniLight3D = lantern.get_node_or_null("WarmLight")
		if light != null:
			light.light_energy = strength * 1.1 * flicker
			light.visible = strength > 0.01
		var flame: MeshInstance3D = lantern.get_node("WarmFlame")
		flame.material_override.emission_energy_multiplier = strength * 2.5 * flicker


func _make_ship() -> Node3D:
	var ship_id: String = str(GameState.ship_state.get("ship_id", "ship_sloop"))
	var visual: Dictionary = GameData.read("res://data/world/ship_visuals.json").get("ships", {}).get(ship_id, {})
	var faction_id: String = str(GameState.player_state.get("origin_race_id", "humans"))
	var registered_ship: Node3D = _attach_catalog_scene(_scene_root, "ships", ship_id, float(visual.get("display_length", 3.48)), faction_id)
	if registered_ship != null:
		_scene_root.remove_child(registered_ship)
		registered_ship.name = "CloseViewShip"
		_add_ship_lanterns(registered_ship, visual.get("lamps", []))
		var heraldry = load("res://systems/rendering/faction_base_style.gd").new()
		heraldry.apply_ship(registered_ship, faction_id)
		var flag: Node3D = heraldry.make_flag(faction_id)
		var anchor: Array = visual.get("flag_at", [0.0, 1.3, 2.6])
		flag.position = Vector3(float(anchor[0]), float(anchor[1]), float(anchor[2]))
		flag.scale = Vector3.ONE * 0.28
		registered_ship.add_child(flag)
		return registered_ship
	var ship := Node3D.new()
	ship.name = "CloseViewShip"
	var hull_material := _material(Color("503629"), 0.72)
	var deck_material := _material(Color("b58955"), 0.82)
	var sail_material := _material(Color("eee3c8"), 0.9)

	# The map hull is 87 world units long; at MAP_TO_METERS this hull is the
	# same apparent size when the camera crosses from the map into 3D.
	_add_box(ship, Vector3(1.04, 0.50, 3.48), Vector3(0.0, 0.15, 0.12), hull_material)
	_add_box(ship, Vector3(0.90, 0.16, 2.84), Vector3(0.0, 0.49, 0.14), deck_material)
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


func sync_generated_world(world_data: Dictionary) -> void:
	_world_data = world_data
	_sync_generated_world(_world_data)

func _sync_generated_world(world_data: Dictionary) -> void:
	var ship_position: Vector2 = Vector2(GameState.ship_state.get("position", Vector2.ZERO))
	var center_chunk := Vector2i(floori(ship_position.x / _chunk_size), floori(ship_position.y / _chunk_size))
	var keep_islands: Dictionary = {}
	var visible_islands: Dictionary = {}
	for raw_island in world_data.get("islands", []):
		var island: Dictionary = raw_island
		var map_position: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var chunk_x: int = floori(map_position.x / _chunk_size)
		var chunk_y: int = floori(map_position.y / _chunk_size)
		if abs(chunk_x - center_chunk.x) > FOG_RADIUS_CHUNKS or abs(chunk_y - center_chunk.y) > FOG_RADIUS_CHUNKS:
			continue
		var island_id: String = str(island.get("id", ""))
		if island_id == "":
			continue
		keep_islands[island_id] = true
		visible_islands[island_id] = island
		var island_port: Dictionary = _find_port_for_island(island_id)
		var is_home: bool = not island_port.is_empty() and str(island_port.get("id", "")) == str(GameState.world_state.get("home_port_id", ""))
		if _island_nodes.has(island_id):
			var existing: Node3D = _island_nodes[island_id]
			if bool(existing.get_meta("home_base", false)) == is_home:
				continue
			existing.queue_free()
			_island_nodes.erase(island_id)
		var island_root := Node3D.new()
		island_root.set_meta("home_base", is_home)
		island_root.name = island_id
		island_root.position = Vector3(map_position.x * MAP_TO_METERS, 0.0, map_position.y * MAP_TO_METERS)
		_scene_root.add_child(island_root)
		_build_island(island_root, island)
		_island_nodes[island_id] = island_root
	_rendered_island_data = visible_islands
	for island_id in _island_nodes.keys():
		if keep_islands.has(island_id):
			continue
		(_island_nodes[island_id] as Node3D).queue_free()
		_island_nodes.erase(island_id)

	var keep_hazards: Dictionary = {}
	for raw_zone in world_data.get("hazard_zones", []):
		var zone: Dictionary = raw_zone
		if not bool(zone.get("active", false)):
			continue
		var map_position: Vector2 = Vector2(zone.get("position", Vector2.ZERO))
		var chunk_x: int = floori(map_position.x / _chunk_size)
		var chunk_y: int = floori(map_position.y / _chunk_size)
		if abs(chunk_x - center_chunk.x) > 1 or abs(chunk_y - center_chunk.y) > 1:
			continue
		var hazard_id: String = str(zone.get("id", ""))
		if hazard_id == "":
			continue
		keep_hazards[hazard_id] = true
		if _hazard_nodes.has(hazard_id):
			continue
		var zone_type: String = str(zone.get("type", "storm"))
		var color: Color = Color("4a9fae")
		match zone_type:
			"tornado": color = Color("e67935")
			"pirate": color = Color("a43d49")
			"anomaly": color = Color("935ed6")
		var radius: float = maxf(2.0, float(zone.get("radius", 150.0)) * MAP_TO_METERS)
		var disk := CylinderMesh.new()
		disk.top_radius = radius
		disk.bottom_radius = radius
		disk.height = 0.025
		disk.radial_segments = 48
		var marker := MeshInstance3D.new()
		marker.name = "Hazard_" + hazard_id
		marker.mesh = disk
		marker.position = Vector3(map_position.x * MAP_TO_METERS, 0.015, map_position.y * MAP_TO_METERS)
		var material := _material(Color(color.r, color.g, color.b, 0.22), 0.4)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = material
		_scene_root.add_child(marker)
		_hazard_nodes[hazard_id] = marker
	for hazard_id in _hazard_nodes.keys():
		if keep_hazards.has(hazard_id):
			continue
		(_hazard_nodes[hazard_id] as Node3D).queue_free()
		_hazard_nodes.erase(hazard_id)

func _build_island(island_root: Node3D, island: Dictionary) -> void:
	var current_id: String = str(island.get("id", ""))
	var island_position: Vector2 = Vector2(island.get("position", Vector2.ZERO))
	var map_radius: float = float(island.get("radius", 90.0))
	var radius: float = map_radius * MAP_TO_METERS
	var landform: String = str(island.get("landform", "small_island"))
	var port: Dictionary = _find_port_for_island(current_id)
	var harbor_key: String = str(island.get("harbor_variant", ""))
	if harbor_key != "":
		var spec: Dictionary = GameData.read("res://data/world/faction_harbors.json").variants[harbor_key]
		var harbor = load("res://systems/rendering/faction_harbor_3d.gd").new()
		harbor.name = "FactionHarbor"
		island_root.add_child(harbor)
		harbor.rotation.y = PI * 0.5 - float(island.get("bay_angle", 0.0))
		harbor.scale = Vector3.ONE * float(island.visual_radius) * MAP_TO_METERS / float(spec.reference_radius)
		harbor.setup(harbor_key)
		return
	if not port.is_empty() and (bool(island.get("port_city", false)) or str(port.get("id", "")) == str(GameState.world_state.get("home_port_id", ""))):
		var base = load("res://systems/rendering/home_port_preview.gd").new()
		base.name = "HomeBase3D"
		island_root.add_child(base)
		var toward_port: Vector2 = Vector2(port.get("position", island_position)) - island_position
		base.rotation.y = -toward_port.angle() - PI * 0.5
		var reference: float = float(GameData.read("res://data/world/home_base_visuals.json").get("reference_radius_m", 60.0))
		base.scale = Vector3.ONE * float(island.get("visual_radius", map_radius)) * MAP_TO_METERS / reference
		if bool(island.get("port_city", false)):
			base.setup("", 18 + posmod(hash(str(port.get("id", ""))), 13), str(port.get("owner_race_id", "humans")))
		else:
			base.setup(str(port.get("id", "")))
		return
	var port_angle: float = INF
	if not port.is_empty():
		var port_offset: Vector2 = Vector2(port.get("position", island_position)) - island_position
		if port_offset.length_squared() > 0.01:
			port_angle = port_offset.angle()
	# Keep island collision and navigation data, but render lightweight procedural geometry.
	var custom_model: Node3D = null
	if custom_model == null:
		# The 3D shoreline varies deterministically while staying inside the
		# navigation circle used by collision and save data.
		var seed_value: int = abs(hash(current_id))
		var cliff_color: Color = Color("596360") if landform == "sea_cliff" else Color("75654f")
		_add_cylinder(island_root, radius * 0.99, radius * 0.79, 1.1, Vector3(0.0, -0.24, 0.0), cliff_color)
		var coast_color: Color = Color("626d69") if landform == "sea_cliff" else Color("b99a69")
		_add_island_surface(island_root, radius, 0.32, 0.98, seed_value, port_angle, 0.10, 0.24, coast_color)
		if landform != "sea_cliff":
			_add_island_surface(island_root, radius, 0.39, 0.83, seed_value + 31, port_angle, 0.16, 0.22, Color("4f7851"))
		if landform == "great_island":
			for peak_index in range(11):
				var peak_angle: float = TAU * float(peak_index) / 11.0 + float(seed_value % 79) * 0.01
				var peak_distance: float = radius * (0.18 + float((peak_index * 7 + seed_value) % 48) / 100.0)
				var peak_height: float = 8.0 + float((peak_index * 13 + seed_value) % 150) / 10.0
				var peak_radius: float = radius * (0.07 + float(peak_index % 4) * 0.018)
				var peak_at := Vector3(cos(peak_angle) * peak_distance, peak_height * 0.5 + 0.45, sin(peak_angle) * peak_distance)
				_add_cylinder(island_root, peak_radius, peak_radius * 0.06, peak_height, peak_at, Color("718269") if peak_index % 3 else Color("797c75"))
			_add_cylinder(island_root, radius * 0.20, 0.0, 28.0, Vector3(-radius * 0.14, 14.4, -radius * 0.12), Color("747e70"))
		elif landform == "sea_cliff":
			var cliff_height: float = radius * 0.95
			_add_cylinder(island_root, radius * 0.42, radius * 0.04, cliff_height, Vector3(-radius * 0.12, cliff_height * 0.5 + 0.4, 0.0), Color("727d79"))
			_add_cylinder(island_root, radius * 0.31, radius * 0.02, cliff_height * 0.78, Vector3(radius * 0.27, cliff_height * 0.39 + 0.4, radius * 0.12), Color("626c69"))
		else:
			_add_cylinder(island_root, radius * 0.34, 0.0, 2.9, Vector3(-radius * 0.18, 3.45, -radius * 0.08), Color("607d4c"))
			_add_cylinder(island_root, radius * 0.24, 0.0, 2.1, Vector3(radius * 0.28, 3.1, radius * 0.12), Color("71865a"))
		var tree_count: int = 0 if landform == "sea_cliff" else (8 if landform == "great_island" else 7)
		for index in range(tree_count):
			var angle: float = TAU * float(index) / float(tree_count) + float(seed_value % 31) * 0.01
			var distance: float = radius * (0.20 + float(index % 3) * 0.12)
			var tree_at := Vector3(cos(angle) * distance, 2.0, sin(angle) * distance)
			_add_cylinder(island_root, 0.10, 0.08, 1.2, tree_at + Vector3(0.0, 0.55, 0.0), Color("73553b"))
			_add_cylinder(island_root, 0.85, 0.04, 1.45, tree_at + Vector3(0.0, 1.7, 0.0), Color("326747"))
		if landform == "great_island" and posmod(seed_value, 13) == 0:
			_add_floating_island(island_root, radius, seed_value)

	if not port.is_empty():
		_build_port(island_root, port, island_position, radius)
	elif custom_model == null:
		_add_cylinder(island_root, radius * 0.16, radius * 0.05, 1.5, Vector3(radius * 0.42, 2.1, -radius * 0.35), Color("8a8272"))


func _add_island_surface(parent: Node3D, radius: float, height: float, base_factor: float, seed_value: int, port_angle: float, bay_cut: float, bay_width: float, color: Color) -> void:
	const SEGMENTS: int = 28
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	var seed_phase: float = float(posmod(seed_value, 10000)) * 0.001
	for index in range(SEGMENTS):
		var angle: float = TAU * float(index) / float(SEGMENTS)
		var coast_noise: float = 1.0 + sin(angle * 3.0 + seed_phase) * 0.035 + sin(angle * 7.0 - seed_phase * 0.7) * 0.022 + sin(angle * 13.0 + seed_phase * 1.4) * 0.012
		var factor: float = base_factor * coast_noise
		if not is_inf(port_angle):
			var angle_gap: float = absf(wrapf(angle - port_angle, -PI, PI))
			factor -= bay_cut * exp(-pow(angle_gap / bay_width, 2.0))
		factor = clampf(factor, 0.55, 1.0)
		vertices.append(Vector3(cos(angle) * radius * factor, 0.0, sin(angle) * radius * factor))
	for index in range(SEGMENTS):
		indices.append(0)
		indices.append(1 + ((index + 1) % SEGMENTS))
		indices.append(1 + index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color, 0.92)
	instance.position.y = height
	parent.add_child(instance)


func _add_floating_island(parent: Node3D, main_radius: float, seed_value: int) -> void:
	var floating := Node3D.new()
	floating.name = "FloatingIsland"
	var angle: float = float(posmod(seed_value, 628)) * 0.01
	var float_radius: float = main_radius * 0.20
	var altitude: float = 34.0 + float(posmod(int(float(seed_value) / 7.0), 260)) * 0.12
	floating.position = Vector3(cos(angle) * main_radius * 1.22, altitude, sin(angle) * main_radius * 1.22)
	parent.add_child(floating)
	_add_cylinder(floating, float_radius * 0.70, float_radius * 0.18, float_radius * 0.72, Vector3(0.0, 0.0, 0.0), Color("777c78"))
	_add_cylinder(floating, float_radius * 0.18, float_radius * 0.48, 0.9, Vector3(0.0, float_radius * 0.39, 0.0), Color("51865e"))
	_add_cylinder(floating, 0.0, float_radius * 0.10, float_radius * 0.86, Vector3(-float_radius * 0.26, -float_radius * 0.70, 0.0), Color("686e6b"))
	_add_cylinder(floating, 0.0, float_radius * 0.07, float_radius * 0.62, Vector3(float_radius * 0.28, -float_radius * 0.56, float_radius * 0.12), Color("686e6b"))


func _attach_catalog_scene(parent: Node3D, category: String, identity: String, target_size_m: float, faction_id: String = "") -> Node3D:
	if category == "ships" and bool(GameData.get_ship(identity).get("warship", false)):
		return preload("res://systems/rendering/naval_ship_factory.gd").new().attach(parent, identity, target_size_m)
	var categories: Dictionary = _asset_catalog.get("categories", {})
	var entries: Array = categories.get(category, [])
	if category == "ships" and faction_id != "":
		var racial: Dictionary = GameData.read("res://data/world/faction_ship_visuals.json").get("factions", {}).get(faction_id, {}).get(identity, {})
		if not racial.is_empty():
			entries = [racial]
	if entries.is_empty() or identity == "":
		return preload("res://systems/rendering/naval_ship_factory.gd").new().attach(parent,identity,target_size_m,true,faction_id) if category == "ships" and identity != "" else null
	var available: Array[Dictionary] = []
	for raw_entry in entries:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		var identities: Array = entry.get("identities", [])
		if not identities.is_empty() and not identities.has(identity):
			continue
		var scene_path: String = str(entry.get("scene", ""))
		if scene_path != "" and ResourceLoader.exists(scene_path):
			available.append(entry)
	if available.is_empty():
		return preload("res://systems/rendering/naval_ship_factory.gd").new().attach(parent,identity,target_size_m,true,faction_id) if category == "ships" else null
	var chosen: Dictionary = available[posmod(abs(hash("%d:%s" % [int(GameState.world_state.get("seed", 0)), identity])), available.size())]
	var packed_scene: PackedScene = load(str(chosen.get("scene", ""))) as PackedScene
	if packed_scene == null:
		return null
	var instance: Node = packed_scene.instantiate()
	var wrapper := Node3D.new()
	wrapper.name = "Asset_" + identity.replace("/", "_").replace(":", "_")
	wrapper.set_meta("world_asset_id", str(chosen.get("id", "")))
	parent.add_child(wrapper)
	wrapper.add_child(instance)
	var reference_size: float = maxf(0.01, float(chosen.get("reference_size_m", target_size_m)))
	wrapper.set_meta("reference_length", reference_size)
	var asset_scale: float = target_size_m / reference_size * float(chosen.get("scale", 1.0))
	wrapper.scale = Vector3.ONE * asset_scale
	wrapper.rotation_degrees.y = float(chosen.get("rotation_y_degrees", 0.0))
	var placement_offset: Array = chosen.get("offset_m", [0.0, 0.0, 0.0])
	if placement_offset.size() >= 3:
		wrapper.position = Vector3(float(placement_offset[0]), float(placement_offset[1]), float(placement_offset[2]))
	return wrapper


func _find_port_for_island(island_id: String) -> Dictionary:
	for raw_port in _world_data.get("ports", {}).values():
		var port: Dictionary = raw_port
		if str(port.get("island_id", "")) == island_id:
			return port
	return {}


func _build_port(island_root: Node3D, port: Dictionary, island_position: Vector2, island_radius: float) -> void:
	var port_position: Vector2 = Vector2(port.get("position", island_position))
	var local_port: Vector2 = (port_position - island_position) * MAP_TO_METERS
	var outward_2d: Vector2 = Vector2.from_angle(float(port.get("harbor_angle", local_port.angle())))
	if outward_2d.length_squared() < 0.01:
		outward_2d = Vector2.RIGHT
	var outward := Vector3(outward_2d.x, 0.0, outward_2d.y)
	var pier_yaw: float = atan2(outward.x, outward.z)
	var pier_right := Vector3(outward.z, 0.0, -outward.x)
	var bay_radius: float = maxf(2.0, float(port.get("harbor_radius", island_radius * 0.18)) * MAP_TO_METERS)
	_add_port_shoals(island_root, Vector3(local_port.x, 0.0, local_port.y), outward, pier_right, pier_yaw, bay_radius)
	var registered_port: Node3D = _attach_catalog_scene(island_root, "ports", str(port.get("id", "port")), 8.0)
	if registered_port != null:
		registered_port.position += Vector3(local_port.x, 0.0, local_port.y)
		registered_port.rotation.y = atan2(outward.x, outward.z)
		return
	var bay_water := CylinderMesh.new()
	bay_water.top_radius = bay_radius
	bay_water.bottom_radius = bay_radius
	bay_water.height = 0.035
	bay_water.radial_segments = 32
	var bay_surface := MeshInstance3D.new()
	bay_surface.name = "NaturalHarborWater"
	bay_surface.mesh = bay_water
	bay_surface.material_override = _material(Color("247b91"), 0.35)
	bay_surface.position = Vector3(local_port.x, 0.05, local_port.y)
	island_root.add_child(bay_surface)
	var dock_start: Vector3 = Vector3(local_port.x, 0.12, local_port.y) + outward * 1.1
	for berth_side in [-1.0, 1.0]:
		var pier_center := Vector3(local_port.x, 0.12, local_port.y) + outward * 2.6 + pier_right * float(berth_side) * 5.0
		var pier := _add_box(island_root, Vector3(1.45, 0.24, 7.2), pier_center, _material(Color("765238"), 0.95))
		pier.name = "SolidBerthPier"
		pier.rotation.y = pier_yaw
		for side_value in [-1.0, 1.0]:
			for distance_value in [-3.0, 0.0, 3.0]:
				var piling_at: Vector3 = pier_center + outward * float(distance_value) + pier_right * float(side_value) * 0.58 + Vector3(0.0, -0.12, 0.0)
				_add_cylinder(island_root, 0.12, 0.12, 0.95, piling_at, Color("4b3829"))

	# Warehouses and small port buildings sit between the beach and the pier.
	var landward: Vector3 = -outward
	var settlement_center: Vector3 = Vector3(local_port.x, 0.0, local_port.y) + landward * 1.8
	var district = load("res://systems/rendering/npc_port_district.gd").new()
	district.name = "NpcPortDistrict_" + str(port.get("id", "port"))
	district.position = settlement_center
	district.rotation.y = pier_yaw
	island_root.add_child(district)
	var owner: String = load("res://systems/world/port_faction_resolver.gd").new().resolve(port, int(GameState.world_state.get("seed", 0)))
	district.setup(owner, island_radius)


func _add_port_shoals(parent: Node3D, harbor: Vector3, outward: Vector3, right: Vector3, yaw: float, bay_radius: float) -> void:
	# Submerged sand tongues tint the water lagoon-green before the steep shore begins.
	var sand := _material(Color("d6bf86"), 0.96)
	for side_value in [-1.0, 1.0]:
		for index in range(3):
			var side: float = float(side_value)
			var along: float = -0.45 + float(index) * 0.54
			var spread: float = 0.58 + float(index % 2) * 0.36
			var patch := MeshInstance3D.new()
			patch.name = "SubmergedSandShoal"
			var shape := SphereMesh.new()
			shape.radius = 1.0
			shape.height = 1.7
			shape.radial_segments = 28
			shape.rings = 12
			patch.mesh = shape
			patch.material_override = sand
			patch.scale = Vector3(bay_radius * 0.34, 0.035, bay_radius * (0.32 + float(index % 2) * 0.08))
			patch.rotation.y = yaw + float(index - 1) * 0.22
			patch.position = harbor + outward * bay_radius * along + right * side * bay_radius * spread + Vector3(0.0, -0.26, 0.0)
			parent.add_child(patch)
	return


func _add_harbor_gate(parent: Node3D, center: Vector3, pier_right: Vector3, bay_radius: float) -> void:
	var stone_color: Color = Color("7c908d")
	var bronze_color: Color = Color("a98c61")
	var stone := _material(stone_color, 0.88)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		var statue := Node3D.new()
		statue.name = "HarborGateStatue"
		statue.position = center + pier_right * side * maxf(5.0, bay_radius * 0.78)
		parent.add_child(statue)
		_add_cylinder(statue, 1.35, 1.02, 8.0, Vector3(0.0, 4.0, 0.0), stone_color)
		_add_cylinder(statue, 1.50, 1.30, 0.65, Vector3(0.0, 0.65, 0.0), bronze_color)
		_add_cylinder(statue, 1.12, 1.38, 0.55, Vector3(0.0, 8.25, 0.0), bronze_color)
		var head := SphereMesh.new()
		head.radius = 1.0
		head.height = 2.2
		head.radial_segments = 10
		head.rings = 6
		var head_node := MeshInstance3D.new()
		head_node.mesh = head
		head_node.material_override = stone
		head_node.position = Vector3(0.0, 9.5, 0.0)
		statue.add_child(head_node)
		var shoulder := _add_box(statue, Vector3(3.1, 0.82, 1.0), Vector3(0.0, 6.75, 0.0), stone)
		shoulder.rotation.z = -side * 0.08
		var arm := _add_box(statue, Vector3(0.68, 3.0, 0.78), Vector3(side * 1.25, 5.25, 0.0), stone)
		arm.rotation.z = side * 0.12


func _sync_fog(ship_position: Vector2) -> void:
	var center := Vector2i(floori(ship_position.x / _chunk_size), floori(ship_position.y / _chunk_size))
	var explored_chunks: Dictionary = GameState.world_state.get("explored_chunks", {})
	if center == _fog_center and explored_chunks.size() == _fog_explored_count:
		for raw_tile in _fog_tiles.values():
			var fog_tile: Node3D = raw_tile as Node3D
			if fog_tile != null and is_instance_valid(fog_tile):
				fog_tile.visible = _transition_factor < 0.35
		return
	_fog_center = center
	_fog_explored_count = explored_chunks.size()
	var keep_tiles: Dictionary = {}
	for chunk_y in range(center.y - FOG_RADIUS_CHUNKS, center.y + FOG_RADIUS_CHUNKS + 1):
		for chunk_x in range(center.x - FOG_RADIUS_CHUNKS, center.x + FOG_RADIUS_CHUNKS + 1):
			var chunk_key: String = "%d:%d" % [chunk_x, chunk_y]
			if explored_chunks.has(chunk_key):
				continue
			keep_tiles[chunk_key] = true
			var fog_tile: Node3D = _fog_tiles.get(chunk_key) as Node3D
			if fog_tile == null or not is_instance_valid(fog_tile):
				fog_tile = _create_fog_tile(chunk_x, chunk_y)
				_scene_root.add_child(fog_tile)
				_fog_tiles[chunk_key] = fog_tile
			fog_tile.visible = _transition_factor < 0.35
	for raw_key in _fog_tiles.keys():
		var chunk_key: String = str(raw_key)
		if keep_tiles.has(chunk_key):
			continue
		var stale_tile: Node3D = _fog_tiles[chunk_key] as Node3D
		if stale_tile != null and is_instance_valid(stale_tile):
			stale_tile.queue_free()
		_fog_tiles.erase(chunk_key)


func _create_fog_tile(chunk_x: int, chunk_y: int) -> Node3D:
	var tile := MeshInstance3D.new()
	tile.name = "UnknownSea_%d_%d" % [chunk_x, chunk_y]
	var plane := PlaneMesh.new()
	plane.size = Vector2(_chunk_size * MAP_TO_METERS, _chunk_size * MAP_TO_METERS)
	tile.mesh = plane
	var fog_material := StandardMaterial3D.new()
	fog_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fog_material.albedo_color = Color(0.035, 0.085, 0.13, 0.92)
	tile.material_override = fog_material
	tile.position = Vector3(
		(float(chunk_x) + 0.5) * _chunk_size * MAP_TO_METERS,
		FOG_HEIGHT,
		(float(chunk_y) + 0.5) * _chunk_size * MAP_TO_METERS
	)
	return tile


func _sync_traffic(traffic_renderer: Node, traffic_group: String) -> void:
	if traffic_renderer == null or not traffic_renderer.has_method("get_vessel_snapshots"):
		return
	var raw_snapshots: Variant = traffic_renderer.call("get_vessel_snapshots")
	if not (raw_snapshots is Array):
		return

	var keep_models: Dictionary = {}
	for raw_snapshot in raw_snapshots:
		if not (raw_snapshot is Dictionary):
			continue
		var vessel: Dictionary = raw_snapshot
		var vessel_id: String = str(vessel.get("id", ""))
		if vessel_id == "":
			continue
		var model_key: String = traffic_group + ":" + vessel_id
		keep_models[model_key] = true
		var model: Node3D = _traffic_models.get(model_key) as Node3D
		var wanted_identity := str(vessel.get("ship_type_id", "ship_barque"))
		var faction_id: String = str(vessel.get("faction_id", GameState.player_state.get("origin_race_id", "humans"))) if traffic_group == "fleet" else str(vessel.get("faction_id", "humans"))
		wanted_identity += ":" + faction_id
		if is_instance_valid(model) and str(model.get_meta("ship_identity", wanted_identity)) != wanted_identity:
			model.queue_free()
			model = null
		if model == null or not is_instance_valid(model):
			var identity: String = str(vessel.get("ship_type_id", vessel.get("kind", "merchant")))
			if GameData.get_ship(identity).is_empty():
				identity = "ship_barque"
			var target_length: float = maxf(3.48, float(vessel.get("length", 87.0)) * MAP_TO_METERS)
			model = _attach_catalog_scene(_scene_root, "ships", identity, target_length, faction_id)
			if model == null:
				model = _make_traffic_ship(vessel)
				_scene_root.add_child(model)
			else:
				var visual: Dictionary = GameData.read("res://data/world/ship_visuals.json").get("ships", {}).get(identity, {})
				var heraldry = load("res://systems/rendering/faction_base_style.gd").new()
				heraldry.apply_ship(model, faction_id)
				_add_ship_lanterns(model, visual.get("lamps", []), false)
				var flag: Node3D = heraldry.make_flag(faction_id)
				var anchor: Array = visual.get("flag_at", [0.0, 1.3, 2.6])
				flag.position = Vector3(float(anchor[0]), float(anchor[1]), float(anchor[2]))
				flag.scale = Vector3.ONE * 0.28
				model.add_child(flag)
			model.name = "Traffic_" + model_key.replace(":", "_").replace("/", "_")
			_traffic_models[model_key] = model
			model.set_meta("ship_identity", wanted_identity)
		if model.has_meta("reference_length"):
			model.scale = Vector3.ONE * maxf(3.48, float(vessel.get("length", 87.0)) * MAP_TO_METERS) / float(model.get_meta("reference_length"))
		var position: Vector2 = Vector2(vessel.get("position", Vector2.ZERO))
		var heading: Vector2 = Vector2(vessel.get("heading", Vector2.UP))
		if heading.length_squared() < 0.001:
			heading = Vector2.UP
		model.position = Vector3(position.x * MAP_TO_METERS, 0.12, position.y * MAP_TO_METERS)
		model.rotation.y = -heading.angle() - PI * 0.5
		var motion_time: float = Time.get_ticks_msec() * 0.001 + float(posmod(hash(model_key),100))/10.0
		var hull_factor: float = clampf(100.0/maxf(80.0,float(vessel.get("length",100))),.4,1.0)
		var sink: float=smoothstep(0.0,1.0,clampf(float(vessel.get("sink_progress",0)),0.0,1.0))
		var visible_length: float=maxf(3.48,float(vessel.get("length",87.0))*MAP_TO_METERS)
		var sink_roll: float=-1.0 if posmod(hash(vessel_id),2)==0 else 1.0
		model.position.y = SEA_LEVEL + 0.04 + sin(motion_time*1.35)*.018*hull_factor-sink*(.8+visible_length*.34)
		model.rotation.x = sin(motion_time*.85)*.008*hull_factor+sink*.22
		model.rotation.z = sin(motion_time*1.1)*.013*hull_factor + clampf(float(vessel.get("turn_velocity",0))*-.07,-.05,.05)+sink*sink_roll*.18

	for raw_model_key in _traffic_models.keys():
		var model_key: String = str(raw_model_key)
		if not model_key.begins_with(traffic_group + ":") or keep_models.has(model_key):
			continue
		var stale_model: Node3D = _traffic_models[model_key] as Node3D
		if stale_model != null and is_instance_valid(stale_model):
			stale_model.queue_free()
		_traffic_models.erase(model_key)


func _make_traffic_ship(vessel: Dictionary) -> Node3D:
	var length: float = maxf(0.6, float(vessel.get("length", 24.0)) * MAP_TO_METERS)
	var width: float = length * 0.28
	var accent: Color = vessel.get("color", Color("6da9bd"))
	var ship := Node3D.new()
	var hull_color: Color = Color("503629") if str(vessel.get("kind", "")) != "fleet" else Color("344a58")
	_add_box(ship, Vector3(width, 0.22, length), Vector3(0.0, 0.16, 0.0), _material(hull_color, 0.78))
	_add_box(ship, Vector3(width * 0.82, 0.10, length * 0.72), Vector3(0.0, 0.32, 0.02), _material(Color("b58955"), 0.84))
	_add_box(ship, Vector3(width * 0.48, 0.28, length * 0.20), Vector3(0.0, 0.49, length * 0.18), _material(accent.darkened(0.25), 0.8))
	var mast_height: float = maxf(0.7, length * 0.55)
	_add_cylinder(ship, maxf(0.025, length * 0.012), maxf(0.025, length * 0.012), mast_height, Vector3(0.0, mast_height * 0.5 + 0.42, -length * 0.04), Color("594434"))
	_add_sail(ship, Vector2(width * 0.82, mast_height * 0.62), Vector3(0.0, mast_height * 0.70 + 0.42, -length * 0.04), _material(Color("eee3c8").lerp(accent, 0.18), 0.92))
	return ship


func _update_camera(ship_position: Vector2, close_factor: float, delta: float, move_camera: bool = true) -> void:
	var velocity: Vector2 = Vector2(GameState.ship_state.get("velocity", Vector2.ZERO))
	var heading: float = float(GameState.ship_state.get(
		"heading",
		velocity.angle() if velocity.length_squared() > 1.0 else -PI * 0.5
	))
	# Godot's 3D ship points along local -Z. This yaw maps that nose to the same
	# direction as the 2D velocity vector (x right, y down).
	var yaw: float = -heading - PI * 0.5
	_ship.rotation.y = lerp_angle(_ship.rotation.y, yaw, 1.0 - exp(-delta * 5.0))
	var ship_world_position := Vector3(ship_position.x * MAP_TO_METERS, 0.0, ship_position.y * MAP_TO_METERS)
	if _sailing_gulls != null:
		_sailing_gulls.position = ship_world_position
	_ship.position = ship_world_position
	_ship.position.y = SEA_LEVEL + 0.04
	_ship.rotation.x = 0.0
	_ship.rotation.z = 0.0

	if not move_camera: return
	var forward := Vector3(cos(heading), 0.0, sin(heading))
	var map_zoom: Vector2 = Vector2.ONE
	var map_camera: Camera2D = get_viewport().get_camera_2d()
	if map_camera != null:
		map_zoom = map_camera.zoom
	var map_view_height: float = get_viewport().get_visible_rect().size.y / maxf(map_zoom.y, 0.01) * MAP_TO_METERS
	var start_fov: float = 18.0
	var top_down_height: float = map_view_height / (2.0 * tan(deg_to_rad(start_fov * 0.5)))
	var camera_back: float = lerpf(0.0, 14.0, close_factor)
	var camera_height: float = lerpf(top_down_height, 5.2, close_factor)
	var orbit_forward: Vector3 = forward.rotated(Vector3.UP, _camera_orbit_yaw)
	var desired_camera_position: Vector3 = ship_world_position - orbit_forward * camera_back + Vector3.UP * camera_height
	if _camera_initialized:
		_camera.position = _camera.position.lerp(desired_camera_position, 1.0 - exp(-delta * 3.5))
	else:
		_camera.position = desired_camera_position
		_camera_initialized = true
	var look_distance: float = lerpf(0.0, 8.0, close_factor)
	var focus: Vector3 = ship_world_position + orbit_forward * look_distance + Vector3.UP * (0.8 * close_factor + tan(_camera_orbit_pitch) * 12.0 * close_factor)
	var map_up := Vector3(0.0, 0.0, -1.0)
	_camera.look_at(focus, map_up.lerp(Vector3.UP, close_factor).normalized())
	_camera.fov = lerpf(start_fov, 58.0, close_factor)



func _update_battle_camera(ship_position: Vector2, delta: float) -> void:
	# At the distant sailing zoom, cannon impacts were only a few pixels wide.
	# Frame the nearby participants in the unobstructed three quarters of the screen.
	_update_camera(ship_position,1.0,delta,false)
	var minimum: Vector2 = ship_position
	var maximum: Vector2 = ship_position
	var battle: Dictionary = GameState.combat_state.get("naval_battle",{})
	for ship in GameState.fleet_state:
		if not battle.get("ship_ids",[]).has(str(ship.get("instance_id",""))): continue
		var point: Vector2 = _map_vector(ship.get("escort_state",{}).get("position",ship_position))
		if point.distance_to(ship_position)>1500: continue
		minimum=minimum.min(point); maximum=maximum.max(point)
	for id in battle.get("enemy_ids",[]):
		var enemy: Dictionary = GameState.combat_state.get("naval_enemies",{}).get(id,{})
		if enemy.is_empty(): continue
		var point: Vector2 = _map_vector(enemy.get("position",ship_position))
		minimum=minimum.min(point); maximum=maximum.max(point)
	var middle: Vector2 = (minimum+maximum)*.5
	var span: float = maxf(23.0,(maximum-minimum).length()*MAP_TO_METERS+12.0)
	var center := Vector3(middle.x*MAP_TO_METERS,.6,middle.y*MAP_TO_METERS)
	var right := Vector3.RIGHT
	var focus: Vector3 = center+right*span*.15
	var desired: Vector3 = focus+Vector3(0,span*.85,span*.6)
	_camera.position=_camera.position.lerp(desired,1-exp(-delta*4.0))
	_camera.look_at(focus,Vector3.UP)
	_camera.fov=58.0

func _map_vector(value: Variant) -> Vector2:
	if value is Vector2: return value
	if value is Array and value.size()>=2: return Vector2(float(value[0]),float(value[1]))
	if value is Dictionary: return Vector2(float(value.get("x",0)),float(value.get("y",0)))
	return Vector2.ZERO

func _find_nearest_island(ship_position: Vector2) -> Dictionary:
	var closest: Dictionary = {}
	var best_gap: float = INF
	for island in _rendered_island_data.values():
		var island_position: Vector2 = Vector2(island.get("position", Vector2.ZERO))
		var radius: float = float(island.get("radius", 0.0))
		var gap: float = maxf(0.0, ship_position.distance_to(island_position) - radius)
		if gap < best_gap:
			best_gap = gap
			closest = island
	return closest


func _set_transition(target: float, delta: float) -> void:
	_transition_factor = lerpf(_transition_factor, target, 1.0 - exp(-delta * 1.7))
	# The transition changes only the camera: both the map view and close view
	# are rendered from this same 3D scene at the same world coordinates.
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


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
