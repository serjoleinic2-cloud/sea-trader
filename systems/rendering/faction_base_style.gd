extends RefCounted

var _profiles: Dictionary = {}
var _materials: Dictionary = {}
var _lamp_glass: StandardMaterial3D
var _lights: Array[OmniLight3D] = []

func set_night_strength(strength: float) -> void:
	for key in _materials:
		if str(key).to_lower().contains("arcade"):
			var window: StandardMaterial3D = _materials[key]
			window.emission_energy_multiplier = strength * 0.75
	if _lamp_glass != null:
		_lamp_glass.emission_energy_multiplier = strength * 2.3
	for light in _lights:
		if is_instance_valid(light):
			light.light_energy = strength * 0.65
			light.visible = strength > 0.02

func apply(building: Node3D, building_id: String, faction_id: String, level: int) -> void:
	if _profiles.is_empty():
		_profiles = GameData.read("res://data/world/faction_architecture.json").get("profiles", {})
	var profile: Dictionary = _profiles.get(faction_id, _profiles.get("humans", {}))
	if profile.is_empty():
		return
	var palette: Array = profile.get("palette", [])
	_recolor(building, palette, faction_id)
	apply_surface_details(building)
	var detail_path: String = "res://assets/world/buildings/details/%s.glb" % building_id
	if ResourceLoader.exists(detail_path):
		var detail_scene: PackedScene = load(detail_path)
		var detail: Node3D = detail_scene.instantiate()
		detail.name = "CarvedArchitecturalDetails"
		var wall_height: float = 1.7 + float((level - 1) / 6) * 0.25 + float((level - 1) % 6) * 0.045
		detail.scale = Vector3(1.0 + float(level - 1) * 0.008, (0.3 + wall_height) / 3.225, 1.0)
		if building_id == "mage_guild":
			detail.scale = Vector3.ONE
		building.add_child(detail)
		_recolor(detail, palette, faction_id)
		apply_surface_details(detail)
	var path: String = str(profile.get("scene", ""))
	if ResourceLoader.exists(path):
		var model: PackedScene = load(path)
		var crown: Node3D = model.instantiate()
		crown.name = "FactionArchitecture"
		var height: float = 2.9 + float((level - 1) / 6) * 0.25
		if building_id == "mage_guild":
			height = 2.8
		elif building_id in ["dock", "fishing_wharf"]:
			height = 0.72
			crown.position.z = 1.4
		crown.position.y = height
		crown.scale = Vector3.ONE * (0.65 + float(level) * 0.008)
		building.add_child(crown)
	var flag: Node3D = make_flag(faction_id)
	flag.position = Vector3(-2.8, 0.0, 2.0)
	building.add_child(flag)
	var lantern: Node3D = _make_lantern(building_id in ["dock", "shipyard", "market", "mage_guild"])
	lantern.position = Vector3(1.1, 1.35, -1.9)
	if building_id in ["dock", "fishing_wharf"]:
		lantern.position = Vector3(-0.8, 0.9, -0.7)
	building.add_child(lantern)
	building.set_meta("architecture_faction", faction_id)

func _make_lantern(with_light: bool) -> Node3D:
	var lamp := Node3D.new()
	lamp.name = "KeroseneLamp"
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("765c32")
	metal.metallic = 0.45
	for y in [-0.15, 0.15]:
		var cap := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.13
		mesh.bottom_radius = 0.13
		mesh.height = 0.045
		mesh.radial_segments = 8
		cap.mesh = mesh
		cap.material_override = metal
		cap.position.y = y
		lamp.add_child(cap)
	if _lamp_glass == null:
		_lamp_glass = StandardMaterial3D.new()
		_lamp_glass.albedo_color = Color("d9a557")
		_lamp_glass.emission_enabled = true
		_lamp_glass.emission = Color("ffb65c")
		_lamp_glass.emission_energy_multiplier = 0.0
	var glass := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.24, 0.16)
	glass.mesh = mesh
	glass.material_override = _lamp_glass
	lamp.add_child(glass)
	if with_light:
		var light := OmniLight3D.new()
		light.light_color = Color("ffb65c")
		light.omni_range = 4.0
		light.shadow_enabled = false
		light.visible = false
		lamp.add_child(light)
		_lights = _lights.filter(func(old: OmniLight3D): return is_instance_valid(old))
		_lights.append(light)
	return lamp

