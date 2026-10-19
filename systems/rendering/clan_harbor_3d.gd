extends Node3D

## Lightweight modular clan-base placeholder; future approved models stay local.
func setup(radius: float, outward: Vector2, faction_id: String, wings: int, logo_png: String, modules: Dictionary = {}, style_id: String = "") -> void:
	rotation.y = -outward.angle() - PI * 0.5
	if _load_local_base(radius, faction_id, modules, style_id, logo_png): return
	var palette: Array = GameData.get_faction(faction_id).get("palette", ["#153149", "#38a6b5", "#c49a58"])
	var dark := Color(str(palette[0]))
	var accent := Color(str(palette[1]))
	var brass := Color(str(palette[2]))
	var decoration: Dictionary = GameData.read("res://data/social/expeditions_and_collection.json").get("styles", {}).get(style_id, {})
	if str(decoration.get("slot", "")) == "harbor":
		dark = dark.lerp(Color(str(decoration.tint)), 0.6)
		accent = Color(str(decoration.accent))
	var disk := CylinderMesh.new()
	disk.top_radius = radius * 0.96; disk.bottom_radius = radius; disk.height = 1.6; disk.radial_segments = 16
	_mesh(disk, Vector3(0, -0.3, 0), dark)
	_box(Vector3(radius * 0.7, 1, radius * 0.85), Vector3(0, 0.8, 0), brass.darkened(0.4))
	_box(Vector3(radius * 0.25, 3, radius * 0.3), Vector3(0, 2.7, radius * 0.1), dark)
	_box(Vector3(radius * 0.3, 0.35, radius * 0.35), Vector3(0, 4.4, radius * 0.1), brass)
	_box(Vector3(radius * 0.3, 0.4, radius * 0.4), Vector3(0, 0.65, -radius * 0.9), brass.darkened(0.3))
	for index in clampi(wings, 0, 4):
		var side: float = -1 if index % 2 == 0 else 1
		var z: float = radius * (0.4 if index < 2 else -0.35)
		_box(Vector3(radius * 0.38, 0.4, radius * 0.22), Vector3(side * radius * 0.55, 0.8, z), brass.darkened(0.35))
		_box(Vector3(radius * 0.16, 2.1, radius * 0.16), Vector3(side * radius * 0.63, 2.05, z), dark)
		_box(Vector3(radius * 0.18, 0.25, radius * 0.18), Vector3(side * radius * 0.63, 3.25, z), accent)
	var mast := CylinderMesh.new(); mast.top_radius = 0.1; mast.bottom_radius = 0.12; mast.height = 8
	_mesh(mast, Vector3(0, 5.5, radius * 0.1), brass)
	var flag := MeshInstance3D.new(); var plane := QuadMesh.new(); plane.size = Vector2(3.2, 3.2); flag.mesh = plane
	flag.position = Vector3(1.65, 7.5, radius * 0.1)
	var material := StandardMaterial3D.new(); material.cull_mode = BaseMaterial3D.CULL_DISABLED; material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var image := Image.new()
	material.albedo_texture = ImageTexture.create_from_image(image) if logo_png != "" and image.load_png_from_buffer(Marshalls.base64_to_raw(logo_png)) == OK else GameData.get_faction_emblem(faction_id)
	flag.material_override = material; add_child(flag)
	for key in modules:
		var level: int = clampi(int(modules[key]), 0, 3)
		if level == 0: continue
		match str(key):
			"beacon":
				var tower := CylinderMesh.new()
				tower.top_radius = radius * 0.045; tower.bottom_radius = radius * 0.07; tower.height = 3.0 + level * 1.5; tower.radial_segments = 10
				_mesh(tower, Vector3(-radius * 0.65, tower.height * 0.5 + 0.6, -radius * 0.4), dark)
				var lamp := SphereMesh.new(); lamp.radius = radius * 0.055; lamp.height = lamp.radius * 2
				var beacon: MeshInstance3D = _mesh(lamp, Vector3(-radius * 0.65, tower.height + 0.7, -radius * 0.4), accent)
				beacon.material_override.emission_enabled = true
				beacon.material_override.emission = accent
			"dock":
				for index in level: _box(Vector3(radius * 0.13, 0.3, radius * 0.6), Vector3(radius * (0.4 + index * 0.14), 0.7, -radius * 0.6), brass.darkened(0.4))
			"trophy":
				_box(Vector3(radius * 0.28, 1.2 + level * 0.5, radius * 0.25), Vector3(radius * 0.4, 1.4, radius * 0.4), dark)
				for index in level + 1: _box(Vector3(radius * 0.035, 2 + level * 0.5, radius * 0.04), Vector3(radius * (0.26 + index * 0.08), 1.7, radius * 0.24), brass)
			"garden":
				for index in level * 2:
					var leaves := SphereMesh.new(); leaves.radius = radius * 0.055; leaves.height = leaves.radius * 1.4; leaves.radial_segments = 8; leaves.rings = 4
					_mesh(leaves, Vector3(-radius * (0.2 + index * 0.09), 1.2, radius * 0.45), Color("327d67"))

func _load_local_base(radius: float, race: String, modules: Dictionary, style_id: String, logo_png: String) -> bool:
	var catalog: Dictionary = GameData.read("res://data/social/base_model_slots.json")
	var path: String = str(catalog.base).replace("{race}", race)
	if not ResourceLoader.exists(path): return false
	var scene: PackedScene = load(path) as PackedScene
	if scene == null: return false
	var base: Node3D = scene.instantiate()
	base.name = "LocalClanBase"
	base.scale *= radius / float(catalog.reference_radius)
	add_child(base)
	for key in catalog.anchors:
		var level: int = clampi(int(modules.get(str(key), 0)), 0, 3)
		if level == 0: continue
		var anchor: Node3D = base.find_child(str(catalog.anchors[key]), true, false) as Node3D
		var module_path: String = str(catalog.module).replace("{race}", race).replace("{module}", str(key)).replace("{level}", str(level))
		if anchor != null and ResourceLoader.exists(module_path):
			var module_scene: PackedScene = load(module_path) as PackedScene
			if module_scene != null: anchor.add_child(module_scene.instantiate())
	set_meta("local_base_path", path)
	set_meta("harbor_style", style_id)
	preload("res://systems/rendering/company_appearance.gd").apply(base, [style_id] if style_id != "" else [])
	var flag: MeshInstance3D = base.find_child(str(catalog.flag_mesh), true, false) as MeshInstance3D
	if flag != null:
		var material := StandardMaterial3D.new()
		var image := Image.new()
		material.albedo_texture = ImageTexture.create_from_image(image) if logo_png != "" and image.load_png_from_buffer(Marshalls.base64_to_raw(logo_png)) == OK else GameData.get_faction_emblem(race)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material_override = material
	return true

func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new(); mesh.size = size; _mesh(mesh, at, color)

func _mesh(mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh = mesh; node.position = at
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.8
	node.material_override = material; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(node)
	return node
