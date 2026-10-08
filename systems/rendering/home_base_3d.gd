extends Node3D

## Presentation of the saved home base. Showcase mode reads no player progress.
var _manifest: Dictionary = {}
var _port_id: String = ""
var _showcase_level: int = 0
var _signature: String = ""
var _refresh_clock: float = 0.0
var _district: Node3D
var _showcase_faction: String = "humans"
var _style = preload("res://systems/rendering/faction_base_style.gd").new()
var _night_strength: float = 0.0
var _life: Node3D
var _people: MultiMeshInstance3D
var _life_clock: float = 0.0
var _beacon_glass: StandardMaterial3D
var _lighthouses: Array[Node3D] = []
var _beam_material: ShaderMaterial
var _street_lights: Array[OmniLight3D] = []
var _street_glass: StandardMaterial3D

func set_night_strength(strength: float) -> void:
	_night_strength = strength
	if _street_glass != null:
		_street_glass.emission_energy_multiplier = strength * 2.5
	for light in _street_lights:
		light.visible = strength > 0.02
		light.light_energy = strength * 0.7
	_style.set_night_strength(strength)
	if has_node("SkyHarbor"):
		get_node("SkyHarbor").set_night_strength(strength)
	if _beacon_glass != null:
		_beacon_glass.emission_energy_multiplier = strength * 3.0
	if _beam_material != null:
		_beam_material.set_shader_parameter("night_strength", strength)
	for rig in _lighthouses:
		rig.visible = strength > 0.02
		var light: SpotLight3D = rig.get_node("SweepLight")
		light.light_energy = strength * 3.5

func set_showcase_faction(faction_id: String) -> void:
	_showcase_faction = faction_id
	_signature = ""
	_refresh_buildings()
	if has_node("SkyHarbor"):
		get_node("SkyHarbor").set_faction(faction_id)

func setup(port_id: String, showcase_level: int = 0) -> void:
	_port_id = port_id
	_showcase_level = showcase_level
	_manifest = GameData.read("res://data/world/home_base_visuals.json")
	var terrain_race := _showcase_faction if _showcase_level > 0 else str(GameState.player_state.get("origin_race_id", "humans"))
	load("res://systems/rendering/low_poly_island.gd").build(self, _manifest.get("coastline", []), terrain_race, false)
	_add_home_shoals()
	_refresh_buildings()
	_setup_lighthouses()
	_setup_street_lights()
	var gulls = load("res://systems/rendering/seabird_flock.gd").new()
	gulls.name = "BayGulls"
	add_child(gulls)
	var sky = load("res://systems/rendering/sky_harbor.gd").new()
	sky.name = "SkyHarbor"
	add_child(sky)
	var sky_offset: Array = GameData.read("res://data/world/sky_harbor_visuals.json").get("port_offset_m", [360.0, 55.0, -500.0])
	var parent_scale: float = maxf(absf(scale.x), 0.01)
	sky.position = Vector3(float(sky_offset[0]), float(sky_offset[1]), float(sky_offset[2])) / parent_scale
	sky.scale = Vector3.ONE / parent_scale
	sky.set_faction(_showcase_faction if _showcase_level > 0 else str(GameState.player_state.get("origin_race_id", "humans")))

func _add_home_shoals() -> void:
	# Pale sandy shelves just under the bay surface make the port shallows read as shallow water.
	for side_value in [-1.0, 1.0]:
		for index in range(3):
			var shoal := MeshInstance3D.new()
			shoal.name = "HomePortSandShoal"
			var mesh := SphereMesh.new()
			mesh.radius = 1.0
			mesh.height = 1.6
			mesh.radial_segments = 36
			mesh.rings = 12
			shoal.mesh = mesh
			var sand := StandardMaterial3D.new()
			sand.albedo_color = Color("d5bd82").lerp(Color("e2cf9d"), float(index) * 0.18)
			sand.roughness = 0.98
			shoal.material_override = sand
			shoal.scale = Vector3(8.0 + float(index % 2) * 2.4, 0.035, 4.5 + float(index % 2) * 1.2)
			shoal.position = Vector3(float(side_value) * (22.0 + float(index) * 5.2), -0.26, -49.0 + float(index) * 6.7)
			add_child(shoal)

func set_showcase_level(level: int) -> void:
	_showcase_level = clampi(level, 1, 30)
	_signature = ""
	_refresh_buildings()