func _recolor(node: Node, palette: Array, faction_id: String) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in range(node.mesh.get_surface_count()):
			var original: Material = node.mesh.surface_get_material(index)
			if not original is StandardMaterial3D:
				continue
			var key: String = faction_id + ":" + original.resource_name
			if not _materials.has(key):
				var material: StandardMaterial3D = original.duplicate()
				var name: String = original.resource_name.to_lower()
				if name.contains("low-poly forest"):
					material.vertex_color_use_as_albedo = true
					material.albedo_color = Color.WHITE
				if name.contains("roof"):
					material.albedo_color = Color(str(palette[0])).lerp(Color(str(palette[1])), 0.25)
				elif name.contains("painted"):
					material.albedo_color = Color(str(palette[0])).lerp(Color("245565"), 0.2)
				elif name.contains("turquoise trim"):
					material.albedo_color = Color(str(palette[1])).darkened(0.25)
					if material.emission_enabled:
						material.emission = Color(str(palette[1]))
						material.emission_energy_multiplier = 1.5
				elif name.contains("brass"):
					material.albedo_color = Color(str(palette[2]))
				elif name.contains("arcade"):
					material.emission_enabled = true
					material.emission = Color("ffb65c")
					material.emission_energy_multiplier = 0.0
				elif name.contains("sandstone") and faction_id in ["surr", "crystari"]:
					material.albedo_color = Color(str(palette[0])).lerp(Color("abb5b3"), 0.4)
				_materials[key] = material
			node.set_surface_override_material(index, _materials[key])
	for child in node.get_children():
		_recolor(child, palette, faction_id)

func apply_ship(ship: Node3D, faction_id: String) -> void:
	var faction: Dictionary = GameData.get_faction(faction_id)
	var palette: Array = faction.get("palette", ["#132b43", "#2bbcc1", "#c49a58"])
	_recolor(ship, palette, faction_id)
	apply_surface_details(ship)
	ship.set_meta("visual_faction", faction_id)

func apply_city_quarter(quarter: Node3D, faction_id: String) -> void:
	apply_ship(quarter, faction_id)
	var profiles: Dictionary = GameData.read("res://data/world/faction_architecture.json").get("profiles", {})
	var profile: Dictionary = profiles.get(faction_id, profiles.get("humans", {}))
	var scene: PackedScene = load(str(profile.get("scene", ""))) as PackedScene
	if scene == null:
		return
	for at in [[-3.0, 4.2, 2.0], [2.0, 5.3, 1.0], [-1.0, 3.8, -3.0], [4.0, 4.2, -3.0]]:
		var trim: Node3D = scene.instantiate()
		trim.position = Vector3(at[0], at[1], at[2])
		trim.scale = Vector3.ONE * 0.5
		quarter.add_child(trim)

func apply_tower(tower: Node3D, faction_id: String) -> void:
	if _profiles.is_empty():
		_profiles = GameData.read("res://data/world/faction_architecture.json").get("profiles", {})
	var profile: Dictionary = _profiles.get(faction_id, _profiles.get("humans", {}))
	_recolor(tower, profile.get("palette", []), faction_id)
	apply_surface_details(tower)
	var path: String = str(profile.get("scene", ""))
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var trim: Node3D = scene.instantiate()
		trim.name = "FactionTowerArchitecture"
		trim.position = Vector3(0, 5.8, -0.9)
		trim.scale = Vector3.ONE * 0.4
		tower.add_child(trim)

