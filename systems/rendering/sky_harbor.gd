extends Node3D
## Visual sky port; independent of the saved economy and sea navigation.
var _manifest: Dictionary
var _district: Node3D
var _style = preload("res://systems/rendering/faction_base_style.gd").new()

func _ready() -> void:
	_manifest = GameData.read("res://data/world/sky_harbor_visuals.json")
	var low_poly = load("res://systems/rendering/low_poly_island.gd")
	for index in _manifest.get("islands", []).size():
		var raw: Array = _manifest.islands[index]
		var radius := float(raw[3])
		var outline: Array = []
		for segment in 16:
			var angle := TAU * float(segment) / 16.0
			outline.append([cos(angle) * radius, sin(angle) * radius])
		var floating := Node3D.new()
		floating.name = "LowPolyCloudIsland_%d" % index
		floating.position = Vector3(float(raw[0]), float(raw[2]), -float(raw[1]))
		add_child(floating)
		low_poly.build(floating, outline, "aery", true)

func set_faction(faction_id: String) -> void:
	if is_instance_valid(_district):
		remove_child(_district)
		_district.queue_free()
	_district = Node3D.new()
	_district.name = "SkyPortDistrict"
	add_child(_district)
	var quarter_path := "res://assets/world/ports/home_base/city_quarter.glb"
	var quarter_scene: PackedScene = load(quarter_path) as PackedScene if ResourceLoader.exists(quarter_path) else null
	var ships: Dictionary = GameData.read("res://data/world/ship_visuals.json").get("ships", {})
	var ship_ids: Array[String] = ["premium_royal_schooner", "premium_golden_clipper", "premium_imperial_yacht"]
	var index: int = 0
	for at in _manifest.get("islands", []):
		var quarter: Node3D = quarter_scene.instantiate() as Node3D if quarter_scene != null else _procedural_quarter(faction_id)
		quarter.position = Vector3(float(at[0]), float(at[2]) + 0.9, -float(at[1]))
		quarter.scale = Vector3.ONE * 0.65
		_district.add_child(quarter)
		_style.apply_city_quarter(quarter, faction_id)
		var flag: Node3D = _style.make_flag(faction_id, 5.0)
		flag.position = quarter.position + Vector3(-3.0, 0.0, 0.0)
		_district.add_child(flag)
		if index < ship_ids.size():
			var definition: Dictionary = ships.get(ship_ids[index], {})
			var ship: Node3D = preload("res://systems/rendering/naval_ship_factory.gd").new().attach(_district, ship_ids[index], 5.8, true, faction_id)
			if ship == null:
				index += 1
				continue
			ship.name = "SkyMooredShip_%d" % index
			ship.position = Vector3(float(at[0]) + 5.0, float(at[2]) + 0.2, -float(at[1]) + float(at[3]) * 0.6)
			_style.apply_ship(ship, faction_id)
		index += 1

func _procedural_quarter(faction_id: String) -> Node3D:
	var quarter := Node3D.new()
	quarter.name = "ProceduralSkyQuarter"
	var color: Color = Color("819399")
	var profile: Dictionary = GameData.read("res://data/world/faction_architecture.json").get("profiles", {}).get(faction_id, {})
	var palette: Array = profile.get("palette", [])
	if not palette.is_empty(): color = Color(str(palette[0]))
	var hull := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(6.0, 2.0, 4.0)
	hull.mesh = body
	hull.position.y = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	hull.material_override = material
	quarter.add_child(hull)
	var roof := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.bottom_radius = 3.0
	cap.height = 2.0
	cap.radial_segments = 5
	roof.mesh = cap
	roof.position.y = 3.0
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("bd9456")
	roof.material_override = roof_material
	quarter.add_child(roof)
	return quarter

func set_night_strength(strength: float) -> void:
	_style.set_night_strength(strength)