func _process(delta: float) -> void:
	_life_clock += delta
	_update_people()
	for index in range(_lighthouses.size()):
		_lighthouses[index].rotation.y = _life_clock * 0.22 + float(index) * PI
	if _showcase_level > 0:
		return
	_refresh_clock += delta
	if _refresh_clock >= 1.0:
		_refresh_clock = 0.0
		_refresh_buildings()

func _load_model(path: String) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null

func _setup_lighthouses() -> void:
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = load("res://assets/world/props/lighthouse/light_beam.gdshader")
	for side in [-1.0, 1.0]:
		var tower: Node3D = _load_model("res://assets/world/props/lighthouse/stylized_lighthouse.glb")
		if tower != null:
			tower.position = Vector3(float(side) * 27.0, 0.0, -49.0)
			add_child(tower)
			_style.apply_surface_details(tower)
		var rig := Node3D.new()
		rig.name = "HarborLighthouse_%d" % _lighthouses.size()
		rig.position = Vector3(float(side) * 27.0, 7.5, -49.0)
		add_child(rig)
		var light := SpotLight3D.new()
		light.name = "SweepLight"
		light.light_color = Color("ffcf87")
		light.spot_range = 120.0
		light.spot_angle = 7.0
		light.spot_attenuation = 0.5
		light.shadow_enabled = false
		rig.add_child(light)
		var beam := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 7.0
		cone.height = 100.0
		cone.radial_segments = 16
		beam.mesh = cone
		beam.rotation.x = PI * 0.5
		beam.position.z = -50.0
		beam.material_override = _beam_material
		rig.add_child(beam)
		_lighthouses.append(rig)
	set_night_strength(_night_strength)

func _setup_street_lights() -> void:
	_street_glass = StandardMaterial3D.new()
	_street_glass.albedo_color = Color("f5ba65")
	_street_glass.emission_enabled = true
	_street_glass.emission = Color("ffb859")
	for index in range(24):
		var post: Node3D = _load_model("res://assets/world/props/lamps/kerosene_post.glb")
		if post == null:
			continue
		var side: float = -1.0 if index % 2 == 0 else 1.0
		post.position = Vector3(side * (23.0 if index < 12 else 34.0), 1.15, -22.0 + float(index / 2) * 5.6)
		add_child(post)
		_style.apply_surface_details(post)
		var flame := MeshInstance3D.new()
		var bulb := SphereMesh.new()
		bulb.radius = 0.075
		bulb.height = 0.25
		flame.mesh = bulb
		flame.material_override = _street_glass
		flame.position = Vector3(0.58, 2.54, 0.0)
		post.add_child(flame)
		# Eight local lights plus visible flames on every post limit GPU light cost.
		if index % 3 == 0:
			var light := OmniLight3D.new()
			light.position = flame.position
			light.light_color = Color("ffcb82")
			light.omni_range = 6.5
			light.shadow_enabled = false
			post.add_child(light)
			_street_lights.append(light)
	set_night_strength(_night_strength)

func _refresh_buildings() -> void:
	var port: Dictionary = GameState.port_state.get(_port_id, {})
	var buildings: Dictionary = port.get("buildings", {})
	var towers: Array = GameState.combat_state.get("towers", [])
	var faction_id: String = _showcase_faction if _showcase_level > 0 else str(GameState.player_state.get("origin_race_id", "humans"))
	var signature: String = str(_showcase_level) + str(buildings) + str(towers) + faction_id
	if signature == _signature:
		return
	_signature = signature
	if is_instance_valid(_district):
		remove_child(_district)
		_district.queue_free()
	_district = Node3D.new()
	_district.name = "BuildingDistrict"
	add_child(_district)
	var variants: Dictionary = _manifest.get("buildings", {})
	var placements: Dictionary = _manifest.get("placements", {})
	for id in variants:
		var saved: Dictionary = buildings.get(id, {})
		var level: int = _showcase_level if _showcase_level > 0 else int(saved.get("level", 0))
		if level <= 0:
			continue
		var entries: Array = variants[id]
		var entry: Dictionary = entries[clampi(level - 1, 0, entries.size() - 1)]
		var building: Node3D = _load_model(str(entry.get("scene", "")))
		if building == null:
			continue
		building.name = str(id)
		building.set_meta("building_level", level)
		var at: Array = placements.get(id, [0, 0, 0])
		building.position = Vector3(float(at[0]), float(at[3]) if at.size() > 3 else 0.82, -float(at[1]))
		building.rotation.y = deg_to_rad(float(at[2]))
		building.scale = Vector3.ONE * float(_manifest.get("building_scales", {}).get(id, 1.0))
		_district.add_child(building)
		_style.apply(building, str(id), faction_id, level)
	var tower_positions: Array = _manifest.get("tower_positions", [])
	var count: int = tower_positions.size() if _showcase_level > 0 else mini(towers.size(), tower_positions.size())
	for index in range(count):
		var tower: Node3D = _load_model(str(_manifest.get("tower", "")))
		if tower == null:
			continue
		tower.name = "IslandTower_%d" % index
		var at: Array = tower_positions[index]
		tower.position = Vector3(float(at[0]), 1.1, -float(at[1]))
		tower.scale = Vector3.ONE * float(_manifest.get("tower_scale", 1.0))
		_district.add_child(tower)
		_style.apply_tower(tower, faction_id)
		var flag: Node3D = _style.make_flag(faction_id, 3.2)
		flag.position = Vector3(0.8, 5.8, 0.3)
		tower.add_child(flag)
		var crystal_id: String = "showcase" if _showcase_level > 0 else str(towers[index].get("crystal_id", ""))
		if crystal_id != "":
			_add_crystal(tower, crystal_id)
	_refresh_city_life(buildings, faction_id)
	_style.set_night_strength(_night_strength)