func apply_surface_details(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for index in range(node.mesh.get_surface_count()):
			var original: Material = node.get_surface_override_material(index)
			if original == null:
				original = node.mesh.surface_get_material(index)
			if not original is StandardMaterial3D or original.emission_enabled:
				continue
			var name: String = original.resource_name.to_lower()
			if name.begins_with("vr flowing water") or name.begins_with("vr waterfall foam"):
				var water_key: String = "waterfall:" + name
				if not _materials.has(water_key):
					var water := ShaderMaterial.new()
					water.shader = load("res://assets/world/materials/stylized_waterfall.gdshader")
					water.set_shader_parameter("tint", original.albedo_color)
					_materials[water_key] = water
				node.set_surface_override_material(index, _materials[water_key])
				continue
			if name.begins_with("illustrated "):
				var illustrated_key: String = "illustrated:" + name
				if not _materials.has(illustrated_key):
					var illustrated := ShaderMaterial.new()
					illustrated.shader = load("res://assets/world/materials/illustrated_environment.gdshader")
					illustrated.set_shader_parameter("tint", original.albedo_color)
					illustrated.set_shader_parameter("rock_surface", 1.0 if name.contains("rock") else 0.0)
					_materials[illustrated_key] = illustrated
				node.set_surface_override_material(index, _materials[illustrated_key])
				continue
			if name.contains("detailed tropical leaf spray") or name.contains("detailed tropical palm spray"):
				var key: String = "wind:" + name
				if not _materials.has(key):
					var foliage := ShaderMaterial.new()
					foliage.shader = load("res://assets/world/materials/tropical_leaf.gdshader")
					foliage.set_shader_parameter("leaf_texture", original.albedo_texture)
					_materials[key] = foliage
				node.set_surface_override_material(index, _materials[key])
				continue
			if name.contains("detailed tropical leaf spray") or name.contains("detailed tropical palm spray"):
				var leaf_key: String = "leaf:" + name
				if not _materials.has(leaf_key):
					var leaf_material: StandardMaterial3D = original.duplicate()
					leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					leaf_material.alpha_scissor_threshold = 0.35
					leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
					leaf_material.roughness = 0.72
					_materials[leaf_key] = leaf_material
				node.set_surface_override_material(index, _materials[leaf_key])
				continue
			var kind: float = 0.0
			if name.contains("basalt") or name.contains("weathered strata"):
				kind = 1.0
			elif name.contains("meadow") or name.contains("canopy"):
				kind = 2.0
			elif name.contains("roof"):
				kind = 3.0
			elif name.contains("teak"):
				kind = 4.0
			elif name.contains("limestone") or name.contains("sandstone"):
				kind = 5.0
			elif name.contains("plaster") or name.contains("residence"):
				kind = 6.0
			elif name.contains("sailcloth") or name.contains("canvas"):
				kind = 7.0
			if kind == 0.0:
				continue
			var texture_kind: String = {1: "basalt", 2: "foliage", 3: "slate", 4: "timber", 5: "limestone", 6: "plaster", 7: "canvas"}.get(int(kind), "plaster")
			var texture_path: String = "res://assets/world/materials/textures/%s_albedo.png" % texture_kind
			var game_texture: String = "res://assets/world/materials/textures/%s_game_albedo.png" % texture_kind
			if ResourceLoader.exists(game_texture):
				texture_path = game_texture
			if ResourceLoader.exists(texture_path):
				var texture_key: String = "textured:" + name + str(original.albedo_color)
				if not _materials.has(texture_key):
					var textured: StandardMaterial3D = original.duplicate()
					textured.albedo_texture = load(texture_path)
					if texture_path == game_texture:
						textured.albedo_color = Color.WHITE
					textured.normal_enabled = true
					textured.normal_texture = load("res://assets/world/materials/textures/%s_normal.png" % texture_kind)
					var game_normal: String = "res://assets/world/materials/textures/%s_game_normal.png" % texture_kind
					if ResourceLoader.exists(game_normal):
						textured.normal_texture = load(game_normal)
					textured.normal_scale = 0.20
					textured.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					textured.uv1_triplanar = true
					textured.uv1_world_triplanar = true
					textured.uv1_scale = Vector3.ONE * (0.055 if kind == 1.0 else 0.18 if kind == 5.0 else 0.35 if kind == 4.0 else 0.5)
					textured.roughness = 0.85
					_materials[texture_key] = textured
				node.set_surface_override_material(index, _materials[texture_key])
				continue
			var key: String = "surface:" + name + str(original.albedo_color)
			if not _materials.has(key):
				var material := ShaderMaterial.new()
				material.shader = load("res://assets/world/materials/maritime_surface.gdshader")
				material.set_shader_parameter("tint", original.albedo_color)
				material.set_shader_parameter("surface_kind", kind)
				material.set_shader_parameter("metallic_amount", original.metallic)
				_materials[key] = material
			node.set_surface_override_material(index, _materials[key])
	for child in node.get_children():
		apply_surface_details(child)

func make_flag(faction_id: String, height: float = 4.5) -> Node3D:
	var flag := Node3D.new()
	flag.name = "HeraldicFlagpole"
	flag.set_meta("emblem_faction", faction_id)
	var pole := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.045
	cylinder.bottom_radius = 0.065
	cylinder.height = height
	cylinder.radial_segments = 8
	pole.mesh = cylinder
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("a37a42")
	brass.metallic = 0.5
	pole.material_override = brass
	pole.position.y = height * 0.5
	if ResourceLoader.exists("res://assets/world/props/heraldry/flagpole.glb"):
		var pole_scene: PackedScene = load("res://assets/world/props/heraldry/flagpole.glb")
		var imported_pole: Node3D = pole_scene.instantiate()
		imported_pole.scale.y = height / 4.5
		flag.add_child(imported_pole)
		pole.free()
	else:
		flag.add_child(pole)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in range(6):
		for x in range(9):
			var uv := Vector2(float(x) / 8.0, float(y) / 5.0)
			vertices.append(Vector3(uv.x * 1.5, height - 0.1 - uv.y * 1.2, 0))
			normals.append(Vector3.FORWARD)
			uvs.append(uv)
	for y in range(5):
		for x in range(8):
			var at: int = y * 9 + x
			indices.append_array(PackedInt32Array([at, at + 9, at + 1, at + 1, at + 9, at + 10]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var cloth := MeshInstance3D.new()
	cloth.name = "FixedFactionEmblem"
	cloth.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/world/props/heraldry/flag_cloth.gdshader")
	material.set_shader_parameter("emblem", GameData.get_faction_emblem(faction_id))
	var faction: Dictionary = GameData.get_faction(faction_id)
	var palette: Array = faction.get("palette", ["#132b43"])
	material.set_shader_parameter("cloth_color", Color(str(palette[0])))
	cloth.material_override = material
	flag.add_child(cloth)
	return flag
