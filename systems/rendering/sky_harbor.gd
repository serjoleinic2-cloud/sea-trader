extends Node3D
## Visual sky port; independent of the saved economy and sea navigation.
var _manifest: Dictionary
var _district: Node3D
var _style = preload("res://systems/rendering/faction_base_style.gd").new()
var _clouds: Array[MeshInstance3D] = []
var _clock: float = 0.0
var _cloud_material: StandardMaterial3D

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
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.75, 0.85, 0.85, 0.20)
	_cloud_material = material
	for index in range(12):
		var cloud := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		cloud.mesh = sphere
		cloud.material_override = material
		cloud.scale = Vector3(7.0 + float(index % 3) * 2.0, 3.0 + float(index % 2), 5.0)
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)
		_clouds.append(cloud)

func set_faction(faction_id: String) -> void:
	if is_instance_valid(_district):
		remove_child(_district)
		_district.queue_free()
	_district = Node3D.new()
	_district.name = "SkyPortDistrict"
	add_child(_district)
	var quarter_scene: PackedScene = load("res://assets/world/ports/home_base/city_quarter.glb")
	var ships: Dictionary = GameData.read("res://data/world/ship_visuals.json").get("ships", {})
	var ship_ids: Array[String] = ["premium_royal_schooner", "premium_golden_clipper", "premium_imperial_yacht"]
	var index: int = 0
	for at in _manifest.get("islands", []):
		var quarter: Node3D = quarter_scene.instantiate()
		quarter.position = Vector3(float(at[0]), float(at[2]) + 0.9, -float(at[1]))
		quarter.scale = Vector3.ONE * 0.65
		_district.add_child(quarter)
		_style.apply_city_quarter(quarter, faction_id)
		var flag: Node3D = _style.make_flag(faction_id, 5.0)
		flag.position = quarter.position + Vector3(-3.0, 0.0, 0.0)
		_district.add_child(flag)
		if index < ship_ids.size():
			var definition: Dictionary = ships.get(ship_ids[index], {})
			var variant: Dictionary = GameData.read("res://data/world/faction_ship_visuals.json").get("factions", {}).get(faction_id, {}).get(ship_ids[index], {})
			var ship_scene: PackedScene = load(str(variant.get("scene", definition.get("scene", ""))))
			var ship: Node3D = ship_scene.instantiate()
			ship.name = "SkyMooredShip_%d" % index
			ship.position = Vector3(float(at[0]) + 5.0, float(at[2]) + 0.2, -float(at[1]) + float(at[3]) * 0.6)
			ship.scale = Vector3.ONE * 5.8 / float(definition.get("length", 8.5))
			_district.add_child(ship)
			_style.apply_ship(ship, faction_id)
			var ship_flag: Node3D = _style.make_flag(faction_id, 2.0)
			ship_flag.position = Vector3(0, 3.0, 0)
			ship.add_child(ship_flag)
		index += 1

func set_night_strength(strength: float) -> void:
	_style.set_night_strength(strength)
	if _cloud_material != null:
		_cloud_material.albedo_color = Color(0.75, 0.85, 0.85, 0.20).lerp(Color(0.10, 0.16, 0.23, 0.15), strength)

func _process(delta: float) -> void:
	_clock += delta
	for index in range(_clouds.size()):
		var group: int = index / 3
		var phase: float = float(group) * TAU / 4.0 + _clock * 0.025
		var sky_height: float = 92.0 if bool(_manifest.get("above_peaks", false)) else 47.0
		_clouds[index].position = Vector3(cos(phase) * 30.0 + float(index % 3) * 5.0, sky_height + float(group) * 8.0 + sin(float(index)) * 1.5, 48.0 + sin(phase) * 20.0)