func _refresh_city_life(buildings: Dictionary, faction_id: String) -> void:
	if is_instance_valid(_life):
		remove_child(_life)
		_life.queue_free()
	_life = Node3D.new()
	_life.name = "CityLife"
	add_child(_life)
	var total: int = 0
	for building in buildings.values():
		total += int(building.get("level", 0))
	if _showcase_level > 0:
		total = _showcase_level * 8
	var quarters: Array = _manifest.get("city_quarters", [])
	var count: int = mini(quarters.size(), 2 + total / 15)
	for index in range(count):
		var quarter := _load_model(str(_manifest.get("city_quarter", "")))
		if quarter == null:
			continue
		var at: Array = quarters[index]
		quarter.name = "CivilianQuarter_%d" % index
		quarter.position = Vector3(at[0], at[3], -at[1])
		quarter.rotation.y = deg_to_rad(float(at[2]))
		_life.add_child(quarter)
		_style.apply_city_quarter(quarter, faction_id)
	for raw in _manifest.get("flag_positions", []):
		var flag: Node3D = _style.make_flag(faction_id, 6.5)
		flag.position = Vector3(raw[0], raw[2], -raw[1])
		flag.scale = Vector3.ONE * 1.5
		_life.add_child(flag)
	if _beacon_glass == null:
		_beacon_glass = StandardMaterial3D.new()
		_beacon_glass.albedo_color = Color("8a652f")
		_beacon_glass.emission_enabled = true
		_beacon_glass.emission = Color("ffc77b")
		_beacon_glass.emission_energy_multiplier = _night_strength * 3.0
	for side in [-1.0, 1.0]:
		var beacon := MeshInstance3D.new()
		var globe := SphereMesh.new()
		globe.radius = 0.73
		globe.height = 0.9
		beacon.mesh = globe
		beacon.material_override = _beacon_glass
		beacon.position = Vector3(float(side) * 27.0, 7.5, -49.0)
		_life.add_child(beacon)
func _update_people() -> void:
	if not is_instance_valid(_people):
		return
	for index in range(_people.multimesh.instance_count):
		var phase := _life_clock * 0.12 + float(index) * 1.72
		var at := Vector3(sin(phase) * 8.0, 1.72, -7.0 + cos(phase) * 2.5)
		if index % 3 != 0:
			var side: float = -1.0 if index % 2 == 0 else 1.0
			at = Vector3(side * 31.0, 1.72, -34.0 + sin(phase) * 8.0)
		at.y += absf(sin(phase * 12.0)) * 0.025
		_people.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))

func _add_crystal(tower: Node3D, crystal_id: String) -> void:
	var color: Color = Color("5de6f5")
	if crystal_id.contains("power"):
		color = Color("ff885c")
	elif crystal_id.contains("guard"):
		color = Color("65a9ff")
	elif crystal_id.contains("wind") or crystal_id.contains("luck"):
		color = Color("b3ef80")
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.30
	mesh.height = 1.2
	mesh.radial_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.65
	var gem := MeshInstance3D.new()
	gem.name = "InstalledCrystal"
	gem.mesh = mesh
	gem.material_override = material
	gem.position.y = 6.65
	tower.add_child(gem)
