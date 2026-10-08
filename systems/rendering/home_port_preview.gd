extends Node3D

## Lightweight sailing preview. Docked town art carries the detailed buildings.
## This view reads progress but never changes construction, collision, or saves.
const Island = preload("res://systems/rendering/low_poly_island.gd")
var _manifest: Dictionary = {}
var _port_id: String = ""
var _showcase_level: int = 0
var _race: String = "humans"
var _signature: String = ""
var _refresh_clock: float = 0.0
var _district: MeshInstance3D
var _beacons: Array[OmniLight3D] = []
var _glass: StandardMaterial3D
var _night: float = -1.0

func setup(port_id: String, showcase_level: int = 0, faction_id: String = "") -> void:
	_port_id = port_id
	_showcase_level = showcase_level
	_race = faction_id if faction_id != "" else str(GameState.player_state.get("origin_race_id", "humans"))
	_manifest = GameData.read("res://data/world/home_base_visuals.json")
	Island.build(self, _manifest.get("coastline", []), _race)
	# Piers remain at the authored home-port placements and waterline height.
	Island.build_piers(self, [
		[[-29,-25],[-23,-25],[-23,-50],[-29,-50]],
		[[35,-30],[41,-30],[41,-50],[35,-50]]
	], _race)
	_add_landmarks()
	_refresh_buildings()
	set_night_strength(0.0)

func _process(delta: float) -> void:
	if _showcase_level > 0:
		return
	_refresh_clock += delta
	if _refresh_clock >= 1.0:
		_refresh_clock = 0.0
		_refresh_buildings()

func _refresh_buildings() -> void:
	var buildings: Dictionary = GameState.port_state.get(_port_id, {}).get("buildings", {})
	var signature := str(buildings) + str(_showcase_level) + _race
	if signature == _signature:
		return
	_signature = signature
	if is_instance_valid(_district):
		remove_child(_district)
		_district.queue_free()
	var placements: Dictionary = _manifest.get("placements", {}).duplicate(true)
	placements["captain_house"] = [-18, 12, 0, 2.0]
	placements["barracks"] = [13, 10, 0, 2.0]
	var accent: Color = Island._race_color(_race)
	var wall: Color = Color("d5c5a0").lerp(accent, 0.24)
	var roof: Color = accent.darkened(0.30)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels: Dictionary = {}
	for id in placements:
		var level := _showcase_level if _showcase_level > 0 else int(buildings.get(id, {}).get("level", 0))
		if level <= 0 or id in ["dock", "fishing_wharf"]:
			continue
		levels[id] = level
		var at: Array = placements[id]
		var height: float = 2.4 + float(level - 1) * 0.055
		var half_width: float = 3.3
		var depth: float = 2.5
		if id == "mage_guild":
			height *= 2.0
			half_width = 2.0
		elif id in ["warehouse", "shipyard", "barracks"]:
			half_width = 5.0
			depth = 3.4
		Island._append_house(tool, Vector3(float(at[0]), float(at[3]), -float(at[1])), Vector3(half_width, height, depth), wall, roof)
		if level >= 11:
			Island._append_house(tool, Vector3(float(at[0])+half_width+1.0, float(at[3]), -float(at[1])), Vector3(1.4, height*.7, depth*.7), wall, roof)
		if level >= 21:
			Island._append_house(tool, Vector3(float(at[0])-half_width+1.0, float(at[3]), -float(at[1])), Vector3(1.1, height*1.5, 1.1), wall, roof)
	# There is still a town silhouette before the player builds specialised sites.
	for i in 8:
		Island._append_house(tool, Vector3(-15.0+float(i%4)*9.0, 0.3, 12.0+float(i/4)*8.0), Vector3(2.0,2.3,1.6), wall, roof)
	tool.generate_normals()
	_district = MeshInstance3D.new()
	_district.name = "LightweightBuildingDistrict"
	_district.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .92
	_district.material_override = material
	_district.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_district.set_meta("building_levels", levels)
	_district.set_meta("architecture_faction", _race)
	add_child(_district)

func _add_landmarks() -> void:
	var style = preload("res://systems/rendering/faction_base_style.gd").new()
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color("f8bb6d")
	_glass.emission_enabled = true
	_glass.emission = Color("ffc477")
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("cabf9d")
	stone.roughness = .94
	for side in [-1.0, 1.0]:
		var tower := MeshInstance3D.new()
		tower.name = "PortEntranceLighthouse"
		var cylinder := CylinderMesh.new()
		cylinder.bottom_radius = 1.3
		cylinder.top_radius = .8
		cylinder.height = 7.0
		cylinder.radial_segments = 8
		tower.mesh = cylinder
		tower.material_override = stone
		tower.position = Vector3(side*27.0,3.5,-49.0)
		tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tower)
		var lamp := MeshInstance3D.new()
		var globe := SphereMesh.new()
		globe.radius = .65
		globe.height = 1.0
		globe.radial_segments = 8
		globe.rings = 3
		lamp.mesh = globe
		lamp.material_override = _glass
		lamp.position = Vector3(side*27.0,7.3,-49.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		var light := OmniLight3D.new()
		light.position = lamp.position
		light.light_color = Color("ffc477")
		light.omni_range = 12.0
		light.shadow_enabled = false
		add_child(light)
		_beacons.append(light)
		var flag: Node3D = style.make_flag(_race, 7.0)
		flag.position = Vector3(side*30.0,0.0,-42.0)
		add_child(flag)

func set_night_strength(strength: float) -> void:
	if absf(_night-strength) < .005:
		return
	_night = strength
	if _glass != null:
		_glass.emission_energy_multiplier = strength * 2.5
	for beacon in _beacons:
		beacon.visible = strength > .02
		beacon.light_energy = strength * 1.4
