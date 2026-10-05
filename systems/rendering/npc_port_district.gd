extends Node3D

## Small ports share the city's editable architecture and racial detail kits.
var _style = preload("res://systems/rendering/faction_base_style.gd").new()

func setup(faction_id: String, size_m: float) -> void:
	var manifest: Dictionary = GameData.read("res://data/world/home_base_visuals.json")
	var quarter_path: String = str(manifest.get("city_quarter", "res://assets/world/ports/home_base/city_quarter.glb"))
	var packed: PackedScene = load(quarter_path) as PackedScene
	if packed == null:
		return
	var scale_factor: float = clampf(size_m / 30.0, 0.35, 1.0)
	for index in range(3):
		var quarter := packed.instantiate() as Node3D
		quarter.position = Vector3(float(index - 1) * 7.5 * scale_factor, 1.1, -3.8)
		quarter.scale = Vector3.ONE * scale_factor
		add_child(quarter)
		_style.apply_city_quarter(quarter, faction_id)
		var flag: Node3D = _style.make_flag(faction_id)
		flag.position = quarter.position + Vector3(0.0, 0.0, 2.0)
		flag.scale = Vector3.ONE * 0.5
		add_child(flag)
	var lighthouse: PackedScene = load("res://assets/world/props/lighthouse/stylized_lighthouse.glb") as PackedScene
	if lighthouse != null:
		var tower := lighthouse.instantiate() as Node3D
		tower.position = Vector3(6.5 * scale_factor, 0.0, 0.0)
		tower.scale = Vector3.ONE * 0.6
		add_child(tower)
		_style.apply_surface_details(tower)

func set_night_strength(strength: float) -> void:
	_style.set_night_strength(strength)
